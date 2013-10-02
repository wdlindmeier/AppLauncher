//
//  DisplayApp.h
//  AppLauncherClient
//
//  Created by William Lindmeier on 10/2/13.
//
//

#pragma once

#include "cinder/Cinder.h"

class DisplayApp
{
public:
    
    DisplayApp(){};
    virtual ~DisplayApp(){};
    
    virtual void loadWallpaper(const ci::fs::path & filePath, const ci::Vec2i & offset) = 0;
    virtual void clearWallpaper() = 0;
    
};