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
        self.durationSeconds = 0;
        self.clientLaunches = @{};
        self.name = @"Unnamed";
    }
    return self;
}

@end
