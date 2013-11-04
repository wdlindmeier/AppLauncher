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

@end

@implementation ITPDocument
{
    NSString *_xmlElementName;
    NSMutableString *_xmlElementValue;
    NSMutableArray *_apps;
    NSMutableArray *_clientAddresses;
    ITPApp *_lastApp;
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

    // TODO: Load from settings
    self.shouldLoop = NO;
    self.shouldAutoAdvance = YES;
    
    self.currentAppName = @"None";
    self.currentTimeRemaining = @"--";
    
    self.numAppsLaunched = 0;
    
    [self updateViewForApps];
    
    [self connectToHosts];
}

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

+ (BOOL)autosavesInPlace
{
    return NO;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
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
//	NSLog(@"socket:%p didReadData:%@ withTag:%ld", sock, response, tag);
    
    NSArray *tokens = [response componentsSeparatedByString:kCommandParamDelim];
    
    if (tokens.count > 0)
    {
        NSString *command = tokens[0];
        // TODO: This should varify that it's the correct app name
        if ([command isEqualToString:kCommandAppWasLaunched] && self.numAppsLaunched < self.sockets.count)
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
            
            if (self.numAppsLaunched <= 0 && self.shouldAutoAdvance)
            {
                NSLog(@"ALL APPS KILLED. Advancing.");
                double delayInSeconds = self.timeSleepBetweenLaunches;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self launchNextApp];
                });
            }
        }
        else if ([command isEqualToString:kCommandError])
        {
            if (tokens.count > 3)
            {
                NSString *errorTask = tokens[1];
                NSString *appName = tokens[2];
                NSString *errorReason = tokens[3];
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
                NSLog(@"ERROR completing task: %@ on app %@. Reason:\n%@", errorTask, appName, errorReason);
                
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
                                      errorTask, appName, errorReason];
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
        NSLog(@"Sending string on socket: %@", socket);
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

// TODO: Call when the document closes
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
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    NSException *exception = [NSException exceptionWithName:@"UnimplementedMethod" reason:[NSString stringWithFormat:@"%@ is unimplemented", NSStringFromSelector(_cmd)] userInfo:nil];
    @throw exception;
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

#pragma mark - XML

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    NSLog(@"START XML");
    //the parser started this document. what are you going to do?
    _apps = [NSMutableArray new];
    _clientAddresses = [NSMutableArray new];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    [self handleLastXMLElement];
    _xmlElementName = elementName;
    _xmlElementValue = [[NSMutableString alloc] init];
    if ([_xmlElementName isEqualToString:kXMLElementApp])
    {
        _lastApp = [ITPApp new];
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

- (void)handleLastXMLElement
{
    NSString *value = [_xmlElementValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([_xmlElementName isEqualToString:kXMLElementDurationSeconds])
    {
        _lastApp.durationSeconds = @([value integerValue]);
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchUrl])
    {
        _lastApp.webURL = value;
        _lastApp.type = AppLaunchTypeWebURL;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchCommand])
    {
        // TODO: Make this launch path relative to the known paths
        _lastApp.command = value;
        _lastApp.type = AppLaunchTypeCommand;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchApp])
    {
        _lastApp.path = value;
        _lastApp.type = AppLaunchTypeAppPath;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementLaunchVideo])
    {
        _lastApp.path = value;
        _lastApp.type = AppLaunchTypeVideo;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementKillName])
    {
        _lastApp.killName = value;
    }
    else if ([_xmlElementName isEqualToString:kXMLElementWallpaperPath])
    {
        _lastApp.wallpaperPath = value;
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
        
        self.currentAppName = app.killName;
        self.currentTimeRemaining = @"--";
        
        self.numAppsLaunched = 0;
        
        NSString *value;
        if (app.type == AppLaunchTypeCommand)
        {
            value = app.command;
        }
        else if (app.type == AppLaunchTypeWebURL)
        {
            value = app.webURL;
        }
        else if (app.type == AppLaunchTypeAppPath)
        {
            value = app.path;
        }
        else if (app.type == AppLaunchTypeVideo)
        {
            value = app.path;
        }
        NSString *message = [NSString stringWithFormat:@"%@%@%@%@%@%@%i%@%@",
                             kCommandLaunchApp,
                             kCommandParamDelim,
                             app.killName,
                             kCommandParamDelim,
                             value,
                             kCommandParamDelim,
                             app.type,
                             kCommandParamDelim,
                             app.wallpaperPath];
        
        for (NSString *hostName in self.sockets)
        {
            [self sendMessage:message toSocket:self.sockets[hostName]];
        }
    }];
}

- (void)killApp:(ITPApp *)app
{
    [self performUponConnection:^() {
    
        [_timer invalidate];
        _timer = nil;
        
        NSString *killMessage = [NSString stringWithFormat:@"%@%@%@%@%i",
                                 kCommandKillApp,
                                 kCommandParamDelim,
                                 app.killName,
                                 kCommandParamDelim,
                                 [app.pid intValue]];
        
        for (NSString *hostName in self.sockets)
        {
            [self sendMessage:killMessage toSocket:self.sockets[hostName]];
        }
        
        app.pid = nil;
        
        [self.buttonStart setEnabled:YES];
        [self.buttonStop setEnabled:NO];
        
        self.currentAppName = @"None";
        self.currentTimeRemaining = @"--";
        
    }];
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
        return app.killName;
    }
    else if ([aTableColumn.identifier isEqualToString:@"duration"])
    {
        // 1 == Duration
        return app.durationSeconds;
    }
    else if ([aTableColumn.identifier isEqualToString:@"path"])
    {
        // 2 == Path
        switch (app.type)
        {
            case AppLaunchTypeAppPath:
                return app.path;
            case AppLaunchTypeVideo:
                return app.path;
            case AppLaunchTypeWebURL:
                return app.webURL;
            case AppLaunchTypeCommand:
                return app.command;
        }
    }
    return @"?";
}

@end
