AppLauncher
===========

###Overview
An application that launches other applications on remote machines.  
Launches can be times, looped and automatically advanced on an arbitrary number of machines.

Originaly developed for the [Big Screens](http://itp.nyu.edu/bigscreens/) course at ITP/NYU.

[Video: Multi-screen](http://www.youtube.com/watch?v=Z4A6BD6035w)  
[Video: Various launch types](http://youtu.be/hgu0jd0R4i0)

![image](https://raw.github.com/wdlindmeier/AppLauncher/master/misc/launcher_screenshot.png)

###Instructions
1) Create a directory on all of the client machines that contatins the apps and wallpapers. This path must be identical on each machine.  

2) Open apps/AppLauncherClient on all of the client machines. This app coordinates with the Launcher to start and stop local processes. The client opens in full-screen mode, but this can be toggled by pressing 'f'.  

3) Open AppLauncher on the controller machine. When it boots, you'll be asked to select a .schedule file. You can find a sample in the "schedules" folder. This is the format to create your own:  

```xml
<schedule>
  
  <!-- 	loop:
  		Should the schedule loop or not? 
  -->
  <loop>false</loop>
  
  <!-- 	auto-advance:
  	   	Should the apps auto advance? 
  -->
  <auto-advance>true</auto-advance>
  
  <!-- 	debug:
		When debug is true, the app will present (more) Alert dialogs 
  	   	if things go wrong. 
  -->  
  <debug>true</debug>
  
  <!-- 	duration-interlude-seconds:
  		The number of seconds to wait between apps. 
  		3+ is recommended to transition out of full-screen mode. 
  -->
  <duration-interlude-seconds>3.0</duration-interlude-seconds>
  
  <!-- 	machines:
  		The IP Addresses of each client machine. 
  -->
  <machines>
  	<!-- A remote machine -->
    <client-ip>10.0.1.2</client-ip>
    <!-- The same machine the launcher is running on -->
    <client-ip>127.0.0.1</client-ip>
  </machines>
  
  <!-- 	apps:
  		The list of apps to run. 
  -->
  <apps>
  
    <app>
      <!-- 	name:
          	A descriptive title. Displayed in the launcher window. 
          	Required.
      -->
      <name>Silly App 0</name>
    
      <!-- 	duration-seconds:
      		The duration in seconds that the app should run before
      		the next app launches. If this value is 0, the launcher 
      		won't quit the app until the "stop" button is pressed.			Required.
      -->
      <duration-seconds>10</duration-seconds>
            
      <!-- 	launch-path:
      		The absolute path to the application.  
      		This must be the same on all machines unless it has a
      		"client-ip" attribute (see below).
          
          	launch-url:
          	A URL to your content. 
          	Will be opened in a full screen Chrome window.

          	launch-video:
          	An absolute path to a video that can be played by QuickTime.
          	Will be presented in a full screen QuickTime window.
          
          	launch-command:
          	A command-line script to execute (e.g. AppleScript).
          
      		One of the above is required. Only one will be launched.
      -->
      <launch-path>/AppLauncher/apps/SillyApp0.app</launch-path>
      <launch-url>https://www.shadertoy.com/view/XslGRr</launch-url>
      <launch-video>/AppLauncher/apps/FullScreenMovie.mov</launch-video>
      <launch-command>/usr/bin/osascript /AppLauncher/scripts/launchApp.scpt</launch-command>

      <!-- 	"client-ip" attribute: 
    		Some app values can also take a "client-ip" attribute. This allows
    		you to specify unique values for different machines (e.g. unique
    		launch paths). Values that can use the "client-ip" attribute:
    		• All launch values (path/url/video/command)
    		• kill-name
    		• wallpaper-path
    		
    		Any value that doesn't have a specific client-ip will be the "default"
    		value for each client.
	  -->      
      <launch-path client-ip="10.0.1.2">/AppLauncher/apps/SillyApp999.app</launch-path>
      
      <!-- 	kill-name:
      		The app "kill name". This should be the string used with the 
      		pkill command (using the -f modifier). This is generally the name 
      		of the app bundle minus the ".app".
      		Required if you want the app to stop running after the duration.
      		Otherwise, the app will continue to run when the next app is launched.
      -->
      <kill-name>SillyApp0</kill-name>
      
      <!-- 	wallpaper-path:
      		The absolute path to the wallpaper. 
      	   	This image is shown behind the launched application. 
      		Optional. 
      -->
      <wallpaper-path>/AppLauncher/wallpapers/wallpaper_0.jpeg</wallpaper-path>
    </app>
    
    <app>
      <name>Silly App 1</name>
      <duration-seconds>5</duration-seconds>
      <launch-path>/AppLauncher/apps/SillyApp1.app</launch-path>
      <kill-name>SillyApp1</kill-name>
      <wallpaper-path>/AppLauncher/wallpapers/wallpaper_1.jpg</wallpaper-path>
    </app>
    
    <app>
      <name>Silly App 2</name>
      <duration-seconds>10</duration-seconds>
      <launch-path>/AppLauncher/SillyApp2.app</launch-path>
      <kill-name>SillyApp2</kill-name>
      <wallpaper-path>/AppLauncher/wallpapers/wallpaper_2.png</wallpaper-path>
    </app>
    
  </apps>
  
</schedule>
```
4) Press the Start button to begin the schedule. The schedule will begin on whatever app is selected in the table view.

###Important Notes

When an app (or video, url, etc.) has timed out, AppLauncher will **force quit** the application (if it has a kill-name). This means all windows will close and any work-in-progress will be unsaved. 

###Contents

* **AppLauncher/**: The code for the controller application. Starts and stops apps on all machines.
* **AppLauncherClient/**: The code for the client application. Launches apps locally on each machine. 
* **SillyApp/**: Sample apps to start and stop.
* **apps/**: Builds of the above applications (for OS X).
* **misc/**: ...
* **schedules/**: Some sample .schedule files, which is what the AppLauncher reads.
* **wallpapers/**: Background images displayed by the client behind the launched app.
* **README.md**: This file.
