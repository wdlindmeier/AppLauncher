//
//  ITPClientLaunch.h
//  AppLauncherClient
//
//  Created by William Lindmeier on 11/11/13.
//
//

#import <Foundation/Foundation.h>

typedef enum AppLaunchTypes
{
    AppLaunchTypeUnknown = 0,
    AppLaunchTypeAppPath = 1,
    AppLaunchTypeWebURL = 2,
    AppLaunchTypeCommand = 3,
    AppLaunchTypeVideo = 4
    
} AppLaunchType;

@interface ITPClientLaunch : NSObject

// Pick one of three launch types:
@property (nonatomic, strong) NSString *path; // E.g. BigScreens.app
@property (nonatomic, strong) NSString *webURL; // E.g. http://bigscreens.com
@property (nonatomic, strong) NSString *command; // E.g. /usr/bin/bigscreens app.script

@property (nonatomic, assign) AppLaunchType type;
@property (nonatomic, assign) BOOL dontKill;
@property (nonatomic, strong) NSString *clientAddress;

@property (nonatomic, strong) NSString *killName;
@property (nonatomic, strong) NSString *wallpaperPath;

- (NSString *)description;

@end
