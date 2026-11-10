# CompassHUD

A configurable compass strip that displays your character's heading, along with various markers with information such as name, distance, and time to arrival.

![Example1](https://i.imgur.com/NmushPm.png)


## Inspirations

I was inspired by [Compass](https://www.wowinterface.com/downloads/info14051-Compass.html) and [GoWCompass](https://www.curseforge.com/wow/addons/gowcompass).</br>
While influenced by their ideas, I wrote my own code from scratch—avoiding too much copy-paste.


## Main Features

- Fully movable and resizable compass strip.
- Optional numeric heading display.
- Support for predefined or custom compass textures, or a strip built from configurable letters and degree marks.
- Plethora of markers to be displayed on the compass:
  - the quest, map pin, POI or vignette you are tracking (supertracking), each quest type with its own look,
  - TomTom waypoints,
  - minimap icons (flight points, area POIs, delves, events, dungeon entrances, vignettes, world quests, ...),
  - party and raid members,
  - gathering nodes from GatherMate2 (or GatherLite in WoW: Forever).
- Name, distance (yards or meters) and time to arrival for markers.
- Profiles for different characters or setups.

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

Find the `CompassHUD` addon in the `Options` -> `AddOns` section of the game menu. It has the main page and the `Supertracker`, `Minimap tracking` and `Profiles` subpages. The AddOns compartment entry (and the optional minimap button) opens the settings too.

Most settings have a tooltip with more details when you hover over them.

### HUD settings

- The `General` tab contains basic global settings:
  - lock the compass in place, show the minimap button and the AddOns compartment entry,
  - distances in yards or meters, and optionally as whole numbers (distances under 1000 otherwise show one decimal),
  - update frequency, field of view, scale, width and height (in percent, or in pixels with `Size by: Pixels`), marker size (all markers, separate from the compass size) and frame strata,
  - `Visibility State`: a macro condition deciding when the HUD is shown (default `[petbattle] hide; show`); the HUD is always hidden in instances where the game gives no player facing (dungeons, raids),
  - center the HUD horizontally or reset its position.

![Settings](https://i.imgur.com/W5uhfbJ.png)

- The `Appearance` tab styles the HUD frame (central pin, opacity, border, background, edge line). Its `Pointer font` section sets a default font, size, outline and color for all pointer texts. A text with its own custom font enabled keeps using that one. Party/raid names keep their own color setting. `Max title width` cuts off long titles of the supertracker, minimap icon and gathering node pointers with "..." (0 = no limit).

- The `Custom HUD` tab lets you choose between the compass texture or a strip built from its parts: main cardinal directions (N, E, S, W), ordinal directions (NE, SE, ...) and degrees, each with its own font, color and position. It also holds the numeric heading display (frame, font, decimal points, north shown as 0 or 360).

![Custom](https://i.imgur.com/ElQIDGp.png)

### Supertracker

Under the `Supertracker` submenu, you can configure visibility and behavior for the pointers to what you are tracking.

*General behavior settings:*</br>
![PointerGeneral](https://i.imgur.com/qWe8KPX.png)

- `Pointers stay on HUD`: a pointer outside the field of view stays at the edge of the HUD (optionally with an out-of-HUD indicator).
- `Hide pointers to other continents`.
- `Use map transition for pointers`: when the target is in another zone, point to the way there suggested by the map (portal, entrance, ...).
- `Hide duplicate TomTom pointer` (on by default, shown when TomTom is loaded): when a TomTom waypoint is at the same place as the quest, map pin or POI the game is tracking, only the game's pointer is shown. The TomTom pointer comes back as soon as the game tracks something else.

*Choosing from pointer texture presets:*</br>
![PointerPresets](https://i.imgur.com/V1mzqaP.png)

There is a pointer type for each kind of target: TomTom, user map pin, POI map pin, quest classifications (Quest, Campaign, Important, Legendary, Questline, Meta, Calling, Bonus, Threat, World Quest), daily, weekly and scheduled quests, and an "unknown" fallback.

*For each pointer type, you can also customize:*</br>
*- Visibility, position, size, and textures (separately for a quest in progress and ready to turn in)*</br>
*- Edge detection and rotation (mainly for arrow textures)*</br>
*- Dynamic icon replacements (for World Quests, POI map pins, etc.)*</br>
*- In-game SuperTracker retexturing (the game's diamond above the target uses the pointer's texture)*</br>
*- Copying texture or text settings from another pointer type*</br>

![PointerTexts](https://i.imgur.com/a9x1IA8.png)

*Text display options with font and size selection:*</br>
![PointerTextures](https://i.imgur.com/hUQFmd7.png)

### Minimap tracking

Under the `Minimap tracking` submenu, you'll find settings for icons usually shown on the minimap. These modules can display many icons on the HUD, which costs some performance when everything is enabled.

#### Minimap icons

The `Minimap icons` section covers standard WoW minimap icons (off by default). It has four tabs:
- `General`: scanning radius, update throttle, position, scale, and an opacity gradient based on distance.
- `Filter`: which icon types are shown. Flight points of the other faction are hidden, and you can show only the closest flight point. `Bypass scanning radius` shows selected types in the whole zone. World quests can be filtered to none, all, tracked ones or those tracked by World Quest Tracker.
- `Texts`: name, distance and time to arrival, shown for all icons or only for the one you're facing.
- `Supertracking`: a keybind that sets the icon you are facing as the game's tracked target (press again to clear it), `Hide icon at the tracked target` (on by default: while an icon is tracked, only its supertracker pointer is shown), and the texture used when a user waypoint has to be created.

![MinimapIcons](https://i.imgur.com/FvCUD2R.png)

#### Party/Raid

In the `Party/Raid` section, you can configure the visibility of party and raid members, including icon textures, name display (class colors, fonts, backgrounds), and formatting.</br>
(Default: Party only)

Members on a different map (another continent, behind a portal, underground, ...) can get their own marker style; their direction may not be accurate.

#### Addon integrations

- **GatherMate2 / GatherLite** (off by default): possible gathering node locations within a scanning radius. Node types follow GatherMate2's own display filter. In WoW: Forever, `GatherLite` works the same way when GatherMate2 is not loaded, following GatherLite's minimap tracking toggles.
- **TomTom**: the TomTom arrow's waypoint is shown as its own pointer type.
- **World Quest Tracker**: its tracked quests can be used as the world quest filter for minimap icons.

### Miscellaneous

#### Custom compass strip textures
You can use your own.<br>
It must be 2048x16, have 720 degrees starting from N(orth), and be in BLP or TGA format (see `CompassHUD.tga` in the Media folder for reference).

Save your file somewhere in the `Interface\Addons` folder (outside any addon folder to avoid deletion on update).

In your SavedVariables file located at `WTF\Account\<AccountID>\SavedVariables\CompassHUD.lua`, add:</br>
*`CompassTextureTexture = [[Interface\Addons\]] .. {your file name without extension}`*</br>
just after the line containing:</br>
*`["PositionX"]`*

Check that you put it in the correct profile. Edit the file only while the game is closed (or logged out), as the game overwrites it on logout.


## Issues and suggestions

If you run into problems or have feature requests, feel free to [open an issue on GitHub](https://github.com/BelegCufea/CompassHUD/issues).
