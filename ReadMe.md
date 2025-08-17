# CompassHUD

A configurable compass strip that displays your character's heading, along with various markers with information such as name, distance, and time to arrival.

![Example1](https://i.imgur.com/NmushPm.png)


## Inspirations

I was inspired by [Compass](https://www.wowinterface.com/downloads/info14051-Compass.html) and [GoWCompass](https://www.curseforge.com/wow/addons/gowcompass).</br>
While influenced by their ideas, I wrote my own code from scratch—avoiding too much copy-paste.


## Main Features

- Fully movable and resizable compass strip.
- Optional numeric heading display.
- Support for predefined or custom compass textures.
- Plethora of markers to be displayed on the compass.

### Some examples:

*- Changing background and border:*</br>
![BackgroundBorder](https://i.imgur.com/fKY6J1S.png)

*- Configuring compass HUD FOV (up to 360°):*</br>
![FOV](https://i.imgur.com/Q9HEzRG.png)

*- Allowing quest markers to remain visible on the edge of the compass HUD:*</br>
![QuestOutOfBoundery](https://i.imgur.com/jzSYOS6.png)

*- Customizing visibility, textures, and behavior for various pointer types:*</br>
![CustomTextures](https://i.imgur.com/fhRaRWj.png)

*- Setting numerical heading display options:*</br>
![Heading](https://i.imgur.com/CxlBmpL.png)


## Configuration

Find the `CompassHUD` addon in the `Options` -> `AddOns` section of the game menu.

### HUD settings

- The `General` panel contains basic global settings. For many of these settings, there is a tooltip shown while hovering over the them.</br>
![Settings](https://i.imgur.com/W5uhfbJ.png)

- The `Compass HUD` panel lets you choose between the default texture or customize your own strip with posibility to show/hide/edit several elements.</br>
![Custom](https://i.imgur.com/ElQIDGp.png)

### Supertracker

Under the `Supertracker` submenu, you can configure visibility and behavior for various pointer types.

*General behavior settings:*</br>
![PointerGeneral](https://i.imgur.com/qWe8KPX.png)

*Choosing from pointer texture presets:*</br>
![PointerPresets](https://i.imgur.com/V1mzqaP.png)

*For each pointer type, you can also customize:*</br>
*- Visibility, position, size, default texture*</br>
*- Edge detection and rotation (mainly for arrow trextures)*</br>
*- Dynamic icon replacements (for World Quests, POI map pins, etc.)*</br>
*- In-game SuperTracker retexturing*</br>

![PointerTexts](https://i.imgur.com/a9x1IA8.png)

*Text display options with font and size selection:*</br>
![PointerTextures](https://i.imgur.com/hUQFmd7.png)

### Minimap tracking

Under the `Minimap tracking` submenu, you’ll find settings for icons usually shown on the minimap. These modules can display many icons on the HUD, potentially impacting FPS if used with all options enabled.

#### Minimap icons

The `Minimap icons` section covers standard WoW minimap icons (off by default).

You can configure:
- Tracking radius</br>
- Opacity gradient based on distance</br>
- Icon filtering by type</br>
- Text display options (name, distance, TTA)</br>
- Whether texts are shown for all icons or only the one you're facing</br>
- Keybind for setting the facing minimap icon as a Supertracker

![MinimapIcons](https://i.imgur.com/FvCUD2R.png)

#### Party/Raid

In the `Party/Raid` section, you can configure the visibility of party and raid members, including icon textures, name display, and formatting.</br>
(Default: Party only)

#### Addon integrations

Additional sections support integrations with other addons (off by default).

For example, if you have `GatherMate2`, you can display possible gathering node locations on the HUD.

### Miscelaneous

#### Custom compass strip textures
You can use your own.<br>
It must be 2048x16, has 720 degrees starting from N(orth) and be in BLP or TGA fromat (see `CompassHUD.tga` at Media folder for reference).

Save your file somewhere in `Interface\Addons` folder (outside any addon folder to avoid deletion on update).

In your SavedVariables file located at `WTF\Account\<AccountID>\SavedVariables\CompassHUD.lua`, add:</br>
*`CompassTextureTexture = [[Interface\Addons\]] .. {your file name without extension}`*</br>
just after the line containing:</br>
*`["PositionX"]`*

Check if you put it in correct profile.


## Issues and suggestions

If you run into problems or have feature requests, feel free to [open an issue on GitHub](https://github.com/BelegCufea/CompassHUD/issues).