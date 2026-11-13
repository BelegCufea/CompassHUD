# CompassHUD API for addon authors

CompassHUD can show markers from other addons on the compass: your addon says where its markers
are, and CompassHUD does the rest. It draws them along the strip, with their name, distance and
time to arrive, fades them by distance, and hides them beyond the scanning radius. They also work
with the supertrack keybinding and text to speech, and get a settings page of their own under
**Minimap tracking**.

CompassHUD's own TomTom, Questie, HandyNotes and gathering markers are built with exactly this
interface (see [Markers/](../Markers)), so it is the same one the addon itself relies on.

- [Quick start](#quick-start)
- [Version promise](#version-promise)
- [CompassHUD.RegisterMarkerSource](#compasshudregistermarkersourcedef)
- [The scan](#the-scan)
- [Markers](#markers)
- [The handle](#the-handle)
- [Your own settings](#your-own-settings)
- [Shared settings](#shared-settings)
- [Errors](#errors)
- [Other entries](#other-entries)

## Quick start

A complete addon: [docs/example/CompassHUDExample](example/CompassHUDExample). Copy its folder into
`Interface\AddOns`, restart the game, and turn it on in CompassHUD's options under
`Minimap tracking → Example`.

```toc
## Interface: 120105
## Title: My Markers
## OptionalDeps: CompassHUD
```

```lua
local compass = CompassHUD
if not (type(compass) == "table" and compass.API_VERSION == 1) then return end

local source
source = compass.RegisterMarkerSource({
    id = "MyMarkers",              -- unique; use your addon's name
    name = "My Markers",           -- options page and Speech tab
    description = "Shows my markers.",
    scan = function(scan)
        for key, point in pairs(MyAddon.points) do
            -- keep a marker already added; new ones are added
            if not scan:Get(key) then
                scan:Add(key, {
                    mapID = point.mapID, mapX = point.x, mapY = point.y, -- 0-1 on that map
                    texture = "Interface\\Icons\\INV_Misc_QuestionMark",
                    name = point.title,
                })
            end
        end
        -- markers not reported by this scan are removed
    end,
})
```

`## OptionalDeps: CompassHUD` (or `## Dependencies:`) makes the game load CompassHUD first, so
`CompassHUD` exists when your file runs. Register once, when your addon loads.

## Version promise

`CompassHUD.API_VERSION` is `1`. Everything documented on this page stays as it is while the
version is 1: later CompassHUD versions only **add** things (new functions, new optional fields,
new option types). The number goes up only if something documented has to change in a way that
is not an addition. So check `CompassHUD.API_VERSION == 1`, and check for a newer addition by its
presence (`if scan.SomethingNew then ...`).

Anything not on this page (other fields of `CompassHUD`, the marker tables' other fields, the
frames) is CompassHUD's own and may change in any version.

## CompassHUD.RegisterMarkerSource(def)

Registers a marker source and returns its [handle](#the-handle). Errors in `def` (missing `id` or
`scan`, an `id` already in use, ...) raise a Lua error right away, so they show while you develop.

| Field | Type | |
|---|---|---|
| `id` | string, required | Letters and digits, starting with a letter. Names your settings (`<id>Enabled`, `<id>Radius`, ...), so it must stay the same between versions of your addon. Use your addon's name. |
| `scan` | function(scan), required | Reports the markers around the player, see [The scan](#the-scan). |
| `name` | string | Name of the options page and of the Speech toggle (default: `id`). |
| `description` | string | Text at the top of the options page. |
| `enabledDesc` | string | Tooltip of the page's `Enabled` checkbox. |
| `what` | string | What one marker is, in the options' texts, e.g. `"waypoint"` ("Scanning radius: only waypoints within this distance ..."). Default `"marker"`. |
| `titleHeader` | string | Heading of the name text's settings on the Texts tab. Default `"Name"`. |
| `isAvailable` | function() → boolean | Whether the data your markers come from is there right now. While false, no scans, no markers and no options page. |
| `title` | function(marker) → string | The name text shown and read out. Default: the marker's `name`. Called when a marker is added and when settings change. |
| `supertrack` | function(marker) → boolean | The [supertrack keybinding](#the-supertrack-keybinding) on one of your markers: return true when you handled it yourself. |
| `bypassesRadius` | function(marker) → boolean | True: the marker is drawn (and can be the faced one) beyond the scanning radius. |
| `defaults` | table | Your defaults for [shared settings](#shared-settings), e.g. `{ Radius = 0 }`. Unknown names are ignored. |
| `options` | list | [Your own settings](#your-own-settings) on the options page. |
| `speech` | table | `{ name, desc, default }`: the source's toggle on the Speech tab (`What to read out`). Default name: `name`; off unless `default = true`. |

A new source is **off** until the player turns it on (`Enabled` on its options page). Scans
don't run inside instances (dungeons, raids, ...), where the compass is hidden.

## The scan

`scan(scan)` runs every `Interval` HUD updates while the source is on and available (first on the
next update after registering, and again after [`Rescan`](#the-handle)). It reports the markers
that should exist now; any marker it does not report (with `Get` or `Add`) is removed afterwards.

The `scan` object has where the player is:

| Field | |
|---|---|
| `scan.uiMapID` | The player's map (HereBeDragons' `GetPlayerZone()`). |
| `scan.mapX`, `scan.mapY` | The player's position on that map (0-1). |
| `scan.x`, `scan.y` | The player's world position (yards, HereBeDragons world coordinates). |
| `scan.instance` | The player's world instance (continent) ID. |
| `scan.radius` | The scanning radius in yards. When the player set it to 0 (whole zone), this is the fading distance instead. Markers beyond it are not drawn, so you may report only what is within it, or everything. |

and the calls that report markers (`key`: any value except nil that names the marker, e.g. an ID,
a string or a table of yours):

| Call | |
|---|---|
| `scan:Get(key)` | The marker added under `key` by an earlier scan, which this scan keeps; nil if there is none. A marker added while the player was on another map is dropped (nil): add it again. |
| `scan:Add(key, fields)` | Adds the marker `fields` (see [Markers](#markers)) under `key`, replacing one with the same key. Returns the marker, or nil when its place is not on the player's continent. |
| `scan:Move(key, x, y)` / `scan:Move(key, mapX, mapY, mapID)` | Moves the marker: world coordinates, or map coordinates (0-1) on `mapID`. Returns false if the new place is not on the player's continent (the marker stays where it was). |
| `scan:Remove(key)` | Removes the marker right away (not needed in a scan: unreported ones are removed anyway). |

The usual pattern: `if not scan:Get(key) then scan:Add(key, {...}) end`. Adding again is how a
marker changes its icon or name; `Get` alone keeps it as it is.

## Markers

The table given to `scan:Add` becomes the marker. Its fields:

| Field | |
|---|---|
| `mapID`, `mapX`, `mapY` | Its place: map coordinates (0-1) on `mapID`. The supertrack keybinding's waypoint is set on this map. |
| `x`, `y` | Or its place in world coordinates (yards, HereBeDragons) on the player's continent, when there is no `mapID`. After `Add`, `x` and `y` always hold the world position. |
| `atlas` | Icon: an atlas name, |
| `texture` | or a texture path or file ID (a question mark when neither is given). |
| `texCoords` | `{ left, right, top, bottom }`: a part of the texture (e.g. an icon sheet). |
| `color` | `{ r, g, b, a }` (0-1): the icon's tint. |
| `scale` | Size of this icon relative to the source's `Scale` setting (default 1). |
| `circle` | true: a round icon with a border. |
| `name` | The name text (unless `title` says otherwise) and what speech reads out. |
| `hidden` | true: not drawn, but it can still be the faced marker for the supertrack keybinding (e.g. CompassHUD's TomTom source hides the crazy arrow's waypoint, which is shown as a pointer, and its keybinding then clears the arrow). Unlike the other fields, it can be changed at any time on the marker `Get` returns. |
| `questID`, `areaPoiID`, `vignetteGUID` | What the supertrack keybinding tracks, see below. |
| `data` | Anything of yours (the marker table is passed to `title`, `supertrack` and `bypassesRadius`). Keep your own values here: other field names may get a meaning in a later version. |

### The supertrack keybinding

The keybinding `Toggle Supertracking for Minimap icon` (the `Use supertracker keybinding` setting,
on by default) acts on the marker closest to the facing direction among all sources:

1. your `supertrack(marker)`, if it returns true (e.g. CompassHUD's TomTom source sets the crazy
   arrow);
2. else the game's tracking: the quest (`questID`), the area POI (`areaPoiID`) or the vignette
   (`vignetteGUID`), or a map waypoint at the marker's place, with its name and icon. Pressed
   again on the tracked one, it stops tracking.

## The handle

`RegisterMarkerSource` returns the handle:

| Call | |
|---|---|
| `handle:GetSetting(name)` | A setting of the source: a [shared one](#shared-settings) (`"Radius"`, `"Enabled"`, ...) or [one of your own](#your-own-settings). |
| `handle:GetSetting(name, item)` | For a `multiselect` option: whether `item` is chosen. |
| `handle:Rescan()` | Scan again on the next update, e.g. when your data changed. |

## Your own settings

`options` is a list of settings shown on the source's page (General tab, after the shared
checkboxes, in list order). Each is stored in CompassHUD's profile as `<id><key>`.

| Field | |
|---|---|
| `key` | Required. Its name (letters and digits), not one of the [shared settings](#shared-settings). |
| `type` | Required: `"toggle"` (checkbox), `"select"` (drop-down) or `"multiselect"` (a checkbox per item). |
| `name`, `desc` | Label and tooltip. |
| `default` | The default value: true/false for a toggle, a key of `values` for a select. For a multiselect, whether an item is chosen until the player changes it (only the player's changes are stored, so new items start at the default). |
| `values` | select and multiselect: `{ [key] = label }`, or a function returning it (called whenever the page is drawn). |
| `onChange` | function(handle): called after the player changed it. |

A change also asks for a new scan and re-applies the settings (titles are asked again), so most
sources need no `onChange`. Read the value with `handle:GetSetting(key)`.

```lua
options = {
    { key = "ShowDone", type = "toggle", name = "Done ones too", default = false },
    { key = "Kinds", type = "multiselect", name = "Kinds", default = true,
      values = { chest = "Chests", rare = "Rares" } },
},
...
if source:GetSetting("Kinds", "rare") then ... end
```

## Shared settings

Every source has these on its options page, stored as `<id><name>`. A source may set its own
default for any of them in `defaults`, and read them with `GetSetting`.

| Name | Default | |
|---|---|---|
| `Enabled` | false | The source is on. |
| `UseMinimapSettings` | true | Use the `Minimap icons` settings (radius, throttle, position, scale, opacity, texts) instead of the source's own. |
| `Supertrack` | true | The supertrack keybinding acts on its markers. |
| `HideAtTarget` | true | A marker at the place of the game's tracked target is not drawn (the target's pointer is). |
| `Radius` | 1000 | Scanning radius in yards; 0 = the whole zone. |
| `Interval` | 30 | Scan every this many HUD updates. |
| `Offset` | 20 | Vertical position of the markers. |
| `Scale` | 1 | Marker size. |
| `OpacityMax`, `OpacityMin` | 0.7, 0.2 | Opacity near and at the scanning radius. |
| `OpacityMinRadius` | 100 | Markers closer than this keep `OpacityMax`. |
| `OpacityMaxRadius` | 1000 | The fading distance when `Radius` is 0. |
| `TextsDegrees` | 2.5 | Texts only on the marker faced within this angle; 0 = on every marker. |
| `OpacitySelected` | 1 | Opacity of the marker whose texts are shown. |
| `ShowDistance`, `ShowTTA`, `ShowTitle` | true | Which texts are shown. |
| `DistanceOffset`, `TtaOffset`, `TitleOffset` | 0 | Vertical position of each text. |

The texts' fonts are settings too, but have no defaults of your own.

## Errors

Every call into your functions (`scan`, `title`, `supertrack`, `bypassesRadius`, `isAvailable`,
`values`, `onChange`) is protected. An error goes to the game's error handler (BugSack shows it)
and does not stop the compass. When a scan fails, the markers it did not get to report stay until
the next scan. After **5 errors** the source is turned off until the next `/reload`, with one line
in the chat.

## Other entries

- `CompassHUD.SupertrackMinimapIcon()`: does what the supertrack keybinding does.
- `CompassHUDFrame`: the compass frame, e.g. to anchor to. Its children are not part of this
  interface.
- `CompassHUD.Debug`: CompassHUD's addon object, for inspecting it in DevTool. Not promised:
  anything in it may change.
