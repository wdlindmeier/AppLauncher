//
//  ITPDocument.m
//  AppLauncher
//
//  Created by William Lindmeier on 9/21/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import "ITPDocument.h"
#import "ITPApp.h"
#include "GCDAsyncSocket.h"

typedef void (^ConnectionCompletionBlock)(void);

@interface ITPDocument()

@property (atomic, assign) int numAppsLaunched;
@property (atomic, strong) NSMutableDictionary *sockets;
@property (atomic, strong) ConnectionCompletionBlock connectedBlock;
@property (atomic, assign) BOOL isAdvancing;

@end

@implementation ITPDocument
{
    NSString *_xmlElementName;
    NSMutableString *_xmlElementValue;
    NSMutableArray *_apps;
    NSMutableArray *_clientAddresses;
    ITPApp *_lastApp;
    NSString *_currentClientAddress;
    int _currentAppIndex;
    NSTimer *_timer;
    NSTimeInterval _timeAppLaunched;
    BOOL _isPlaying;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _xmlElementName = nil;
        _currentAppIndex = -1;
        self.isAdvancing = NO;
        self.connectedBlock = nil;
        self.isDebug = true;
        self.timeSleepBetweenLaunches = 3.0f;

    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"ITPDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.

    // self.shouldLoop = NO;
    // self.shouldAutoAdvance = YES;
    
    self.currentAppName = @"None";
    self.currentTimeRemaining = @"--";
    
    self.numAppsLaunched = 0;
    
    [self updateViewForApps];
    
    [self connectToHosts];
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (void)close
{
    [self disconnectSockets];
    [super close];
}

#pragma mark - View

- (void)updateViewForApps
{
    if (_apps.count > 0)
    {
        // self.tableView.selectedRow = 0;
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                    byExtendingSelection:NO];
        [self.buttonStart setEnabled:YES];
        [self.buttonStop setEnabled:NO];
    }
    else
    {
        [self.buttonStart setEnabled:NO];
        [self.buttonStop setEnabled:NO];
    }
}

#pragma mark - Socket Delegate

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	NSLog(@"socket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    if (self.connectedBlock)
    {
        BOOL allAreConnected = YES;
        for (NSString *hostName in self.sockets)
        {
            GCDAsyncSocket *socket = self.sockets[hostName];
            if (!socket.isConnected)
            {
                allAreConnected = NO;
                break;
            }
        }
        if (allAreConnected)
        {
            dispatch_async(dispatch_get_main_queue(), self.connectedBlock);
            self.connectedBlock = nil;
        }
    }
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
	NSLog(@"socketDidSecure:%p", sock);
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	NSLog(@"socket:%p didWriteDataWithTag:%ld", sock, tag);
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    NSArray *tokens = [response componentsSeparatedByString:kCommandParamDelim];
    
    if (tokens.count > 0)
    {
        NSString *command = tokens[0];

        if ([command isEqualToString:kCommandAppWasLaunched]
            && self.numAppsLaunched < self.sockets.count)
        {
            self.numAppsLaunched += 1;;
            
            if (self.numAppsLaunched >= self.sockets.count)
            {
                NSLog(@"ALL APPS LAUNCHED. Starting timer.");
                dispatch_async(dispatch_get_main_queue(), ^{
                    _timeAppLaunched = [NSDate timeIntervalSinceReferenceDate];
                    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0f
                                                              target:self
                                                            selector:@selector(updateTimer)
                                                            userInfo:NULL
                                                             repeats:YES];
                });
            }
        }
        else if ([command isEqualToString:kCommandAppWasKilled] && self.numAppsLaunched > 0)
        {
            self.numAppsLaunched -= 1;
            [self advanceIfAllAppsKilled];
        }
        else if ([command isEqualToString:kCommandError])
        {
            if (tokens.count > 3)
            {
                NSString *errorTask = tokens[1];
                NSString *appID = tokens[2];
                NSString *errorReason = tokens[3];
                int appIdx = [appID intValue];
                ITPApp *app = _apps[appIdx];
                assert(app.appID == appIdx); // These should be the same
                
                if (!errorReason || errorReason.length == 0)
                {
                    if ([errorTask isEqualToString:kCommandKillApp])
                    {
                        errorReason = @"Unknown. Make sure your kill name is correct.";
                    }
                    else if([errorTask isEqualToString:kCommandLaunchApp])
                    {
                        errorReason = @"Unknown. Make sure your launch path is correct and the same on all machines.";
                    }
                    else
                    {
                        errorReason = @"Unknown";
                    }
                }
                NSLog(@"ERROR completing task: %@ on app %@. Reason:\n%@",
                      errorTask, app.name, errorReason);
                
                if ([errorTask isEqualToString:kCommandKillApp])
                {
                    // Set the current app index so reset doesn't try to kill it again.
                    _currentAppIndex = -1;
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Kill everything
                    [self buttonStopPressed:nil];
                });
                
                NSString *titleString = [NSString stringWithFormat:@"Error on %@", sock.connectedHost];
                if (self.isDebug)
                {
                    NSAlert *alert = [NSAlert alertWithMessageText:titleString
                                                     defaultButton:@"OK"
                                                   alternateButton:nil
                                                       otherButton:nil
                                         informativeTextWithFormat:@"There was an error completing the task: %@\nApp: %@\nReason: %@",
                                      errorTask, app.name, errorReason];
                    [alert runModal];
                }
            }
        }
    }
    
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"socketDidDisconnect: %p withError: %@", sock, err);
    NSLog(@"HOST: %@", sock.connectedHost);
    if (self.connectedBlock)
    {
        self.connectedBlock = nil;
        NSString *disconnectedHost = nil;
        for (NSString *hostName in self.sockets)
        {
            if (self.sockets[hostName] == sock)
            {
                disconnectedHost = hostName;
                break;
            }
        }
        if (disconnectedHost)
        {
            if (self.isDebug)
            {
                NSAlert *alert = [NSAlert alertWithMessageText:@"Client Disconnected"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"%@ has disconnected.", disconnectedHost];
                [alert runModal];
            }
        }
    }
}

