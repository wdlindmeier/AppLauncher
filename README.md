AppLauncher
===========

##Overview
An application that launches other applications on remote machines.  
Launches can be times, looped and automatically advanced on an arbitrary number of machines.

[Video](http://www.youtube.com/watch?v=TMVnVEth684):  
http://www.youtube.com/watch?v=TMVnVEth684

![image](https://raw.github.com/wdlindmeier/AppLauncher/master/misc/launcher_screenshot.png)

##Instructions
When AppLauncher is run, you must open a .schedule file. You can find a sample in the "data" folder. The format:  

```xml
<settings>
  
  <!-- Should the schedule loop or not? -->
  <loop>false</loop>
  
  <!-- Should the apps auto advance? -->
  <auto-advance>true</auto-advance>
  
  <!-- IP Addresses of each client machine. -->
  <machines>
  	<!-- A remote machine -->
    <client-ip>10.0.1.2</client-ip>
    <!-- The same machine the launcher is running on -->
    <client-ip>127.0.0.1</client-ip>
  </machines>
  
  <!-- The list of apps to run. -->
  <apps>
  
    <app>
      <!-- 	duration-seconds:
      		The duration, in seconds, that the app should run. 
      		Required.
      -->
      <duration-seconds>10</duration-seconds>
            
      <!-- 	launch-path:
      		The absolute path to the application.  
      		This must be the same on all machines. 
      		Required.
      -->
      <launch-path>/silly_apps/apps/SillyApp0.app</launch-path>
      
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
      <wallpaper-path>/silly_apps/wallpapers/wallpaper_0.jpeg</wallpaper-path>
    </app>
    
    <app>
      <duration-seconds>5</duration-seconds>
      <launch-path>/silly_apps/apps/SillyApp1.app</launch-path>
      <kill-name>SillyApp1</kill-name>
      <wallpaper-path>/silly_apps/wallpapers/wallpaper_1.jpg</wallpaper-path>
    </app>
    
    <app>
      <duration-seconds>10</duration-seconds>
      <launch-path>/silly_apps/SillyApp2.app</launch-path>
      <kill-name>SillyApp2</kill-name>
      <wallpaper-path>/silly_apps/wallpapers/wallpaper_2.png</wallpaper-path>
    </app>
  </apps>
</settings>
```

##Contents

* *AppLauncher*: The code for the controller application. Starts and stops apps on all machines.
* *AppLauncherClient*: The code for the client application. Launches apps locally on each machine. 
* *SillyApp*: Sample apps to start and stop.
* *apps*: Builds of the above applications (for OS X).
* *data*: .schedule files, which is what the AppLauncher reads.
* *misc*: ...
* *wallpapers*: Background images displayed by the client behind the launched app.
* *README.md*: This file.
