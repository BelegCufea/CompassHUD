-- Default settings (AceDB profile defaults) and media registration.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local Debug = Addon.DEBUG
local LSM               = LibStub("LibSharedMedia-3.0")

function addToLSM()
    LSM:Register("background", "CompassHUD gradient", [[Interface\Addons\]].. ADDON_NAME .. [[\Media\CompassHUD-gradient]])
end

Addon.Defaults = {
    profile = {
        Enabled         = true,
        Debug           = false,
        Minimap         = { hide = true, minimapPos = 220, radius = 80, },
        Compartment     = { hide = false},
        PositionX       = -1,
        PositionY       = -1,
		Degrees         = 180,
	    Interval        = 60,
		Level           = 500,
		Lock            = false,
        PinVisible      = true,
		Scale           = 1,
        HorizontalScale = 1,
        VerticalScale   = 1,
        IconScale       = 1,
        SizeMode        = "SCALE", -- SCALE: HorizontalScale/VerticalScale; PIXELS: Width/Height
        Width           = 0, -- HUD size in pixels (SizeMode PIXELS), set from the current size when switched on
        Height          = 0,
        SizeVersion     = 0, -- 1: IconScale migrated from VerticalScale (see migrateProfile)
		Strata          = 'HIGH',
        Transparency    = 1,
        Border          = 'Blizzard Dialog Gold',
        BorderThickness = 2.5,
        BorderColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        Background      = 'Blizzard Tooltip',
        BackgroundColor = {r = 1, g = 1, b = 1, a = 1},
        PinTexture      = [[Interface\MainMenuBar\UI-ExhaustionTickNormal]],
        PointerStay     = true,
        StayArrow       = true,
        StayAtlasID     = "NPE_ArrowUp",
        Line            = '',
        LineThickness   = 1,
        LinePosition    = 0,
        LineColor       = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        Visibility      = "[petbattle] hide; show",
        HideFar         = false,
        HideTomTomAtTarget = true,
        HidePOIAtTarget = true,
        UseCurrentMap   = true,
        UseMeters       = false,
        RoundDistance   = false,
        HeadingEnabled         = false,
        HeadingDecimals        = 0,
        HeadingTrueNorth       = true,
        HeadingScale           = 1,
        HeadingWidth           = 1,
        HeadingPosition        = 0,
        HeadingTransparency    = 1,
        HeadingBorder          = 'Blizzard Dialog Gold',
        HeadingBorderThickness = 2.5,
        HeadingBorderColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        HeadingBackground      = 'Blizzard Tooltip',
        HeadingBackgroundColor = {r = 1, g = 1, b = 1, a = 1},
        HeadingFont            = 'Arial Narrow',
        HeadingFontSize        = 14,
        HeadingFontFlags       = 'OUTLINE',
        HeadingFontColor       = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        HeadingFontPositionV   = 0,
        HeadingFontPositionH   = 0,
        HeadingStrataLevel     = 100,
        PointerFontCustom      = false,
        PointerFont            = "Friz Quadrata TT",
        PointerFontSize        = 12,
        PointerFontFlags       = "",
        PointerFontColor       = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        PointerTitleMaxWidth   = 0,
        SpeechEnabled          = false,
        SpeechSupertracked     = true, -- the marker sources' Speech<prefix>: see registerMarkerSource
        SpeechTomTomArrow      = true,
        SpeechDistance         = false,
        SpeechOnlyShownNames   = false,
        SpeechDegrees          = 10,
        SpeechDelay            = 0.5,
        SpeechVoice            = -1, -- -1: the voice of the game's text to speech settings
        SpeechRate             = 0,
        SpeechVolume           = 100,
        UseCustomCompass             = true,
        CompassTextureTexture           = [[Interface\Addons\]] .. ADDON_NAME .. [[\Media\CompassHUD]],
        CompassCustomMainVisible        = true,
        CompassCustomSecondaryVisible   = true,
        CompassCustomDegreesVisible     = true,
        CompassCustomDegreesSpan        = 15,
        CompassCustomMainFont           = 'Arial Narrow',
        CompassCustomSecondaryFont      = 'Arial Narrow',
        CompassCustomDegreesFont        = 'Arial Narrow',
        CompassCustomMainSize           = 14,
        CompassCustomSecondarySize      = 12,
        CompassCustomDegreesSize        = 9,
        CompassCustomMainPosition       = -3,
        CompassCustomSecondaryPosition  = -3,
        CompassCustomDegreesPosition    = -5,
        CompassCustomMainColor          = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        CompassCustomSecondaryColor     = {r = 0, g = 1, b = 1, a = 1},
        CompassCustomDegreesColor       = {r = 1, g = 1, b = 1, a = 1},
        CompassCustomMainFlags          = 'OUTLINE',
        CompassCustomSecondaryFlags     = 'OUTLINE',
        CompassCustomDegreesFlags       = '',
        CompassCustomTicksPosition      = 'TOP',
        CompassCustomTicksForce         = false,
        GroupShowParty    = true,
        GroupShowRaid     = false,
        GroupInterval     = 6,
        GroupShowAllZones = true,
        GroupOffset       = 0,
        GroupStay         = true,
        GroupScale        = 1,
        GroupTexture      = 'PartyMember',
        GroupRotate           = 0,
        GroupZoneDesaturate   = true,
        GroupZoneTransparency = 0.7,
        GroupZoneOffset       = 10,
        GroupZoneScale        = 1,
        GroupZoneTexture      = 'PartyMember',
        GroupZoneRotate       = 0,
        GroupPartyNameShow       = true,
        GroupPartyNameOffset     = 0,
        GroupPartyNameCustomFont = false,
        GroupPartyNameFont       = "Friz Quadrata TT",
        GroupPartyNameFontSize   = 12,
        GroupPartyNameFontFlags  = "",
        GroupPartyNameFontColor  = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GroupPartyNameClassColor = true,
        GroupRaidNameShow        = true,
        GroupRaidNameOffset      = 10,
        GroupRaidNameCustomFont  = false,
        GroupRaidNameFont        = "Friz Quadrata TT",
        GroupRaidNameFontSize    = 12,
        GroupRaidNameFontFlags   = "",
        GroupRaidNameFontColor   = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GroupRaidNameClassColor  = true,
        GroupPartyNameBorder          = 'Blizzard Dialog Gold',
        GroupPartyNameBorderThickness = 2.5,
        GroupPartyNameBorderClass     = false,
        GroupPartyNameBorderColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GroupPartyNameBackground      = 'Blizzard Tooltip',
        GroupPartyNameBackgroundClass = false,
        GroupPartyNameBackgroundColor = {r = 1, g = 1, b = 1, a = 1},
        GroupRaidNameBorder           = 'Blizzard Dialog Gold',
        GroupRaidNameBorderThickness  = 2.5,
        GroupRaidNameBorderClass      = false,
        GroupRaidNameBorderColor      = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GroupRaidNameBackground       = 'Blizzard Tooltip',
        GroupRaidNameBackgroundClass  = false,
        GroupRaidNameBackgroundColor  = {r = 1, g = 1, b = 1, a = 1},
        -- The marker sources' settings (<prefix>Radius, ...) are added by registerMarkerSource from
        -- markerSourceDefaults below and each source's own defaults (Markers/*.lua). The minimap
        -- icons' filters and other settings of their own:
        POITrackFilter             = {
            [poiTypeEnum.TAXI] = false,
            [poiTypeEnum.TAXI.."_min"] = false,
            [poiTypeEnum.EVENT] = true,
            [poiTypeEnum.INSTANCE] = true,
            [poiTypeEnum.DELVE] = true,
            [poiTypeEnum.HUB] = true,
            [poiTypeEnum.PORTAL] = false,
            [poiTypeEnum.LINK] = false,
            [poiTypeEnum.OTHER] = true,
            [poiTypeEnum.VIGNETTE] = false,
            [poiTypeEnum.RACE] = false,
            [poiTypeEnum.QUEST] = false,
        },
        -- quests from the quest log (Filter tab): which ones, only this zone, icon style
        POITrackQuestWhich         = "both", -- both, active, complete
        POITrackQuestCurrentZone   = false,
        POITrackQuestIcon          = "pointer", -- pointer (like the supertracker), game
        POITrackWholeZone          = {},
        POITrackWQFilter           = "All",
        POITrackWQWholeZone        = false,
        POITrackSTRetexture        = true,
        POITrackWorldmapTexture    = true,
    },
}