#pragma mark - Socket Communication

- (void)sendMessage:(NSString *)message toSocket:(GCDAsyncSocket *)socket
{
    if ([socket isConnected])
    {
        //NSLog(@"Sending string on socket: %@", socket);
        NSLog(@"Sending message: %@", message);
        [socket writeData:[message dataUsingEncoding:NSUTF8StringEncoding]
              withTimeout:-1
                      tag:0];
        [socket readDataWithTimeout:-1 tag:0];
    }
    else
    {
        NSLog(@"ERROR: Socket is not connected");
    }
}

#pragma mark - Connection

- (void)connectToHosts
{
    self.sockets = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    for (NSString *clientIP in _clientAddresses)
    {
        GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                            delegateQueue:dispatch_get_main_queue()];
        
        NSError *connectError = nil;
        if (![socket connectToHost:clientIP onPort:kConnectionPort error:&connectError])
        {
            NSLog(@"ERROR: Couldn't connect to socket: %@", connectError);
        }
        
        // Always add the socket event if it doesn't
        // connect because we can reconnect later
        self.sockets[clientIP] = socket;
    }
}

- (void)performUponConnection:(ConnectionCompletionBlock)completionBlock
{
    self.connectedBlock = completionBlock;
    int numConnected = 0;
    
    // Make sure all of the sockets are connected
    for (NSString *hostName in self.sockets)
    {
        GCDAsyncSocket *socket = self.sockets[hostName];
        
        if (socket.isConnected)
        {
            numConnected += 1;
        }
        else
        {
            NSError *connectError = nil;
            if (![socket connectToHost:hostName
                                onPort:kConnectionPort
                                 error:&connectError])
            {
                self.connectedBlock = nil;
                
                NSString *errorMessage = [NSString stringWithFormat:@"Couldn't reconnect to host %@\n%@",
                                          hostName,
                                          [connectError localizedDescription]];
                NSLog(@"CONNECTION ERROR:\n%@", connectError);
                
                NSAlert *alert = [NSAlert alertWithMessageText:@"Connection Error"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"%@", errorMessage];
                [alert runModal];
            }
        }
    }
    if (numConnected == self.sockets.count)
    {
        self.connectedBlock = nil;
        completionBlock();
    }
}

