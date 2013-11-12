//
//  ConnectionManager.m
//  AppLauncherClient
//
//  Created by William Lindmeier on 10/2/13.
//
//

#import "ConnectionManager.h"
#include "GCDAsyncSocket.h"
#include "ITPClientLaunch.h"
#include "DisplayApp.hpp"

@implementation ConnectionManager
{
    GCDAsyncSocket *_serverSocket;
    NSMutableDictionary *_launches;
    dispatch_queue_t _socketQueue;
    DisplayApp *_displayApp;
}

- (id)initWithApp:(DisplayApp *)cinderApp
{
    self = [super init];
    if (self)
    {
        _launches = [NSMutableDictionary dictionary];
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
        
        ITPClientLaunch *launch = nil;
        if (tokens.count > 1)
        {
            NSString *launchKillName = tokens[1];
            launch = _launches[launchKillName];
            if (!launch)
            {
                launch = [ITPClientLaunch new];
                launch.killName = launchKillName;
                _launches[launchKillName] = launch;
            }
        }
        else
        {
            NSLog(@"ERROR: Couldn't find app kill name");
            return;
        }
        
        if ([command isEqualToString:@"LAUNCH"])
        {
            if (tokens.count > 3)
            {
                launch.type = (AppLaunchType)[(NSString *)tokens[3] intValue];
                if (launch.type == AppLaunchTypeCommand)
                {
                    launch.command = tokens[2];
                }
                else if (launch.type == AppLaunchTypeWebURL)
                {
                    launch.webURL = tokens[2];
                }
                else if (launch.type == AppLaunchTypeAppPath)
                {
                    launch.path = tokens[2];
                }
                else if (launch.type == AppLaunchTypeVideo)
                {
                    launch.path = tokens[2];
                }
            }
            else
            {
                NSLog(@"ERROR: Couldn't find app path to launch");
                return;
            }

            if (tokens.count > 4)
            {
                launch.wallpaperPath = tokens[4];
            }
            else
            {
                launch.wallpaperPath = nil;
            }

            [self launchApp:launch];

        }
        
        else if ([command isEqualToString:@"KILL"])
        {
            /*
            if (tokens.count > 2)
            {
                int pid = [(NSString *)tokens[2] intValue];
                if (pid != 0)
                {
                    app.pid = @(pid);
                }
            }
            */
            [self killApp:launch];
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

- (void)launchApp:(ITPClientLaunch *)launch
{
    NSString *killName = launch.killName;
    
    NSTask *task = [[NSTask alloc] init];
    NSString *grepName = nil;
    if (launch.type == AppLaunchTypeCommand)
    {
        NSLog(@"Launching command: %@", launch.command);
        NSArray *commandComponents = [launch.command componentsSeparatedByString:@" "];
        NSString *launchPath = commandComponents[0];
        [task setLaunchPath:launchPath];
        grepName = launchPath;
        if (commandComponents.count > 1)
        {
            NSArray *otherArgs = [commandComponents subarrayWithRange:NSMakeRange(1, commandComponents.count - 1)];
            //[task setArguments:@[[otherArgs componentsJoinedByString:@" "]]];
            [task setArguments:otherArgs];
        }
    }
    else if (launch.type == AppLaunchTypeWebURL)
    {
        NSString *commandPath = @"/usr/bin/osascript"; // Apple script
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"openChromeURL" ofType:@"scpt"];
        NSLog(@"Launching url: %@", launch.webURL);
        [task setLaunchPath:commandPath];
        grepName = @"\"Google Chrome\""; // ?
        [task setArguments:@[scriptPath, launch.webURL]];
    }
    else if (launch.type == AppLaunchTypeAppPath)
    {
        NSLog(@"Launching app: %@", launch.path);
        [task setLaunchPath:@"/usr/bin/open"];
        
        // -F: Asks to open the app "Fresh"
        [task setArguments:@[@"-F", launch.path]];
        grepName = launch.path;
    }
    else if (launch.type == AppLaunchTypeVideo)
    {
        NSLog(@"Launching video: %@", launch.path);
        NSString *commandPath = @"/usr/bin/osascript"; // Apple script
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"openVideo" ofType:@"scpt"];
        [task setLaunchPath:commandPath];
        [task setArguments:@[scriptPath, launch.path]];
        grepName = @"QuickTime Player";
    }
    
    if (launch.wallpaperPath)
    {
        std::string cppPath([launch.wallpaperPath UTF8String]);
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
                                           launch.killName,
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
        
        [grepTask setArguments:@[grepName]];
        
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
                                               launch.killName,
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
//            NSArray *lines = [string componentsSeparatedByString:@"\n"];
            
            ITPClientLaunch *launch = _launches[killName];
            
            /*
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
            */
//            NSLog(@"Grep returned: %@", lines);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@",
                                           kCommandAppWasLaunched,
                                           kCommandParamDelim,
                                           launch.killName]
                                          dataUsingEncoding:NSUTF8StringEncoding]
                             withTimeout:-1
                                     tag:0];
            });
        }];
        
        [grepTask launch];
        
    }];
    
    [task launch];
}

- (void)killApp:(ITPClientLaunch *)launch
{
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSString *killName = launch.killName;
    NSString *scriptPath = nil;
    /*
    BOOL isKillingWithPID = false;
    if (app.pid && [app.pid intValue] != 0)
    {
        isKillingWithPID = true;
        NSLog(@"Attempting to kill pid: >>%@<<", app.pid);
        scriptPath = @"/bin/kill";
        [task setArguments: @[@"-9", [app.pid stringValue]]];
    }
    else
    {*/
        NSLog(@"Attempting to kill app named: >>%@<<", launch.killName);
        scriptPath = @"/usr/bin/pkill";
        [task setArguments: @[@"-9", launch.killName]];
    //}
    
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

            /*
            if (isKillingWithPID)
            {
                // NOTE: If killing using a PID throws an error, try killing with it's name
                app.pid = nil;
                return [self killApp:app];
            }
            else
            {*/
                NSLog(@"Kill returned error status: %@", errorString);
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Tell the server that we've launched
                    [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                                               kCommandError,
                                               kCommandParamDelim,
                                               kCommandKillApp,
                                               kCommandParamDelim,
                                               launch.killName,
                                               kCommandParamDelim,
                                               errorString]
                                              dataUsingEncoding:NSUTF8StringEncoding]
                                 withTimeout:-1
                                         tag:0];
                });
            //}
            return;
        }
        
        // NSData *data = [file readDataToEndOfFile];
        // NSString *outputString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ITPClientLaunch *launch = _launches[killName];
            // app.pid = nil;
            [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@",
                                       kCommandAppWasKilled,
                                       kCommandParamDelim,
                                       launch.killName]
                                      dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:-1
                                 tag:0];
        });
    }];
    
    [task launch];
}

@end
