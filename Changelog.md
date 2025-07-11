# v1.5.0a

## Fix
- Posible fix for In-world SuperTracker texture not always replacing default diamond

# v1.5.0 (4.7.2025)

## New
- In-world SuperTracker texture replacer
  ![SuperTracker texture](https://i.imgur.com/VlWUldp.png)
  - Lets you replace the default golden diamond of the in-world SuperTracker with a CompassHUD pointer texture.
  - Options to enable this behavior for each type of pointer can be found under `CompassHUD` -> `Pointers` as `Re-texture SuperTracker`. This is enabled by default for World Quests and POIs.
  ![SuperTracker texture options](https://i.imgur.com/brzS5GT.png)


- [GatherMate2](https://www.curseforge.com/wow/addons/gathermate2) integration (disabled by default)
  ![GatherMate2](https://i.imgur.com/kJGB9hg.png)
  - Allows you to display icons for gathering nodes from the GatherMate2 database. These mark potential spawn points — so there’s no guarantee a material will always be present.
  - Only shows nodes that are enabled in your GatherMate2 settings. There’s no need to toggle their visibility on the world map or minimap.
  - Options can be found under `CompassHUD` -> `Addon integrations`. These include `Scanning radius` option, which sets the minimum distance at which a node will appear on the HUD (default is 150). Be aware that setting this too high can clutter your CompassHUD!
    - 100 = max zoomed in minimap
    - 300 = max zoomed out minimap
  ![GatherMate2 Options](https://i.imgur.com/JGXEgbj.png)

# v1.4.7 (18.6.2025)

## Fix
- Removed circular background around `WorldQuests` pointers when not using `Use reward texture` option (thanks [Snagle69](https://legacy.curseforge.com/members/snagle69))

## Misc
- Bumped TOC to 11.1.7

# v1.4.6 (26.4.2025)

## Misc
- Textures used for world quests (when `Use reward texture` is enabled in the `WorldQuests` category under the `Pointers` tab) are now circular with a subtle border to better match the game's visual style.
- Updated TOC to 11.1.5
- *Lua (for programming purposes only):* Cleaned up the code to avoid creating unnecessary global frames. All elements can now be accessed through the main `CompassHUD` frame.

# v1.4.5 (21.4.2025)

## New
- Added a new option (enabled by default) to use map-suggested transitions (such as portals or entrances) when the tracked quest or map pin is located in a different zone. You can toggle this feature using the `Use map transition for pointers` checkbox found on the `General` tab.

  **Tip:** For better results, consider disabling the `Hide pointers to other continents` option (also found on the`General` tab). This setting is now disabled by default for new profiles and fresh installations.

  ![Map transition](https://i.imgur.com/3k87nBR.png)

# 1.4.4 (16.4.2025)

## New
- World quest textures no longer require the [World Quest Tracker](https://www.curseforge.com/wow/addons/world-quest-tracker) addon. The `Use WQT texture` option has been renamed to `Use reward texture` and it can be toggled in the `WorldQuests` category under the `Pointers` tab (enabled by default). The textures used should match or closely resemble those from WQT.

## Fix
- Hide pointers for world map vignettes when you arive at destination
- Nudged pointing arrows (left/right) a bit when not using `Edge rotation`

# 1.4.3 (8.4.2025)

## New
- World map POIs for Taxi locations are now recognized, with proper coordinates, titles, and textures applied.
- World map POIs for Quest offers now display their titles if available (still working on retrieving accurate coordinates).
- World map vignettes (e.g., scrap piles, world bosses, etc.) are now trackable as POIs (configuration in `POI map pin` category on the `Pointers` tab).
- World Quests now support textures from the [World Quest Tracker](https://www.curseforge.com/wow/addons/world-quest-tracker) addon.
If you prefer a unified pointer for all world quests, you can disable the `Use WQT texture` option in the `WorldQuests` category on the `Pointers` tab.

# 1.4.2 (29.3.2025)

## New
- World map POIs (delves, cities, etc.) now have their own preset category, `POI map pin` on the `Pointers` tab. By default, the pointer texture matches the world map texture. If no texture is found, it will fall back to the selected default.

  If you prefer a unified pointer for all POIs, you can disable the `Use worldmap texture` option in the `POI map pin` category.

  ![POI texture](https://i.imgur.com/yef5Ziy.png)

# 1.4.1 (21.3.2025)

## New
- Options to hide pointers to other continents (General tab, default true)

## Misc
- Added category (User Interface) to TOC

# 1.4.0 (6.11.2024)

## New
- Ability to track POI on Worldmap (delves, quest offers, taxis ...)
  - For some map pins (delves, cities ...) I was able to get precise coordinates. If I can't do that, I approximate coordinates from cursor position in the moment of clicking the POI on WorldMap so they may be bit off.

# v1.3.1 (30.10.2024)

## Fix
- Some small fixes for TomTom integration

## Misc
- TOC 11.0.5

# v1.3.0a (4.10.2024)

## Fix
- Fix for world quest pointer stay visible even after world quest is finished

# v1.3.0 (8.9.2024)

## New

### **Markers for group members**
**Idea, help, and testing by [raptormama](https://github.com/raptormama)**

For those who like to quest in a group or for the masochists doing overworld raids and wanting to see every single one of their groupmates displayed as a marker on the compass, we now introduce the brand-new Group Markers feature.

![Heading](https://i.imgur.com/SRvscsO.png)

You can change several options on the `Group tab` in the addon's settings. Primarily, you can decide whether you want to use this feature only in Party or also in Raid (it might get a bit cluttered, so it's off by default), and you can modify the markers.

![Heading](https://i.imgur.com/iEfYw9x.png)

There's also a whole section dedicated to group members' names on `Texts tab` in the `Group` settings. Only the Party section is shown below, but there's also one for Raids.

![Heading](https://i.imgur.com/19hiPvu.png)

We (both [raptormama](https://github.com/raptormama) and I) hope you like it and that there are as few errors as possible.

## Fix

- Fix for TomTom (reported and tested by [yoshimo](https://github.com/yoshimo))

# v1.2.3 (1.9.2024)

## New

- Classic/Modern preset for pointers

## Fix

- Compass visible in Delves

# v1.2.2a (27.8.2024)

## Fix

- Bonus objective tracking and pointer in Modern preset
  - more may come as I will play through the new expansion (sorry for inconvenience)

# v1.2.2 (25.8.2024)

## New

- Option to display heading (idea and testing by [Weischbier](https://github.com/Weischbier))

![Heading](https://i.imgur.com/p5Jcgkl.png)

- Option to show minimap button and/or entry in AddOns Compartment on `General Tab` (request by [raptormama](https://github.com/raptormama))
- Support for DataBroker

## Fix

- Quest pointer did not change scale and orientation (when on the edge) upon quest completion
- Fixed few typos in the settings (there may still be more).

## Misc

- Some shuffling of settings in addon options to make it less crowded and to make more room for additional features.
- "Borrowed" a much more efficient code for obtaining quest positions on the map from [Kaliel's Tracker](https://www.curseforge.com/wow/addons/kaliels-tracker)

# v1.2.1 (21.8.2024)

## New

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