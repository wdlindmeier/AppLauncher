//
//  ITPApp.h
//  AppLauncher
//
//  Created by William Lindmeier on 9/27/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum AppLaunchTypes
{
    AppLaunchTypeAppPath = 0,
    AppLaunchTypeWebURL = 1,
    AppLaunchTypeCommand = 2
    
} AppLaunchType;


@interface ITPApp : NSObject

// Pick one of three launch types:
@property (nonatomic, strong) NSString *path; // E.g. BigScreens.app
@property (nonatomic, strong) NSString *webURL; // E.g. http://bigscreens.com
@property (nonatomic, strong) NSString *command; // E.g. /usr/bin/bigscreens app.script

@property (nonatomic, assign) AppLaunchType type;

@property (nonatomic, strong) NSString *killName;
@property (nonatomic, strong) NSString *wallpaperPath;
@property (nonatomic, strong) NSNumber *durationSeconds;
@property (nonatomic, strong) NSNumber *pid;

@end
