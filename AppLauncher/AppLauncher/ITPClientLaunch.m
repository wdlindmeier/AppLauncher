//
//  ITPClientLaunch.m
//  AppLauncherClient
//
//  Created by William Lindmeier on 11/11/13.
//
//

#import "ITPClientLaunch.h"

@implementation ITPClientLaunch

- (id)init
{
    self = [super init];
    if (self)
    {
        self.type = AppLaunchTypeUnknown;
        self.dontKill = false;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<ITPClientLaunch path: %@ url: %@ command: %@ type: %i clientAddress: %@ killName: %@ wallpaperPath: %@>",
     self.path,
     self.webURL,
     self.command,
     self.type,
     self.clientAddress,
     self.killName,
     self.wallpaperPath];
}

@end
