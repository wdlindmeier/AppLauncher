//
//  AppLauncherConsts.h
//  AppLauncher
//
//  Created by William Lindmeier on 10/2/13.
//  Copyright (c) 2013 ITP. All rights reserved.
//

#pragma once

static NSString * const kXMLElementApp = @"app";
static NSString * const kXMLElementDurationSeconds = @"duration-seconds";
static NSString * const kXMLElementLaunchPath = @"launch-path";
static NSString * const kXMLElementKillName = @"kill-name";
static NSString * const kXMLElementWallpaperPath = @"wallpaper-path";

static NSString * const kCommandAppWasKilled = @"KILLED";
static NSString * const kCommandError = @"ERROR";
static NSString * const kCommandAppWasLaunched = @"LAUNCHED";
static NSString * const kCommandKillApp = @"KILL";
static NSString * const kCommandLaunchApp = @"LAUNCH";
static NSString * const kCommandParamDelim = @"~~";

const static int kConnectionPort = 9234;