- (void)disconnectSockets
{
    // Stop any client connections
    @synchronized(self.sockets)
    {
        for (NSString *hostName in self.sockets)
        {
            [(GCDAsyncSocket *)self.sockets[hostName] disconnect];
        }
    }
}

#pragma mark - File Handling

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    self.displayName = [[[[self fileURL] absoluteString] componentsSeparatedByString:@"/"] lastObject];
    
    NSXMLParser * parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    [parser parse];

    return YES;
}

#pragma mark - Apps

// Make sure each client also has the attributes of the default client.
- (void)updateLastAppLaunchDefaults
{
    ITPClientLaunch *defaultLaunch = _lastApp.clientLaunches[kITPClientKeyDefault];
    // NSLog(@"defaultLaunch: %@", defaultLaunch);
    if (defaultLaunch)
    {
        for (NSString *clientAddress in _lastApp.clientLaunches)
        {
            if (clientAddress != kITPClientKeyDefault)
            {
                ITPClientLaunch *clientLaunch = _lastApp.clientLaunches[clientAddress];
                if (clientLaunch.type == AppLaunchTypeUnknown)
                {
                    clientLaunch.type = defaultLaunch.type;
                    switch (clientLaunch.type)
                    {
                        case AppLaunchTypeAppPath:
                        case AppLaunchTypeVideo:
                            clientLaunch.path = defaultLaunch.path;
                            break;
                        case AppLaunchTypeCommand:
                            clientLaunch.command = defaultLaunch.command;
                            break;
                        case AppLaunchTypeWebURL:
                            clientLaunch.webURL = defaultLaunch.webURL;
                            break;
                        default:
                            break;
                    }
                }
                
                if (!clientLaunch.killName)
                {
                    clientLaunch.killName = defaultLaunch.killName;
                }
                
                if (!clientLaunch.wallpaperPath)
                {
                    clientLaunch.wallpaperPath = defaultLaunch.wallpaperPath;
                }
                
                // NSLog(@"clientLaunch: %@", clientLaunch);

            }
        }
    }
}

#pragma mark - XML

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    _apps = [NSMutableArray new];
    _clientAddresses = [NSMutableArray new];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict
{
    [self handleLastXMLElement];
    _currentClientAddress = attributeDict[kXMLElementClientIP];
    if (!_currentClientAddress)
    {
        // Send any unspecified params to "default" (all)
        _currentClientAddress = kITPClientKeyDefault;
    }
    _xmlElementName = elementName;
    _xmlElementValue = [[NSMutableString alloc] init];
    if ([_xmlElementName isEqualToString:kXMLElementApp])
    {
        if (_lastApp)
        {
            [self updateLastAppLaunchDefaults];
        }
        _lastApp = [ITPApp new];
        _lastApp.appID = _apps.count;
        [_apps addObject:_lastApp];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [_xmlElementValue appendString:string];
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
    [self handleLastXMLElement];
    _xmlElementName = nil;

    if (_lastApp)
    {
        [self updateLastAppLaunchDefaults];
    }
    
    NSLog(@"Done loading document.\nApps:\n%@\nClients:\n%@", _apps, _clientAddresses);
    [self updateViewForApps];
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
    NSLog(@"XML Parse Error: %@", parseError);
    NSString *errorMessage = [parseError userInfo][@"NSXMLParserErrorMessage"];
    NSAlert *alert = [NSAlert alertWithMessageText:@"Schedule Error"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", errorMessage];
    [alert runModal];
}

BOOL XMLToBOOL(NSString *xmlValue)
{
    NSString *lcv = [[xmlValue lowercaseString]
                     stringByTrimmingCharactersInSet:[NSCharacterSet 
                                                      whitespaceAndNewlineCharacterSet]];
    return lcv && lcv.length > 0 && ([lcv isEqualToString:@"1"] || [lcv isEqualToString:@"true"]);
}

- (ITPClientLaunch *)currentLaunch
{
    ITPClientLaunch *launch = _lastApp.clientLaunches[_currentClientAddress];
    if (!launch)
    {
        launch = [[ITPClientLaunch alloc] init];
        launch.clientAddress = _currentClientAddress;
        NSMutableDictionary *launches = [NSMutableDictionary
                                         dictionaryWithDictionary:_lastApp.clientLaunches];
        launches[_currentClientAddress] = launch;
        _lastApp.clientLaunches = [launches copy];
    }
    return launch;
}

- (void)handleLastXMLElement
{
    NSString *value = [_xmlElementValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([_xmlElementName isEqualToString:kXMLElementDurationSeconds])
    {
        _lastApp.durationSeconds = @([value integerValue]);
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchUrl])
    {
        [self currentLaunch].webURL = value;
        [self currentLaunch].type = AppLaunchTypeWebURL;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchCommand])
    {
        [self currentLaunch].command = value;
        [self currentLaunch].type = AppLaunchTypeCommand;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchApp])
    {
        [self currentLaunch].path = value;
        [self currentLaunch].type = AppLaunchTypeAppPath;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchVideo])
    {
        [self currentLaunch].path = value;
        [self currentLaunch].type = AppLaunchTypeVideo;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementKillName])
    {
        [self currentLaunch].killName = value;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementName])
    {
        _lastApp.name = value;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementWallpaperPath])
    {
        [self currentLaunch].wallpaperPath = value;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementShouldLoop])
    {
        self.shouldLoop = XMLToBOOL(value);
    }
    else if ([_xmlElementName isEqualToString:kXMLElementAutoAdvance])
    {
        self.shouldAutoAdvance = XMLToBOOL(value);
    }
    else if ([_xmlElementName isEqualToString:kXMLElementSleepBetweenApps])
    {
        self.timeSleepBetweenLaunches = [value floatValue];
    }
    else if ([_xmlElementName isEqualToString:kXMLElementDebug])
    {
        self.isDebug = XMLToBOOL(value);
    }
    else if ([_xmlElementName isEqualToString:kXMLElementClientIP])
    {
        [_clientAddresses addObject:value];
    }
}

