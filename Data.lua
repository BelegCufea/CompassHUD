-- Shared state, constants, pointer texture lists and texture presets.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

copyPointersDialogName = ADDON_NAME .. "_copyPointers"
StaticPopupDialogs[copyPointersDialogName] = {
    text = "Do you want to proceed?",
    button1 = "Yes",
    button2 = "No",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

Options = nil
HUD = nil
timer = 0
groupThrottle = 0
gatherMateThrottle = 0
poiTrackThrottle = 0
player = {x = 0, y = 0, angle = 0}
tomTomActive = nil
poiTypeEnum = {
    DELVE = "Delve",
    RACE = "Race",
    EVENT = "Event",
    HUB = "Hub",
    TAXI = "Taxi",
    PORTAL = "Portal",
    INSTANCE = "Instance",
    LINK = "Link",
    VIGNETTE = "Vignette",
    OTHER = "Other",
}
poiCache = {}
poiCacheContinents = {}
questPointsTable = {}
groupPointsTable = {}
gatherMatePointTable = {}
poiTrackPointTable = {}
poiTrackHeading = nil -- minimap icon closest to the facing direction, re-picked on every pass
poiTrackCurrentMap = nil
STtexture = { last = {} } -- SuperTracker retexture state; last = what was applied to the icon
editModeActive = false -- the game's Edit Mode is open (EditMode.lua)
directions = {
    [0] = {letter = "N" , main = true },
    [45] = {letter = "NE" , main = false },
    [90] = {letter = "E" , main = true },
    [135] = {letter = "SE" , main = false},
    [180] = {letter = "S" , main = true },
    [225] = {letter = "SW" , main = false },
    [270] = {letter = "W" , main = true },
    [315] = {letter = "NW" , main = false },
    [360] = {letter = "N" , main = true },
}

ADJ_FACTOR = 1 / math.rad(720)
defaultTextureWidth, defaultTextureHeight = 2048, 16
textureWidth, textureHeight = defaultTextureWidth, defaultTextureHeight
-- base size of the markers (Options.IconScale), separate from the ribbon height (textureHeight)
iconSize = defaultTextureHeight
texturePosition = function() return textureWidth * ADJ_FACTOR end
adjCoord, currentFacing = nil, nil

questUnknown = -999
tomTom = -200
mapPin = -100
selectedPin = -110

defaultTexturePreset = "Classic"
texturePreset = defaultTexturePreset
questPointerIdent = "pointer_"

-- some predefined textures fo poiners (not used in texturePresets)
pointerTextures = {
    ["Arrow Red"] = {
        atlasID = "MiniMap-DeadArrow",
        textureRotate = true,
    },
    ["Arrow Silver"] = {
        atlasID = "MinimapArrow",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Repeatable Blue"] = {
        atlasID = "UI-QuestPoiRecurring-QuestNumber",
    },
    ["Repeatable Gold"] = {
        atlasID = "UI-QuestPoiRecurring-QuestNumber-SuperTracked",
    },
    ["Arrow Blue small"] = {
        atlasID = "Rotating-MinimapArrow",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Kite Gold"] = {
        atlasID = "Navigation-Tracked-Arrow",
        textureScale = 0.9,
        textureRotate = true,
    },
    ["Up Green"] = {
        atlasID = "Garr_LevelUpgradeArrow",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Double Wedge Gold"] = {
        atlasID = "NPE_ArrowUp",
        textureRotate = true,
    },
    ["Wedge Gold"] = {
        atlasID = "NPE_ArrowUpGlow",
        textureRotate = true,
    },
    ["Triangle White"] = {
        atlasID = "Soulbinds_Collection_Scrollbar_Arrow_Up",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Up Red"] = {
        atlasID = "Vehicle-SilvershardMines-Arrow",
        textureRotate = true,
    },
    ["Triangle Yellow"] = {
        atlasID = "glues-characterSelect-icon-arrowUp",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Pointer Green"] = {
        atlasID = "loottoast-arrow-green",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Pointer Blue"] = {
        atlasID = "loottoast-arrow-blue",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Pointer Purple"] = {
        atlasID = "loottoast-arrow-purple",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Pointer Orange"] = {
        atlasID = "loottoast-arrow-orange",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Up Gold"] = {
        atlasID = "poi-door-arrow-up",
        textureScale = 0.8,
        textureRotate = true,
    },
    ["Questionmark Blue"] = {
        atlasID = "QuestRepeatableTurnin",
        textureScale = 0.8,
    },
    ["Event"] = {
        atlasID = "VignetteEvent",
        textureScale = 0.8,
    },
    ["Party"] = {
        atlasID = "PartyMember",
    },
    ["Circle Gold"] = {
        atlasID = "honorsystem-bar-rewardborder-circle",
        textureScale = 0.8,
    },
    ["Circle Silver"] = {
        atlasID = "jailerstower-wayfinder-rewardcircle",
        textureScale = 0.8,
    },
    ["Circle Green"] = {
        atlasID = "talents-node-choiceflyout-circle-greenglow",
        textureScale = 0.8,
    },
    ["Circle White"] = {
        atlasID = "Relic-Rankselected-circle",
        textureScale = 0.8,
    },
    ["Circle Red"] = {
        atlasID = "talents-node-circle-red",
        textureScale = 0.6,
    },
}

-- "Quest" Classifications
questPointers = {
	[tomTom] =  "TomTom",
	[questUnknown] = "Unknown pointer",
    [mapPin] = "User map pin",
    [selectedPin] = "POI map pin",
	[Enum.QuestClassification.Important] = "Important",
	[Enum.QuestClassification.Legendary] = "Legendary",
	[Enum.QuestClassification.Campaign] = "Campaign",
	[Enum.QuestClassification.Calling] = "Calling",
	[Enum.QuestClassification.Meta] = "Meta",
	[Enum.QuestClassification.Normal] = "Quest",
	[Enum.QuestClassification.Questline] = "Questline",
	[Enum.QuestClassification.BonusObjective] = "Bonus",
	[Enum.QuestClassification.Threat] = "Threat",
	[Enum.QuestClassification.WorldQuest] = "WorldQuest",
	[Enum.QuestFrequency.Daily + 100] = "Daily",
	[Enum.QuestFrequency.Weekly + 100] = "Weekly",
    [Enum.QuestFrequency.ResetByScheduler + 100] = "Scheduled",
}

-- Texture Presets
-- At least one of 'atlasIDavailable' or 'reference' must be defined for each preset.
-- 'reference' will inherit the definition from the referenced member within the same preset, but it only supports one level of reference depth.
-- You can use 'reference' in combination with other parameters. When used together, the defined parameters will override the inherited values from the reference. Undefined parameters will be inherited.
-- 'atlasName...' will be displayed in the Texture drop-down box. If not present, some combination of 'questPointers' name and "_available"/"_turn-in" will be used.
-- In 'defaultTexturePreset', all "Quest" classifications from 'questPointers' must be defined.
-- In all other presets, if a member is omitted, the corresponding values from 'defaultTexturePreset' will be used.
-- Currently, only the following parameters can be defined: 'atlasIDavailable', 'atlasIDturnin', 'textureScaleAvailable', 'textureScaleTurnin', 'textureRotateAvailable', and 'textureRotateTurnin'.
-- If 'atlasIDturnin' and other '..Turnin' parameters are not defined, the corresponding 'available' parameter will be used instead.
texturePresets = {
    [defaultTexturePreset] = {
        [tomTom] = {
            atlasIDavailable = "Rotating-MinimapGroupArrow",
            atlasNameAvailable = "Arrow Green small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [questUnknown] = {
            atlasIDavailable = "128-Store-Main",
            atlasNameAvailable = "Other",
            textureScaleAvailable = 0.8,
        },
        [mapPin] = {
            atlasIDavailable = "Waypoint-MapPin-Minimap-Tracked",
            atlasNameAvailable = "User pin",
        },
        [selectedPin] = {
            atlasIDavailable = "Waypoint-MapPin-Minimap-Tracked",
            atlasNameAvailable = "User pin",
            textureScaleAvailable = 1.20,
        },
        [Enum.QuestClassification.Important] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.Legendary] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.Campaign] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.Calling] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.Meta] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.Normal] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasNameAvailable = "Arrow Gold",
            textureRotateAvailable = true,
        },
        [Enum.QuestClassification.Questline] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.BonusObjective] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.Threat] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.WorldQuest] = {
            atlasIDavailable = "Rotating-MinimapGuideArrow",
            atlasNameAvailable = "Arrow Gold small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestFrequency.Daily + 100] = {
            atlasIDavailable = "MiniMap-VignetteArrow",
            atlasNameAvailable = "Arrow Blue",
            textureRotateAvailable = true,
        },
        [Enum.QuestFrequency.Weekly + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
        [Enum.QuestFrequency.ResetByScheduler + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
    },
    ["Modern"] = {
        [tomTom] = {
            atlasIDavailable = "Rotating-MinimapGroupArrow",
            atlasIDturnin = "Rotating-MinimapArrow",
            atlasNameAvailable = "Arrow Green small",
            atlasNameTurnin = "Arrow Blue small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestClassification.Important] = {
            atlasIDavailable = "quest-important-available",
            atlasIDturnin = "quest-important-turnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Legendary] = {
            atlasIDavailable = "quest-legendary-available",
            atlasIDturnin = "quest-legendary-turnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Campaign] = {
            atlasIDavailable = "Quest-Campaign-Available",
            atlasIDturnin = "Quest-Campaign-TurnIn",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Calling] = {
            atlasIDavailable = "callings-available",
            atlasIDturnin = "callings-turnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Meta] = {
            atlasIDavailable = "quest-wrapper-available",
            atlasIDturnin = "quest-wrapper-turnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Normal] = {
            atlasIDavailable = "QuestNormal",
            atlasIDturnin = "QuestTurnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Questline] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.BonusObjective] = {
            atlasIDavailable = "QuestBonusObjective",
            atlasIDturnin = "QuestBonusObjective",
            textureScaleAvailable = 1.35,
            textureScaleTurnin = 1.35,
        },
        [Enum.QuestClassification.Threat] = {
            atlasIDavailable = "vignettekillboss",
            atlasIDturnin = "vignettekillboss",
        },
        [Enum.QuestClassification.WorldQuest] = {
            atlasIDavailable = "completiondialog-warwithincampaign-worldquests-icon",
            atlasIDturnin = "completiondialog-warwithincampaign-worldquests-icon",
            textureScaleAvailable = 1.35,
            textureScaleTurnin = 1.35,
        },
        [Enum.QuestFrequency.Daily + 100] = {
            atlasIDavailable = "quest-recurring-available",
            atlasIDturnin = "quest-recurring-turnin",
            textureScaleAvailable = 0.8,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestFrequency.Weekly + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
        [Enum.QuestFrequency.ResetByScheduler + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
    },
    [defaultTexturePreset.." - turn-in"] = {
        [tomTom] = {
            atlasIDavailable = "Rotating-MinimapGroupArrow",
            atlasIDturnin = "Rotating-MinimapArrow",
            atlasNameAvailable = "Arrow Green small",
            atlasNameTurnin = "Arrow Blue small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestClassification.Important] = {
            reference = Enum.QuestClassification.Normal
        },
        [Enum.QuestClassification.Legendary] = {
            reference = Enum.QuestClassification.Normal
        },
        [Enum.QuestClassification.Campaign] = {
            reference = Enum.QuestClassification.Normal
        },
        [Enum.QuestClassification.Calling] = {
            reference = Enum.QuestClassification.Normal
        },
        [Enum.QuestClassification.Meta] = {
            reference = Enum.QuestFrequency.Daily + 100
        },
        [Enum.QuestClassification.Normal] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "QuestTurnin",
            textureRotateAvailable = true,
            textureScaleTurnin = 0.8,
            textureRotateTurnin = false,
        },
        [Enum.QuestClassification.Questline] = {
            reference = Enum.QuestClassification.Normal,
        },
        [Enum.QuestClassification.BonusObjective] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.Threat] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.WorldQuest] = {
            atlasIDavailable = "Rotating-MinimapGuideArrow",
            atlasNameAvailable = "Arrow Gold small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestFrequency.Daily + 100] = {
            atlasIDavailable = "MiniMap-VignetteArrow",
            atlasIDturnin = "QuestRepeatableTurnin",
            textureRotateAvailable = true,
            textureScaleTurnin = 0.8,
            textureRotateTurnin = false,
        },
        [Enum.QuestFrequency.Weekly + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
        [Enum.QuestFrequency.ResetByScheduler + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
    },
    [defaultTexturePreset.."/Modern"] = {
        [tomTom] = {
            atlasIDavailable = "Rotating-MinimapGroupArrow",
            atlasIDturnin = "Rotating-MinimapArrow",
            atlasNameAvailable = "Arrow Green small",
            atlasNameTurnin = "Arrow Blue small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestClassification.Important] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "quest-important-turnin",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Legendary] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "quest-legendary-turnin",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Campaign] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "Quest-Campaign-TurnIn",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Calling] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "callings-turnin",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Meta] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "quest-wrapper-turnin",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Normal] = {
            atlasIDavailable = "MiniMap-QuestArrow",
            atlasIDturnin = "QuestTurnin",
            atlasNameAvailable = "Arrow Gold",
            textureRotateAvailable = true,
            textureScaleAvailable = 1,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestClassification.Questline] = {
            reference = Enum.QuestClassification.Normal
        },
        [Enum.QuestClassification.BonusObjective] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.Threat] = {
            reference = Enum.QuestClassification.WorldQuest
        },
        [Enum.QuestClassification.WorldQuest] = {
            atlasIDavailable = "Rotating-MinimapGuideArrow",
            atlasNameAvailable = "Arrow Gold small",
            textureScaleAvailable = 1.35,
            textureRotateAvailable = true,
        },
        [Enum.QuestFrequency.Daily + 100] = {
            atlasIDavailable = "MiniMap-VignetteArrow",
            atlasIDturnin = "quest-recurring-turnin",
            textureRotateAvailable = true,
            textureRotateTurnin = false,
            textureScaleTurnin = 0.8,
        },
        [Enum.QuestFrequency.Weekly + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
        [Enum.QuestFrequency.ResetByScheduler + 100] = {
            reference = Enum.QuestFrequency.Daily + 100,
        },
    },
}
