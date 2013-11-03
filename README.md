AppLauncher
===========

###Overview
An application that launches other applications on remote machines.  
Launches can be times, looped and automatically advanced on an arbitrary number of machines.

[Video](http://www.youtube.com/watch?v=Z4A6BD6035w):  
http://www.youtube.com/watch?v=Z4A6BD6035w

![image](https://raw.github.com/wdlindmeier/AppLauncher/master/misc/launcher_screenshot.png)

###Instructions
1) Create a directory on all of the client machines that contatins the apps and wallpapers. This path must be identical on each machine.  

2) Open apps/AppLauncherClient on all of the client machines. This app coordinates with the Launcher to start and stop local processes. The client opens in full-screen mode, but this can be toggled by pressing 'f'.  

3) Open AppLauncher on the controller machine. When it boots, you'll be asked to select a .schedule file. You can find a sample in the "data" folder. This is the format to create your own:  

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
      <!-- 	duration-seconds:
      		The duration in seconds that the app should run. 
      		If this value is 0, the launcher won't quit the app
			until the "stop" button is pressed.
      		Required.
      -->
      <duration-seconds>10</duration-seconds>
            
      <!-- 	launch-path:
      		The absolute path to the application.  
      		This must be the same on all machines. 
          
          	launch-url:
          	A URL to your content. Will be opened in Chrome (full screen).
          
          	launch-command:
          	A command-line script to execute (e.g. AppleScript).
          
      		One of the above is required. Only one will be launched.
      -->
      <launch-path>/AppLauncher/apps/SillyApp0.app</launch-path>
      <launch-url>https://www.shadertoy.com/view/XslGRr</launch-url>
      <launch-command>/usr/bin/osascript /AppLauncher/scripts/launchApp.scpt</launch-command>
      
      <!-- 	kill-name:
      		The app "kill name". This is used as a unique identifier and 
      		should be the same name used with the pkill command. 
      		This is generally the name of the app bundle minus the ".app". 
      		Required.
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
      <duration-seconds>5</duration-seconds>
      <launch-path>/AppLauncher/apps/SillyApp1.app</launch-path>
      <kill-name>SillyApp1</kill-name>
      <wallpaper-path>/AppLauncher/wallpapers/wallpaper_1.jpg</wallpaper-path>
    </app>
    
    <app>
      <duration-seconds>10</duration-seconds>
      <launch-path>/AppLauncher/SillyApp2.app</launch-path>
      <kill-name>SillyApp2</kill-name>
      <wallpaper-path>/AppLauncher/wallpapers/wallpaper_2.png</wallpaper-path>
    </app>
    
  </apps>
  
</schedule>
```
4) Press the Start button to begin the schedule. The schedule will begin on whatever app is selected in the table view.

###Contents

* **AppLauncher/**: The code for the controller application. Starts and stops apps on all machines.
* **AppLauncherClient/**: The code for the client application. Launches apps locally on each machine. 
* **SillyApp/**: Sample apps to start and stop.
* **apps/**: Builds of the above applications (for OS X).
* **data/**: .schedule files, which is what the AppLauncher reads.
* **misc/**: ...
* **wallpapers/**: Background images displayed by the client behind the launched app.
* **README.md**: This file.
