#include "cinder/app/AppNative.h"
#include "cinder/gl/gl.h"

using namespace ci;
using namespace ci::app;
using namespace std;

class SillyAppApp : public AppNative {
  public:
	void setup();
	void mouseDown( MouseEvent event );	
	void update();
	void draw();
};

void SillyAppApp::setup()
{
}

void SillyAppApp::mouseDown( MouseEvent event )
{
}

void SillyAppApp::update()
{
}

void SillyAppApp::draw()
{
	// clear out the window with black
	gl::clear( Color( 0, 0, 0 ) );
    gl::color(0.75f,0.75f,0.75f);
    gl::drawSolidCircle(getWindowCenter(), 200);
    gl::enableAlphaBlending();
    gl::drawString("0", getWindowCenter(), ColorA::black());
}

CINDER_APP_NATIVE( SillyAppApp, RendererGl )