-- The settings every marker source has, named <prefix><name>, with the minimap icons' values. A
-- source changes some of them and adds its own (Enabled, UseMinimapSettings, Supertrack, ...) in
-- its 'defaults' (see registerMarkerSource).
markerSourceDefaults = {
    Enabled          = false,
    Radius           = 1000, -- 0 = whole zone
    Interval         = 30,
    Offset           = 20,
    Scale            = 1,
    OpacityMax       = 0.7,
    OpacityMin       = 0.2,
    OpacitySelected  = 1,
    OpacityMaxRadius = 1000,
    OpacityMinRadius = 100,
    TextsDegrees     = 2.5,
    ShowDistance     = true,
    ShowTTA          = true,
    ShowTitle        = true,
    DistanceOffset   = 0,
    TtaOffset        = 0,
    TitleOffset      = 0,
}

-- Adds a marker source's defaults to the profile defaults: the shared ones, the source's own
-- ('defaults', by name without the prefix) and the fonts of its three texts (distance, time to
-- arrive, name). Each color gets a table of its own (a shared one would link the colors of all
-- texts). Runs while the files load, before AceDB is set up (OnInitialize).
function addMarkerSourceDefaults(prefix, defaults)
    local profile = Addon.Defaults.profile
    for name, value in pairs(markerSourceDefaults) do
        profile[prefix .. name] = value
    end
    for name, value in pairs(defaults or {}) do
        profile[prefix .. name] = value
    end
    for _, text in ipairs({ "Distance", "Tta", "Title" }) do
        profile[prefix .. text .. "CustomFont"] = false
        profile[prefix .. text .. "Font"]       = "Friz Quadrata TT"
        profile[prefix .. text .. "FontSize"]   = 12
        profile[prefix .. text .. "FontColor"]  = {r = 255/255, g = 215/255, b = 0/255, a = 1}
        profile[prefix .. text .. "FontFlags"]  = ""
    end
end