#pragma mark - App Management

- (void)launchNextApp
{
    if (!_isPlaying)
    {
        return;
    }

    _currentAppIndex++;
    if (self.shouldLoop)
    {
        _currentAppIndex = _currentAppIndex % _apps.count;
    }
    
    if (_currentAppIndex < _apps.count)
    {
        [self launchApp:_apps[_currentAppIndex]];
    }
    else
    {
        _isPlaying = NO;
        [self.buttonStart setEnabled:YES];
        [self.buttonStop setEnabled:NO];
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                    byExtendingSelection:NO];
    }
}

- (void)launchApp:(ITPApp *)app
{
    [self performUponConnection:^() {
        
        [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_currentAppIndex]
                    byExtendingSelection:NO];
        
        [self.buttonStart setEnabled:NO];
        [self.buttonStop setEnabled:YES];
        
        self.currentAppName = app.name;
        self.currentTimeRemaining = @"--";
        self.numAppsLaunched = 0;
        
        for (NSString *hostName in self.sockets)
        {
            ITPClientLaunch *launch = app.clientLaunches[hostName];
            if (!launch)
            {
                launch = app.clientLaunches[kITPClientKeyDefault];
                assert(launch);
            }
            NSString *value;
            if (launch.type == AppLaunchTypeCommand)
            {
                value = launch.command;
            }
            else if (launch.type == AppLaunchTypeWebURL)
            {
                value = launch.webURL;
            }
            else if (launch.type == AppLaunchTypeAppPath)
            {
                value = launch.path;
            }
            else if (launch.type == AppLaunchTypeVideo)
            {
                value = launch.path;
            }
            NSString *message = [NSString stringWithFormat:@"%@%@%i%@%@%@%i%@%@",
                                 kCommandLaunchApp,
                                 kCommandParamDelim,
                                 app.appID,
                                 kCommandParamDelim,
                                 value,
                                 kCommandParamDelim,
                                 launch.type,
                                 kCommandParamDelim,
                                 launch.wallpaperPath ? launch.wallpaperPath : @""];
            [self sendMessage:message toSocket:self.sockets[hostName]];
        }
    }];
}

