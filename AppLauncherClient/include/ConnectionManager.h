//
//  ConnectionManager.h
//  AppLauncherClient
//
//  Created by William Lindmeier on 10/2/13.
//
//

#import <Foundation/Foundation.h>
//#include "DisplayApp.hpp"

@class ITPClientLaunch;
class DisplayApp;

@interface ConnectionManager : NSObject

- (id)initWithApp:(DisplayApp *)cinderApp;
- (void)disconnect;
- (void)connectOnPort:(int)portNum;
- (void)killApp:(ITPClientLaunch *)app withID:(NSString *)appID;
- (void)launchApp:(ITPClientLaunch *)app withID:(NSString *)appID;

@end
