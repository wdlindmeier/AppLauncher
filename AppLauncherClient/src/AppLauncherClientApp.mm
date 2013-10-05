#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"
#include "cinder/gl/Texture.h"
#include "cinder/Surface.h"
#include "ITPApp.h"
#include "ConnectionManager.h"
#include "DisplayApp.hpp"
#include "AppLauncherConsts.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class AppLauncherClientApp : public AppNative, public DisplayApp
{
  public:
    void prepareSettings(Settings *settings);
	void setup();
    void shutdown();
    void resize();
	void mouseDown(MouseEvent event);
	void update();
	void draw();
    void keyDown(KeyEvent event);
    void loadWallpaper(const fs::path &, const Vec2i &);
    void clearWallpaper();

    ConnectionManager *mConnectionManager;
    fs::path mWallpaperPath;
    Vec2i mWallpaperOffset;
    gl::Texture mBackgroundTexture;
};

void AppLauncherClientApp::prepareSettings(Settings *settings)
{
    settings->setBorderless();
}

void AppLauncherClientApp::setup()
{
    setWindowPos(0, 0);
    setFullScreen(true);
    clearWallpaper();
    mConnectionManager = [[ConnectionManager alloc] initWithApp:this];
    [mConnectionManager connectOnPort:kConnectionPort];
}

void AppLauncherClientApp::shutdown()
{
    mConnectionManager = nil;
}

void AppLauncherClientApp::resize()
{
    if (mWallpaperPath != fs::path())
    {
        loadWallpaper(mWallpaperPath, mWallpaperOffset);
    }
}

void AppLauncherClientApp::mouseDown( MouseEvent event )
{
}

void AppLauncherClientApp::update()
{
}

void AppLauncherClientApp::clearWallpaper()
{
    mWallpaperPath = fs::path();
    mWallpaperOffset = Vec2i::zero();
    mBackgroundTexture = gl::Texture();
}

void AppLauncherClientApp::loadWallpaper(const fs::path & imagePath, const Vec2i & offset)
{
    if (fs::exists(imagePath))
    {
        mWallpaperPath = imagePath;
        mWallpaperOffset = offset;
        
        Surface wallpaper = loadImage(loadFile(imagePath));
        
        if (wallpaper && wallpaper.getSize().x > 0 && wallpaper.getSize().y > 0)
        {
        
            Vec2i slideSize = wallpaper.getSize();
            Rectf clientRect = Rectf(offset, getWindowSize() + offset);
            
            int cropX = std::min<int>(clientRect.x1, slideSize.x);
            int cropY = std::min<int>(clientRect.y1, slideSize.y);
            
            int cropWidth = std::min<int>(std::max<int>(std::min<int>(slideSize.x - cropX, slideSize.x), 0),
                                          clientRect.getWidth());
            
            int cropHeight = std::min<int>(std::max<int>(std::min<int>(slideSize.y - cropY, slideSize.y), 0),
                                           clientRect.getHeight());
            
            Surface cropped(cropWidth, cropHeight, wallpaper.hasAlpha());
            for (int x = 0; x < cropWidth; ++x)
            {
                for (int y = 0; y < cropHeight; ++y)
                {
                    cropped.setPixel(Vec2i(x,y), ColorA::black());
                }
            }
            
            Area cropArea(Vec2i(cropX, cropY), Vec2i(cropX + cropWidth, cropY + cropHeight));
            
            cropped.copyFrom(wallpaper, cropArea, cropArea.getUL() * -1);
            
            // Clear it out
            wallpaper = Surface(0,0,0);
            
            mBackgroundTexture = cropped;
            
            return;
        }
    }

    console() << "ERROR: Could not load wallpaper: " << imagePath << endl;
    clearWallpaper();
}

void AppLauncherClientApp::keyDown(KeyEvent event)
{
    if (event.getCode() == KeyEvent::KEY_ESCAPE ||
        event.getChar() == 'f')
    {
        app::setFullScreen(!isFullScreen());
    }
}

void AppLauncherClientApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
    if (mBackgroundTexture)
    {
        gl::draw(mBackgroundTexture);
    }
}

CINDER_APP_NATIVE( AppLauncherClientApp, RendererGl )
