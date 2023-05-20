# CompassHUD

A configurable compass strip showing player's heading along with questmarkers including distance and time to arive.

![Example1](https://i.imgur.com/D7Ugc0T.png)


## Inspirations

I was inspired by [Compass](https://www.wowinterface.com/downloads/info14051-Compass.html) and [GoWCompass](https://www.curseforge.com/wow/addons/gowcompass) addons. Thought I tried to write my own code and not use CTRL+C and CTRL+V too much.


## Features

- Compass strip can be moved, resized and centered on screen.
- You can define update rate.
- You can choose either predefined texture for main HUD or define your own.
- Autamatically detects TomTom crazy arrow and allows to set pointer on the HUD.
- Available configurable options are:

    *- setting background and border*

    ![BackgroundBorder](https://i.imgur.com/fKY6J1S.png)

    *- setting compass HUD FOV up to 360*

    ![FOV](https://i.imgur.com/Q9HEzRG.png)

    *- allowing quest markers to stay on the edge of compass HUD even when they go beyond the boundaries*

    ![QuestOutOfBoundery](https://i.imgur.com/jzSYOS6.png)

    *- setting visibility and several other options for different types of pointers*

    *- setting font, visibilty and colors for cardinal and ordinal directions and degrees for custom HUD*


## Configuration

Locate the `CompassHUD` section within the `Options` -> `Addon` section.

- On the `Settings` panel you can change some general options.

![Settings](https://i.imgur.com/3c6xno9.png)

- On the `Compass HUD settings` panel you can choose if you want to construct your own custom HUD or use standard texture.

![Custom](https://i.imgur.com/GSMDwDR.png)

- On the `Pointers` panel you can set visiblity and several other settings for different types of pointers.

![Pointers](https://i.imgur.com/Xh1lwo5.png)


## Known bugs (will hammer them eventually)

- strata doesn't work

### TODO (maybe, if there is a demand)

- More textures
    - *You can use your own. It has to be 2048x16, has 720 degrees starting from N and be in BLP or TGA fromat (look at `CompassHUD.tga` at Media folder). Just put it somewhere in Interface\Addons folder (don't put it in any addon folder as it may be deleted when updating that addon) in SavedVariables put* `CompassTextureTexture = [[Interface\Addons\]] .. {your texture name},` *just after line* `["PositionX"]` ... *of your profile.*


## Issues and suggestions

If you encounter any problems or have a suggestion, please [open an issue on Github](https://github.com/BelegCufea/CompassHUD/issues).