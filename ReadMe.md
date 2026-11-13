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
  - TomTom's crazy arrow target and all your TomTom waypoints,
  - minimap icons (flight points, area POIs, delves, events, dungeon entrances, vignettes, world quests, quests from your quest log, ...),
  - party and raid members,
  - gathering nodes from GatherMate2 (or GatherLite in WoW: Forever),
  - Questie's minimap icons: available quests, turn-ins, objectives, townsfolk (innkeepers, trainers, mailboxes, ...),
  - the icons of HandyNotes plugins (MapNotes, treasures and rares of the expansion plugins, your own notes, ...).
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

*- Questie's icons (quest givers, turn-ins, townsfolk) on the compass:*</br>
![QuestieInAction](https://i.imgur.com/hJeXf5u.png)


## Configuration

Find the `CompassHUD` addon in the `Options` -> `AddOns` section of the game menu. It has the main page and the `Supertracker`, `Minimap tracking` and `Profiles` subpages. The AddOns compartment entry (and the optional minimap button) opens the settings too.

Most settings have a tooltip with more details when you hover over them.

### HUD settings

- The `General` tab contains basic global settings:
  - lock the compass in place (it can still be moved in the game's Edit Mode: drag the highlighted compass, click it to open these options), show the minimap button and the AddOns compartment entry,
  - distances in yards or meters, and optionally as whole numbers (distances under 1000 otherwise show one decimal),
  - update frequency, field of view, scale, width and height (in percent, or in pixels with `Size by: Pixels`), marker scale (all markers, separate from the compass size) and frame strata,
  - `Visibility State`: a macro condition deciding when the HUD is shown (default `[petbattle] hide; show`); the HUD is always hidden in instances where the game gives no player facing (dungeons, raids),
  - center the HUD horizontally or reset its position.

![Settings](https://i.imgur.com/wym5Vc0.png)

*The compass in the game's Edit Mode (drag it to move, click it for the options):*</br>
![EditMode](https://i.imgur.com/pf4eOgR.png)

- The `Appearance` tab styles the HUD frame (central pin, opacity, border, background, edge line). Its `Pointer font` section sets a default font, size, outline and color for all pointer texts. A text with its own custom font enabled keeps using that one. Party/raid names keep their own color setting. `Max title width` cuts off long titles of the supertracker pointers and of all icon markers with "..." (0 = no limit).

- The `Custom HUD` tab lets you choose between the compass texture or a strip built from its parts: main cardinal directions (N, E, S, W), ordinal directions (NE, SE, ...) and degrees, each with its own font, color and position. It also holds the numeric heading display (frame, font, decimal points, north shown as 0 or 360).

![Custom](https://i.imgur.com/ElQIDGp.png)

- The `Speech` tab (accessibility) reads out the name of what is in front of you on the compass, with the game's text to speech: the supertracked target, TomTom's crazy arrow target, minimap icons, Questie icons, gathering nodes, TomTom waypoints and/or HandyNotes icons (the one closest to the direction you are facing), each with its own toggle, optionally with the distance. Each one is read once, when you turn to it and have faced it for a short delay; you can set the facing angle, the delay, the voice (any voice the game offers), rate and volume, and test it. `Only read out names shown on the compass` limits it to what currently shows its name (with a texts visibility angle: the one icon showing its texts). Text to speech is played outside the game's sound channels, so it has its own volume.

![Speech](https://i.imgur.com/GxYMsDN.png)

### Supertracker

Under the `Supertracker` submenu, you can configure visibility and behavior for the pointers to what you are tracking.

*General behavior settings:*</br>
![PointerGeneral](https://i.imgur.com/qWe8KPX.png)

- `Pointers stay on HUD`: a pointer outside the field of view stays at the edge of the HUD (optionally with an out-of-HUD indicator).
- `Hide pointers to other continents`.
- `Use map transition for pointers`: when the target is in another zone, point to the way there suggested by the map (portal, entrance, ...).

*Choosing from pointer texture presets:*</br>
![PointerPresets](https://i.imgur.com/V1mzqaP.png)

There is a pointer type for each kind of target: user map pin, POI map pin, quest classifications (Quest, Campaign, Important, Legendary, Questline, Meta, Calling, Bonus, Threat, World Quest), daily, weekly and scheduled quests, and an "unknown" fallback. The pointer for TomTom's crazy arrow has the same settings, on the TomTom page under `Minimap tracking` (see Addon integrations).

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
- `Filter`: which icon types are shown, in sub-tabs. Each type has `Any distance` next to it (shown regardless of the scanning radius: everything the game lists for the current map, for flight points this can be the whole continent). `Places`: one row per type. `Quests`: quests from your quest log that have a place on the current map (objective area, or the turn-in when complete), with `Progress` (all, in progress or ready to turn in), optionally only those of the zone you are in, with the supertracker's icons or the game's quest marks. `Flight points` hides the other faction's ones and can show only the closest one. `World quests` can be filtered to none, all, tracked ones or those tracked by World Quest Tracker.
- `Texts`: name, distance and time to arrival, shown for all icons or only for the one you're facing (`Texts visibility angle`). With an angle set here or in the other icon sections (gathering nodes, Questie, TomTom, HandyNotes), only one icon of them all shows its texts: the one closest to the direction you are facing.
- `Supertracking`: a keybind that sets the icon you are facing as the game's tracked target (press again to clear it), `Hide icon at the tracked target` (on by default: while an icon is tracked, only its supertracker pointer is shown), and the texture used when a user waypoint has to be created. A waypoint keeps the icon's name, and with `Icon texture` its icon. The other icon sections can use the same keybind (`Use supertracker keybinding` in their sections); for TomTom waypoints it makes the waypoint you face the crazy arrow's target.

*Filter tab, `Places` and `Quests`:*</br>
![MinimapIconsPlaces](https://i.imgur.com/AyYAzuF.png)
![MinimapIconsQuests](https://i.imgur.com/avo0S4y.png)

#### Party/Raid

In the `Party/Raid` section, you can configure the visibility of party and raid members, including icon textures, name display (class colors, fonts, backgrounds), and formatting.</br>
(Default: Party only)

Members on a different map (another continent, behind a portal, underground, ...) can get their own marker style; their direction may not be accurate.

#### Addon integrations

Each addon has its own section under `Minimap tracking`, shown when the addon is loaded. They all work the same way: off by default; the Minimap icons settings (scanning radius, update throttle, position, scale, opacity, texts) or, with `Use minimap icons settings` off, their own; a texts visibility angle; and optionally the supertrack keybinding and text to speech for the icon you face.

- **GatherMate2 / GatherLite**: possible gathering node locations within a scanning radius. Node types follow GatherMate2's own display filter. In WoW: Forever, `GatherLite` works the same way when GatherMate2 is not loaded, following GatherLite's minimap tracking toggles. Unlike the others, it has its own settings by default.
- **HandyNotes**: the icons HandyNotes plugins place on the minimap: MapNotes, the treasures and rares of the expansion plugins, your own notes, and so on.
  - `Plugins`: which plugins appear on the compass (all by default). Plugins turned off in HandyNotes are not shown either.
  - `Icons from nearby zones` (off by default): also the icons of zones and cities around you within the scanning radius. Off, only the icons of the zone you are in are shown, as on HandyNotes' minimap.
  - Names come from the plugins' own data where they provide it (MapNotes, the expansion plugins of Zarillion and Kemayo, your own notes); other icons are titled with the plugin's name.
  - The supertrack keybinding sets a map waypoint on the icon you face.
- **Questie** (experimental): the icons Questie places on the minimap: available quests, quest turn-ins, quest objectives and the townsfolk chosen in Questie's minimap menu. Which icons appear is decided by Questie's own settings. The name can show the kind of icon in parentheses, e.g. "Innkeeper Farley (Innkeeper)". The supertrack keybinding tracks the quest itself for turn-ins and objectives, else it sets a waypoint with the icon's name and look. Questie has no public interface for its icons, so a Questie update may turn this off until CompassHUD is updated.
- **TomTom**: your TomTom waypoints, and the crazy arrow's target as a pointer.
  - Waypoints are shown with the icon of TomTom's minimap theme. `Waypoints from other zones` (on by default) also shows those set on other maps of the continent you are on, e.g. in the zone around a city. The crazy arrow's waypoint is not shown twice.
  - The supertrack keybinding makes the waypoint you face the crazy arrow's target. Pressed while facing the crazy arrow's waypoint, it clears the arrow (the waypoint stays in TomTom).
  - `Crazy arrow` tab: the arrow's pointer, with the same settings as the supertracker's pointer types (textures, texts, position). `Hide duplicate TomTom pointer` (on by default) shows only the game's pointer when the arrow's waypoint is at the same place as what the game is tracking. `Use text to speech` reads out the arrow's waypoint. `Use TomTom's arrow` (off by default) uses the arrow of TomTom's minimap theme instead of the pointer textures; it points at the compass, and sideways toward the waypoint when the pointer stays at the compass edge. The pointer follows TomTom's arrow: it goes away when the arrow is cleared, and hides while TomTom hides it (e.g. when the waypoint is on another continent).
- **World Quest Tracker**: its tracked quests can be used as the world quest filter for minimap icons.

*Questie icons on the compass, and their settings:*</br>
![QuestieInAction](https://i.imgur.com/hJeXf5u.png)
![QuestieSettings](https://i.imgur.com/qHnkZhv.png)

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
