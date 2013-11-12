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
static NSString * const kXMLElementLaunchApp = @"launch-app";
static NSString * const kXMLElementLaunchUrl = @"launch-url";
static NSString * const kXMLElementLaunchCommand = @"launch-command";
static NSString * const kXMLElementLaunchVideo = @"launch-video";
static NSString * const kXMLElementKillName = @"kill-name";
static NSString * const kXMLElementWallpaperPath = @"wallpaper-path";
static NSString * const kXMLElementShouldLoop = @"loop";
static NSString * const kXMLElementAutoAdvance = @"auto-advance";
static NSString * const kXMLElementSleepBetweenApps = @"duration-interlude-seconds";
static NSString * const kXMLElementDebug = @"debug";
static NSString * const kXMLElementName = @"name";
static NSString * const kXMLElementClientIP = @"client-ip";

static NSString * const kITPClientKeyDefault = @"default";

static NSString * const kCommandAppWasKilled = @"KILLED";
static NSString * const kCommandError = @"ERROR";
static NSString * const kCommandAppWasLaunched = @"LAUNCHED";
static NSString * const kCommandKillApp = @"KILL";
static NSString * const kCommandLaunchApp = @"LAUNCH";
static NSString * const kCommandParamDelim = @"~~";

const static int kConnectionPort = 9234;