- (void)killApp:(ITPApp *)app
{
    [self performUponConnection:^()
    {
        [_timer invalidate];
        _timer = nil;
        
        for (NSString *hostName in self.sockets)
        {
            ITPClientLaunch *launch = app.clientLaunches[hostName];
            if (!launch)
            {
                launch = app.clientLaunches[kITPClientKeyDefault];
                assert(launch);
            }
            
            if (launch.killName)
            {
                NSString *killMessage = [NSString stringWithFormat:@"%@%@%i%@%@",
                                         kCommandKillApp,
                                         kCommandParamDelim,
                                         app.appID,
                                         kCommandParamDelim,
                                         launch.killName];
            
                [self sendMessage:killMessage toSocket:self.sockets[hostName]];
            }
            else
            {
                // NOTE: If there is no kill name, let it keep running.
                // This can be used for MPE Server.
                self.numAppsLaunched -= 1;
            }
        }

        [self.buttonStart setEnabled:YES];
        [self.buttonStop setEnabled:NO];
        
        self.currentAppName = @"None";
        self.currentTimeRemaining = @"--";
        
        [self advanceIfAllAppsKilled];
    }];
}

- (void)advanceIfAllAppsKilled
{
    // Added a lock (self.isAdvancing) around the timeout.
    // We don't want to advance more than once during the delay.
    if (!self.isAdvancing &&
        self.numAppsLaunched <= 0 &&
        self.shouldAutoAdvance)
    {
        NSLog(@"ALL APPS KILLED. Advancing.");
        self.isAdvancing = YES;
        double delayInSeconds = self.timeSleepBetweenLaunches;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void)
                       {
                           self.isAdvancing = NO;
                           [self launchNextApp];
                       });
    }
}

#pragma mark - Timer

- (void)updateTimer
{
    NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delta = ti - _timeAppLaunched;
    ITPApp *currentApp = _apps[_currentAppIndex];
    int secondsAppDuration = [currentApp.durationSeconds intValue];
    if (secondsAppDuration > 0)
    {
        int secondsAppRemain = secondsAppDuration - (int)delta;

        int minutes = secondsAppRemain / 60;
        int seconds = secondsAppRemain % 60;
        int hours = minutes / 60;
        minutes = minutes % 60;
        if (hours > 0)
        {
            self.currentTimeRemaining = [NSString stringWithFormat:@"%i:%02i:%02i", hours, minutes, seconds];
        }
        else
        {
            self.currentTimeRemaining = [NSString stringWithFormat:@"%02i:%02i", minutes, seconds];
        }
        
        if (secondsAppRemain <= 0)
        {
            [self killApp:currentApp];
        }
    }
    else
    {
        // The duration is 0. Never force quit.
        self.currentTimeRemaining = @"∞";
    }
}

#pragma mark - IBAction

- (IBAction)buttonStartPressed:(id)sender
{
    _isPlaying = YES;
    _currentAppIndex = (int)self.tableView.selectedRow - 1;
    [self launchNextApp];
}

- (IBAction)buttonStopPressed:(id)sender
{
    if (_currentAppIndex > -1)
    {
        [self killApp:_apps[_currentAppIndex]];
    }
    _currentAppIndex = -1;
    _isPlaying = NO;
}

#pragma mark - Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return _apps.count;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex
{
    ITPApp *app = _apps[rowIndex];
    if ([aTableColumn.identifier isEqualToString:@"name"])
    {
        return app.name;
    }
    else if ([aTableColumn.identifier isEqualToString:@"duration"])
    {
        return app.durationSeconds;
    }
    else if ([aTableColumn.identifier isEqualToString:@"auto kill"])
    {
        int possibleKills = (int)app.clientLaunches.count;
        int numKills = 0;

        for (NSString *clientAddr in app.clientLaunches)
        {
            ITPClientLaunch *launch = app.clientLaunches[clientAddr];
            if (launch.killName)
            {
                numKills++;
            }
        }
        if (numKills == possibleKills)
        {
            return @"True";
        }
        else if (numKills == 0)
        {
            return @"False";
        }

        return [NSString stringWithFormat:@"%i/%i", numKills, possibleKills];
    }
    return @"?";
}

@end
