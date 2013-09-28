//
//  ITPAppLauncherApplicationDelegate.m
//  AppLauncher
//
//  Created by William Lindmeier on 9/21/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import "ITPAppLauncherApplication.h"

@implementation ITPAppLauncherApplication
{
    NSDocumentController *_documentController;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        self.delegate = self;
    }
    return self;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
{
    return NO;
}

- (BOOL)restoreWindowWithIdentifier:(NSString *)identifier
                              state:(NSCoder *)state
                  completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    return NO;
}

- (void)finishLaunching
{
    [super finishLaunching];
    /*
    NSDocumentController *docController = [NSDocumentController sharedDocumentController];
    [docController runModalOpenPanel:[NSOpenPanel openPanel] forTypes:@[@"schedule"]];
    */
    // How do I load up the results?
}

@end
