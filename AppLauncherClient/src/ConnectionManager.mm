//
//  ConnectionManager.m
//  AppLauncherClient
//
//  Created by William Lindmeier on 10/2/13.
//
//

#import "ConnectionManager.h"
#include "GCDAsyncSocket.h"
#include "ITPApp.h"
#include "DisplayApp.hpp"

@implementation ConnectionManager
{
    GCDAsyncSocket *_serverSocket;
    NSMutableDictionary *_apps;
    dispatch_queue_t _socketQueue;
    DisplayApp *_displayApp;
}

- (id)initWithApp:(DisplayApp *)cinderApp
{
    self = [super init];
    if (self)
    {
        _apps = [NSMutableDictionary dictionary];
        _socketQueue = dispatch_queue_create("socketQueue", NULL);
        _serverSocket = nil;
        _displayApp = cinderApp;
    }
    return self;
}

- (void)disconnect
{
    if(_serverSocket && _serverSocket.isConnected)
    {
        [_serverSocket disconnect];
        _serverSocket = nil;
    }
}

- (void)connectOnPort:(int)portNum
{
    [self disconnect];
    
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self
                                               delegateQueue:_socketQueue];
    NSError *error = nil;
    BOOL didAccept = [_serverSocket acceptOnPort:portNum
                                           error:&error];
    if (!didAccept)
    {
        NSLog(@"ERROR: Can't accept on port %i:\n%@", portNum, error);
    }
    else
    {
        NSLog(@"Accpeting on port %i", portNum);
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Socket did receive data: %@ with tag: %li", message, tag);
    NSArray *tokens = [message componentsSeparatedByString:@"~~"];
    
    if (tokens.count > 0)
    {
        NSString *command = tokens[0];
        
        ITPApp *app = nil;
        if (tokens.count > 1)
        {
            NSString *appKillName = tokens[1];
            app = _apps[appKillName];
            if (!app)
            {
                app = [ITPApp new];
                app.killName = appKillName;
                _apps[appKillName] = app;
            }
        }
        else
        {
            NSLog(@"ERROR: Couldn't find app kill name");
            return;
        }
        
        if ([command isEqualToString:@"LAUNCH"])
        {
            if (tokens.count > 2)
            {
                app.path = tokens[2];
            }
            else
            {
                NSLog(@"ERROR: Couldn't find app path to launch");
                return;
            }
            if (tokens.count > 3)
            {
                app.wallpaperPath = tokens[3];
            }
            else
            {
                app.wallpaperPath = nil;
            }

            [self launchApp:app];

        }
        
        else if ([command isEqualToString:@"KILL"])
        {
            if (tokens.count > 2)
            {
                int pid = [(NSString *)tokens[2] intValue];
                if (pid != 0)
                {
                    app.pid = @(pid);
                }
            }
            
            [self killApp:app];
        }
    }
    
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    if ([_serverSocket isConnected])
    {
        [_serverSocket disconnect];
    }
    _serverSocket = newSocket;
    [newSocket readDataWithTimeout:-1 tag:0];
}

