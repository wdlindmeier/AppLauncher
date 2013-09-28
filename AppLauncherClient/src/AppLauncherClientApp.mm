#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "GCDAsyncSocket.h"
#include "ITPApp.h"

using namespace ci;
using namespace ci::app;
using namespace std;

@interface SocketDelegate : NSObject

//- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag;
//- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket;

@end

@implementation SocketDelegate
{
    GCDAsyncSocket *_serverSocket;
    NSMutableDictionary *_apps;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _apps = [NSMutableDictionary dictionary];
    }
    return self;
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
                [self launchApp:app];
            }
            else
            {
                NSLog(@"ERROR: Couldn't find app path to launch");
            }
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
    
    NSLog(@"app.path: %@", app.path);

    [task setArguments:@[app.path]];
    
    [task setTerminationHandler:^(NSTask *t) {
        
        int status = [t terminationStatus];
        if (status != 0)
        {
            NSLog(@"Launch returned error status");
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"ERROR~~LAUNCH~~%@",
                                           app.killName]
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
                NSLog(@"Grep returned error status.");
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Tell the server that we've launched
                    [_serverSocket writeData:[[NSString stringWithFormat:@"ERROR~~LAUNCH~~%@",
                                               app.killName]
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
                if ([line rangeOfString:app.path].location != NSNotFound &&
                    [line rangeOfString:@"grep "].location == NSNotFound)
                {
                    NSArray *tokens = [line componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    app.pid = @([tokens[0] intValue]);
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"LAUNCHED~~%@", app.killName]
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
    if (app.pid)
    {
        NSLog(@"Attempting to kill pid: >>%@<<", app.pid);
        scriptPath = @"/bin/kill";
        // TODO: Load these up from the settings file
        [task setArguments: @[[app.pid stringValue]]];
        NSLog(@"App: %@\nArguments: %@", app.killName, [task arguments]);
    }
    else
    {
        scriptPath = @"/usr/bin/pkill";
        // TODO: Load these up from the settings file
        [task setArguments: @[app.killName]];
    }
    
    [task setLaunchPath: scriptPath];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task setTerminationHandler:^(NSTask *t) {
        
        int status = [t terminationStatus];
        if (status != 0)
        {
            NSLog(@"Kill returned error status");
            dispatch_async(dispatch_get_main_queue(), ^{
                // Tell the server that we've launched
                [_serverSocket writeData:[[NSString stringWithFormat:@"ERROR~~KILL~~%@",
                                           app.killName]
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
            [_serverSocket writeData:[[NSString stringWithFormat:@"KILLED~~%@", app.killName]
                                      dataUsingEncoding:NSUTF8StringEncoding]
                         withTimeout:-1
                                 tag:0];
        });
    }];
    
    [task launch];
}

@end

class AppLauncherClientApp : public AppNative
{
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
    
    dispatch_queue_t socketQueue;
    GCDAsyncSocket *mSocket;
    SocketDelegate *mSocketDelegate;
};

void AppLauncherClientApp::setup()
{
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    mSocketDelegate = [SocketDelegate new];
    mSocket = [[GCDAsyncSocket alloc] initWithDelegate:mSocketDelegate
                                         delegateQueue:socketQueue];
    NSError *error = nil;
    BOOL didAccept = [mSocket acceptOnPort:1234
                                     error:&error];
    if (!didAccept)
    {
        NSLog(@"ERROR: Can't accept on port %i:\n%@", 1234, error);
    }
    else
    {
        NSLog(@"Accpeting on port 1234");
    }
}

void AppLauncherClientApp::mouseDown( MouseEvent event )
{
    [mSocket readDataWithTimeout:-1 tag:1221];
}

void AppLauncherClientApp::update()
{
}

void AppLauncherClientApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) ); 
}

CINDER_APP_NATIVE( AppLauncherClientApp, RendererGl )
