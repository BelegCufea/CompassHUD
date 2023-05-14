# CompassHUD

A configurable compass strip showing player's heading along with questmarkers including distance and time to arive.

![Example1](https://i.imgur.com/D7Ugc0T.png)


## Inspirations

I was inspired by [Compass](https://www.wowinterface.com/downloads/info14051-Compass.html) and [GoWCompass](https://www.curseforge.com/wow/addons/gowcompass) addons. Thought I tried to write my own code and not use CTRL+C and CTRL+V too much.


## Features

- Compass strip can be moved, resized and centered on screen.
- You can define update rate.
- You can choose either predefined texture for main HUD or define your own.
- Autamatically detects TomTom crazy arrow and adds a marker (on top)
- Available configurable options are (T indicates it is also avaliable for texture HUD option):

    *- setting backdound and border (T)*

    ![BackgroundBorder](https://i.imgur.com/fKY6J1S.png)

    *- setting compass HUD FOV up to 360 (T)*

    ![FOV](https://i.imgur.com/Q9HEzRG.png)

    *- allowing quest markers to stay on the edge of compass HUD even when they go beyond the boundaries (T)*

    ![QuestOutOfBoundery](https://i.imgur.com/jzSYOS6.png)

    *- setting font, visibilty and colors for cardinal and ordinal directions and degrees for custom HUD*


## Configuration

Locate the `CompassHUD` section within the `Options -> Addon` section.

- On the `Settings` panel you can change options available for any kind of compass.

![Settings](https://i.imgur.com/3c6xno9.png)

- On the `Compass HUD settings` panel you can choose if you want to construct your own custom HUD or use standard texture.

![Custom](https://i.imgur.com/GSMDwDR.png)


## Known bugs (will hammer them eventually)

- strata doesn't work
- switching profiles generates lots of LUA errors, /reload needed

### TODO (maybe, if there is a demand)

- More textures (*You can use your own. It has to be 2048x16, has 720 degrees staring from N and be in BLP or TGA fromat. Just put it in CompassHUD\Media and in SavedVariables put* CompassTextureTexture = [[Interface\Addons\]] .. ADDON_NAME .. [[\Media\]] .. {your texture name}, )
- Customize pointers (hide some types, distance, TTA ...)


## Issues and suggestions

If you encounter any problems or have a suggestion, please [open an issue on Github](https://github.com/BelegCufea/CompassHUD/issues).