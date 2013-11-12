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

#pragma mark - Connection

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

#pragma mark - Socket Data

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"Socket did receive data: %@ with tag: %li", message, tag);
    NSArray *tokens = [message componentsSeparatedByString:kCommandParamDelim];
    
    if (tokens.count > 0)
    {
        NSString *command = tokens[0];
        
        ITPClientLaunch *launch = nil;
        NSString *appID = nil;
        if (tokens.count > 1)
        {
            NSString *appID = tokens[1];
            launch = _launches[appID];
            if (!launch)
            {
                launch = [ITPClientLaunch new];
                _launches[appID] = launch;
            }
        }
        else
        {
            NSLog(@"ERROR: Couldn't find app ID");
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

            [self launchApp:launch withID:appID];

        }
        
        else if ([command isEqualToString:@"KILL"])
        {
            if (tokens.count > 2)
            {
                NSString *killName = tokens[2];
                launch.killName = killName;
                [self killApp:launch withID:appID];
            }
            else
            {
                NSLog(@"ERROR: Couldn't find app kill name");
                return;
            }
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

- (void)sendError:(NSString *)errorString
            appID:(NSString *)appID
       forCommand:(NSString *)command
{
    [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@%@%@%@%@",
                               kCommandError,
                               kCommandParamDelim,
                               command,
                               kCommandParamDelim,
                               appID,
                               kCommandParamDelim,
                               errorString]
                              dataUsingEncoding:NSUTF8StringEncoding]
                 withTimeout:-1
                         tag:0];
}

#pragma mark - App Management

- (void)launchApp:(ITPClientLaunch *)launch withID:(NSString *)appID
{
    NSTask *task = [[NSTask alloc] init];
    
    if (launch.type == AppLaunchTypeCommand)
    {
        NSLog(@"Launching command: %@", launch.command);
        NSArray *commandComponents = [launch.command componentsSeparatedByString:@" "];
        NSString *launchPath = commandComponents[0];
        [task setLaunchPath:launchPath];
        
        if (commandComponents.count > 1)
        {
            NSArray *otherArgs = [commandComponents subarrayWithRange:NSMakeRange(1, commandComponents.count - 1)];
            [task setArguments:otherArgs];
        }
    }
    else if (launch.type == AppLaunchTypeWebURL)
    {
        NSString *commandPath = @"/usr/bin/osascript"; // Apple script
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"openChromeURL" ofType:@"scpt"];
        NSLog(@"Launching url: %@", launch.webURL);
        [task setLaunchPath:commandPath];

        [task setArguments:@[scriptPath, launch.webURL]];
    }
    else if (launch.type == AppLaunchTypeAppPath)
    {
        NSLog(@"Launching app: %@", launch.path);
        [task setLaunchPath:@"/usr/bin/open"];
        // -F: Asks to open the app "Fresh"
        [task setArguments:@[@"-F", launch.path]];
    }
    else if (launch.type == AppLaunchTypeVideo)
    {
        NSLog(@"Launching video: %@", launch.path);
        NSString *commandPath = @"/usr/bin/osascript"; // Apple script
        NSString *scriptPath = [[NSBundle mainBundle] pathForResource:@"openVideo" ofType:@"scpt"];
        [task setLaunchPath:commandPath];
        [task setArguments:@[scriptPath, launch.path]];

    }
    
    if (launch.wallpaperPath)
    {
        std::string cppPath([launch.wallpaperPath UTF8String]);
        ci::fs::path wallpaperPath(cppPath);
        
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
                [self sendError:errorString
                          appID:appID
                     forCommand:kCommandLaunchApp];
            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Tell the server that we've launched
            ITPClientLaunch *launch = _launches[appID];
            [_serverSocket writeData:[[NSString stringWithFormat:@"%@%@%@",
                                       kCommandAppWasLaunched,
                                       kCommandParamDelim,
                                       launch.killName]
                                      dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:-1
                                 tag:0];
        });

    }];
    
    [task launch];
}

- (void)killApp:(ITPClientLaunch *)launch withID:(NSString *)appID
{
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSString *killName = launch.killName;
    NSString *scriptPath = nil;
    
    NSLog(@"Attempting to kill app named: >>%@<<", launch.killName);
    scriptPath = @"/usr/bin/pkill";
    [task setArguments: @[@"-9", @"-f", launch.killName]];

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
                
                [self sendError:errorString
                          appID:appID
                     forCommand:kCommandKillApp];

            });
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            ITPClientLaunch *launch = _launches[killName];
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