- (void)launchApp:(ITPApp *)app
{
    NSString *killName = app.killName;
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/open"];
    
    NSLog(@"Launching app: %@", app.path);
    
    if (app.wallpaperPath)
    {
        std::string cppPath([app.wallpaperPath UTF8String]);
        ci::fs::path wallpaperPath(cppPath);
        
        // TODO: Take screen position into account.
        // Currently just tiling the background.
        dispatch_async(dispatch_get_main_queue(), ^{
            _displayApp->loadWallpaper(wallpaperPath,
                                       ci::Vec2i::zero());;
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            _displayApp->clearWallpaper();
        });
    }
    
    [task setArguments:@[app.path]];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task setTerminationHandler:^(NSTask *t) {
        
        int status = [t terminationStatus];
        if (status != 0)
        {
            
            NSData *data = [file readDataToEndOfFile];
            NSString *errorString = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];

            NSLog(@"Launch returned error status: %@", errorString);
            dispatch_async(dispatch_get_main_queue(), ^{
                [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                                           kCommandError,
                                           kCommandParamDelim,
                                           kCommandLaunchApp,
                                           kCommandParamDelim,
                                           app.killName,
                                           kCommandParamDelim,
                                           errorString
                                           ]
                                          dataUsingEncoding:NSUTF8StringEncoding]
                             withTimeout:-1
                                     tag:0];
            });
            return;
        }
        
        NSTask *grepTask = [[NSTask alloc] init];
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"app_grep" ofType:nil];
        [grepTask setLaunchPath:scriptPath];
        
        [grepTask setArguments:@[app.path]];
        
        NSPipe *pipe = [NSPipe pipe];
        [grepTask setStandardOutput:pipe];
        
        NSFileHandle *file = [pipe fileHandleForReading];
        
        [grepTask setTerminationHandler:^(NSTask *t) {
            
            int status = [t terminationStatus];
            if (status != 0)
            {
                NSData *data = [file readDataToEndOfFile];
                NSString *errorString = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
                NSLog(@"Grep returned error status: %@", errorString);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Tell the server that we've launched
                    [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                                               kCommandError,
                                               kCommandParamDelim,
                                               kCommandLaunchApp,
                                               kCommandParamDelim,
                                               app.killName,
                                               kCommandParamDelim,
                                               errorString]
                                              dataUsingEncoding:NSUTF8StringEncoding]
                                 withTimeout:-1
                                         tag:0];
                });
                return;
            }
            
            NSData *data = [file readDataToEndOfFile];
            NSString *string = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
            NSArray *lines = [string componentsSeparatedByString:@"\n"];
            
            ITPApp *app = _apps[killName];
            app.pid = nil;
            
            for (NSString *line in lines)
            {
                if ([line rangeOfString:killName].location != NSNotFound &&
                    [line rangeOfString:@"grep "].location == NSNotFound)
                {
                    NSArray *tokens = [[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                                       componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    app.pid = @([tokens[0] intValue]);
                }
            }
            
            NSLog(@"App launched with PID: %@", app.pid);
//            NSLog(@"Grep returned: %@", lines);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@",
                                           kCommandAppWasLaunched,
                                           kCommandParamDelim,
                                           app.killName]
                                          dataUsingEncoding:NSUTF8StringEncoding]
                             withTimeout:-1
                                     tag:0];
            });
        }];
        
        [grepTask launch];
        
    }];
    
    [task launch];
}

- (void)killApp:(ITPApp *)app
{
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSString *killName = app.killName;
    NSString *scriptPath = nil;
    if (app.pid && [app.pid intValue] != 0)
    {
        NSLog(@"Attempting to kill pid: >>%@<<", app.pid);
        scriptPath = @"/bin/kill";
        [task setArguments: @[[app.pid stringValue]]];
    }
    else
    {
        scriptPath = @"/usr/bin/pkill";
        [task setArguments: @[app.killName]];
    }
    
    [task setLaunchPath: scriptPath];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];

    [task setTerminationHandler:^(NSTask *t) {
        
        int status = [t terminationStatus];
        if (status != 0)
        {
            NSData *data = [file readDataToEndOfFile];
            NSString *errorString = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];

            NSLog(@"Kill returned error status: %@", errorString);
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                                           kCommandError,
                                           kCommandParamDelim,
                                           kCommandKillApp,
                                           kCommandParamDelim,
                                           app.killName,
                                           kCommandParamDelim,
                                           errorString]
                                          dataUsingEncoding:NSUTF8StringEncoding]
                             withTimeout:-1
                                     tag:0];
            });
            return;
        }
        
        // NSData *data = [file readDataToEndOfFile];
        // NSString *outputString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ITPApp *app = _apps[killName];
            app.pid = nil;
            [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@",
                                       kCommandAppWasKilled,
                                       kCommandParamDelim,
                                       app.killName]
                                      dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:-1
                                 tag:0];
        });
    }];
    
    [task launch];
}

@end
