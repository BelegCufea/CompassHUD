# v1.2.2 ()

## Fix

- Quest pointer did not change scale and orientation (when on the edge) upon quest completion
- Fixed a typo in the settings (there may still be more).

## Misc

- "Borrowed" a much more efficient code for obtaining quest positions on the map from [Kaliel's Tracker]https://www.curseforge.com/wow/addons/kaliels-tracker

# v1.2.1 (21.8.2024)

## Added

- More options for scaling (separate width and height)
- Option to show a small indicator when the pointer is out of the HUD boundaries for non-rotating textures
- Option to show/hide center HUD pin indicating player's facing
- CompassHUD gradient background with the ability to change color (see screenshot below)

*Scale and `Out of HUD indicator` settings*

![ScaleSettings](https://i.imgur.com//kxXlfMi.png)

*`Out of HUD indicator` and new `CompassHUD gradient` background demonstration*

![Gradient](https://i.imgur.com/piZGMsG.png)

# v1.2.0a (19.8.2024)

## Fix

- The turn-in pointer texture was rotating at the edge of the compass even when "Edge rotation" was unchecked. This has been resolved.

## Misc

- Revamped the pointer texture presets system to allow for easier addition of new presets.
- Added a new "Classic Turn-In" preset.

# v1.2.0 (18.8.2024)

## New

### **Dynamic Pointer Textures**
**Idea, help, and testing by [sampconrad](https://github.com/sampconrad)**

First of all, the number of pointers has increased. This should somehow accommodate new quest types in the `The War Within` expansion.

On the `Pointers` tab, the settings are now split into two tabs.

The previous options are now moved into a `Texts` tab. The new `Textures` tab now includes settings for more options regarding pointer textures. The `Copy...` functionality will copy only settings from that particular tab.

![PointersTextures](https://i.imgur.com/PjywdZ6.png)

Options are split into two subsections: `Progress pointer`, which will be used when a quest is not finished yet, and `Turn-in pointer`, which will be used when a quest is ready for turn-in (dah!).

Besides the obvious ones, the settings include these two options:

- **Edge Detection** - Previously, the arrows were flipped when on the top side of the compass and, when `Pointers stays on HUD` was checked, they rotated when on the edge of the Compass. Now, for some textures, that may look ridiculous, so you have an option to disable that behavior.
- **Custom Atlas ID** - If you don't like any of the available `Texture` pointers, you can enter an atlasID to use instead. WoW currently doesn't supply the list of these, but you can use, for example, the integrated Texture picker in [WeakAuras](https://www.curseforge.com/wow/addons/weakauras-2) (use `Blizzard Atlas` option) or [TextureAtlasViewer](https://www.curseforge.com/wow/addons/textureatlasviewer).

There are also two `Presets` accessible by clicking that line on top of the pointers list.

![PointersTextures](https://i.imgur.com/SghnLjp.png)

The `Modern` one should closely follow the [The War Within](https://news.blizzard.com/en-us/world-of-warcraft/24117139/user-interface-and-quest-updates-in-the-war-within) new look.


## Fix

- Compass stayed visible in instances

# v1.1.5 (15.8.2024)

## New

- Added `Visibility State` option on Settings tab to set conditions for displaying compass, they use [macro conditionals](https://wowpedia.fandom.com/wiki/Macro_conditionals)

# v1.1.4 (14.8.2024)

## New

- Added an option to include quest text
- Added an option to change the pointers' texture

## Fix

- Fix for 11.0.2

# v1.1.3 (6.8.2024)

## Fix

- Missing new type of quest (ResetByScheduler)

# v1.1.2 (1.8.2024)

## Fix

- The War Within (11.0) Expansion workaround (possible fix by [sampconrad](https://github.com/sampconrad))
- Fix for not finding "portals"
- Bottom edge line vertical positioning is moving the line other way

# v1.1.2-beta (27.7.2024)

## Fix

- The War Within (11.0) Expansion workaround (possible fix by [sampconrad](https://github.com/sampconrad))
- Bottom edge line vertical positioning is moving the line other way

# v1.1.1 (20.5.2023)

## New

- Added option to add edge line (top and/or bottom) for the HUD (settings on the `General` panel)

![EdgeLine](https://i.imgur.com/fjhDr8Y.png)

## Fix

- Strata doesn't work

# v1.1.0 (17.5.2023)

## New

- On the `Pointers` panel you can set visiblity and several other settings for different types of pointers.

![Pointers](https://i.imgur.com/Xh1lwo5.png)

# *v1.1.0-beta1 (16.5.2023)*

## New

- Options for modifying visibility and behavior of quest pointers.

# v1.0.0a (15.5.2023)

## Fix

- Switching profiles generates lots of LUA errors

# v1.0.0 (14.5.2023) - **Initial release**