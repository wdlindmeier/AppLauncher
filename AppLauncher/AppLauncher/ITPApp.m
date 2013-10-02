//
//  ITPApp.m
//  AppLauncher
//
//  Created by William Lindmeier on 9/27/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import "ITPApp.h"

@implementation ITPApp

- (id)init
{
    self = [super init];
    if (self)
    {
        self.wallpaperPath = @"";
        self.durationSeconds = 0;
        self.pid = nil;
    }
    return self;
}

@end
