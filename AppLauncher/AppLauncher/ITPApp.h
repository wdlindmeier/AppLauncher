//
//  ITPApp.h
//  AppLauncher
//
//  Created by William Lindmeier on 9/27/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ITPApp : NSObject

@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *killName;
@property (nonatomic, strong) NSNumber *durationSeconds;
@property (nonatomic, strong) NSNumber *pid;

@end
