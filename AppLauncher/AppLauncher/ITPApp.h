//
//  ITPApp.h
//  AppLauncher
//
//  Created by William Lindmeier on 9/27/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ITPClientLaunch.h"

@interface ITPApp : NSObject

@property (nonatomic, strong) NSNumber *durationSeconds;
@property (nonatomic, strong) NSDictionary *clientLaunches;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) int appID;

@end
