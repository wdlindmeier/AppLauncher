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

@interface ITPDocument()

@property (atomic, assign) int numAppsLaunched;
@property (atomic, strong) NSMutableDictionary *sockets;

@end

@implementation ITPDocument
{
    NSString *_xmlElementName;
    NSMutableString *_xmlElementValue;
    NSMutableArray *_apps;
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
    
    _sockets = [[NSMutableDictionary alloc] initWithCapacity:1];
    
    NSString *hostAddress = @"127.0.0.1";
    int hostPort = 1234;
    
    // TODO: Make a loop for all clients
    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                                       delegateQueue:dispatch_get_main_queue()];
    NSError *connectError = nil;
    if (![socket connectToHost:hostAddress onPort:hostPort error:&connectError])
    {
        NSLog(@"ERROR: Couldn't connect to socket: %@", connectError);
    }
    else
    {
        NSLog(@"Connected to %@:%i", hostAddress, hostPort);
        [socket readDataWithTimeout:-1 tag:0];
    }
    
    _sockets[hostAddress] = socket;
    
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
	NSLog(@"socket:%p didReadData:%@ withTag:%ld", sock, response, tag);
    
    NSArray *tokens = [response componentsSeparatedByString:@"~~"];
    
    if (tokens.count > 0)
    {
        NSString *command = tokens[0];
        // TODO: This should varify that it's the correct app name
        if ([command isEqualToString:@"LAUNCHED"] && self.numAppsLaunched < self.sockets.count)
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
        else if ([command isEqualToString:@"KILLED"] && self.numAppsLaunched > 0)
        {
            self.numAppsLaunched -= 1;
            
            if (self.numAppsLaunched <= 0 && self.shouldAutoAdvance)
            {
                NSLog(@"ALL APPS KILLED. Advancing.");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self launchNextApp];
                });
            }
        }
        else if ([command isEqualToString:@"ERROR"])
        {
            if (tokens.count > 1)
            {
                NSString *errorTask = tokens[1];
                NSLog(@"ERROR completing task: %@", errorTask);
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Kill everything
                    [self buttonStopPressed:nil];
                });
            }
        }
    }
    
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);
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
    @synchronized(_sockets)
    {
        for (NSString *hostName in _sockets)
        {
            [(GCDAsyncSocket *)_sockets[hostName] disconnect];
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
    //the parser started this document. what are you going to do?
    _apps = [[NSMutableArray alloc] init];
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    [self handleLastXMLElement];
    _xmlElementName = elementName;
    _xmlElementValue = [[NSMutableString alloc] init];
    if ([_xmlElementName isEqualToString:@"app"])
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
    NSLog(@"Done loading document. Apps:");
    NSLog(@"%@", _apps);
    [self updateViewForApps];
}

- (void)handleLastXMLElement
{
    NSString *value = [_xmlElementValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([_xmlElementName isEqualToString:@"duration-seconds"])
    {
        _lastApp.durationSeconds = @([value integerValue]);
    }
    else if ([_xmlElementName isEqualToString:@"launch-path"])
    {
        _lastApp.path = value;
    }
    else if ([_xmlElementName isEqualToString:@"kill-name"])
    {
        _lastApp.killName = value;
    }
}

#pragma mark - App Management

- (void)launchNextApp
{
    if (!_isPlaying)
    {
        return;
    }
    
    if (_currentAppIndex > -1 && _currentAppIndex < _apps.count)
    {
        [self killApp:_apps[_currentAppIndex]];
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
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_currentAppIndex]
                byExtendingSelection:NO];

    [self.buttonStart setEnabled:NO];
    [self.buttonStop setEnabled:YES];

    self.currentAppName = app.killName;
    self.currentTimeRemaining = @"--";

    self.numAppsLaunched = 0;
    
    NSString *message = [NSString stringWithFormat:@"LAUNCH~~%@~~%@", app.killName, app.path];
    for (NSString *hostName in _sockets)
    {
        [self sendMessage:message toSocket:_sockets[hostName]];
    }
}

- (void)killApp:(ITPApp *)app
{
    [_timer invalidate];
    _timer = nil;
    
    NSString *killMessage = [NSString stringWithFormat:@"KILL~~%@~~%i",
                             app.killName,
                             [app.pid intValue]];
    
    for (NSString *hostName in _sockets)
    {
        [self sendMessage:killMessage toSocket:_sockets[hostName]];
    }
    
    app.pid = nil;
    
    [self.buttonStart setEnabled:YES];
    [self.buttonStop setEnabled:NO];
    
    self.currentAppName = @"None";
    self.currentTimeRemaining = @"--";
}

#pragma mark - Timer

- (void)updateTimer
{
    NSTimeInterval ti = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval delta = ti - _timeAppLaunched;
    ITPApp *currentApp = _apps[_currentAppIndex];
    int secondsAppDuration = [currentApp.durationSeconds intValue];
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
        return app.path;
    }
    return @"?";
}

@end
