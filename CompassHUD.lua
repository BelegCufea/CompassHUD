local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

BINDING_HEADER_COMPASSHUD = "CompassHUD"
BINDING_NAME_COMPASSHUD_SUPERTRACK = "Toggle Supertracking for Minimap icon"

local Const = Addon.CONST
local Debug = Addon.DEBUG

local AceDBOptions      = LibStub("AceDBOptions-3.0")
local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")

local copyPointersDialogName = ADDON_NAME .. "_copyPointers"
StaticPopupDialogs[copyPointersDialogName] = {
    text = "Do you want to proceed?",
    button1 = "Yes",
    button2 = "No",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local GetPlayerFacing = GetPlayerFacing
local GetQuestsOnMap = C_QuestLog.GetQuestsOnMap
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestInfo = C_QuestLog.GetInfo
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetMapForQuestPOIs = C_QuestLog.GetMapForQuestPOIs
local GetNextWaypoint = C_QuestLog.GetNextWaypoint
local GetNextWaypointForMap = C_QuestLog.GetNextWaypointForMap
local GetQuestAdditionalHighlights = C_QuestLog.GetQuestAdditionalHighlights
local IsQuestComplete = C_QuestLog.IsComplete
local GetQuestRewardCurrencyInfo = C_QuestLog.GetQuestRewardCurrencyInfo
local GetNumWorldQuestWatches = C_QuestLog.GetNumWorldQuestWatches
local GetQuestIDForWorldQuestWatchIndex = C_QuestLog.GetQuestIDForWorldQuestWatchIndex
local GetQuestZoneID = C_TaskQuest.GetQuestZoneID
local GetQuestLocation = C_TaskQuest.GetQuestLocation
local IsTaskQuestActive = C_TaskQuest.IsActive
local RequestPreloadRewardData = C_TaskQuest.RequestPreloadRewardData
local GetWorldQuestsOnMap = C_TaskQuest.GetQuestsOnMap
local GetQuestClassification = C_QuestInfoSystem.GetQuestClassification
local GetMapInfo = C_Map.GetMapInfo
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetMapLinksForMap = C_Map.GetMapLinksForMap
local CanSetUserWaypointOnMap = C_Map.CanSetUserWaypointOnMap
local SetUserWaypoint = C_Map.SetUserWaypoint
local GetMapChildrenInfo = C_Map.GetMapChildrenInfo
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedMapPin = C_SuperTrack.GetSuperTrackedMapPin
local GetSuperTrackedVignette = C_SuperTrack.GetSuperTrackedVignette
local ClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
local GetHighestPrioritySuperTrackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType
local GetNextWaypointForMapTracker = C_SuperTrack.GetNextWaypointForMap
local IsSuperTrackingAnything = C_SuperTrack.IsSuperTrackingAnything
local SetSuperTrackedQuestID = C_SuperTrack.SetSuperTrackedQuestID
local SetSuperTrackedMapPin = C_SuperTrack.SetSuperTrackedMapPin
local SetSuperTrackedUserWaypoint = C_SuperTrack.SetSuperTrackedUserWaypoint
local ClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
local GetAreaPOIForMap =  C_AreaPoiInfo.GetAreaPOIForMap
local GetDelvesForMap =  C_AreaPoiInfo.GetDelvesForMap
local GetEventsForMap =  C_AreaPoiInfo.GetEventsForMap
local GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo
local GetQuestHubsForMap = C_AreaPoiInfo.GetQuestHubsForMap
local GetDragonridingRacesForMap = C_AreaPoiInfo.GetDragonridingRacesForMap
local GetDungeonEntrancesForMap = C_EncounterJournal.GetDungeonEntrancesForMap
local GetClassColor = C_ClassColor.GetClassColor
local GetAtlasInfo = C_Texture.GetAtlasInfo
local GetTaxiNodesForMap = C_TaxiMap.GetTaxiNodesForMap
local GetVignettes = C_VignetteInfo.GetVignettes
local GetVignettePosition = C_VignetteInfo.GetVignettePosition
local GetVignetteInfo = C_VignetteInfo.GetVignetteInfo

local Options
local HUD
local timer = 0
local groupThrottle = 0
local gatherMateThrottle = 0
local poiTrackThrottle = 0
local player = {x = 0, y = 0, angle = 0}
local tomTomActive
local poiTypeEnum = {
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
local poiCache = {}
local poiCacheContinents = {}
local questPointsTable = {}
local groupPointsTable = {}
local gatherMatePointTable = {}
local poiTrackPointTable = {}
local poiTrackCurrentMap = nil
local HBDmaps = {}
local STtexture = {}
local directions = {
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

local ADJ_FACTOR = 1 / math.rad(720)
local defaultTextureWidth, defaultTextureHeight = 2048, 16
local textureWidth, textureHeight = defaultTextureWidth, defaultTextureHeight
local texturePosition = function() return textureWidth * ADJ_FACTOR end
local adjCoord, currentFacing

local questUnknown = -999
local tomTom = -200
local mapPin = -100
local selectedPin = -110

local defaultTexturePreset = "Classic"
local texturePreset = defaultTexturePreset
local questPointerIdent = "pointer_"

-- some predefined textures fo poiners (not used in texturePresets)
local pointerTextures = {
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
local questPointers = {
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
local texturePresets = {
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

local function addToLSM()
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
        UseCurrentMap   = true,
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
        UseCustomCompass                = true,
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
        GatherMateEnabled            = false,
        GatherMateRadius             = 150,
        GatherMateInterval           = 6,
        GatherMateOffset             = 20,
        GatherMateScale              = 0.8,
        GatherMateShowDistance       = false,
        GatherMateShowTTA            = false,
        GatherMateShowTitle          = false,
        GatherMateDistanceOffset     = 0,
        GatherMateTtaOffset          = 0,
        GatherMateTitleOffset        = 0,
        GatherMateDistanceCustomFont = false,
        GatherMateDistanceFont       = "Friz Quadrata TT",
        GatherMateDistanceFontSize   = 12,
        GatherMateDistanceFontColor  = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GatherMateDistanceFontFlags  = "",
        GatherMateTtaCustomFont      = false,
        GatherMateTtaFont            = "Friz Quadrata TT",
        GatherMateTtaFontSize        = 12,
        GatherMateTtaFontColor       = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GatherMateTtaFontFlags       = "",
        GatherMateTitleCustomFont    = false,
        GatherMateTitleFont          = "Friz Quadrata TT",
        GatherMateTitleFontSize      = 12,
        GatherMateTitleFontColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        GatherMateTitleFontFlags     = "",
        POITrackEnabled            = false,
        POITrackRadius             = 1000,
        POITrackInterval           = 30,
        POITrackOffset             = 20,
        POITrackScale              = 1,
        POITrackOpacityMax         = 0.7,
        POITrackOpacityMin         = 0.2,
        POITrackOpacitySelected    = 1,
        POITrackOpacityMaxRadius   = 1000,
        POITrackOpacityMinRadius   = 100,
        POITrackTextsDegrees       = 2.5,
        POITrackShowDistance       = true,
        POITrackShowTTA            = true,
        POITrackShowTitle          = true,
        POITrackDistanceOffset     = 0,
        POITrackTtaOffset          = 0,
        POITrackTitleOffset        = 0,
        POITrackDistanceCustomFont = false,
        POITrackDistanceFont       = "Friz Quadrata TT",
        POITrackDistanceFontSize   = 12,
        POITrackDistanceFontColor  = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        POITrackDistanceFontFlags  = "",
        POITrackTtaCustomFont      = false,
        POITrackTtaFont            = "Friz Quadrata TT",
        POITrackTtaFontSize        = 12,
        POITrackTtaFontColor       = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        POITrackTtaFontFlags       = "",
        POITrackTitleCustomFont    = false,
        POITrackTitleFont          = "Friz Quadrata TT",
        POITrackTitleFontSize      = 12,
        POITrackTitleFontColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        POITrackTitleFontFlags     = "",
        POITrackFilter             = {
            [poiTypeEnum.TAXI] = false,
            [poiTypeEnum.EVENT] = true,
            [poiTypeEnum.INSTANCE] = true,
            [poiTypeEnum.DELVE] = true,
            [poiTypeEnum.HUB] = true,
            [poiTypeEnum.PORTAL] = false,
            [poiTypeEnum.LINK] = false,
            [poiTypeEnum.OTHER] = true,
            [poiTypeEnum.VIGNETTE] = false,
            [poiTypeEnum.RACE] = false,
        },
        POITrackWQFilter           = "All",
        POITrackWQWholeZone        = false,
        POITrackSTRetexture        = true,
        POITrackWorldmapTexture    = true,
    },
}

local strataLevels = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

local function round(n, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(n * power + 0.5) / power
end

local function getContinentMapID()
    local mapID = GetBestMapForUnit("player")
    if not mapID then return nil end

    while true do
        local mapInfo = GetMapInfo(mapID)
        if not mapInfo or mapInfo.mapType <= Enum.UIMapType.Continent then
            return mapID
        end

        mapID = mapInfo.parentMapID
        if not mapID or mapID == 0 then return nil end
    end
end

local function cacheMapPOIs(mapPOIs, poiType, uiMapID)
    if mapPOIs and #mapPOIs > 0 then
        for _, poiID in ipairs(mapPOIs) do
            if poiID then
                local poi = GetAreaPOIInfo(uiMapID, poiID)
                if not poiCache[poi.areaPoiID] then
                    poiCache[poi.areaPoiID] = {}
                end
                poiCache[poi.areaPoiID][uiMapID] = {
                    poiType = poiType,
                    poi = poi
                }
            end
        end
    end
end

local function cachePOIs()
    local continentID = getContinentMapID()
    if continentID and not poiCacheContinents[continentID] then
        local childrenInfo = GetMapChildrenInfo(continentID, 3, true)
        if not childrenInfo or #childrenInfo == 0 then
            return
        end
        for _, childInfo in ipairs(childrenInfo) do
            local uiMapID = childInfo.mapID
            if uiMapID and uiMapID > 0 then
                cacheMapPOIs(GetAreaPOIForMap(uiMapID), poiTypeEnum.OTHER, uiMapID)
                cacheMapPOIs(GetDelvesForMap(uiMapID), poiTypeEnum.DELVE, uiMapID)
                cacheMapPOIs(GetDragonridingRacesForMap(uiMapID), poiTypeEnum.RACE, uiMapID)
                cacheMapPOIs(GetEventsForMap(uiMapID), poiTypeEnum.EVENT, uiMapID)
                cacheMapPOIs(GetQuestHubsForMap(uiMapID), poiTypeEnum.HUB, uiMapID)
            end
        end
        poiCacheContinents[continentID] = true
        Debug:Table("Cached POIs for continent ID: " .. continentID, poiCache)
    end
end

local function getPointerAtlasIDs()
    local atlasIDs = {}
    for key, value in pairs(pointerTextures) do
        atlasIDs[value.atlasID] = key
    end
    return atlasIDs
end

local function getSortedPointerAtlasIDKeys()
    local sorting = {}
    local sortedKeys = {}
    for key, value in pairs(pointerTextures) do
        table.insert(sortedKeys, {key = value.atlasID, value = key})
    end
    table.sort(sortedKeys, function(a, b) return a.value < b.value end)
    for _, entry in ipairs(sortedKeys) do
        table.insert(sorting, entry.key)
    end
    return sorting
end

local function getPointerTextureByAtlasID(atlasID)
    for _, pointerTexture in pairs(pointerTextures) do
        if pointerTexture.atlasID == atlasID then
            return pointerTexture
        end
    end
    return nil
end

local function getAtlasTexture(atlasID)
    local atlasInfo = GetAtlasInfo(atlasID)
    if not atlasInfo then return nil end
    return atlasInfo.file
end

local function getAtlasCoords(atlasID)
    local atlasInfo = GetAtlasInfo(atlasID)
    if not atlasInfo then return {0,0,0,1,1,0,1,1} end
    return {
        atlasInfo.leftTexCoord,
        atlasInfo.topTexCoord,
        atlasInfo.leftTexCoord,
        atlasInfo.bottomTexCoord,
        atlasInfo.rightTexCoord,
        atlasInfo.topTexCoord,
        atlasInfo.rightTexCoord,
        atlasInfo.bottomTexCoord
    }
end

local function getStrateLevels()
    local values = {}
    for i, v in ipairs(strataLevels) do
        values[v] = i .. " - " .. v
    end
    return values
end

local function getPOITrackFilter()
    local list = {}
    list[poiTypeEnum.TAXI] = "Flightpoints"
    list[poiTypeEnum.EVENT] = "Events"
    list[poiTypeEnum.INSTANCE] = "Instances (Dungeons, Raids)"
    list[poiTypeEnum.HUB] = "Hubs (Cities, Towns, etc.)"
    list[poiTypeEnum.DELVE] = "Delves"
    list[poiTypeEnum.PORTAL] = "Teleports"
    list[poiTypeEnum.LINK] = "Links (Shortcuts, Connections, Paths)"
    list[poiTypeEnum.VIGNETTE] = "Vignettes"
    list[poiTypeEnum.OTHER] = "Miscellaneous"
    list[poiTypeEnum.RACE] = "Dragonriding races"
    return list
end

local function getPOIFrackWQFilter()
    local list = {}
    list["None"] = "None"
    list["All"] = "All"
    list["Tracked"] = "Tracked"
    if WorldQuestTrackerAddon then
        list["WQTracker"] = "World Quest Tracker (WQT)"
    end
    return list
end

Addon.Options = {
    type = "group",
    name = Const.METADATA.NAME,
    args = {
        Tabs = {
            type = "group",
            order = 10,
            name = "Options",
            childGroups = "tab",
            get = function(info)
                return Addon.db.profile[info[#info]]
            end,
            set = function(info, value)
                Addon.db.profile[info[#info]] = value
                Addon:UpdateHUDSettings()
            end,
            args = {
                Settings = {
                    type = "group",
                    order = 10,
                    name = "General",
                    args = {
                        Enabled = {
                            type = "toggle",
                            name = "Enabled",
                            width = "full",
                            order = 00,
                            hidden = true,
                        },
                        Lock = {
                            type = "toggle",
                            name = "Lock compass",
                            width = "full",
                            order = 10,
                        },
                        Minimap = {
                            type = "toggle",
                            name = "Show minimap icon",
                            width = 1.5,
                            order = 20,
                            get = function(info) return not Addon.db.profile[info[#info]].hide end,
                            set = function(info, value)
                                Addon.db.profile[info[#info]].hide = not value
                                if Addon.db.profile[info[#info]].hide then
                                    Addon.icon:Hide(Addon.CONST.METADATA.NAME)
                                else
                                    Addon.icon:Show(Addon.CONST.METADATA.NAME)
                                end
                             end,
                        },
                        Compartment = {
                            type = "toggle",
                            name = "Show in AddOns Compartment",
                            width = 1.5,
                            order = 25,
                            get = function(info) return not Addon.db.profile[info[#info]].hide end,
                            set = function(info, value)
                                Addon.db.profile[info[#info]].hide = not value
                                if Addon.db.profile[info[#info]].hide then
                                    if Addon.icon:IsButtonInCompartment(Addon.CONST.METADATA.NAME) then
                                        Addon.icon:RemoveButtonFromCompartment(Addon.CONST.METADATA.NAME)
                                    end
                                else
                                    if not Addon.icon:IsButtonInCompartment(Addon.CONST.METADATA.NAME) then
                                        Addon.icon:AddButtonToCompartment(Addon.CONST.METADATA.NAME)
                                    end
                                end
                             end,
                        },
                        BlankInterval = { type = "description", order = 29, fontSize = "small",name = "",width = "full", },
                        Interval = {
                            type = "range",
                            order = 30,
                            name = "Update frequency",
                            desc = "Number of updates per second",
                            min = 1,
                            max = 600,
                            softMin = 5,
                            softMax = 120,
                            step = 1,
                            bigStep = 5,
                        },
                        BlankDegrees = { type = "description", order = 39, fontSize = "small",name = "",width = "full", },
                        Degrees = {
                            type = "range",
                            order = 40,
                            name = "Field of View",
                            desc = "Adjusts the horizontal width of the compass display. Higher values show more directions at once. (45-360)",
                            min = 45,
                            max = 360,
                            softMin = 90,
                            softMax = 270,
                            step = 1,
                            bigStep = 5,
                        },
                        BlankScale = { type = "description", order = 69, fontSize = "small",name = "",width = "full", },
                        Scale = {
                            type = "range",
                            name = "Scale",
                            order = 70,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        HorizontalScale = {
                            type = "range",
                            name = "Width",
                            order = 80,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            isPercent = true,
                            set = function(info, value)
                                Options[info[#info]] = value
                                textureWidth = defaultTextureWidth * value
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        VerticalScale = {
                            type = "range",
                            name = "Height",
                            order = 90,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            isPercent = true,
                            set = function(info, value)
                                Options[info[#info]] = value
                                textureHeight = defaultTextureHeight * value
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        Strata = {
                            type = "select",
                            name = "Strata",
                            order = 100,
                            values = function()
                                return getStrateLevels()
                            end,
                            sorting = strataLevels,
                            style = "dropdown",
                        },
                        Level  = {
                            type = "range",
                            name = "Position in Strata",
                            order = 110,
                            min = 0,
                            max = 900,
                            softMin = 0,
                            softMax = 900,
                            step = 1,
                            bigStep = 10,
                        },
                        BlankVisibility = { type = "description", order = 499, fontSize = "small",name = "",width = "full", },
                        Visibility = {
                            type = "input",
                            order = 500,
                            name = "Visibility State",
                            desc = "This works like a macro, you can run different situations to get the compass to show/hide differently.\nExample: '[petbattle][combat] hide;show' to hide in combat and during pet battles.",
                            width = "full",
                        },
                        Center = {
                            type = "execute",
                            order = 510,
                            name = "Center HUD horizontally",
                            width = 3/2,
                            func = function() Addon:ResetPosition(true, false) end
                        },
                        Reset = {
                            type = "execute",
                            order = 520,
                            name = "Reset HUD position",
                            width = 3/2,
                            func = function() Addon:ResetPosition(true, true) end
                        },
                        Debug = {
                            type = "toggle",
                            name = "Debug",
                            width = "full",
                            order = 900,
                        },
                    },
                },
                Display = {
                    type = "group",
                    order = 20,
                    name = "Appearance",
                    args = {
                        PinVisible = {
                            type = "toggle",
                            name = "Central HUD pin visible",
                            desc = "Shows a small reticule on the HUD indicating your current facing direction.",
                            width = "full",
                            order = 10,
                        },
                        Transparency = {
                            type = "range",
                            order = 20,
                            name = "Opacity",
                            min = 0,
                            max = 1,
                            softMin = 0,
                            softMax = 1,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        BlankBorder = { type = "description", order = 29, fontSize = "small",name = "",width = "full", },
                        Border = {
                            type = "select",
                            order = 30,
                            name = "Border",
                            dialogControl = "LSM30_Border",
                            values = AceGUIWidgetLSMlists.border,
                        },
                        BorderColor = {
                            type = "color",
                            order = 40,
                            name = "Border color",
                            hasAlpha = true,
                            get = function(info)
                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Options[info[#info]].r = r
                                Options[info[#info]].g = g
                                Options[info[#info]].b = b
                                Options[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        BorderThickness = {
                            type = "range",
                            order = 50,
                            name = "Border thickness",
                            min = 1,
                            max = 24,
                            step = 0.5,
                        },
                        Background = {
                            type = "select",
                            order = 60,
                            name = "Background",
                            dialogControl = "LSM30_Background",
                            values = AceGUIWidgetLSMlists['background'],
                        },
                        BackgroundColor = {
                            type = "color",
                            order = 70,
                            name = "Background color",
                            hasAlpha = true,
                            get = function(info)
                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Options[info[#info]].r = r
                                Options[info[#info]].g = g
                                Options[info[#info]].b = b
                                Options[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        LineGroup = {
                            type = "group",
                            order = 80,
                            name = "Edge line",
                            inline = true,
                            args = {
                                Line = {
                                    type = "select",
                                    order = 10,
                                    name = "Position",
                                    values = {
                                        [""] = "none",
                                        ["BOTTOM"] = "on the bottom",
                                        ["TOP"] = "on the top",
                                        ["BOTH"] = "both",
                                    },
                                },
                                LineThickness = {
                                    type = "range",
                                    order = 20,
                                    name = "Thickness",
                                    min = 1,
                                    max = 24,
                                    step = 0.5,
                                },
                                LinePosition = {
                                    type = "range",
                                    order = 30,
                                    name = "Vertical adjustment",
                                    min = -16,
                                    max = 16,
                                    step = 0.5,
                                },
                                LineColor = {
                                    type = "color",
                                    order = 40,
                                    name = "Color",
                                    width = 1/2,
                                    hasAlpha = true,
                                    get = function(info)
                                        return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                                    end,
                                    set = function (info, r, g, b, a)
                                        Options[info[#info]].r = r
                                        Options[info[#info]].g = g
                                        Options[info[#info]].b = b
                                        Options[info[#info]].a = a
                                        Addon:UpdateHUDSettings()
                                    end,
                                },
                            },
                        },
                    },
                },
                CompassHUD = {
                    type = "group",
                    order = 30,
                    name = "Custom HUD",
                    args = {
                        UseCustomCompass = {
                            type = "toggle",
                            name = "Use Custom compass",
                            width = "full",
                            order = 10,
                        },
                        CustomCompass = {
                            type = "group",
                            order = 20,
                            name = "Custom compass",
                            inline = true,
                            disabled = function() return not Addon.db.profile.UseCustomCompass end,
                            args = {
                                MainCardinal = {
                                    type = "group",
                                    order = 10,
                                    name = "Main cardinal directions (N, E, S, W)",
                                    inline = true,
                                    args = {
                                        CompassCustomMainVisible = {
                                            type = "toggle",
                                            order = 10,
                                            name = "Enabled",
                                        },
                                        CompassCustomMainPosition = {
                                            type = "range",
                                            order = 15,
                                            name = "Vertical adjustment",
                                            min = -64,
                                            max = 64,
                                            step = 1,
                                        },
                                        Blank1 = { type = "description", order = 19, fontSize = "small",name = "",width = "full", },
                                        CompassCustomMainFont = {
                                            type = "select",
                                            order = 20,
                                            name = "Font",
                                            width = 1,
                                            dialogControl = "LSM30_Font",
                                            values = AceGUIWidgetLSMlists['font'],
                                        },
                                        CompassCustomMainSize = {
                                            type = "range",
                                            order = 30,
                                            name = "Size",
                                            width = 3/4,
                                            min = 2,
                                            max = 36,
                                            step = 0.5,
                                        },
                                        CompassCustomMainFlags = {
                                            type = "select",
                                            order = 40,
                                            name = "Outline",
                                            width = 3/4,
                                            values = {
                                                [""] = "None",
                                                ["OUTLINE"] = "Normal",
                                                ["THICKOUTLINE"] = "Thick",
                                            },
                                        },
                                        CompassCustomMainColor = {
                                            type = "color",
                                            order = 50,
                                            name = "Color",
                                            width = 1/2,
                                            hasAlpha = true,
                                            get = function(info)
                                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                                            end,
                                            set = function (info, r, g, b, a)
                                                Options[info[#info]].r = r
                                                Options[info[#info]].g = g
                                                Options[info[#info]].b = b
                                                Options[info[#info]].a = a
                                                Addon:UpdateHUDSettings()
                                            end,
                                        },
                                    },
                                },
                                SecondaryCardinal = {
                                    type = "group",
                                    order = 20,
                                    name = "Ordinal directions (NE, SE, SW, NW)",
                                    inline = true,
                                    args = {
                                        CompassCustomSecondaryVisible = {
                                            type = "toggle",
                                            order = 10,
                                            name = "Enabled",
                                        },
                                        CompassCustomSecondaryPosition = {
                                            type = "range",
                                            order = 15,
                                            name = "Vertical adjustment",
                                            min = -64,
                                            max = 64,
                                            step = 1,
                                        },
                                        Blank1 = { type = "description", order = 19, fontSize = "small",name = "",width = "full", },
                                        CompassCustomSecondaryFont = {
                                            type = "select",
                                            order = 20,
                                            name = "Font",
                                            width = 1,
                                            dialogControl = "LSM30_Font",
                                            values = AceGUIWidgetLSMlists['font'],
                                        },
                                        CompassCustomSecondarySize = {
                                            type = "range",
                                            order = 30,
                                            name = "Size",
                                            width = 3/4,
                                            min = 2,
                                            max = 36,
                                            step = 0.5,
                                        },
                                        CompassCustomSecondaryFlags = {
                                            type = "select",
                                            order = 40,
                                            name = "Outline",
                                            width = 3/4,
                                            values = {
                                                [""] = "None",
                                                ["OUTLINE"] = "Normal",
                                                ["THICKOUTLINE"] = "Thick",
                                            },
                                        },
                                        CompassCustomSecondaryColor = {
                                            type = "color",
                                            order = 50,
                                            name = "Color",
                                            width = 1/2,
                                            hasAlpha = true,
                                            get = function(info)
                                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                                            end,
                                            set = function (info, r, g, b, a)
                                                Options[info[#info]].r = r
                                                Options[info[#info]].g = g
                                                Options[info[#info]].b = b
                                                Options[info[#info]].a = a
                                                Addon:UpdateHUDSettings()
                                            end,
                                        },
                                    },
                                },
                                Degrees = {
                                    type = "group",
                                    order = 30,
                                    name = "Degrees",
                                    inline = true,
                                    args = {
                                        CompassCustomDegreesVisible = {
                                            type = "toggle",
                                            order = 10,
                                            name = "Enabled",
                                        },
                                        CompassCustomDegreesPosition = {
                                            type = "range",
                                            order = 15,
                                            name = "Vertical adjustment",
                                            min = -64,
                                            max = 64,
                                            step = 1,
                                        },
                                        CompassCustomDegreesSpan = {
                                            type = "range",
                                            order = 18,
                                            name = "Interval between degrees",
                                            min = 5,
                                            max = 90,
                                            softMin = 5,
                                            softMax = 45,
                                            step = 1,
                                            bigStep = 5,
                                        },
                                        Blank1 = { type = "description", order = 19, fontSize = "small",name = "",width = "full", },
                                        CompassCustomDegreesFont = {
                                            type = "select",
                                            order = 20,
                                            name = "Font",
                                            width = 1,
                                            dialogControl = "LSM30_Font",
                                            values = AceGUIWidgetLSMlists['font'],
                                        },
                                        CompassCustomDegreesSize = {
                                            type = "range",
                                            order = 30,
                                            name = "Size",
                                            width = 3/4,
                                            min = 2,
                                            max = 36,
                                            step = 0.5,
                                        },
                                        CompassCustomDegreesFlags = {
                                            type = "select",
                                            order = 40,
                                            name = "Outline",
                                            width = 3/4,
                                            values = {
                                                [""] = "None",
                                                ["OUTLINE"] = "Normal",
                                                ["THICKOUTLINE"] = "Thick",
                                            },
                                        },
                                        CompassCustomDegreesColor = {
                                            type = "color",
                                            order = 50,
                                            name = "Color",
                                            width = 1/2,
                                            hasAlpha = true,
                                            get = function(info)
                                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                                            end,
                                            set = function (info, r, g, b, a)
                                                Options[info[#info]].r = r
                                                Options[info[#info]].g = g
                                                Options[info[#info]].b = b
                                                Options[info[#info]].a = a
                                                Addon:UpdateHUDSettings()
                                            end,
                                        },
                                    },
                                },
                                CompassCustomTicksPosition = {
                                    type = "select",
                                    order = 90,
                                    name = "Ticks position",
                                    values = {
                                        [""] = "hide ticks",
                                        ["TOP"] = "on top",
                                        ["BOTTOM"] = "on bottom",
                                        ["BOTH"] = "both on top and bottom",
                                    },
                                },
                                CompassCustomTicksForce = {
                                    type = "toggle",
                                    order = 100,
                                    name = "Force ticks",
                                    desc = "Display ticks even if letters or degrees are not visible."
                                },
                            },
                        },
                    },
                },
                Heading ={
                    type = "group",
                    order = 40,
                    name = "Heading",
                    args = {
                        HeadingEnabled = {
                            type = "toggle",
                            name = "Show heading",
                            width = "full",
                            order = 0,
                        },
                        HeadingTrueNorth = {
                            type = "toggle",
                            name = "Display north as 360",
                            order = 5,
                        },
                        HeadingDecimals = {
                            type = "range",
                            order = 10,
                            name = "Decimal points",
                            desc = "-1 = to nearest 5, -2 to nearset 10 degree",
                            min = -2,
                            max = 3,
                            step = 1,
                        },
                        Blank0 = { type = "description", order = 19, fontSize = "small",name = "",width = "full", },
                        HeadingScale = {
                            type = "range",
                            order = 20,
                            name = "Scale",
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        HeadingWidth = {
                            type = "range",
                            order = 20,
                            name = "Width",
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        HeadingPosition = {
                            type = "range",
                            order = 20,
                            name = "Vertical adjustment",
                            min = -64,
                            max = 64,
                            step = 1,
                        },
                        Blank1 = { type = "description", order = 29, fontSize = "small",name = "",width = "full", },
                        HeadingTransparency = {
                            type = "range",
                            order = 30,
                            name = "Opacity",
                            min = 0,
                            max = 1,
                            softMin = 0,
                            softMax = 1,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        HeadingStrataLevel = {
                            type = "range",
                            order = 35,
                            name = "Strata level finetuning",
                            desc = "Positive number will bring the heading in foreground, negative to background.",
                            min = -100,
                            max = 100,
                            step = 1,
                        },
                        Blank2 = { type = "description", order = 39, fontSize = "small",name = "",width = "full", },
                        HeadingBorder = {
                            type = "select",
                            order = 40,
                            name = "Border",
                            dialogControl = "LSM30_Border",
                            values = AceGUIWidgetLSMlists.border,
                        },
                        HeadingBorderColor = {
                            type = "color",
                            order = 50,
                            name = "Border color",
                            hasAlpha = true,
                            get = function(info)
                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Options[info[#info]].r = r
                                Options[info[#info]].g = g
                                Options[info[#info]].b = b
                                Options[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        HeadingBorderThickness = {
                            type = "range",
                            order = 60,
                            name = "Border thickness",
                            min = 1,
                            max = 24,
                            step = 0.5,
                        },
                        HeadingBackground = {
                            type = "select",
                            order = 70,
                            name = "Background",
                            dialogControl = "LSM30_Background",
                            values = AceGUIWidgetLSMlists['background'],
                        },
                        HeadingBackgroundColor = {
                            type = "color",
                            order = 80,
                            name = "Background color",
                            hasAlpha = true,
                            get = function(info)
                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Options[info[#info]].r = r
                                Options[info[#info]].g = g
                                Options[info[#info]].b = b
                                Options[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        HeadingText = { type = "header", order = 89, name = "Text settings", },
                        HeadingFont = {
                            type = "select",
                            order = 90,
                            name = "Font",
                            width = 1,
                            dialogControl = "LSM30_Font",
                            values = AceGUIWidgetLSMlists['font'],
                        },
                        HeadingFontSize = {
                            type = "range",
                            order = 100,
                            name = "Size",
                            width = 3/4,
                            min = 2,
                            max = 36,
                            step = 0.5,
                        },
                        HeadingFontFlags = {
                            type = "select",
                            order = 110,
                            name = "Outline",
                            width = 3/4,
                            values = {
                                [""] = "None",
                                ["OUTLINE"] = "Normal",
                                ["THICKOUTLINE"] = "Thick",
                            },
                        },
                        HeadingFontColor = {
                            type = "color",
                            order = 120,
                            name = "Color",
                            width = 1/2,
                            hasAlpha = true,
                            get = function(info)
                                return Options[info[#info]].r, Options[info[#info]].g, Options[info[#info]].b, Options[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Options[info[#info]].r = r
                                Options[info[#info]].g = g
                                Options[info[#info]].b = b
                                Options[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        HeadingFontPositionV = {
                            type = "range",
                            order = 130,
                            name = "Vertical text adjustment",
                            width = 3/2,
                            min = -64,
                            max = 64,
                            step = 1,
                        },
                        HeadingFontPositionH = {
                            type = "range",
                            order = 140,
                            name = "Horizontal text adjustment",
                            width = 3/2,
                            min = -64,
                            max = 64,
                            step = 1,
                        },
                    },
                },
            },
        },
    },
}

local SupertrackerOptions = {
    type = "group",
    order = 10,
    name = "Supertracker",
    childGroups = "tab",
    args = {
        General = {
            type = "group",
            order = 10,
            name = "General",
            get = function(info)
                return Addon.db.profile[info[#info]]
            end,
            set = function(info, value)
                Addon.db.profile[info[#info]] = value
                Addon:UpdateHUDSettings()
            end,
            args = {
                PointerStay = {
                    type = "toggle",
                    name = "Pointers stay on HUD",
                    desc = "When pointers go beyond the boundaries of the compass HUD, they will transform into sideways arrows, remaining positioned at the edge of the HUD.",
                    width = 1.5,
                    order = 50,
                },
                StayArrow = {
                    type = "toggle",
                    name = "Pointer Out-of-HUD indicator",
                    desc = "Show a small indicator that the pointer is out of the HUD boundaries. Only show this for textures that don't have Edge rotation enabled.",
                    width = 1.5,
                    order = 60,
                    disabled = function() return not Addon.db.profile.PointerStay end,
                },
                HideFar = {
                    type = "toggle",
                    name = "Hide pointers to other continents",
                    desc = "Hide pointers that are located on other continents or in zones that require map transitions.",
                    width = 1.5,
                    order = 65,
                },
                UseCurrentMap = {
                    type = "toggle",
                    name = "Use map transition for pointers",
                    desc = "If the tracked quest or map pin is located in a different zone, the pointer will attempt to use map-suggested transitions (e.g., portals, entrances) instead of pointing directly to the marker.",
                    width = 1.5,
                    order = 66,
                },
            },
        },
        Pointers = {
            type = "group",
            order = 100,
            name = "Pointers",
            get = function(info)
                return Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]]
            end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] = value
                Addon:UpdateHUDSettings()
            end,
            args = {},
        },
    },
}

local TrackingOption = {
    type = "group",
    order = 20,
    name = "Minimap",
    get = function(info)
        return Addon.db.profile[info[#info]]
    end,
    set = function(info, value)
        Addon.db.profile[info[#info]] = value
        Addon:UpdateHUDSettings()
    end,
    args = {},
}

local POITrackOptions = {
    type = "group",
    order = 10,
    name = "Minimap icons",
    childGroups = "tab",
    args = {
        Settings = {
            type = "group",
            order = 10,
            name = "General",
            args = {
                ModuleDescription = {
                    type = "description",
                    order = 0,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:This module will display location, name, distance and TTA of some minimap icons in current zone.|r",
                    fontSize = "medium",
                },
                POITrackAlert = {
                    type = "description",
                    name = "|cnPURE_RED_COLOR:Be aware that this option will eat your FPS!|r",
                    fontSize = "medium",
                    image = "Interface/EncounterJournal/UI-EJ-WarningTextIcon",
                    order = 1,
                },
                POITrackEnabled = {
                    type = "toggle",
                    name = "Enabled",
                    width = "full",
                    order = 10,
                },
                POITrackRadius = {
                    type = "range",
                    order = 20,
                    name = "Scanning radius",
                    desc = "Radius around the player in which icons will be added to the HUD.\nIf set to 0, then all icons in current zone will be added.",
                    min = 0,
                    max = 10000,
                    softMin = 0,
                    softMax = 5000,
                    step = 1,
                    bigStep = 10,
                },
                POITrackInterval = {
                    type = "range",
                    order = 30,
                    name = "Update throttle",
                    desc = "Interval between adding/removing icons on the HUD based on their distance, relative to the 'Update Frequency' set on the 'General' tab.\nIf set to 30 (default) and 'Update Frequency' is set to 60 (default), then visibility check will be run 60/30 = 2 times per second.",
                    min = 1,
                    max = 100,
                    softMin = 1,
                    softMax = 60,
                    step = 1,
                },
                HeaderPOITrackNode = {
                    type = "header",
                    order = 50,
                    name = "Icon"
                },
                POITrackOffset = {
                    type = "range",
                    order = 60,
                    name = "Vertical adjustment",
                    min = -64,
                    max = 64,
                    step = 0.5,
                },
                POITrackScale = {
                    type = "range",
                    order = 70,
                    name = "Scale",
                    min = 0,
                    max = 3,
                    step = 0.01,
                    isPercent = true,
                },
                HeaderPOITrackOpacity = {
                    type = "header",
                    order = 100,
                    name = "Opacity"
                },
                POITrackOpacityDescription = {
                    type = "description",
                    order = 110,
                    name = "Adjust the opacity range for POI icons on the HUD.\nIcons farther from the player will appear more transparent, down to the specified minimum opacity.",
                    fontSize = "medium",
                },
                POITrackOpacityMin = {
                    type = "range",
                    order = 120,
                    name = "Minimum opacity",
                    min = 0,
                    max = 1,
                    softMin = 0.1,
                    softMax = 1,
                    step = 0.01,
                    isPercent = true,
                },
                POITrackOpacityMax = {
                    type = "range",
                    order = 130,
                    name = "Maximum opacity",
                    min = 0,
                    max = 1,
                    softMin = 0.1,
                    softMax = 1,
                    step = 0.01,
                    isPercent = true,
                },
            },
        },
        Filter = {
            type = "group",
            order = 20,
            name = "Filter",
            args = {
               ModuleDescription = {
                    type = "description",
                    order = 0,
                    name = "Select which icons will be wisible.",
                    fontSize = "medium",
                },
                POITrackFilter = {
                    type = "multiselect",
                    name = "Visible icon types",
                    order = 910,
                    width = "full",
                    values = function() return getPOITrackFilter() end,
                    get = function(info, key)
                        return Addon.db.profile.POITrackFilter[key] or false
                    end,
                    set = function(info, key, value)
                        Addon.db.profile.POITrackFilter[key] = value
                        Addon:UpdateHUDSettings()
                    end,
                },
                POITrackWQFilter = {
                    type = "select",
                    order = 1010,
                    name = "World Quests ",
                    desc = "Select which WorldQuest icons will be visible on the HUD.",
                    values = function() return getPOIFrackWQFilter() end,
                    get = function(info)
                        return Addon.db.profile.POITrackWQFilter
                    end,
                    set = function(info, value)
                        Addon.db.profile.POITrackWQFilter = value
                        Addon:UpdateHUDSettings()
                    end,
                },
                POITrackWQWholeZone = {
                    type = "toggle",
                    order = 1020,
                    name = "Bypass scanning radius",
                    desc = "If enabled, World Quests will be shown in the whole zone, not just in the scanning radius.",
                },
            },
        },
        Texts = {
            type = "group",
            order = 30,
            name = "Texts",
            args = {
                POITrackTextsDegrees = {
                    type = "range",
                    order = 10,
                    name = "Texts visibility angle",
                    desc = "Texts will be shown only if the angle to the icon is less than this value.\nOnly the closest icon to heading will show texts.\nIf set to 0, then all selected texts are shown for every visible icon.",
                    min = 0,
                    max = 360,
                    softMin = 0,
                    softMax = 30,
                    step = 0.5,
                },
                POITrackOpacitySelected = {
                    type = "range",
                    order = 20,
                    name = "Opacity of visible texts",
                    desc = "Set the opacity of the text labels for icon near the heading.\nThis option is only enabled when 'Texts visibility angle' is greater than 0.",                    min = 0,
                    max = 1,
                    softMin = 0.1,
                    softMax = 1,
                    step = 0.01,
                    isPercent = true,
                    disabled = function() return Options.POITrackTextsDegrees == 0 end,
                },
                HeaderPOITrackDistance = {
                    type = "header",
                    order = 100,
                    name = "Distance text"
                },
                POITrackShowDistance = {
                    type = "toggle",
                    order = 110,
                    name = "Show",
                },
                POITrackDistanceOffset = {
                    type = "range",
                    order = 120,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                POITrackDistanceCustomFont = {
                    type = "toggle",
                    order = 130,
                    name = "Use custom font",
                },
                POITrackDistanceFont = {
                    type = "select",
                    order = 140,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.POITrackDistanceCustomFont end,
                },
                POITrackDistanceFontSize = {
                    type = "range",
                    order = 150,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.POITrackDistanceCustomFont end,
                },
                POITrackDistanceFontFlags = {
                    type = "select",
                    order = 160,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.POITrackDistanceCustomFont end,
                },
                POITrackDistanceFontColor = {
                    type = "color",
                    order = 170,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.POITrackDistanceCustomFont end,
                },
                HeaderPOITrackTTA = {
                    type = "header",
                    order = 200,
                    name = "Time to arrive"
                },
                POITrackShowTTA = {
                    type = "toggle",
                    order = 210,
                    name = "Show",
                },
                POITrackTtaOffset = {
                    type = "range",
                    order = 220,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                POITrackTtaCustomFont = {
                    type = "toggle",
                    order = 230,
                    name = "Use custom font",
                },
                POITrackTtaFont = {
                    type = "select",
                    order = 240,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.POITrackTtaCustomFont end,
                },
                POITrackTtaFontSize = {
                    type = "range",
                    order = 250,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.POITrackTtaCustomFont end,
                },
                POITrackTtaFontFlags = {
                    type = "select",
                    order = 260,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.POITrackTtaCustomFont end,
                },
                POITrackTtaFontColor = {
                    type = "color",
                    order = 270,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.POITrackTtaCustomFont end,
                },
                HeaderPOITrackTitle = {
                    type = "header",
                    order = 300,
                    name = "Icon name"
                },
                POITrackShowTitle = {
                    type = "toggle",
                    order = 310,
                    name = "Show",
                },
                POITrackTitleOffset = {
                    type = "range",
                    order = 320,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                POITrackTitleCustomFont = {
                    type = "toggle",
                    order = 330,
                    name = "Use custom font",
                },
                POITrackTitleFont = {
                    type = "select",
                    order = 340,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.POITrackTitleCustomFont end,
                },
                POITrackTitleFontSize = {
                    type = "range",
                    order = 350,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.POITrackTitleCustomFont end,
                },
                POITrackTitleFontFlags = {
                    type = "select",
                    order = 360,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.POITrackTitleCustomFont end,
                },
                POITrackTitleFontColor = {
                    type = "color",
                    order = 370,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.POITrackTitleCustomFont end,
                },
            },
        },
        Supertracking = {
            type = "group",
            order = 40,
            name = "Supertracking",
            args = {
                POITrackWaypointNote = {
                    type = "description",
                    order = 9,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:This feature attempts to set world supertracking for currently facing minimap icon as if you had clicked the POI on the World Map.\nIf no valid POI is found (e.g., for vignettes), a user waypoint will be set instead.|r\n\n",
                    fontSize = "medium",
                },
                POITrackKeyBinding = {
                    order = 10,
                    type = "keybinding",
                    name = "Keybind (" .. BINDING_NAME_COMPASSHUD_SUPERTRACK .. ")",
                    desc = "Toggles the minimap icon you are facing as a waypoint.",
                    width = "full",
                    get = function()
                        return GetBindingKey("COMPASSHUD_SUPERTRACK")
                    end,
                    set = function(_, key)
                        local oldKey1, oldKey2 = GetBindingKey("COMPASSHUD_SUPERTRACK")
                        if oldKey1 then SetBinding(oldKey1) end
                        if oldKey2 then SetBinding(oldKey2) end
                        if key and key ~= "" then
                            SetBinding(key, "COMPASSHUD_SUPERTRACK")
                        end
                    end,
                },
                HeaderPOITrackTexture = {
                    type = "header",
                    order = 108,
                    name = "User Waypoint Texture"
                },
                POITrackTextureNote = {
                    type = "description",
                    order = 109,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:Only applies if a user waypoint is used (e.g., for vignettes).\nOtherwise, the settings in Supertracker for the relevant pointer category are applied.|r\n\n",
                    fontSize = "medium",
                },
                POITrackWorldmapTexture = {
                    type = "toggle",
                    order = 110,
                    name = "Icon texture",
                    desc = "If enabled, the user waypoint will use the minimap icon’s texture instead of the default diamond icon.",
                },
                POITrackSTRetexture = {
                    type = "toggle",
                    order = 120,
                    name = "Retexture Waypoint",
                    desc = "If enabled, the user waypoint will use the same texture as the minimap icon.",
                },

            },
        },
    },
}

local GroupOptions = {
    type = "group",
    order = 110,
    name = "Party/Raid",
    childGroups = "tab",
    args = {
        Settings = {
            type = "group",
            order = 10,
            name = "General",
            args = {
                ModuleDescription = {
                    type = "description",
                    order = 0,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:This module will display location and names of party and raid members.|r",
                    fontSize = "medium",
                },
                GroupAlert = {
                    type = "description",
                    name = "|cnPURE_RED_COLOR:Be aware that the compass is hidden in instances (dungeons, raids, delves, etc.), so this functionality won't be available there either.|r",
                    fontSize = "medium",
                    image = "Interface/EncounterJournal/UI-EJ-WarningTextIcon",
                    order = 1,
                },
                GroupShowParty = {
                    type = "toggle",
                    name = "Show markers for party members",
                    desc = "Show markers for party members on the compass HUD.",
                    width = "full",
                    order = 10,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                },
                GroupShowRaid = {
                    type = "toggle",
                    name = "Show markers for raid members",
                    desc = "Show markers for raid members on the compass HUD.",
                    width = "full",
                    order = 20,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                },
                BlankGroupStayArrow = { type = "description", order = 29, fontSize = "small",name = "",width = "full", },
                GroupStay = {
                    type = "toggle",
                    name = "Group markers stay on HUD",
                    desc = "Show markers on the edge of compass if they are out of the HUD bounderies. ",
                    width = "full",
                    order = 30,
                },
                GroupInterval = {
                    type = "range",
                    order = 40,
                    name = "Update throttle",
                    desc = "Interval between checking group members' positions relative to the 'Update Frequency' set on the 'General' tab.\nIf set to 6 (default) and 'Update Frequency' is set to 60 (default), then positions will be updated 60/6 = 10 times per second.",
                    width = "full",
                    min = 1,
                    max = 100,
                    softMin = 1,
                    softMax = 60,
                    step = 1,
                },
            },
        },
        GroupMarkers = {
            type = "group",
            order = 100,
            name = "Textures",
            args = {
                HeaderGroupTexture = { type = "header", order = 100, name = "Group member on the same map", },
                GroupOffset = {
                    type = "range",
                    order = 100,
                    name = "Vertical adjustment",
                    width = "full",
                    min = -64,
                    max = 64,
                    step = 1,
                },
                GroupTexturePreview = {
                    type = "description",
                    order = 110,
                    name = "",
                    width = 1/6,
                    image = function(info)
                        local atlasID = Addon.db.profile.GroupTexture
                        if atlasID then
                            return getAtlasTexture(atlasID)
                        end
                        return nil
                    end,
                    imageWidth = 24,
                    imageHeight = 24,
                    imageCoords = function(info)
                        local atlasID = Addon.db.profile.GroupTexture
                        if atlasID then
                            return getAtlasCoords(atlasID)
                        end
                    end
                },
                GroupTexture = {
                    type = "select",
                    order = 120,
                    name = "Texture",
                    values = function() return getPointerAtlasIDs() end,
                    sorting = function() return getSortedPointerAtlasIDKeys() end,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value
                        local texture = getPointerTextureByAtlasID(value)
                        Addon.db.profile.GroupScale = texture and texture.textureScale or 1
                        Addon.db.profile.GroupRotate = (texture and texture.textureRotate) and 1 or -1
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                },
                GroupScale = {
                    type = "range",
                    name = "Scale",
                    order = 130,
                    min = 0.01,
                    max = 5,
                    softMin = 0.2,
                    softMax = 3,
                    step = 0.01,
                    bigStep = 0.05,
                    isPercent = true,
                },
                GroupTextureCustom = {
                    type = "input",
                    order = 140,
                    name = "Custom atlas ID",
                    desc = "AtlasID of the texture. You can enter your own. Try WeakAuras' internal texture browser to pick one.",
                    width = "full",
                    get = function(info)
                        return Addon.db.profile.GroupTexture
                    end,
                    set = function(info, value)
                        Addon.db.profile.GroupTexture = value
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                },
                GroupRotate = {
                    type = "toggle",
                    order = 150,
                    name = "Edge rotation",
                    desc = "When enabled, the marker will flip when at the top side of the compass and rotate 90° when on the edge.",
                    get = function(info)
                        return Addon.db.profile[info[#info]] and Addon.db.profile[info[#info]] > 0
                    end,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value and 1 or -1
                    end,
                },
                HeaderGroupShowAllZones = { type = "header", order = 200, name = "Group member on different map", },
                DescGroupShowAllZone = {
                    type = "description",
                    order = 200.1,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:Typically on different continet, zone behind portal, underground zone etc. These markers may not point to the right direction.|r"
                },
                GroupShowAllZones = {
                    type = "toggle",
                    name = "Show marker",
                    order = 201,
                },
                GroupZoneDesaturate = {
                    type = "toggle",
                    name = "Desaturate marker",
                    order = 202,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                GroupZoneOffset = {
                    type = "range",
                    order = 203,
                    name = "Vertical adjustment",
                    min = -64,
                    max = 64,
                    step = 1,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                GroupZoneTransparency = {
                    type = "range",
                    name = "Marker opacity",
                    order = 204,
                    min = 0.01,
                    max = 1,
                    softMin = 0.1,
                    softMax = 1,
                    step = 0.01,
                    bigStep = 0.05,
                    isPercent = true,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                BlankGroupZoneTexturePreview = { type = "description", order = 209, fontSize = "small",name = "",width = "full", },
                GroupZoneTexturePreview = {
                    type = "description",
                    order = 210,
                    name = "",
                    width = 1/6,
                    image = function(info)
                        local atlasID = Addon.db.profile.GroupZoneTexture
                        if atlasID then
                            return getAtlasTexture(atlasID)
                        end
                        return nil
                    end,
                    imageWidth = 24,
                    imageHeight = 24,
                    imageCoords = function(info)
                        local atlasID = Addon.db.profile.GroupZoneTexture
                        if atlasID then
                            return getAtlasCoords(atlasID)
                        end
                    end
                },
                GroupZoneTexture = {
                    type = "select",
                    order = 220,
                    name = "Texture",
                    values = function() return getPointerAtlasIDs() end,
                    sorting = function() return getSortedPointerAtlasIDKeys() end,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value
                        local texture = getPointerTextureByAtlasID(value)
                        Addon.db.profile.GroupZoneScale = texture and texture.textureScale or 1
                        Addon.db.profile.GroupZoneRotate = (texture and texture.textureRotate) and 1 or -1
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                GroupZoneScale = {
                    type = "range",
                    name = "Scale",
                    order = 230,
                    min = 0.01,
                    max = 5,
                    softMin = 0.2,
                    softMax = 3,
                    step = 0.01,
                    bigStep = 0.05,
                    isPercent = true,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                GroupZoneTextureCustom = {
                    type = "input",
                    order = 240,
                    name = "Custom atlas ID",
                    desc = "AtlasID of the texture. You can enter your own. Try WeakAuras' internal texture browser to pick one.",
                    width = "full",
                    get = function(info)
                        return Addon.db.profile.GroupZoneTexture
                    end,
                    set = function(info, value)
                        Addon.db.profile.GroupZoneTexture = value
                        Addon:HideGroupIcons()
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
                GroupZoneRotate = {
                    type = "toggle",
                    order = 250,
                    name = "Edge rotation",
                    desc = "When enabled, the marker will flip when at the top side of the compass and rotate 90° when on the edge.",
                    get = function(info)
                        return Addon.db.profile[info[#info]] and Addon.db.profile[info[#info]] > 0
                    end,
                    set = function(info, value)
                        Addon.db.profile[info[#info]] = value and 1 or -1
                    end,
                    disabled = function() return not Addon.db.profile.GroupShowAllZones end,
                },
            },
        },
        GroupTexts = {
            type = "group",
            order = 200,
            name = "Texts",
            childGroups = "tab",
            args = {
                Party = {
                    type = "group",
                    order = 10,
                    name = "Party",
                    args = {
                        GroupPartyNameShow = {
                            type = "toggle",
                            order = 20,
                            name = "Show",
                        },
                        GroupPartyNameOffset = {
                            type = "range",
                            order = 30,
                            name = "Vertical adjustment",
                            min = -20,
                            max = 20,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        HeaderGroupPartyBorderBackground = { type = "header", order = 39, name = "Border and Background", },
                        GroupPartyNameBorder = {
                            type = "select",
                            order = 40,
                            width = 1,
                            name = "Border",
                            dialogControl = "LSM30_Border",
                            values = AceGUIWidgetLSMlists.border,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        GroupPartyNameBorderThickness = {
                            type = "range",
                            order = 45,
                            name = "Border thickness",
                            width = 1,
                            min = 1,
                            max = 24,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        BlankGroupPartyNameBorderColor = { type = "description", order = 49, fontSize = "small",name = "",width = "full", },
                        GroupPartyNameBorderClass = {
                            type = "toggle",
                            order = 50,
                            name = "Class color",
                            width = 1,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        GroupPartyNameBorderColor = {
                            type = "color",
                            order = 55,
                            name = "Custom color",
                            width = 1,
                            hasAlpha = true,
                            get = function(info)
                                return Addon.db.profile[info[#info]].r, Addon.db.profile[info[#info]].g, Addon.db.profile[info[#info]].b, Addon.db.profile[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Addon.db.profile[info[#info]].r = r
                                Addon.db.profile[info[#info]].g = g
                                Addon.db.profile[info[#info]].b = b
                                Addon.db.profile[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or Addon.db.profile.GroupPartyNameBorderClass end,
                        },
                        BlankGroupPartyNameBackground = { type = "description", order = 69, fontSize = "small",name = "",width = "full", },
                        GroupPartyNameBackground = {
                            type = "select",
                            order = 70,
                            name = "Background",
                            width = 1,
                            dialogControl = "LSM30_Background",
                            values = AceGUIWidgetLSMlists['background'],
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        BlankGroupPartyNameBackgroundColor = { type = "description", order = 74, fontSize = "small",name = "",width = "full", },
                        GroupPartyNameBackgroundClass = {
                            type = "toggle",
                            order = 75,
                            name = "Class color",
                            width = 1,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        GroupPartyNameBackgroundColor = {
                            type = "color",
                            order = 80,
                            name = "Custom color",
                            width = 1,
                            hasAlpha = true,
                            get = function(info)
                                return Addon.db.profile[info[#info]].r, Addon.db.profile[info[#info]].g, Addon.db.profile[info[#info]].b, Addon.db.profile[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Addon.db.profile[info[#info]].r = r
                                Addon.db.profile[info[#info]].g = g
                                Addon.db.profile[info[#info]].b = b
                                Addon.db.profile[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or Addon.db.profile.GroupPartyNameBackgroundClass end,
                        },
                        HeaderGroupPartyFont = { type = "header", order = 89, name = "Font", },
                        GroupPartyNameClassColor = {
                            type = "toggle",
                            order = 90,
                            name = "Use class color",
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        GroupPartyNameFontColor = {
                            type = "color",
                            order = 100,
                            name = "Custom color",
                            hasAlpha = true,
                            get = function(info)
                                local color = Addon.db.profile[info[#info]]
                                return color.r, color.g, color.b, color.a
                            end,
                            set = function (info, r, g, b, a)
                                local color = Addon.db.profile[info[#info]]
                                color.r = r
                                color.g = g
                                color.b = b
                                color.a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or Addon.db.profile.GroupPartyNameClassColor end,
                        },
                        BlankGroupPartyCustomFont = { type = "description", order = 109, fontSize = "small",name = "",width = "full", },
                        GroupPartyNameCustomFont = {
                            type = "toggle",
                            order = 110,
                            name = "Custom font",
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow end,
                        },
                        BlankGroupPartyNameCustomFontName = { type = "description", order = 119, fontSize = "small",name = "",width = "full", },
                        GroupPartyNameFont = {
                            type = "select",
                            order = 120,
                            name = "Font",
                            width = 3/4,
                            dialogControl = "LSM30_Font",
                            values = AceGUIWidgetLSMlists['font'],
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or not Addon.db.profile.GroupPartyNameCustomFont end,
                        },
                        GroupPartyNameFontSize = {
                            type = "range",
                            order = 130,
                            name = "Size",
                            width = 3/4,
                            min = 2,
                            max = 36,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or not Addon.db.profile.GroupPartyNameCustomFont end,
                        },
                        GroupPartyNameFontFlags = {
                            type = "select",
                            order = 140,
                            name = "Outline",
                            width = 3/4,
                            values = {
                                [""] = "None",
                                ["OUTLINE"] = "Normal",
                                ["THICKOUTLINE"] = "Thick",
                            },
                            disabled = function() return not Addon.db.profile.GroupPartyNameShow or not Addon.db.profile.GroupPartyNameCustomFont end,
                        },
                    },
                },
                Raid = {
                    type = "group",
                    order = 20,
                    name = "Raid",
                    args = {
                        GroupRaidNameShow = {
                            type = "toggle",
                            order = 220,
                            name = "Show",
                        },
                        GroupRaidNameOffset = {
                            type = "range",
                            order = 230,
                            name = "Vertical adjustment",
                            min = -20,
                            max = 20,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        HeaderGroupRaidNameShow = { type = "header", order = 239, name = "Border and Background", },
                        GroupRaidNameBorder = {
                            type = "select",
                            order = 240,
                            name = "Border",
                            width = 1,
                            dialogControl = "LSM30_Border",
                            values = AceGUIWidgetLSMlists.border,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        GroupRaidNameBorderThickness = {
                            type = "range",
                            order = 245,
                            name = "Border thickness",
                            width = 1,
                            min = 1,
                            max = 24,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        BlankGroupRaidNameBorderColor = { type = "description", order = 249, fontSize = "small",name = "",width = "full", },
                        GroupRaidNameBorderClass = {
                            type = "toggle",
                            order = 250,
                            name = "Class color",
                            width = 1,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        GroupRaidNameBorderColor = {
                            type = "color",
                            order = 255,
                            name = "Custom color",
                            width = 1,
                            hasAlpha = true,
                            get = function(info)
                                return Addon.db.profile[info[#info]].r, Addon.db.profile[info[#info]].g, Addon.db.profile[info[#info]].b, Addon.db.profile[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Addon.db.profile[info[#info]].r = r
                                Addon.db.profile[info[#info]].g = g
                                Addon.db.profile[info[#info]].b = b
                                Addon.db.profile[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or Addon.db.profile.GroupRaidNameBorderClass end,
                        },
                        BlankGroupRaidNameBackground = { type = "description", order = 269, fontSize = "small",name = "",width = "full", },
                        GroupRaidNameBackground = {
                            type = "select",
                            order = 270,
                            name = "Background",
                            width = 1,
                            dialogControl = "LSM30_Background",
                            values = AceGUIWidgetLSMlists['background'],
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        BlankGroupRaidNameBackgroundColor = { type = "description", order = 274, fontSize = "small",name = "",width = "full", },
                        GroupRaidNameBackgroundClass = {
                            type = "toggle",
                            order = 275,
                            name = "Class color",
                            width = 1,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        GroupRaidNameBackgroundColor = {
                            type = "color",
                            order = 280,
                            name = "Custom color",
                            width = 1,
                            hasAlpha = true,
                            get = function(info)
                                return Addon.db.profile[info[#info]].r, Addon.db.profile[info[#info]].g, Addon.db.profile[info[#info]].b, Addon.db.profile[info[#info]].a
                            end,
                            set = function (info, r, g, b, a)
                                Addon.db.profile[info[#info]].r = r
                                Addon.db.profile[info[#info]].g = g
                                Addon.db.profile[info[#info]].b = b
                                Addon.db.profile[info[#info]].a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or Addon.db.profile.GroupRaidNameBackgroundClass end,
                        },
                        HeaderGroupPartyFont = { type = "header", order = 289, name = "Font", },
                        GroupRaidNameClassColor = {
                            type = "toggle",
                            order = 290,
                            name = "Use class color",
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        GroupRaidNameFontColor = {
                            type = "color",
                            order = 300,
                            name = "Custom color",
                            hasAlpha = true,
                            get = function(info)
                                local color = Addon.db.profile[info[#info]]
                                return color.r, color.g, color.b, color.a
                            end,
                            set = function (info, r, g, b, a)
                                local color = Addon.db.profile[info[#info]]
                                color.r = r
                                color.g = g
                                color.b = b
                                color.a = a
                                Addon:UpdateHUDSettings()
                            end,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or Addon.db.profile.GroupRaidNameClassColor end,
                        },
                        BlankGroupRaidCustomFont = { type = "description", order = 309, fontSize = "small",name = "",width = "full", },
                        GroupRaidNameCustomFont = {
                            type = "toggle",
                            order = 310,
                            name = "Custom font",
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow end,
                        },
                        BlankGroupRaidNameCustomFontName = { type = "description", order = 319, fontSize = "small",name = "",width = "full", },
                        GroupRaidNameFont = {
                            type = "select",
                            order = 320,
                            name = "Font",
                            width = 3/4,
                            dialogControl = "LSM30_Font",
                            values = AceGUIWidgetLSMlists['font'],
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or not Addon.db.profile.GroupRaidNameCustomFont end,
                        },
                        GroupRaidNameFontSize = {
                            type = "range",
                            order = 330,
                            name = "Size",
                            width = 3/4,
                            min = 2,
                            max = 36,
                            step = 0.5,
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or not Addon.db.profile.GroupRaidNameCustomFont end,
                        },
                        GroupRaidNameFontFlags = {
                            type = "select",
                            order = 340,
                            name = "Outline",
                            width = 3/4,
                            values = {
                                [""] = "None",
                                ["OUTLINE"] = "Normal",
                                ["THICKOUTLINE"] = "Thick",
                            },
                            disabled = function() return not Addon.db.profile.GroupRaidNameShow or not Addon.db.profile.GroupRaidNameCustomFont end,
                        },
                    },
                },
            },
        },
    },
}

local GatherMateOptions = {
    type = "group",
    order = 1010,
    name = "GatherMate2 addon",
    childGroups = "tab",
    args = {
        Settings = {
            type = "group",
            order = 10,
            name = "General",
            args = {
                ModuleDescription = {
                    type = "description",
                    order = 0,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:This module will display potential locations of gathering nodes.|r",
                    fontSize = "medium",
                },                GatherMateEnabled = {
                    type = "toggle",
                    name = "Enabled",
                    width = "full",
                    order = 10,
                },
                GatherMateRadius = {
                    type = "range",
                    order = 20,
                    name = "Scanning radius",
                    min = 1,
                    max = 2000,
                    softMin = 50,
                    softMax = 1000,
                    step = 1,
                    bigStep = 5,
                },
                GatherMateInterval = {
                    type = "range",
                    order = 30,
                    name = "Update throttle",
                    desc = "Interval between adding/removing nodes on the HUD based on their distance, relative to the 'Update Frequency' set on the 'General' tab.\nIf set to 6 (default) and 'Update Frequency' is set to 60 (default), then visibility check will be run 60/6 = 10 times per second.",
                    min = 1,
                    max = 100,
                    softMin = 1,
                    softMax = 60,
                    step = 1,
                },
                HeaderGatherMateNode = {
                    type = "header",
                    order = 50,
                    name = "Node"
                },
                GatherMateOffset = {
                    type = "range",
                    order = 60,
                    name = "Vertical adjustment",
                    min = -64,
                    max = 64,
                    step = 0.5,
                },
                GatherMateScale = {
                    type = "range",
                    order = 70,
                    name = "Scale",
                    min = 0,
                    max = 3,
                    step = 0.01,
                    isPercent = true,
                },
            },
        },
        Texts = {
            type = "group",
            order = 20,
            name = "Texts",
            args = {
                HeaderGatherMateDistance = {
                    type = "header",
                    order = 100,
                    name = "Distance text"
                },
                GatherMateShowDistance = {
                    type = "toggle",
                    order = 110,
                    name = "Show",
                },
                GatherMateDistanceOffset = {
                    type = "range",
                    order = 120,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                GatherMateDistanceCustomFont = {
                    type = "toggle",
                    order = 130,
                    name = "Use custom font",
                },
                GatherMateDistanceFont = {
                    type = "select",
                    order = 140,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.GatherMateDistanceCustomFont end,
                },
                GatherMateDistanceFontSize = {
                    type = "range",
                    order = 150,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.GatherMateDistanceCustomFont end,
                },
                GatherMateDistanceFontFlags = {
                    type = "select",
                    order = 160,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.GatherMateDistanceCustomFont end,
                },
                GatherMateDistanceFontColor = {
                    type = "color",
                    order = 170,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.GatherMateDistanceCustomFont end,
                },
                HeaderGatherMateTTA = {
                    type = "header",
                    order = 200,
                    name = "Time to arrive"
                },
                GatherMateShowTTA = {
                    type = "toggle",
                    order = 210,
                    name = "Show",
                },
                GatherMateTtaOffset = {
                    type = "range",
                    order = 220,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                GatherMateTtaCustomFont = {
                    type = "toggle",
                    order = 230,
                    name = "Use custom font",
                },
                GatherMateTtaFont = {
                    type = "select",
                    order = 240,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.GatherMateTtaCustomFont end,
                },
                GatherMateTtaFontSize = {
                    type = "range",
                    order = 250,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.GatherMateTtaCustomFont end,
                },
                GatherMateTtaFontFlags = {
                    type = "select",
                    order = 260,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.GatherMateTtaCustomFont end,
                },
                GatherMateTtaFontColor = {
                    type = "color",
                    order = 270,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.GatherMateTtaCustomFont end,
                },
                HeaderGatherMateTitle = {
                    type = "header",
                    order = 300,
                    name = "Node name"
                },
                GatherMateShowTitle = {
                    type = "toggle",
                    order = 310,
                    name = "Show",
                },
                GatherMateTitleOffset = {
                    type = "range",
                    order = 320,
                    name = "Vertical adjustment",
                    min = -20,
                    max = 20,
                    step = 0.5,
                },
                GatherMateTitleCustomFont = {
                    type = "toggle",
                    order = 330,
                    name = "Use custom font",
                },
                GatherMateTitleFont = {
                    type = "select",
                    order = 340,
                    name = "Font",
                    width = 1,
                    dialogControl = "LSM30_Font",
                    values = AceGUIWidgetLSMlists['font'],
                    disabled = function() return not Options.GatherMateTitleCustomFont end,
                },
                GatherMateTitleFontSize = {
                    type = "range",
                    order = 350,
                    name = "Size",
                    width = 3/4,
                    min = 2,
                    max = 36,
                    step = 0.5,
                    disabled = function() return not Options.GatherMateTitleCustomFont end,
                },
                GatherMateTitleFontFlags = {
                    type = "select",
                    order = 360,
                    name = "Outline",
                    width = 3/4,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Normal",
                        ["THICKOUTLINE"] = "Thick",
                    },
                    disabled = function() return not Options.GatherMateTitleCustomFont end,
                },
                GatherMateTitleFontColor = {
                    type = "color",
                    order = 370,
                    name = "Color",
                    width = 1/2,
                    hasAlpha = true,
                    get = function(info)
                        local color = Addon.db.profile[info[#info]]
                        return color.r, color.g, color.b, color.a
                    end,
                    set = function (info, r, g, b, a)
                        local color = Addon.db.profile[info[#info]]
                        color.r = r
                        color.g = g
                        color.b = b
                        color.a = a
                        Addon:UpdateHUDSettings()
                    end,
                    disabled = function() return not Options.GatherMateTitleCustomFont end,
                },
            },
        },
    },
}

local function GetQuestPOIInfo(questID)
    local completed = IsQuestComplete(questID)

    -- try to get waypoint
    local uiMapID, x, y = GetNextWaypoint(questID)
    if uiMapID and x and y then
        return uiMapID, x, y, completed
    end

    -- give me proper uiMapID
    uiMapID = GetQuestUiMapID(questID) or GetQuestAdditionalHighlights(questID)
    if uiMapID and uiMapID > 0 then
        -- try to get waypoint when clicked on mapPin
        x, y = GetNextWaypointForMap(questID, uiMapID)
        if x and y then
            return uiMapID, x, y, completed
        end
        -- try to parse all quests on current Map
        local quests = GetQuestsOnMap(uiMapID)
        for _, quest in pairs(quests) do
            if quest.questID == questID then
                return uiMapID, quest.x, quest.y, completed
            end
       end
    end
end

local function getMapId(questID)
    local uiMapID = GetMapForQuestPOIs()
    if uiMapID and uiMapID > 0 then return uiMapID end
    for _, uiMapID in ipairs(HBDmaps) do
        local quests = GetQuestsOnMap(uiMapID)
        for _, quest in pairs(quests) do
           if quest.questID == questID then
              local mapInfo = GetMapInfo(uiMapID)
              if mapInfo.mapType == 3 then
                 return uiMapID
              end
           end
        end
    end
end

local function updatePlayerCoords()
    if player.inInstance then return end

    player.x, player.y, player.instance = HBD:GetPlayerWorldPosition()
    player.uiMapID = HBD:GetPlayerZone()
    player.angle = GetPlayerFacing()
end

local function getPlayerFacingAngle(questID)
    if not player.angle then return end
	if not questID or not questPointsTable[questID] or not questPointsTable[questID].x then return end

    local point = questPointsTable[questID]
    local angle = player.angle - HBD:GetWorldVector(point.instance, player.x, player.y, point.x, point.y)
    if angle < 0 then angle = angle + (2 * PI) end
    if angle > PI then angle = angle - (2 * PI) end
	return angle
end

local function updateCompassHUD()
    local scale = Options.Scale * Options.VerticalScale
    -- middle HUD pointer texture
    HUD.pin = HUD.pin or HUD:CreateTexture(nil, "ARTWORK")
    HUD.pin:SetTexture(Options.PinTexture)
    HUD.pin:ClearAllPoints()
    HUD.pin:SetSize(textureHeight * 1.5, textureHeight * 1.5)
	HUD.pin:SetPoint('TOP', HUD, 'TOP', 0, 6)
    HUD.pin:SetShown(Options.PinVisible)

    -- compass texture
    HUD.compassTexture = HUD.compassTexture or HUD:CreateTexture(nil, "BORDER")
    HUD.compassTexture:SetTexture(Options.CompassTextureTexture)
    HUD.compassTexture:ClearAllPoints()
    HUD.compassTexture:SetPoint('TOPLEFT', HUD, 'TOPLEFT', Options.BorderThickness + 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMLEFT', HUD, 'BOTTOMLEFT', Options.BorderThickness + 1, Options.BorderThickness + 1)
    HUD.compassTexture:SetPoint('TOPRIGHT', HUD, 'TOPRIGHT', -Options.BorderThickness - 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMRIGHT', HUD, 'BOTTOMRIGHT', -Options.BorderThickness - 1, Options.BorderThickness + 1)

    -- static frame to display compass leters and numbers with clipchildren
    HUD.compassCustom = HUD.compassCustom or CreateFrame('Frame', nil, HUD)
    HUD.compassCustom:SetSize(textureWidth / 2, textureHeight)
    HUD.compassCustom:SetPoint('TOP', HUD, 'TOP', 0, 0)
    HUD.compassCustom:SetClipsChildren(true)

    -- movable frame to reflect player facing
    HUD.compassCustom.mask = HUD.compassCustom.mask or CreateFrame('Frame', nil, HUD.compassCustom)
    HUD.compassCustom.mask:SetSize(textureWidth, textureHeight)
    HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', 0, 0)

    -- top edge line
    HUD.edgeTOP = HUD.edgeTOP or HUD:CreateTexture(nil, "OVERLAY")
    HUD.edgeTOP:SetColorTexture(Options.LineColor.r, Options.LineColor.g, Options.LineColor.b, Options.LineColor.a)
    HUD.edgeTOP:SetHeight(Options.LineThickness)
    HUD.edgeTOP:ClearAllPoints()
    HUD.edgeTOP:SetPoint("BOTTOM", HUD, "TOP", 0, Options.LinePosition)
    HUD.edgeTOP:SetWidth(HUD:GetWidth())
    HUD.edgeTOP:SetShown(Options.Line == "TOP" or Options.Line == "BOTH")

    -- bottom edge lines
    HUD.edgeBOTTOM = HUD.edgeBOTTOM or HUD:CreateTexture(nil, "OVERLAY")
    HUD.edgeBOTTOM:SetColorTexture(Options.LineColor.r, Options.LineColor.g, Options.LineColor.b, Options.LineColor.a)
    HUD.edgeBOTTOM:SetHeight(Options.LineThickness)
    HUD.edgeBOTTOM:ClearAllPoints()
    HUD.edgeBOTTOM:SetPoint("TOP", HUD, "BOTTOM", 0, -Options.LinePosition)
    HUD.edgeBOTTOM:SetWidth(HUD:GetWidth())
    HUD.edgeBOTTOM:SetShown(Options.Line == "BOTTOM" or Options.Line == "BOTH")

    local lettersMainFont = LSM:Fetch("font", Options.CompassCustomMainFont)
    local lettersSecondaryFont = LSM:Fetch("font", Options.CompassCustomSecondaryFont)
    local degreesFont = LSM:Fetch("font", Options.CompassCustomDegreesFont)

    if type(HUD.compassCustom.letters) ~= "table" then
        HUD.compassCustom.letters = {}
    end
    local letters = HUD.compassCustom.letters

    for _, v in pairs(letters) do
        v:Hide()
    end

    for _, side in ipairs({ 1, -1}) do
        for k, v in pairs(directions) do
            letters[k*side] = letters[k*side] or HUD.compassCustom.mask:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            letters[k*side]:SetText(v.letter)
            letters[k*side]:SetJustifyV("TOP")
            letters[k*side]:SetSize(0, 16)
            letters[k*side]:SetParent(HUD.compassCustom.mask)
            letters[k*side]:ClearAllPoints()
            letters[k*side].data = v

            if v.main then
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomMainPosition)
                letters[k*side]:SetFont(lettersMainFont, Options.CompassCustomMainSize * scale, Options.CompassCustomMainFlags)
                letters[k*side]:SetTextColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                letters[k*side]:SetShown(Options.CompassCustomMainVisible)
            else
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomSecondaryPosition)
                letters[k*side]:SetFont(lettersSecondaryFont, Options.CompassCustomSecondarySize * scale, Options.CompassCustomSecondaryFlags)
                letters[k*side]:SetTextColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
                letters[k*side]:SetShown(Options.CompassCustomSecondaryVisible)
            end
        end
    end

    if type(HUD.compassCustom.degrees) ~= "table" then
        HUD.compassCustom.degrees = {}
    end
    local degrees = HUD.compassCustom.degrees

    for _, v in pairs(degrees) do
        v:Hide()
        v.span = false
    end

    for i = -360, 360, Options.CompassCustomDegreesSpan do
        if math.abs(i) ~= 360 then
            degrees[i] = degrees[i] or HUD.compassCustom.mask:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            degrees[i]:SetText(((i > 0) and i) or (360 + i))
            degrees[i]:SetJustifyV("TOP")
            degrees[i]:SetSize(0, 16)
            degrees[i]:ClearAllPoints()
            degrees[i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth + 1, Options.CompassCustomDegreesPosition)
            degrees[i]:SetParent(HUD.compassCustom.mask)
            degrees[i]:SetFont(degreesFont, Options.CompassCustomDegreesSize * scale, Options.CompassCustomDegreesFlags)
            degrees[i]:SetTextColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
            degrees[i]:SetShown(Options.CompassCustomDegreesVisible)
            degrees[i].span = true
            if letters[i] and letters[i]:IsShown() then
                degrees[i]:Hide()
            end
        end
    end

    if type(HUD.compassCustom.ticks) ~= "table" then
        HUD.compassCustom.ticks = {}
    end
    local ticks = HUD.compassCustom.ticks

    for _, v in pairs(ticks) do
        v:Hide()
    end

    for _, tickPosition in ipairs({"TOP", "BOTTOM"}) do
        for i, v in pairs(letters) do
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(nil, "OVERLAY")
            ticks[tickPosition .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
            if v:IsShown() then
                if v.data.main then
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                else
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
                end
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
            ticks[tickPosition .. i]:SetSize(2, 2)
            ticks[tickPosition .. i]:SetPoint(tickPosition, HUD.compassCustom.mask, tickPosition, i / 720 * textureWidth, -2)
            ticks[tickPosition .. i]:SetParent(HUD.compassCustom.mask)
            if Options.CompassCustomTicksForce then
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
        end

        for i, v in pairs(degrees) do
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(nil, "OVERLAY")
            ticks[tickPosition .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
            if not letters[i] or not letters[i]:IsShown() then
                ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
                ticks[tickPosition .. i]:SetShown(v:IsShown() and ((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH")))
                ticks[tickPosition .. i]:SetSize(2, 4)
            end
            ticks[tickPosition .. i]:SetPoint(tickPosition, HUD.compassCustom.mask, tickPosition, i / 720 * textureWidth, -2)
            ticks[tickPosition .. i]:SetParent(HUD.compassCustom.mask)
            if Options.CompassCustomTicksForce and v.span then
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
        end
    end

    -- heading frame
    HUD.heading = HUD.heading or CreateFrame('Frame', nil, HUD, "BackdropTemplate")
    HUD.heading:SetSize(textureHeight * 2 * Options.HeadingWidth, textureHeight)
    HUD.heading:SetPoint('CENTER', HUD, 'CENTER', 0, Options.HeadingPosition)
    HUD.heading:SetClipsChildren(true)

    HUD.heading:SetScale(Options.HeadingScale)
	HUD.heading:SetFrameLevel(Options.Level+Options.HeadingStrataLevel)
    HUD.heading:SetAlpha(Options.HeadingTransparency)

	local headingBackdrop = {
		bgFile = LSM:Fetch("background", Options.HeadingBackground),
		edgeFile = LSM:Fetch("border", Options.HeadingBorder),
		edgeSize = Options.HeadingBorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	HUD.heading:SetBackdrop(headingBackdrop)
    HUD.heading:SetBackdropColor(Options.HeadingBackgroundColor.r,Options.HeadingBackgroundColor.g, Options.HeadingBackgroundColor.b, Options.HeadingBackgroundColor.a)
	HUD.heading:SetBackdropBorderColor(Options.HeadingBorderColor.r,Options.HeadingBorderColor.g, Options.HeadingBorderColor.b, Options.HeadingBorderColor.a)

    local headingFont = LSM:Fetch("font", Options.HeadingFont)
    HUD.heading.text = HUD.heading.text or HUD.heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    HUD.heading.text:SetJustifyV("MIDDLE")
    HUD.heading.text:SetJustifyH("CENTER")
    HUD.heading.text:SetParent(HUD.heading)
    HUD.heading.text:ClearAllPoints()
    HUD.heading.text:SetPoint("CENTER", HUD.heading, "CENTER", Options.HeadingFontPositionH, Options.HeadingFontPositionV)
    HUD.heading.text:SetFont(headingFont, Options.HeadingFontSize * scale, Options.HeadingFontFlags)
    HUD.heading.text:SetTextColor(Options.HeadingFontColor.r, Options.HeadingFontColor.g, Options.HeadingFontColor.b, Options.HeadingFontColor.a)

    HUD.compassTexture:SetShown(not Options.UseCustomCompass)
    HUD.compassCustom:SetShown(Options.UseCustomCompass)
    HUD.heading:SetShown(Options.HeadingEnabled)

    -- pointers
    HUD.pointers = HUD.pointers or {}

    -- groups
    HUD.groups = HUD.groups or {}
end

local function setTime(frame, distance, speed)
    if speed and speed > 0 then
        local eta = math.abs(distance / speed)
        local minutes = math.floor(eta / 60)
        local seconds = math.floor(eta % 60)
        local tta = string.format("%d:%02.f", minutes, seconds)
        frame.TimeText:SetText(tta)
    else
        frame.TimeText:SetText("***")
    end
end

local function questPointerSetTexts(frame, dt)
    if player.inInstance then return end
    frame.elapsed = frame.elapsed + dt
    if frame.distanceHidden and frame.timeHidden then return end
    frame.distance = HBD:GetWorldDistance(frame.instance, player.x, player.y, frame.x, frame.y)
    if not frame.distance then
        frame:Hide()
        return
    end
    if not frame.minDistance or frame.minDistance > frame.distance then
        frame.minDistance = frame.distance
    end
    frame:Show()
    frame.DistanceText:SetText(BreakUpLargeNumbers(frame.distance))
    if frame.timeHidden then return end
    if frame.elapsed >= 1 then
        frame.elapsed = 0
        local speed = GetUnitSpeed("player") or GetUnitSpeed("vehicle")
        if not speed or speed == 0 then -- delta
            frame.oldDistance = frame.distance
            C_Timer.After(1, function()
                local currentDistance = HBD:GetWorldDistance(frame.instance, player.x, player.y, frame.x, frame.y)
                if currentDistance then
                    speed = math.abs(currentDistance - frame.oldDistance)
                else
                    speed = 0
                end
                setTime(frame, currentDistance, speed)
            end)
        else
            setTime(frame, frame.distance, speed)
        end
    end
end

local function getPointerCategory(questID, questType)
    local category = questType or questUnknown
    if questType < 0 then
        return questPointers[category] and category or questUnknown
    end
    category = GetQuestClassification(questID) or questUnknown
    if category == Enum.QuestClassification.Recurring then
        local questIndex = GetLogIndexForQuestID(questID)
        if not questIndex then return questUnknown end
        local questInfo = GetQuestInfo(questIndex)
        category = (questInfo and questInfo.frequency + 100) or category
    end
    return category
end

local function getPointerType(questID, questType)
    local questClassification = getPointerCategory(questID, questType)
    return questPointerIdent .. (questPointers[questClassification] and questClassification or questUnknown)
end

local function isTask(questID)
    local classification = GetQuestClassification(questID)
    return
        (classification == Enum.QuestClassification.BonusObjective)
        or (classification == Enum.QuestClassification.WorldQuest)
end

local function getWQicon(questID)
    local icon
    RequestPreloadRewardData(questID)
    local reward = GetQuestRewardCurrencyInfo(questID, 1, false)
    local _, itemTexture = GetQuestLogRewardInfo(1, questID)
    local gold = GetQuestLogRewardMoney(questID)
    if gold > 0 then
        icon = [[Interface\Icons\INV_Misc_Coin_02]]
    else
        icon = itemTexture or (reward and reward.texture)
    end
    return icon
end

local function retextureSuperTrackedFrame(questPointer)
    STtexture.questID = questPointer.questID
    STtexture.pointer = nil
    STtexture.atlas = nil

    local questPoint = questPointsTable[STtexture.questID]
    local moreArgs = questPoint.moreArgs
    if not questPoint or not questPoint.frame then return end

    local options = Options.Pointers[questPoint.frame.pointerType]
    if not (options and (options.stRetexture or (moreArgs and moreArgs.stRetexture)) and IsSuperTrackingAnything()) then
        -- Clean up if not retexturing
        if STtexture.mask then
            SuperTrackedFrame.Icon:RemoveMaskTexture(STtexture.mask)
            STtexture.mask:Hide()
        end
        if STtexture.border then
            STtexture.border:Hide()
        end
        return
    end

    -- === Ensure mask and border exist ===
    if not STtexture.iconSize then
        STtexture.iconSize = SuperTrackedFrame.Icon:GetWidth()
    end

    if not STtexture.mask then
        STtexture.mask = SuperTrackedFrame:CreateMaskTexture()
        STtexture.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        STtexture.mask:SetAllPoints(SuperTrackedFrame.Icon)
        STtexture.mask:Hide()
    end

    if not STtexture.border then
        STtexture.border = SuperTrackedFrame:CreateTexture(nil, "OVERLAY", nil, 1)
        STtexture.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
        STtexture.border:SetAllPoints(SuperTrackedFrame.Icon)
        STtexture.border:Hide()
    end

    -- === Determine texture or atlas ===
    if questPoint.texture and options.worldmapTexture then
        STtexture.pointer = questPoint.texture
    elseif questPoint.atlasName and (options.worldmapTexture or (moreArgs and moreArgs.worldmapTexture)) then
        STtexture.atlas = questPoint.atlasName
    else
        STtexture.atlas = questPoint.completed and options.atlasAltID or options.atlasID
    end

    -- === Apply or remove mask/border ===
    STtexture.scale = (questPoint.completed and options.textureAltScale or options.textureScale) * (questPointer.scaleMultiplier or 1)
    if questPoint.circle then
        SuperTrackedFrame.Icon:AddMaskTexture(STtexture.mask)
        STtexture.mask:SetScale(STtexture.scale or 1)
        STtexture.border:SetScale(STtexture.scale or 1)
        STtexture.mask:Show()
        STtexture.border:Show()
    else
        SuperTrackedFrame.Icon:RemoveMaskTexture(STtexture.mask)
        STtexture.mask:Hide()
        STtexture.border:Hide()
    end
end

local function updateQuestIcon(questPointer)
    local scale = Options.Scale * Options.VerticalScale
    local options = Options.Pointers[questPointer.pointerType]
    local pointer = questPointsTable[questPointer.questID]
    local completed = pointer.completed
    questPointer.position = options.pointerOffset * textureHeight * -1
    local size = textureHeight * (completed and options.textureAltScale or options.textureScale) * (questPointer.scaleMultiplier or 1.5)
    questPointer:SetSize(size, size)

    local gameFontNormal = { fontColor = {}}
    gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags = GameFontNormal:GetFont()
    gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a = GameFontNormal:GetTextColor()

    if options.distanceCustomFont then
        local font = LSM:Fetch("font", options.distanceFont)
        questPointer.DistanceText:SetFont(font, options.distanceFontSize * scale, options.distanceFontFlags)
        questPointer.DistanceText:SetTextColor(options.distanceFontColor.r, options.distanceFontColor.g, options.distanceFontColor.b, options.distanceFontColor.a)
    else
        questPointer.DistanceText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        questPointer.DistanceText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if options.ttaCustomFont then
        local font = LSM:Fetch("font", options.ttaFont)
        questPointer.TimeText:SetFont(font, options.ttaFontSize * scale, options.ttaFontFlags)
        questPointer.TimeText:SetTextColor(options.ttaFontColor.r, options.ttaFontColor.g, options.ttaFontColor.b, options.ttaFontColor.a)
    else
        questPointer.TimeText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        questPointer.TimeText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if options.questCustomFont then
        local font = LSM:Fetch("font", options.questFont)
        questPointer.QuestText:SetFont(font, options.questFontSize * scale, options.questFontFlags)
        questPointer.QuestText:SetTextColor(options.questFontColor.r, options.questFontColor.g, options.questFontColor.b, options.questFontColor.a)
    else
        questPointer.QuestText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        questPointer.QuestText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end

    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = -options.distanceOffset + 2
    local timeTextPosition = - ((options.showDistance and (options.distanceFontSize * 1.2 * scale)) or 0) - options.ttaOffset + 2
    local questTextPosition = - ((options.showDistance and (options.distanceFontSize * 1.2 * scale)) or 0) - ((options.showTTA and (options.ttaFontSize * 1.2 * scale)) or 0) - options.questOffset + 4
    local cropX, cropY = pointer.crop / textureHeight, pointer.crop / textureHeight
    questPointer.texture:SetTexCoord(cropX, 1 - cropX, cropY, 1 - cropY)
    questPointer.flipped = false
    if questPointer.position > 0 then
        questPointer.flipped = true
        if (completed and (options.textureAltRotate == 1)) or (not completed and (options.textureRotate == 1)) then
            questPointer.texture:SetTexCoord(cropX, 1 - cropX, 1 - cropY, cropY)
        end
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((options.showTTA and (options.ttaFontSize * 1.2 * scale)) or 0) + options.distanceOffset - 12
        timeTextPosition = options.ttaOffset - 12
        local questText = pointer.text
        if questText and questText:match("%S") and options.showQuest then
            questTextPosition = options.questOffset - 6
            timeTextPosition = timeTextPosition + (options.questFontSize * 1.2 * scale)
            distanceTextPosition = distanceTextPosition + (options.questFontSize * 1.2 * scale)
        end
    end

    questPointer.DistanceText:ClearAllPoints()
    questPointer.DistanceText:SetPoint(point, questPointer, relativePoint, 0, distanceTextPosition)
    questPointer.TimeText:ClearAllPoints()
    questPointer.TimeText:SetPoint(point, questPointer, relativePoint, 0, timeTextPosition)
    questPointer.QuestText:ClearAllPoints()
    questPointer.QuestText:SetPoint(point, questPointer, relativePoint, 0, questTextPosition)

    questPointer.DistanceText:SetShown(options.showDistance)
    questPointer.TimeText:SetShown(options.showTTA)
    questPointer.QuestText:SetShown(options.showQuest)

    if pointer.circle then
        questPointer.texture:AddMaskTexture(questPointer.mask)
        questPointer.mask:Show()
        questPointer.border:Show()
    else
        questPointer.texture:RemoveMaskTexture(questPointer.mask)
        questPointer.mask:Hide()
        questPointer.border:Hide()
    end

    retextureSuperTrackedFrame(questPointer)
end

local function createQuestIcon(questID, questType)
    local pointerType = getPointerType(questID, questType)
    if not Options.Pointers[pointerType] then
        return
    end
    if not Options.Pointers[pointerType].enabled then return end
    local questPointer = CreateFrame("FRAME", nil, HUD)
    HUD.pointers[questID] = questPointer
	questPointer.questID = questID
    questPointer.pointerType = pointerType
	questPointer:SetSize(textureHeight, textureHeight)
	questPointer:SetPoint("CENTER");
	questPointer:Hide()

    if questID > 0 then
        questPointer:SetScript("OnEvent", function(self, event)
            if event == "QUEST_LOG_UPDATE" then
                if not select(2,GetQuestPOIInfo(self.questID)) then
                    questPointer:Hide()
                end
            end
        end)
        questPointer:RegisterEvent("QUEST_LOG_UPDATE")
    end

    questPointer.texture = questPointer:CreateTexture(nil, "ARTWORK")
    questPointer.texture:SetAllPoints(questPointer)
    questPointer.texture:SetAtlas(Options.Pointers[pointerType].atlasID)
    questPointer.mask = questPointer:CreateMaskTexture()
    questPointer.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    questPointer.mask:SetAllPoints(questPointer.texture)
    questPointer.mask:Hide()
    questPointer.border = questPointer:CreateTexture(nil, "OVERLAY", nil, 1)
    questPointer.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
    questPointer.border:SetAllPoints(questPointer.texture)
    questPointer.border:Hide()

    questPointer.arrowTexture = questPointer:CreateTexture(nil, "BACKGROUND")
    questPointer.arrowTexture:SetAllPoints(questPointer)
	questPointer.arrowTexture:SetAtlas(Options.StayAtlasID)
    questPointer.arrowTexture:Hide()

    questPointer.DistanceText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.DistanceText:SetJustifyV("TOP")
    questPointer.DistanceText:SetSize(0, 16)
    questPointer.DistanceText:SetParent(questPointer)

    questPointer.TimeText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.TimeText:SetJustifyV("TOP")
    questPointer.TimeText:SetSize(0, 16)
    questPointer.TimeText:SetParent(questPointer)

    questPointer.QuestText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.QuestText:SetJustifyV("TOP")
    questPointer.QuestText:SetSize(0, 16)
    questPointer.QuestText:SetParent(questPointer)

    updateQuestIcon(questPointer)

    questPointer.elapsed = 0
    questPointer:SetScript("OnUpdate", questPointerSetTexts)
	return questPointer
end

local function setQuestsIcons()
    local vignetteGUID = GetSuperTrackedVignette()
    local supertrackingType = GetHighestPrioritySuperTrackingType()
    local isTrackingUserWaypoint = (supertrackingType == Enum.SuperTrackingType.UserWaypoint)
    local trackingTypes = {[Enum.SuperTrackingType.MapPin] = true, [Enum.SuperTrackingType.Vignette] = true}
    local isTrackingPOI = trackingTypes[supertrackingType]
    local trackedQuest = GetSuperTrackedQuestID()
    local _, _, playerInstance = HBD:GetPlayerWorldPosition()
    if trackedQuest and isTask(trackedQuest) and not IsTaskQuestActive(trackedQuest) then
        trackedQuest = 0
    end
	for questID, quest in pairs(questPointsTable) do
        local questHide = false
        if quest.moreArgs and quest.moreArgs.vignetteGUID and quest.moreArgs.vignetteGUID == vignetteGUID and quest.frame and quest.frame.minDistance and quest.frame.minDistance < 10 then
            questHide = true
            ClearAllSuperTracked()
        end
		if not questHide and ((not Options.HideFar or (quest.instance == playerInstance)) and ((questID == trackedQuest) or (questID == mapPin and isTrackingUserWaypoint) or (questID == selectedPin and isTrackingPOI) or (questID == tomTom and quest.track))) then
			local angle = getPlayerFacingAngle(questID)
			if quest.frame and angle then
                if Options.Pointers[quest.frame.pointerType].enabled then
                    local visible = math.rad(Options.Degrees)/2
                    local arrowShow = false
                    local pointerRotate = 0
                    if angle < visible and angle > -visible then
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, quest.frame.position)
                        quest.frame:Show()
                    elseif Options.PointerStay then
                        local side = math.abs(angle)/angle
                        local option = Options.Pointers[quest.frame.pointerType]
                        if (quest.completed and (option.textureAltRotate == 1)) or (not quest.completed and (option.textureRotate == 1)) and not quest.overrideRotation then
                            pointerRotate = (PI/2 * side * ((quest.frame.flipped and 1) or -1))
                        elseif ((quest.completed and (option.textureAltRotate ~= 1)) or (not quest.completed and (option.textureRotate ~= 1)) or quest.overrideRotation) and Options.StayArrow then
                            local width, height = quest.frame.texture:GetSize()
                            local offsetX = side * (width * 0.75 + 3)
                            quest.frame.arrowTexture:ClearAllPoints()
                            quest.frame.arrowTexture:SetPoint("CENTER", quest.frame, "CENTER", offsetX, 0)
                            quest.frame.arrowTexture:SetSize(width, height)
                            quest.frame.arrowTexture:SetScale(0.75)
                            quest.frame.arrowTexture:SetRotation(PI/2 * side * -1)
                            arrowShow = true
                        end
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * side * visible, quest.frame.position)
                        quest.frame:Show()
                    else
                        quest.frame:Hide()
                    end
                    quest.frame.arrowTexture:SetShown(arrowShow)
                    quest.frame.texture:SetRotation(pointerRotate)
                else
                    quest.frame:Hide()
                end
            end
        else
            if quest.frame then
			    quest.frame:Hide()
            end
		end
	end

    if STtexture.pointer or STtexture.atlas then
        if STtexture.pointer then
            SuperTrackedFrame.Icon:SetTexture(STtexture.pointer)
        elseif STtexture.atlas then
            SuperTrackedFrame.Icon:SetAtlas(STtexture.atlas)
        end

        SuperTrackedFrame.Icon:SetSize(STtexture.iconSize, STtexture.iconSize)
        SuperTrackedFrame.Icon:SetScale(STtexture.scale or 1)
    end


end

local function createGroupMemberIcon(unit)
    local groupPointer = CreateFrame("FRAME", nil, HUD)
    HUD.groups[unit] = groupPointer
	groupPointer:SetSize(textureHeight, textureHeight)
	groupPointer:SetPoint("CENTER");
	groupPointer.texture = groupPointer:CreateTexture(nil, "ARTWORK")
	groupPointer.texture:SetAllPoints(groupPointer)
	groupPointer.texture:SetAtlas(Options.GroupTexture)
	groupPointer:Hide()
    groupPointer.Name = CreateFrame('Frame', nil, HUD, "BackdropTemplate")
    groupPointer.Name:SetParent(groupPointer)
    groupPointer.Name.text = groupPointer.Name:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupPointer.Name.text:SetJustifyV("MIDDLE")
    groupPointer.Name.text:SetJustifyH("CENTER")
    groupPointer.Name.text:ClearAllPoints()
    groupPointer.Name.text:SetPoint("CENTER", groupPointer.Name, "CENTER", 0, 0)
    groupPointer.Name.text:SetParent(groupPointer.Name)
	return groupPointer
end

local function updateGroupMemberTexts(unit)
    if not groupPointsTable or not groupPointsTable[unit] then return end
    local v = groupPointsTable[unit]
    local scale = Options.Scale * Options.VerticalScale
    local differentZone = player.instance ~= v.instance
    local flipped = (differentZone and Options.GroupZoneOffset > 0) or (not differentZone and Options.GroupOffset > 0)
    v.frame.Name:ClearAllPoints()
    v.frame.Name:SetPoint(flipped and "BOTTOM" or "TOP", v.frame, flipped and "TOP" or "BOTTOM", 0, v.type == "party" and Options.GroupPartyNameOffset or Options.GroupRaidNameOffset)
    local gameFontNormal = { fontColor = {}}
    gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags = GameFontNormal:GetFont()
    gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a = GameFontNormal:GetTextColor()
    v.frame.Name.text:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
    if v.type == "party" and Options.GroupPartyNameCustomFont then
        local font = LSM:Fetch("font", Options.GroupPartyNameFont)
        v.frame.Name.text:SetFont(font, Options.GroupPartyNameFontSize * scale, Options.GroupPartyNameFontFlags)
    end
    if v.type == "raid" and Options.GroupRaidNameCustomFont then
        local font = LSM:Fetch("font", Options.GroupRaidNameFont)
        v.frame.Name.text:SetFont(font, Options.GroupRaidNameFontSize * scale, Options.GroupRaidNameFontFlags)
    end
    local nameTextColor = (v.type == "raid") and Options.GroupRaidNameFontColor or Options.GroupPartyNameFontColor
    if ((v.type == "party" and Options.GroupPartyNameClassColor) or (v.type == "raid" and Options.GroupRaidNameClassColor)) and v.classColor then
        v.frame.Name.text:SetTextColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
        v.frame.Name.text:SetTextColor(nameTextColor.r, nameTextColor.g, nameTextColor.b, nameTextColor.a)
    end
	local nameBackdrop = {
		bgFile = LSM:Fetch("background", (v.type == "raid") and Options.GroupRaidNameBackground or Options.GroupPartyNameBackground),
		edgeFile = LSM:Fetch("border", (v.type == "raid") and Options.GroupRaidNameBorder or Options.GroupPartyNameBorder),
		edgeSize = (v.type == "raid") and Options.GroupRaidNameBorderThickness or Options.GroupPartyNameBorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	v.frame.Name:SetBackdrop(nameBackdrop)
    local nameBackgroundColor = (v.type == "raid") and Options.GroupRaidNameBackgroundColor or Options.GroupPartyNameBackgroundColor
    if ((v.type == "party" and Options.GroupPartyNameBackgroundClass) or (v.type == "raid" and Options.GroupRaidNameBackgroundClass)) and v.classColor then
        v.frame.Name:SetBackdropColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
        v.frame.Name:SetBackdropColor(nameBackgroundColor.r, nameBackgroundColor.g, nameBackgroundColor.b, nameBackgroundColor.a)
    end
    local nameBorderColor = (v.type == "raid") and Options.GroupRaidNameBorderColor or Options.GroupPartyNameBorderColor
    if ((v.type == "party" and Options.GroupPartyNameBorderClass) or (v.type == "raid" and Options.GroupRaidNameBorderClass)) and v.classColor then
        v.frame.Name:SetBackdropBorderColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
	    v.frame.Name:SetBackdropBorderColor(nameBorderColor.r, nameBorderColor.g, nameBorderColor.b, nameBorderColor.a)
    end
end

local function updateGroupMember(unit)
    if not groupPointsTable[unit] then
        groupPointsTable[unit] = { type = string.gsub(unit, "%d+$", "")}
    end
    local wasActive = groupPointsTable[unit].active
    local wasClass = groupPointsTable[unit].className
    groupPointsTable[unit].active = false
    if not groupPointsTable[unit].frame then
        groupPointsTable[unit].frame = createGroupMemberIcon(unit)
        wasClass = "NONE"
    end
    if UnitExists(unit) then
        local x, y, instance = HBD:GetUnitWorldPosition(unit)
        local className, classFile = UnitClass(unit)

        if className then
            groupPointsTable[unit].className = className
            groupPointsTable[unit].classColor = GetClassColor(classFile)
        else
            groupPointsTable[unit].className = nil
            groupPointsTable[unit].classColor = type == "party" and Options.GroupPartyNameFontColor or Options.GroupRaidNameFontColor
        end
        if x and y and instance then
            groupPointsTable[unit].x = x
            groupPointsTable[unit].y = y
            groupPointsTable[unit].instance = instance
            groupPointsTable[unit].name, groupPointsTable[unit].realm = UnitName(unit)
            groupPointsTable[unit].realm = groupPointsTable[unit].realm or player.realm
            groupPointsTable[unit].active = true
            if player.x and player.y then
                groupPointsTable[unit].distance = HBD:GetWorldDistance(instance, player.x, player.y, x, y)
            end
        end
    end
    if groupPointsTable[unit].name == player.name and groupPointsTable[unit].realm == player.realm then
        groupPointsTable[unit].active = false
    end
    if not wasClass or wasClass ~= groupPointsTable[unit].className then
        updateGroupMemberTexts(unit)
    end
    if wasActive and not groupPointsTable[unit].active then
        groupPointsTable[unit].frame:Hide()
    end
end

local function updateGroupTexts()
    for k, _ in pairs(groupPointsTable) do
        updateGroupMemberTexts(k)
    end
end

local function setGroupStrataLevels()
    local activeUnits = {}
    for unit, data in pairs(groupPointsTable) do
        if data.active and data.distance then
            table.insert(activeUnits, { unit = unit, distance = data.distance })
        end
    end
    table.sort(activeUnits, function(a, b)
        return a.distance > b.distance
    end)
    for rank, item in ipairs(activeUnits) do
        groupPointsTable[item.unit].strataLevel = rank+1
    end
end

local function setGroupIcons()
    if not player.groupType or player.groupType == "none" then return end
    if player.groupType == "party" and not Options.GroupShowParty then return end
    if player.groupType == "raid" and not Options.GroupShowRaid then return end
    if groupThrottle and groupThrottle >= Options.GroupInterval then
        groupThrottle = 0
        local groupSize = player.groupType == "raid" and 40 or player.groupType == "party" and 4
        for i = 1,groupSize do
            updateGroupMember(player.groupType..i)
        end
    end
    for _, v in pairs(groupPointsTable) do
        if v and v.frame then
            local shown = false
            local markerRotate = 0
            local differentZone = player.instance ~= v.instance
            local size = textureHeight * (differentZone and Options.GroupZoneScale or Options.GroupScale)
            local flipped = (differentZone and Options.GroupZoneOffset > 0 and Options.GroupZoneRotate == 1) or (not differentZone and Options.GroupOffset > 0 and Options.GroupRotate == 1)
            if v.active and player.angle then
                if v.x and v.y and v.instance then
                    local angle = player.angle - HBD:GetWorldVector(v.instance, player.x, player.y, v.x, v.y)
                    if angle < 0 then angle = angle + (2 * PI) end
                    if angle > PI then angle = angle - (2 * PI) end
                    if angle then
                        local visible = math.rad(Options.Degrees)/2
                        if angle < visible and angle > -visible then
                            v.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, differentZone and Options.GroupZoneOffset or Options.GroupOffset)
                            shown = true
                        elseif Options.GroupStay then
                            local side = math.abs(angle)/angle
                            if (differentZone and (Options.GroupZoneRotate == 1)) or (not differentZone and (Options.GroupRotate == 1)) then
                                markerRotate = PI/2 * side * ((flipped and 1) or -1)
                            end
                            v.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * side * visible, differentZone and Options.GroupZoneOffset or Options.GroupOffset)
                            shown = true
                        end
                    end
                end
            end
            shown = shown and (Options.GroupShowAllZones or not differentZone)
            v.frame:SetShown(shown)
            if shown then
                v.frame:SetSize(size, size)
                v.frame:SetAlpha(differentZone and Options.GroupZoneTransparency or 1)
                v.frame:SetFrameLevel(Options.Level + (v.strataLevel or 0) + ((not differentZone and 50) or 0))
                v.frame.texture:SetTexCoord(0, 1, flipped and 1 or 0, flipped and 0 or 1)
                v.frame.texture:SetAtlas(differentZone and Options.GroupZoneTexture or Options.GroupTexture)
                v.frame.texture:SetDesaturated(differentZone and Options.GroupZoneDesaturate)
                v.frame.texture:SetRotation(markerRotate)
                v.frame.Name.text:SetText(v.name)
                local sizeX, sizeY = v.frame.Name.text:GetSize()
                sizeX = sizeX or textureHeight
                sizeY = sizeY or textureHeight
                v.frame.Name:SetSize(sizeX + 4, sizeY + 4)
                v.frame.Name:SetShown((player.groupType == "party" and Options.GroupPartyNameShow) or (player.groupType == "raid" and Options.GroupRaidNameShow))
            end
        end
    end
    setGroupStrataLevels()
end

local function updateGatherMateNode(node)
    local scale = Options.Scale * Options.VerticalScale * Options.GatherMateScale
    node.frame:SetSize(textureHeight * Options.GatherMateScale, textureHeight * Options.GatherMateScale)
    local gameFontNormal = { fontColor = {}}
    gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags = GameFontNormal:GetFont()
    gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a = GameFontNormal:GetTextColor()

    if Options.GatherMateDistanceCustomFont then
        local font = LSM:Fetch("font", Options.GatherMateDistanceFont)
        node.frame.DistanceText:SetFont(font, Options.GatherMateDistanceFontSize * scale, Options.GatherMateDistanceFontFlags)
        node.frame.DistanceText:SetTextColor(Options.GatherMateDistanceFontColor.r, Options.GatherMateDistanceFontColor.g, Options.GatherMateDistanceFontColor.b, Options.GatherMateDistanceFontColor.a)
    else
        node.frame.DistanceText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        node.frame.DistanceText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if Options.GatherMateTtaCustomFont then
        local font = LSM:Fetch("font", Options.GatherMateTtaFont)
        node.frame.TimeText:SetFont(font, Options.GatherMateTtaFontSize * scale, Options.GatherMateTtaFontFlags)
        node.frame.TimeText:SetTextColor(Options.GatherMateTtaFontColor.r, Options.GatherMateTtaFontColor.g, Options.GatherMateTtaFontColor.b, Options.GatherMateTtaFontColor.a)
    else
        node.frame.TimeText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        node.frame.TimeText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if Options.GatherMateTitleCustomFont then
        local font = LSM:Fetch("font", Options.GatherMateTitleFont)
        node.frame.Title:SetFont(font, Options.GatherMateTitleFontSize * scale, Options.GatherMateTitleFontFlags)
        node.frame.Title:SetTextColor(Options.GatherMateTitleFontColor.r, Options.GatherMateTitleFontColor.g, Options.GatherMateTitleFontColor.b, Options.GatherMateTitleFontColor.a)
    else
        node.frame.Title:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        node.frame.Title:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end

    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = Options.GatherMateDistanceOffset
    local timeTextPosition = - ((Options.GatherMateShowDistance and (Options.GatherMateDistanceFontSize * 1.2 * scale)) or 0) - Options.GatherMateTtaOffset
    local titlePosition = - ((Options.GatherMateShowDistance and (Options.GatherMateDistanceFontSize * 1.2 * scale)) or 0) - ((Options.GatherMateShowTTA and (Options.GatherMateTtaFontSize * 1.2 * scale)) or 0) - Options.GatherMateTitleOffset
    node.flipped = false
    if Options.GatherMateOffset > 0 then
        node.flipped = true
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((Options.GatherMateShowTTA and (Options.GatherMateTtaFontSize * 1.2 * scale)) or 0) + Options.GatherMateDistanceOffset - 4
        timeTextPosition = Options.GatherMateTtaOffset - 4
        if Options.GatherMateShowTitle then
            titlePosition = Options.GatherMateTitleOffset - 4
            timeTextPosition = timeTextPosition + (Options.GatherMateTitleFontSize * 1.2 * scale) - 4
            distanceTextPosition = distanceTextPosition + (Options.GatherMateTitleFontSize * 1.2 * scale) - 4
        end
    end

    node.frame.DistanceText:ClearAllPoints()
    node.frame.DistanceText:SetPoint(point, node.frame, relativePoint, 0, distanceTextPosition)
    node.frame.TimeText:ClearAllPoints()
    node.frame.TimeText:SetPoint(point, node.frame, relativePoint, 0, timeTextPosition)
    node.frame.Title:ClearAllPoints()
    node.frame.Title:SetPoint(point, node.frame, relativePoint, 0, titlePosition)

    node.frame.DistanceText:SetShown(Options.GatherMateShowDistance)
    node.frame.TimeText:SetShown(Options.GatherMateShowTTA)
    node.frame.Title:SetShown(Options.GatherMateShowTitle)
end

local function updateGatherMate()
    for _, nodes in pairs(gatherMatePointTable) do
        for _, node in pairs(nodes) do
            if not Options.GatherMateEnabled then
                node.visible = false
                if node.frame then
                    node.frame:Hide()
                end
            end
            if node.frame then
                updateGatherMateNode(node)
            end
        end
    end
end

local function createGatherMateNode(nodeID, nodeType, table)
    local gatherMateNode =  table.frame or CreateFrame("FRAME", nil, HUD)
	gatherMateNode:SetSize(textureHeight, textureHeight)
	gatherMateNode:SetPoint("CENTER");
	gatherMateNode.texture = gatherMateNode:CreateTexture(nil, "ARTWORK")
	gatherMateNode.texture:SetAllPoints(gatherMateNode)
	gatherMateNode.texture:SetTexture(GatherMate2.nodeTextures[nodeType][nodeID])
	gatherMateNode:Hide()
    gatherMateNode.DistanceText = gatherMateNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    gatherMateNode.DistanceText:SetJustifyV("TOP")
    gatherMateNode.DistanceText:SetSize(0, 16)
    gatherMateNode.DistanceText:SetParent(gatherMateNode)
    gatherMateNode.TimeText = gatherMateNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    gatherMateNode.TimeText:SetJustifyV("TOP")
    gatherMateNode.TimeText:SetSize(0, 16)
    gatherMateNode.TimeText:SetParent(gatherMateNode)
    gatherMateNode.Title = gatherMateNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    gatherMateNode.Title:SetJustifyV("TOP")
    gatherMateNode.Title:SetSize(0, 16)
    gatherMateNode.Title:SetParent(gatherMateNode)
    gatherMateNode.Title:SetText(GatherMate2:GetNameForNode(nodeType, nodeID))
    gatherMateNode.type = "GatherMate"
    gatherMateNode.instance = table.instance
    gatherMateNode.x = table.x
    gatherMateNode.y = table.y
    gatherMateNode.elapsed = 0
    gatherMateNode:SetScript("OnUpdate", questPointerSetTexts)
	return gatherMateNode
end

local function setGatherMateNodes()
    if not Options.GatherMateEnabled or not GatherMate2 then return end
    if gatherMateThrottle and gatherMateThrottle >= Options.GatherMateInterval then
        gatherMateThrottle = 0
        local x, y = HBD:GetZoneCoordinatesFromWorld(player.x, player.y, player.uiMapID, false)
        if x and y then
            for map, nodes in pairs(gatherMatePointTable) do
                for coord, node in pairs(nodes) do
                    gatherMatePointTable[map][coord].visible = false
                end
            end
            for _, db_type in pairs(GatherMate2.db_types) do
                if GatherMate2.Visible[db_type] then
                    for coord, nodeID in GatherMate2:FindNearbyNode(player.uiMapID, x, y, db_type, Options.GatherMateRadius) do
                        if not gatherMatePointTable[player.uiMapID] then
                            gatherMatePointTable[player.uiMapID] = {}
                        end
                        if not gatherMatePointTable[player.uiMapID][coord] then
                            local xZone, yZone = GatherMate2:DecodeLoc(coord)
                            local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                            gatherMatePointTable[player.uiMapID][coord] = { visible = true, instance = player.uiMapID, x = xWorld, y = yWorld }
                            gatherMatePointTable[player.uiMapID][coord].frame = createGatherMateNode(nodeID, db_type, gatherMatePointTable[player.uiMapID][coord])
                            updateGatherMateNode(gatherMatePointTable[player.uiMapID][coord])
                        end
                        gatherMatePointTable[player.uiMapID][coord].visible = true
                    end
                end
            end
        end
    end
    for _, nodes in pairs(gatherMatePointTable) do
        for _, node in pairs(nodes) do
            local shown = false
            if node.visible and player.angle then
                if node.x and node.y and node.instance then
                    local angle = player.angle - HBD:GetWorldVector(node.instance, player.x, player.y, node.x, node.y)
                    if angle < 0 then angle = angle + (2 * PI) end
                    if angle > PI then angle = angle - (2 * PI) end
                    if angle then
                        local visible = math.rad(Options.Degrees)/2
                        if angle < visible and angle > -visible then
                            node.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, Options.GatherMateOffset)
                            shown = true
                        end
                    end
                end
            end
            node.frame:SetShown(shown)
        end
    end
    HUD.gathermateNodes = gatherMatePointTable
end

local function updatePOITrackNode(poi)
    local scale = Options.Scale * Options.VerticalScale * Options.POITrackScale
    poi.frame:SetSize(textureHeight * Options.POITrackScale * (poi.scale or 1), textureHeight * Options.POITrackScale * (poi.scale or 1))
    local gameFontNormal = { fontColor = {}}
    gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags = GameFontNormal:GetFont()
    gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a = GameFontNormal:GetTextColor()

    if Options.POITrackDistanceCustomFont then
        local font = LSM:Fetch("font", Options.POITrackDistanceFont)
        poi.frame.DistanceText:SetFont(font, Options.POITrackDistanceFontSize * scale, Options.POITrackDistanceFontFlags)
        poi.frame.DistanceText:SetTextColor(Options.POITrackDistanceFontColor.r, Options.POITrackDistanceFontColor.g, Options.POITrackDistanceFontColor.b, Options.POITrackDistanceFontColor.a)
    else
        poi.frame.DistanceText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        poi.frame.DistanceText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if Options.POITrackTtaCustomFont then
        local font = LSM:Fetch("font", Options.POITrackTtaFont)
        poi.frame.TimeText:SetFont(font, Options.POITrackTtaFontSize * scale, Options.POITrackTtaFontFlags)
        poi.frame.TimeText:SetTextColor(Options.POITrackTtaFontColor.r, Options.POITrackTtaFontColor.g, Options.POITrackTtaFontColor.b, Options.POITrackTtaFontColor.a)
    else
        poi.frame.TimeText:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        poi.frame.TimeText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if Options.POITrackTitleCustomFont then
        local font = LSM:Fetch("font", Options.POITrackTitleFont)
        poi.frame.Title:SetFont(font, Options.POITrackTitleFontSize * scale, Options.POITrackTitleFontFlags)
        poi.frame.Title:SetTextColor(Options.POITrackTitleFontColor.r, Options.POITrackTitleFontColor.g, Options.POITrackTitleFontColor.b, Options.POITrackTitleFontColor.a)
    else
        poi.frame.Title:SetFont(gameFontNormal.font, gameFontNormal.fontSize * scale, gameFontNormal.fontFlags)
        poi.frame.Title:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end

    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = Options.POITrackDistanceOffset
    local timeTextPosition = - ((Options.POITrackShowDistance and (Options.POITrackDistanceFontSize * 1.2 * scale)) or 0) - Options.POITrackTtaOffset
    local titlePosition = - ((Options.POITrackShowDistance and (Options.POITrackDistanceFontSize * 1.2 * scale)) or 0) - ((Options.POITrackShowTTA and (Options.POITrackTtaFontSize * 1.2 * scale)) or 0) - Options.POITrackTitleOffset
    poi.flipped = false
    if Options.POITrackOffset > 0 then
        poi.flipped = true
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((Options.POITrackShowTTA and (Options.POITrackTtaFontSize * 1.2 * scale)) or 0) + Options.POITrackDistanceOffset - 4
        timeTextPosition = Options.POITrackTtaOffset - 4
        if Options.POITrackShowTitle then
            titlePosition = Options.POITrackTitleOffset - 4
            timeTextPosition = timeTextPosition + (Options.POITrackTitleFontSize * 1.2 * scale) - 4
            distanceTextPosition = distanceTextPosition + (Options.POITrackTitleFontSize * 1.2 * scale) - 4
        end
    end

    poi.frame.DistanceText:ClearAllPoints()
    poi.frame.DistanceText:SetPoint(point, poi.frame, relativePoint, 0, distanceTextPosition)
    poi.frame.TimeText:ClearAllPoints()
    poi.frame.TimeText:SetPoint(point, poi.frame, relativePoint, 0, timeTextPosition)
    poi.frame.Title:ClearAllPoints()
    poi.frame.Title:SetPoint(point, poi.frame, relativePoint, 0, titlePosition)

    poi.frame.DistanceText:SetShown(Options.POITrackShowDistance)
    poi.frame.TimeText:SetShown(Options.POITrackShowTTA)
    poi.frame.Title:SetShown(Options.POITrackShowTitle)
end

local function updatePoiTrack()
    for _, pois in pairs(poiTrackPointTable) do
        for _, poi in pairs(pois) do
            if not Options.POITrackEnabled then
                poi.visible = false
                if poi.frame then
                    poi.frame:Hide()
                end
            end
            if poi.frame then
                updatePOITrackNode(poi)
            end
        end
    end
end

local function createPOITrackNode(table)
    local poiTrackNode =  table.frame or CreateFrame("FRAME", nil, HUD)
	poiTrackNode:SetSize(textureHeight, textureHeight)
	poiTrackNode:SetPoint("CENTER");
	poiTrackNode.texture = poiTrackNode:CreateTexture(nil, "ARTWORK")
	poiTrackNode.texture:SetAllPoints(poiTrackNode)
    poiTrackNode.texture:SetAtlas(table.atlasName)
    poiTrackNode.texture:SetSize(textureHeight, textureHeight)
    if table.circle then
        poiTrackNode.texture:SetSize(textureHeight, textureHeight)
        poiTrackNode.mask = poiTrackNode:CreateMaskTexture()
        poiTrackNode.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        poiTrackNode.mask:SetAllPoints(poiTrackNode.texture)
        poiTrackNode.texture:AddMaskTexture(poiTrackNode.mask)
        poiTrackNode.border = poiTrackNode:CreateTexture(nil, "OVERLAY", nil, 1)
        poiTrackNode.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
        poiTrackNode.border:SetAllPoints(poiTrackNode.texture)
    end
    poiTrackNode.DistanceText = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    poiTrackNode.DistanceText:SetJustifyV("TOP")
    poiTrackNode.DistanceText:SetSize(0, 16)
    poiTrackNode.DistanceText:SetParent(poiTrackNode)
    poiTrackNode.TimeText = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    poiTrackNode.TimeText:SetJustifyV("TOP")
    poiTrackNode.TimeText:SetSize(0, 16)
    poiTrackNode.TimeText:SetParent(poiTrackNode)
    poiTrackNode.Title = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    poiTrackNode.Title:SetJustifyV("TOP")
    poiTrackNode.Title:SetSize(0, 16)
    poiTrackNode.Title:SetParent(poiTrackNode)
    poiTrackNode.Title:SetText(table.name)
    poiTrackNode.type = "poiTrack"
    poiTrackNode.instance = table.instance
    poiTrackNode.x = table.x
    poiTrackNode.y = table.y
    poiTrackNode.elapsed = 0
    poiTrackNode:SetScript("OnUpdate", questPointerSetTexts)
	return poiTrackNode
end

local function setPOITrackNode(poiID, poiType)

    local id = poiType .. "_" .. poiID
    if not poiTrackPointTable[player.uiMapID][id] then
        local poi = poiCache[poiID] and poiCache[poiID][player.uiMapID] and poiCache[poiID][player.uiMapID].poi or GetAreaPOIInfo(player.uiMapID, poiID)
        poiTrackPointTable[player.uiMapID][id] = poi
        local xZone, yZone = poiTrackPointTable[player.uiMapID][id].position.x, poiTrackPointTable[player.uiMapID][id].position.y
        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
        poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
        poiTrackPointTable[player.uiMapID][id].x = xWorld
        poiTrackPointTable[player.uiMapID][id].y = yWorld
        poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
        poiTrackPointTable[player.uiMapID][id].scale = 1.3
        updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
    end
    return id
end

local function setPOITrackNodes()
    if not Options.POITrackEnabled then return end
    if poiTrackThrottle and poiTrackThrottle >= Options.POITrackInterval then
        if poiTrackCurrentMap ~= player.uiMapID then
            for map, pois in pairs(poiTrackPointTable) do
                if map ~= player.uiMapID then
                    for _, poi in pairs(pois) do
                        if poi.frame then
                            poi.visible = false
                            poi.frame:Hide()
                        end
                    end
                end
            end
            poiTrackCurrentMap = player.uiMapID
        end
        for poiID, _ in pairs(poiTrackPointTable and poiTrackPointTable[player.uiMapID]  or {}) do
            poiTrackPointTable[player.uiMapID][poiID].visible = false
        end
        local x, y = HBD:GetZoneCoordinatesFromWorld(player.x, player.y, player.uiMapID, false)
        if x and y then
            if not poiTrackPointTable[player.uiMapID] then
                poiTrackPointTable[player.uiMapID] = {}
            end

            local mapPOIs = GetAreaPOIForMap(player.uiMapID)
            if (Options.POITrackFilter[poiTypeEnum.PORTAL] or Options.POITrackFilter[poiTypeEnum.OTHER]) and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local id = setPOITrackNode(poiID, poiTypeEnum.OTHER)
                    local poi = poiTrackPointTable[player.uiMapID][id]
                    local startsWithTaxiNode = poi.atlasName:sub(1, #("TaxiNode")) == "TaxiNode"
                    poi.visible = (startsWithTaxiNode and Options.POITrackFilter[poiTypeEnum.PORTAL]) or
                                (not startsWithTaxiNode and Options.POITrackFilter[poiTypeEnum.OTHER])
                end
            end

            mapPOIs = GetDelvesForMap(player.uiMapID)
            if Options.POITrackFilter["Delve"] and  mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local id = setPOITrackNode(poiID, poiTypeEnum.DELVE)
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            mapPOIs = GetEventsForMap(player.uiMapID)
            if Options.POITrackFilter["Event"] and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local id = setPOITrackNode(poiID, poiTypeEnum.EVENT)
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            mapPOIs = GetQuestHubsForMap(player.uiMapID)
            if Options.POITrackFilter["Hub"] and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local id = setPOITrackNode(poiID, poiTypeEnum.HUB)
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            mapPOIs = GetDragonridingRacesForMap(player.uiMapID)
            if Options.POITrackFilter["Race"] and  mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local id = setPOITrackNode(poiID, poiTypeEnum.RACE)
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            local portalPOIs = GetMapLinksForMap(player.uiMapID)
            if (Options.POITrackFilter["Portal"] or Options.POITrackFilter["Link"]) and portalPOIs then
                for _, poi in ipairs(portalPOIs) do
                    local id = "LINK" .. poi.areaPoiID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        poiTrackPointTable[player.uiMapID][id] = poi
                        local xZone, yZone = poiTrackPointTable[player.uiMapID][id].position.x, poiTrackPointTable[player.uiMapID][id].position.y
                        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                        poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
                        poiTrackPointTable[player.uiMapID][id].x = xWorld
                        poiTrackPointTable[player.uiMapID][id].y = yWorld
                        poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
                        poiTrackPointTable[player.uiMapID][id].scale = 1.3
                        updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
                    end
                    local startsWithTaxiNode = poi.atlasName:sub(1, #("TaxiNode")) == "TaxiNode"
                    poiTrackPointTable[player.uiMapID][id].visible = (startsWithTaxiNode and Options.POITrackFilter["Portal"]) or
                        (not startsWithTaxiNode and Options.POITrackFilter["Link"])
                end
            end

            local dungeonEntrances = GetDungeonEntrancesForMap(player.uiMapID)
            if Options.POITrackFilter["Instance"] and dungeonEntrances then
                for _, entrance in ipairs(dungeonEntrances) do
                    local id = "ENTRANCE_" .. entrance.areaPoiID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        poiTrackPointTable[player.uiMapID][id] = entrance
                        local xZone, yZone = poiTrackPointTable[player.uiMapID][id].position.x, poiTrackPointTable[player.uiMapID][id].position.y
                        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                        poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
                        poiTrackPointTable[player.uiMapID][id].x = xWorld
                        poiTrackPointTable[player.uiMapID][id].y = yWorld
                        poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
                        poiTrackPointTable[player.uiMapID][id].scale = 1.3
                        updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
                    end
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            local mapTaxis = GetTaxiNodesForMap(player.uiMapID)
            if Options.POITrackFilter["Taxi"] and mapTaxis then
                for _, taxi in ipairs(mapTaxis) do
                    local id = "TAXI_" .. taxi.nodeID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        poiTrackPointTable[player.uiMapID][id] = taxi
                        local xZone, yZone = poiTrackPointTable[player.uiMapID][id].position.x, poiTrackPointTable[player.uiMapID][id].position.y
                        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                        poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
                        poiTrackPointTable[player.uiMapID][id].x = xWorld
                        poiTrackPointTable[player.uiMapID][id].y = yWorld
                        poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
                        poiTrackPointTable[player.uiMapID][id].scale = 1.2
                        updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
                    end
                    poiTrackPointTable[player.uiMapID][id].visible = true
                end
            end

            local mapWQ = GetWorldQuestsOnMap(player.uiMapID)
            if Options.POITrackWQFilter ~= "None" and mapWQ then
                local trackedWQ = {}
                if Options.POITrackWQFilter == "Tracked" then
                    for i = 1, GetNumWorldQuestWatches() do
                        trackedWQ[GetQuestIDForWorldQuestWatchIndex(i)] = true
                    end
                elseif Options.POITrackWQFilter == "WQTracker" and WorldQuestTrackerAddon then
                    for _, wq in ipairs(WorldQuestTrackerAddon.QuestTrackList or {}) do
                        trackedWQ[wq.questID] = true
                    end
                elseif Options.POITrackWQFilter == "WQTracker" then
                    Options.POITrackWQFilter = "All"
                end

                for _, wq in ipairs(mapWQ) do
                    if isTask(wq.questID) and (wq.mapID == player.uiMapID) then
                        local id = "WQ_" .. wq.questID
                        if not poiTrackPointTable[player.uiMapID][id] then
                            poiTrackPointTable[player.uiMapID][id] = wq
                            local xZone, yZone = poiTrackPointTable[player.uiMapID][id].x, poiTrackPointTable[player.uiMapID][id].y
                            local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                            poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
                            poiTrackPointTable[player.uiMapID][id].name = GetTitleForQuestID(wq.questID)
                            poiTrackPointTable[player.uiMapID][id].x = xWorld
                            poiTrackPointTable[player.uiMapID][id].y = yWorld
                            poiTrackPointTable[player.uiMapID][id].atlasName = "completiondialog-warwithincampaign-worldquests-icon"
                            poiTrackPointTable[player.uiMapID][id].circle = true
                            poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
                            poiTrackPointTable[player.uiMapID][id].scale = 1
                            updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
                        end
                        if not poiTrackPointTable[player.uiMapID][id].texture then
                            poiTrackPointTable[player.uiMapID][id].texture = getWQicon(wq.questID)
                            if poiTrackPointTable[player.uiMapID][id].texture then
                                local poiTrackNode = poiTrackPointTable[player.uiMapID][id].frame
                                poiTrackNode.texture:SetTexture(poiTrackPointTable[player.uiMapID][id].texture)
                            end
                        end
                        if Options.POITrackWQFilter ~= "All" and not trackedWQ[wq.questID] then
                            poiTrackPointTable[player.uiMapID][id].visible = false
                        else
                            poiTrackPointTable[player.uiMapID][id].visible = true
                        end
                        poiTrackPointTable[player.uiMapID][id].wholeZone = Options.POITrackWQWholeZone
                    end
                end
            end

            local vignetteGUIDs = GetVignettes()
            if Options.POITrackFilter["Vignette"] and vignetteGUIDs then
                for _, vignetteGUID in ipairs(vignetteGUIDs) do
                    local vignetteInfo = GetVignetteInfo(vignetteGUID)
                    local vignettePosition = GetVignettePosition(vignetteGUID, player.uiMapID)
                    if vignetteInfo and vignettePosition then
                        local id = "VIGNETTE_" .. vignetteInfo.vignetteGUID
                        if not poiTrackPointTable[player.uiMapID][id] then
                            poiTrackPointTable[player.uiMapID][id] = vignetteInfo
                            local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(vignettePosition.x, vignettePosition.y, player.uiMapID)
                            poiTrackPointTable[player.uiMapID][id].instance = player.uiMapID
                            poiTrackPointTable[player.uiMapID][id].x = xWorld
                            poiTrackPointTable[player.uiMapID][id].y = yWorld
                            poiTrackPointTable[player.uiMapID][id].frame = createPOITrackNode(poiTrackPointTable[player.uiMapID][id])
                            poiTrackPointTable[player.uiMapID][id].scale = 1.3
                            updatePOITrackNode(poiTrackPointTable[player.uiMapID][id])
                        end
                        poiTrackPointTable[player.uiMapID][id].visible = true
                    end
                end
            end
        end
        poiTrackThrottle = 0
    end

    local minAngle = 360
    local effectivePOITrackRadius = Options.POITrackRadius == 0 and Options.POITrackOpacityMaxRadius or Options.POITrackRadius
    local opacityFactor = (Options.POITrackOpacityMin - Options.POITrackOpacityMax) / (effectivePOITrackRadius - Options.POITrackOpacityMinRadius)
    for _, poi in pairs(poiTrackPointTable and poiTrackPointTable[player.uiMapID] or {}) do
        if poi.frame then
            local shown = false
            if poi.visible and player.angle then
                if poi.x and poi.y and poi.instance then
                    poi.distance = HBD:GetWorldDistance(poi.instance, player.x, player.y, poi.x, poi.y)
                    if Options.POITrackRadius == 0 or poi.wholeZone or (poi.distance and poi.distance <= Options.POITrackRadius) then
                        local angle = player.angle - HBD:GetWorldVector(poi.instance, player.x, player.y, poi.x, poi.y)
                        poi.angle = angle
                        if abs(angle) < minAngle then
                            minAngle = abs(angle)
                        end
                        if angle < 0 then angle = angle + (2 * PI) end
                        if angle > PI then angle = angle - (2 * PI) end
                        if angle then
                            local visible = math.rad(Options.Degrees)/2
                            if angle < visible and angle > -visible then
                                poi.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, Options.POITrackOffset)
                                shown = true
                            end
                        end
                    end
                end
            end
            poi.frame:SetShown(shown)
            poi.frame.DistanceText:SetShown(Options.POITrackShowDistance and Options.POITrackTextsDegrees == 0)
            poi.frame.distanceHidden= not (Options.POITrackShowDistance and Options.POITrackTextsDegrees == 0)
            poi.frame.TimeText:SetShown(Options.POITrackShowTTA and Options.POITrackTextsDegrees == 0)
            poi.frame.timeHidden = not (Options.POITrackShowTTA and Options.POITrackTextsDegrees == 0)
            poi.frame.Title:SetShown(Options.POITrackShowTitle and Options.POITrackTextsDegrees == 0)
            poi.shown = shown

            poi.opacity = Options.POITrackOpacityMin
            if not poi.distance or (poi.distance < Options.POITrackOpacityMinRadius) then
                poi.opacity = Options.POITrackOpacityMax
            elseif poi.distance <= effectivePOITrackRadius then
                poi.opacity = Options.POITrackOpacityMax + (poi.distance - Options.POITrackOpacityMinRadius) * opacityFactor
            end
            poi.frame:SetAlpha(poi.opacity)
        end
    end
    if (Options.POITrackTextsDegrees > 0) and (minAngle <= math.rad(Options.POITrackTextsDegrees)) then
        local done = false
        for _, pois in pairs(poiTrackPointTable) do
            for _, poi in pairs(pois) do
                if poi.visible and poi.shown and poi.angle then
                    if abs(poi.angle) <= (minAngle + 0.001) then
                        poi.frame.DistanceText:SetShown(Options.POITrackShowDistance)
                        poi.frame.distanceHidden = not Options.POITrackShowDistance
                        poi.frame.TimeText:SetShown(Options.POITrackShowTTA)
                        poi.frame.timeHidden = not Options.POITrackShowTTA
                        poi.frame.Title:SetShown(Options.POITrackShowTitle)
                        poi.frame:SetAlpha(Options.POITrackOpacitySelected)
                        poiTrackPointTable[player.uiMapID].heading = poi
                        done = true
                        break
                    end
                end
            end
            if done then break end
        end
    end
    HUD.minimapIcons = poiTrackPointTable
end

local function updateHeading()
    if HUD.heading and HUD.heading.text and player.angle then
        local heading = (360 - (player.angle * (180 / math.pi))) % 360
        if Options.HeadingDecimals >= 0 then
            local multiplier = 10^Options.HeadingDecimals
            heading = math.floor(heading * multiplier + 0.5) / multiplier
        else
            local multiplier = Options.HeadingDecimals * 5 * -1
            heading = math.floor((heading + multiplier/2) / multiplier) * multiplier
        end

        --Zee-ro fix
        if heading == 0 and Options.HeadingTrueNorth then
            heading = 360
        end

        HUD.heading.text:SetText(heading)
    end
end

local function updateHUD(force)
    local facing = GetPlayerFacing() or 0
    if force or facing ~= currentFacing then
        local coord = (facing < PI and 0.5 or 1) - (facing * ADJ_FACTOR)
        -- rotate texture
        HUD.compassTexture:SetTexCoord(coord - adjCoord, coord + adjCoord, 0, 1)
        -- rotate letters
        HUD.compassCustom.mask:ClearAllPoints()
        HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', (1/2 - coord) * textureWidth, 0)
        currentFacing = facing
    end
    updatePlayerCoords()
    updateHeading()
    setQuestsIcons()
    setGroupIcons()
    setGatherMateNodes()
    setPOITrackNodes()
end

local function updatePointerTextures()
    for _, v in pairs(questPointsTable) do
        local options = Options.Pointers[v.frame.pointerType]
        if v.texture and options.worldmapTexture then
            v.frame.texture:SetTexture(v.texture)
        else
            v.frame.texture:SetAtlas(options.worldmapTexture and v.atlasName and v.atlasName or v.completed and options.atlasAltID or options.atlasID)
        end
    end
end

local function onUpdate(_, elapsed)
    if player.inInstance then return end

    timer = timer + elapsed
    if timer < (1 / Options.Interval) then return end
    timer = 0
    groupThrottle = groupThrottle + 1
    gatherMateThrottle = gatherMateThrottle + 1
    poiTrackThrottle = poiTrackThrottle + 1
    updateHUD(false)
end

local function updateQuest(questID, x, y, uiMapID, questType, title, completed, atlasName, texture, moreArgs)
    if type(questPointsTable[questID]) ~= "table" then
        questPointsTable[questID] = {}
    end
    title = title or GetTitleForQuestID(questID) or ""
    local HBDuiMapID = uiMapID

    -- Use map transitions
    if Options.UseCurrentMap then
        local playerUiMapId = GetBestMapForUnit("player")
        if playerUiMapId and uiMapID ~= playerUiMapId then
            local mx, my, waypointDescription = GetNextWaypointForMapTracker(playerUiMapId)
            if mx and my then
                x, y, HBDuiMapID = mx, my, playerUiMapId
            end
            if waypointDescription then
                title = title .. " (" .. waypointDescription .. ")"
            end
        end
    end

    local lx, ly, instance = HBD:GetWorldCoordinatesFromZone(x, y, HBDuiMapID)
    questPointsTable[questID].x = lx
    questPointsTable[questID].y = ly
    questPointsTable[questID].uiMapID = uiMapID
    questPointsTable[questID].instance = instance
    questPointsTable[questID].text = title
    questPointsTable[questID].completed = completed
    questPointsTable[questID].atlasName = atlasName
    questPointsTable[questID].texture = texture
    questPointsTable[questID].moreArgs = moreArgs
    questPointsTable[questID].overrideRotation = false
    questPointsTable[questID].crop = 0
    questPointsTable[questID].category = getPointerCategory(questID, questType)
    questPointsTable[questID].circle = false


    if questPointsTable[questID].category == Enum.QuestClassification.WorldQuest then
        questPointsTable[questID].texture = getWQicon(questID)
        questPointsTable[questID].circle = true
    end

    if not questPointsTable[questID].frame then
        questPointsTable[questID].frame = createQuestIcon(questID, questType)
    end
    questPointsTable[questID].frame.scaleMultiplier = 1.5
    questPointsTable[questID].frame.minDistance = nil
    questPointsTable[questID].frame.QuestText:SetText(title)
    questPointsTable[questID].frame.type = "Quest"
    questPointsTable[questID].frame.instance = questPointsTable[questID].instance
    questPointsTable[questID].frame.x = questPointsTable[questID].x
    questPointsTable[questID].frame.y = questPointsTable[questID].y
    local options = Options.Pointers[questPointsTable[questID].frame.pointerType]
    if questPointsTable[questID].texture and options.worldmapTexture then
        questPointsTable[questID].frame.texture:SetTexture(questPointsTable[questID].texture)
        questPointsTable[questID].overrideRotation = true
        questPointsTable[questID].frame.scaleMultiplier = 1
    elseif questPointsTable[questID].atlasName and (options.worldmapTexture or (moreArgs and moreArgs.worldmapTexture)) then
        questPointsTable[questID].frame.texture:SetAtlas(questPointsTable[questID].atlasName)
        questPointsTable[questID].overrideRotation = true
        questPointsTable[questID].frame.scaleMultiplier = 1
    else
        questPointsTable[questID].frame.texture:SetAtlas(completed and options.atlasAltID or options.atlasID)
        questPointsTable[questID].circle = false
    end
    updateQuestIcon(questPointsTable[questID].frame)
end

local function tomtomSetCrazyArrow(self, uid, dist, title)
    if not Options.Pointers[questPointerIdent .. tomTom].enabled then return end
    if not uid then return end
    if type(uid) ~= "table" then return end
    local questID = tomTom
    local questType = tomTom
    local completed = false
    if string.find(title, "^Turn in: ") then
        completed = true
    end
    updateQuest(questID, uid[2], uid[3], uid[1], questType, title, completed)
    tomTomActive = TomTom:GetKey(uid)
    questPointsTable[tomTom].track = true
end

local function tomtomClearWaypoint(self, uid)
    if not uid then return end
    if type(uid) ~= "table" then return end
    local tomTomRemoved = TomTom:GetKey(uid)
    if tomTomActive == tomTomRemoved then
        questPointsTable[tomTom].track = false
    end
end

local function supertrackPOITrack()
    if not Options.POITrackEnabled then return end
    if not player.uiMapID or not poiTrackPointTable[player.uiMapID] then
        return
    end

    local poi = poiTrackPointTable[player.uiMapID].heading
    if poi then
        local type = GetHighestPrioritySuperTrackingType()
        if poi.questID then
            if type == Enum.SuperTrackingType.Quest then
                local questID = GetSuperTrackedQuestID()
                if questID == poi.questID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedQuestID(poi.questID)
        elseif poi.areaPoiID then
            if type == Enum.SuperTrackingType.MapPin then
                local _, stTypeID = GetSuperTrackedMapPin()
                if stTypeID == poi.areaPoiID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, poi.areaPoiID)
        elseif poi.nodeID then
            if type == Enum.SuperTrackingType.MapPin then
                local _, stTypeID = GetSuperTrackedMapPin()
                if stTypeID == poi.nodeID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.TaxiNode, poi.nodeID)
        elseif CanSetUserWaypointOnMap(poi.instance) then
            local poiTracked = { atlasName = poi.atlasName, name = poi.name, x = poi.x, y = poi.y, instance = poi.instance, questID = poi.questID }
            poiTracked.xZone, poiTracked.yZone = HBD:GetZoneCoordinatesFromWorld(poi.x, poi.y, poi.instance, false)
            local pos = CreateVector2D(poiTracked.xZone, poiTracked.yZone)
            local mapPoint = UiMapPoint.CreateFromVector2D(poiTracked.instance, pos)
            poiTrackPointTable[player.uiMapID].tracked = poiTracked
            if type == Enum.SuperTrackingType.UserWaypoint then
                local userWaypoint = GetUserWaypoint()
                if userWaypoint and userWaypoint.uiMapID == poiTracked.instance and
                    math.floor(userWaypoint.position.x * 100000000 + 0.5) == math.floor(poiTracked.xZone * 100000000 + 0.5) and
                    math.floor(userWaypoint.position.y * 100000000 + 0.5) == math.floor(poiTracked.yZone * 100000000 + 0.5) then
                    C_Map.ClearUserWaypoint()
                    ClearAllSuperTracked()
                    return
                end
            end
            SetUserWaypoint(mapPoint)
            SetSuperTrackedUserWaypoint(true)
        end
    end
end

local function createHUD()
    HUD = CreateFrame('Frame', ADDON_NAME, UIParent, "BackdropTemplate")
    HUD:SetPoint("CENTER")
    HUD:SetClampedToScreen(true)
    HUD:RegisterForDrag("LeftButton")

    HUD:SetScript("OnAttributeChanged", function(self, name, value)
        if name == "state-hudvisibility" then
            local visible = false
            if value == "show" and not player.inInstance then
                visible = true
            end
            Addon:SetVisibility(visible)
        end
    end)

    HUD.SupertrackMinimapIcon = function(self)
        supertrackPOITrack()
    end
end

local function OnEvent(event,...)
    if TomTom and TomTomCrazyArrow and not TomTomCrazyArrow:IsShown() and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
    local questID = GetSuperTrackedQuestID()
    local completed = false
    if questID and questID > 0 then
        local x, y, uiMapID
    	if isTask(questID)  then
            uiMapID = GetQuestZoneID(questID)
            if not uiMapID then
                uiMapID = getMapId(questID)
            end
            if uiMapID then
                x, y = GetQuestLocation(questID, uiMapID)
            end
        else
            uiMapID, x, y, completed = GetQuestPOIInfo(questID)
        end
        if x and y and uiMapID then
            updateQuest(questID, x, y, uiMapID, 0, nil, completed)
        end
    else
        local superTrackingType = GetHighestPrioritySuperTrackingType()
        if superTrackingType == Enum.SuperTrackingType.UserWaypoint then
            local point = GetUserWaypoint()
            if point then
                local poiTracked = poiTrackPointTable[player.uiMapID] and poiTrackPointTable[player.uiMapID].tracked
                local mult = 100000000
                local name, atlasName
                if poiTracked and poiTracked.questID then
                   updateQuest(poiTracked.questID, poiTracked.xZone, poiTracked.yZone, player.uiMapID, 0, nil, false)
                elseif poiTracked and math.floor(point.position.x * mult + 0.5) == math.floor(poiTracked.xZone * mult + 0.5) and
                    math.floor(point.position.y * mult + 0.5) == math.floor(poiTracked.yZone * mult + 0.5) then
                    name, atlasName = poiTracked.name, poiTracked.atlasName
                    updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, name, completed, atlasName, nil, {
                        ["stRetexture"] = Options.POITrackSTRetexture,
                        ["worldmapTexture"] = Options.POITrackWorldmapTexture,
                    })
                end
            end
        end
        local uiMapID = WorldMapFrame:GetMapID()
        if superTrackingType == Enum.SuperTrackingType.MapPin then
            local STtype, STtypeID = GetSuperTrackedMapPin()
            Debug:Info("SuperTrackingType: ", superTrackingType, " STtype: ", STtype, " STtypeID: ", STtypeID, "uiMapID: ", uiMapID)
            local poiInfo
            local title

            local moreArgs = {
                ["STtype"] = STtype,
                ["STtypeID"] = STtypeID
            }

            -- try to get corrent uiMapID
            if questPointsTable[selectedPin] and questPointsTable[selectedPin].moreArgs and questPointsTable[selectedPin].moreArgs.STtype == moreArgs.STtype and questPointsTable[selectedPin].moreArgs.STtypeID == moreArgs.STtypeID then
                uiMapID = questPointsTable[selectedPin].uiMapID
                Debug:Info("Using selectedPin uiMapID: ", STtypeID, uiMapID)
            elseif STtypeID and (not uiMapID or not poiCache[STtypeID] or not poiCache[STtypeID][uiMapID]) then
                for mapID, _ in pairs(poiCache[STtypeID] or {}) do
                    uiMapID = mapID
                    break
                end
                Debug:Info("Using poiCache uiMapID: ", STtypeID, uiMapID)
            end

            -- POI
            if STtype == 0 then
                Debug:Info("SuperTrackingType is AreaPOI", uiMapID, STtypeID)
                poiInfo = GetAreaPOIInfo(uiMapID, STtypeID)
                Debug:Table("poiInfo: ", poiInfo)
            end

            -- Offer
            if STtype == 1 then
                title = GetTitleForQuestID(STtypeID)
            end

            -- Taxi
            if STtype == 2 then
                local taxis = GetTaxiNodesForMap(uiMapID)
                if taxis then
                    for _,v in pairs(taxis) do
                        if v.nodeID == STtypeID then
                            poiInfo = v
                            break
                        end
                    end
                end
            end

            if poiInfo then
                updateQuest(selectedPin, poiInfo.position.x, poiInfo.position.y, uiMapID, selectedPin, poiInfo.name, completed, poiInfo.atlasName, nil, moreArgs)
            elseif WorldMapFrame:IsVisible() then
                local x, y = WorldMapFrame:GetNormalizedCursorPosition()
                if uiMapID and x and y then
                    updateQuest(selectedPin, x, y, uiMapID, selectedPin, title, completed)
                end
            end
        end
        if superTrackingType == Enum.SuperTrackingType.Vignette and WorldMapFrame:IsVisible() then
            local vignetteGUID = GetSuperTrackedVignette()
            if vignetteGUID then
                local vignettePosition = GetVignettePosition(vignetteGUID, uiMapID)
                local vignetteInfo = GetVignetteInfo(vignetteGUID)
                if vignettePosition and vignetteInfo then
                    local x, y = vignettePosition:GetXY()
                    if x and y then
                        updateQuest(selectedPin, x, y, uiMapID, selectedPin, vignetteInfo.name, false, vignetteInfo.atlasName, nil, vignetteInfo)
                    end
                end
            end
        end
    end
    setQuestsIcons()
end

local function OnGroup(event, ...)
    local groupType = (IsInRaid() and "raid") or  (IsInGroup() and "party") or "none"
    if groupType ~= (player.groupType or "") then Addon:HideGroupIcons() end
    player.groupType = groupType
end

local function OnZoneChange(event, ...)
    cachePOIs()
    player.inInstance = IsInInstance()
    Addon:SetVisibility(not player.inInstance)
    OnGroup(event, ...)
    OnEvent(event, ...)
end

function Addon:HideGroupIcons()
    for _,v in pairs(groupPointsTable) do
        if v.frame then v.frame:Hide() end
        v.active = false
    end
end

function Addon:SetVisibility(visible)
    if visible then
        HUD:Show()
        HUD:SetScript('OnUpdate', onUpdate)
    else
        HUD:Hide()
        HUD:SetScript('OnUpdate',nil)
    end
end

function Addon:GetPointerTypes()
    local pointerTypes = {}
    for k, v in pairs(Options.Pointers) do
        pointerTypes[k] = v.name
    end

    return pointerTypes
end

function Addon:CopyPointerSettings(from, to, what)
    local optionNames = {}
    for _, pointer in pairs(Addon.Options.args.Supertracker.args.Pointers.args) do
        if pointer.args.Textures then
            for option, _ in pairs(pointer.args[what].args) do
                optionNames[option] = true
            end
            break
        end
    end
    local dialog = StaticPopupDialogs[copyPointersDialogName]
    dialog.OnAccept =  function ()
        for k, v in pairs(Addon.db.profile.Pointers[from]) do
            if k ~= "name" and k ~= "value" and k ~= "enabled" and k ~= "worldmapTexture" and optionNames[k] then
                Addon.db.profile.Pointers[to][k] = v
            end
        end
        AceConfigRegistry:NotifyChange(Const.METADATA.NAME)
        Addon:UpdateHUDSettings()
    end
    StaticPopup_Show(copyPointersDialogName)
end

function Addon:ResetPosition(resetX, resetY)
    if resetX then
        Options.PositionX = (UIParent:GetWidth() / Options.Scale - HUD:GetWidth()) / 2
    end
    if resetY then
        Options.PositionY = (UIParent:GetHeight() - HUD:GetHeight() - 64) / Options.Scale
    end
    HUD:ClearAllPoints()
    HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
end

function Addon:UpdateHUDSettings()
    textureWidth = defaultTextureWidth * Options.HorizontalScale
    textureHeight = defaultTextureHeight * Options.VerticalScale
    local width, height = Options.Degrees / (720 / textureWidth) + Options.BorderThickness * 2, textureHeight + Options.BorderThickness * 2
    adjCoord = Options.Degrees / 1440

    HUD:EnableMouse(not Options.Lock)
    HUD:SetMovable(not Options.Lock)
	if Options.Lock then
		HUD:SetScript('OnDragStart', nil)
		HUD:SetScript('OnDragStop', nil)
		HUD:StopMovingOrSizing()
	else
		HUD:SetScript('OnDragStart', function()
            HUD:StartMoving()
        end)
		HUD:SetScript('OnDragStop', function ()
            HUD:StopMovingOrSizing()
            Options.PositionX = HUD:GetLeft()
            Options.PositionY = HUD:GetBottom()
        end)
	end

    if Options.PositionX < 0 then
        self:ResetPosition(true, true)
    else
        local currentScale = round(HUD:GetScale(), 2)
        local currentWidth = round(HUD:GetWidth(), 2)
        if  currentWidth ~= 0 then

            if currentScale ~= Options.Scale then
                local diffScale = currentScale / Options.Scale
                local center = (Options.PositionX + currentWidth / 2) * diffScale
                Options.PositionX = center - currentWidth / 2
                Options.PositionY = Options.PositionY * diffScale
            end

            if currentWidth ~= width then
                local diffWidth = (currentWidth - width) / 2
                Options.PositionX = Options.PositionX + diffWidth
            end
        end

        HUD:ClearAllPoints()
        HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
    end

    HUD:SetSize(width, height)
    HUD:SetScale(Options.Scale)
	HUD:SetFrameStrata(Options.Strata)
	HUD:SetFrameLevel(Options.Level)
    HUD:SetAlpha(Options.Transparency)

	local backdrop = {
		bgFile = LSM:Fetch("background", Options.Background),
		edgeFile = LSM:Fetch("border", Options.Border),
		edgeSize = Options.BorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	HUD:SetBackdrop(backdrop)
    HUD:SetBackdropColor(Options.BackgroundColor.r,Options.BackgroundColor.g, Options.BackgroundColor.b, Options.BackgroundColor.a)
	HUD:SetBackdropBorderColor(Options.BorderColor.r,Options.BorderColor.g, Options.BorderColor.b, Options.BorderColor.a)

    Options.PositionX = HUD:GetLeft()
    Options.PositionY = HUD:GetBottom()

    updateCompassHUD()

    HUD.compassCustom:SetSize(width, height)
    for _, quest in pairs(questPointsTable) do
        if quest.frame then
            updateQuestIcon(quest.frame)
        end
    end
    updateHUD(true)
    updatePointerTextures()
    updateGroupTexts()
    updateGatherMate()
    updatePoiTrack()
    UnregisterAttributeDriver(HUD, 'state-hudvisibility')
    RegisterAttributeDriver(HUD, "state-hudvisibility", Options.Visibility)
end

function Addon:ConstructDefaultsAndOptions()
    local function atlasIDExists(atlasID)
        for _, data in pairs(pointerTextures) do
            if data.atlasID == atlasID then
                return true
            end
        end
        return false
    end
    -- add textures from questPointers into pointerTextures
    for _, preset in pairs(texturePresets) do
        for k, v in pairs(preset) do
            if (v.atlasIDavailable and v.atlasIDturnin and v.atlasIDavailable == v.atlasIDturnin) or (v.atlasIDavailable and not v.atlasIDturnin) and not atlasIDExists(v.atlasIDavailable) then
                local name = v.atlasNameAvailable or (k > 100 and "Recurring") or questPointers[k]
                pointerTextures[name] = { atlasID = v.atlasIDavailable }
                if v.textureScaleAvailable then
                    pointerTextures[name].textureScale = v.textureScaleAvailable
                end
                if v.textureRotateAvailable then
                    pointerTextures[name].textureRotate = v.textureRotateAvailable
                end
            else
                if v.atlasIDavailable and not atlasIDExists(v.atlasIDavailable) then
                    local name = v.atlasNameAvailable or ((k > 100 and "Recurring") or questPointers[k]).." progress"
                    pointerTextures[name] = { atlasID = v.atlasIDavailable }
                    if v.textureScaleAvailable then
                        pointerTextures[name].textureScale = v.textureScaleAvailable
                    end
                    if v.textureRotateAvailable then
                        pointerTextures[name].textureRotate = v.textureRotateAvailable
                    end
                end
                if v.atlasIDturnin and not atlasIDExists(v.atlasIDturnin) then
                    local name = v.atlasNameTurnin or v.atlasNameAvailable or ((k > 100 and "Recurring") or questPointers[k]).." turn-in"

                    pointerTextures[name] = { atlasID = v.atlasIDturnin }
                    if v.textureScaleTurnin then
                        pointerTextures[name].textureScale = v.textureScaleTurnin
                    end
                    if v.textureRotateTurnin then
                        pointerTextures[name].textureRotate = v.textureRotateTurnin
                    end
                end
            end
        end
    end

    local pointersDefaults = {}
    local pointersOptionsArgs = {}

    -- presets
    pointersOptionsArgs["Presets"] = {
        type = "group",
        order = 0,
        name = "|A:CreditsScreen-Assets-Buttons-FastForward:18:18|a |cnPURE_GREEN_COLOR:Presets|r |A:CreditsScreen-Assets-Buttons-Rewind:18:18|a",
        args = {
            PointersPreset = {
                type = "select",
                order = 10,
                name = "Texture presets",
                values = function()
                    local val = {}
                    for k, _ in pairs(texturePresets) do
                        val[k] = k
                    end
                    return val
                end,
                get = function(info)
                    local previews = Addon.Options.args.Supertracker.args.Pointers.args.Presets.args.Preview.args
                    wipe(previews)
                    for k, v in pairs(questPointers) do
                        local preset = texturePresets[texturePreset][k]
                        local default = texturePresets[defaultTexturePreset][k]
                        local reference = preset and preset.reference and texturePresets[texturePreset][preset.reference]
                        local atlasID = preset and (preset.atlasIDavailable or (reference and reference.atlasIDavailable)) or default.atlasIDavailable
                        local atlasAltID = preset and (preset.atlasIDturnin or (reference and reference.atlasIDturnin)) or default.atlasIDturnin or (reference and reference.atlasIDavailable) or default.atlasIDavailable
                        previews["AvailablePreview_"..k] = {
                            type = "description",
                            order = k*10,
                            name = "",
                            width = 1/6,
                            image = function()
                                if atlasID then
                                    return getAtlasTexture(atlasID)
                                end
                                return nil
                            end,
                            imageWidth = 24,
                            imageHeight = 24,
                            imageCoords = function(info)
                                if atlasID then
                                    return getAtlasCoords(atlasID)
                                end
                            end,
                        }
                        previews["TurnInPreview_"..k] = {
                            type = "description",
                            order = k*10+1,
                            name = "",
                            width = 1/6,
                            image = function()
                                if atlasID then
                                    return getAtlasTexture(atlasAltID)
                                end
                                return nil
                            end,
                            imageWidth = 24,
                            imageHeight = 24,
                            imageCoords = function(info)
                                if atlasID then
                                    return getAtlasCoords(atlasAltID)
                                end
                            end,
                        }
                        previews["QuestType_"..k] = {
                            type = "description",
                            order = k*10+5,
                            name = v,
                            width = 5/6,
                        }
                    end
                    AceConfigRegistry:NotifyChange(Const.METADATA.NAME)
                    return texturePreset
                end,
                set = function(info, value) texturePreset = value end,
            },
            Set = {
                type = "execute",
                order = 20,
                name = "Set",
                func = function()
                    for k, v in pairs(Options.Pointers) do
                        local questPointer = questPointers[v.value]
                        if questPointer then
                            local preset = texturePresets[texturePreset][v.value]
                            local default = texturePresets[defaultTexturePreset][v.value]
                            local reference = preset and preset.reference and texturePresets[texturePreset][preset.reference]
                            local atlasID = preset and (preset.atlasIDavailable or (reference and reference.atlasIDavailable)) or default.atlasIDavailable
                            local atlasAltID = preset and (preset.atlasIDturnin or (reference and reference.atlasIDturnin)) or default.atlasIDturnin or (reference and reference.atlasIDavailable) or default.atlasIDavailable
                            v.atlasID = atlasID
                            v.atlasAltID = atlasAltID
                            local texture = getPointerTextureByAtlasID(v.atlasID)
                            if texture then
                                v.textureScale = texture.textureScale or 1
                                v.textureRotate = texture.textureRotate and 1 or -1
                            end
                            texture = getPointerTextureByAtlasID(v.atlasAltID)
                            if texture then
                                v.textureAltScale = texture.textureScale or 1
                                v.textureAltRotate = texture.textureRotate and 1 or -1
                            end
                        end
                    end
                    Addon:UpdateHUDSettings()
                end
            },
            Preview = {
                type = "group",
                order = 30,
                name = "Preview",
                inline = true,
                args = {},
            },
        },
    }
    for k, v in pairs(questPointers) do
        local preset = texturePresets[defaultTexturePreset][k]
        local reference = preset and preset.reference and texturePresets[defaultTexturePreset][preset.reference]
        -- defaults
        pointersDefaults[questPointerIdent .. k] = {value = k}
        pointersDefaults[questPointerIdent .. k].name = v
        pointersDefaults[questPointerIdent .. k].atlasID = preset.atlasIDavailable or (reference and reference.atlasIDavailable)
        pointersDefaults[questPointerIdent .. k].atlasAltID = preset.atlasIDturnin or (reference and reference.atlasIDturnin) or (reference and reference.atlasIDavailable) or preset.atlasIDavailable
        pointersDefaults[questPointerIdent .. k].textureScale = preset.textureScaleAvailable or (reference and reference.textureScaleAvailable) or 1
        pointersDefaults[questPointerIdent .. k].textureAltScale = preset.textureScaleTurnin or (reference and reference.textureScaleTurnin) or (reference and reference.textureScaleAvailable) or preset.textureScaleAvailable or 1
        pointersDefaults[questPointerIdent .. k].textureRotate = (preset.textureRotateAvailable and 1) or (reference and reference.textureRotateAvailable and 1) or 0
        pointersDefaults[questPointerIdent .. k].textureAltRotate = (preset.textureRotateTurnin and 1) or (reference and reference.textureRoteteTurnin and 1) or (reference and reference.textureRotateAvailable and 1) or (preset.textureRotateAvailable and 1) or 0
        pointersDefaults[questPointerIdent .. k].pointerOffset = (v == "TomTom") and -1.1 or 1
        pointersDefaults[questPointerIdent .. k].enabled = true
        pointersDefaults[questPointerIdent .. k].stRetexture = false
        if k == selectedPin then
            pointersDefaults[questPointerIdent .. k].worldmapTexture = true
            pointersDefaults[questPointerIdent .. k].stRetexture = true
        end
        if k == Enum.QuestClassification.WorldQuest then
            pointersDefaults[questPointerIdent .. k].worldmapTexture = true
            pointersDefaults[questPointerIdent .. k].stRetexture = true
        end
        pointersDefaults[questPointerIdent .. k].showDistance = true
        pointersDefaults[questPointerIdent .. k].showTTA = true
        pointersDefaults[questPointerIdent .. k].showQuest = true
        pointersDefaults[questPointerIdent .. k].distanceOffset = 0
        pointersDefaults[questPointerIdent .. k].ttaOffset =  0
        pointersDefaults[questPointerIdent .. k].questOffset = 0
        pointersDefaults[questPointerIdent .. k].distanceCustomFont = false
        pointersDefaults[questPointerIdent .. k].distanceFont = "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].distanceFontSize = 12
        pointersDefaults[questPointerIdent .. k].distanceFontColor = {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].distanceFontFlags = ""
        pointersDefaults[questPointerIdent .. k].ttaCustomFont = false
        pointersDefaults[questPointerIdent .. k].ttaFont = "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].ttaFontSize = 12
        pointersDefaults[questPointerIdent .. k].ttaFontColor = {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].ttaFontFlags = ""
        pointersDefaults[questPointerIdent .. k].questCustomFont = false
        pointersDefaults[questPointerIdent .. k].questFont = "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].questFontSize = 12
        pointersDefaults[questPointerIdent .. k].questFontColor = {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].questFontFlags = ""

        -- options
        pointersOptionsArgs[questPointerIdent .. k] = {
            type = "group",
            order = k+10,
            childGroups = "tab",
            name = v,
            icon = function(info)
                local atlasID = Addon.db.profile[info[#info-1]][info[#info]].atlasID
                if atlasID then
                    local texture = getAtlasTexture(atlasID)
                    return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
                end
                return "Interface\\Icons\\INV_Misc_QuestionMark"
            end,
            iconCoords = function(info)
                local atlasID = Addon.db.profile[info[#info-1]][info[#info]].atlasID
                if atlasID then
                    return getAtlasCoords(atlasID)
                end
                return {0,0,0,1,1,0,1,1}
            end,
            args = {}
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures = {
            type = "group",
            order = 10,
            name = "Textures",
            args = {}
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts = {
            type = "group",
            order = 20,
            name = "Texts",
            args = {}
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.enabled = {
            type = "toggle",
            order = 0,
            name = "Enable pointer",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.copyFrom = {
            type = "select",
            order = 5,
            name = "Copy texture setting from",
            values = function() return Addon:GetPointerTypes() end,
            get = function(info)
                return ""
            end,
            set = function(info, value)
                Addon:CopyPointerSettings(value, info[#info-2], info[#info-1])
            end
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.headerCombined = {
            type = "header",
            order = 10,
            name = "Combined options"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.stRetexture = {
            type = "toggle",
            order = 15,
            name = "Re-texture SuperTracker",
            desc = "When enabled, the SuperTracker diamond will use the same texture as the pointer.",
        }
        if k == selectedPin then
            pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.worldmapTexture = {
                type = "toggle",
                order = 20,
                name = "Use worldmap texture",
            }
        end
        if k == Enum.QuestClassification.WorldQuest then
            pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.worldmapTexture = {
                type = "toggle",
                order = 20,
                name = "Use reward texture"
            }
        end
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.pointerOffset = {
            type = "range",
            order = 30,
            name = "Vertical adjustment",
            min = -5,
            max = 5,
            step = 0.01,
            isPercent = true,
            width = "full",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.headerProgress = {
            type = "header",
            order = 100,
            name = "Progress pointer"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasIDPreview = {
            type = "description",
            order = 110,
            name = "",
            width = 1/6,
            image = function(info)
                local atlasID = Addon.db.profile[info[#info-3]][info[#info-2]].atlasID
                if atlasID then
                    return getAtlasTexture(atlasID)
                end
                return nil
            end,
            imageWidth = 24,
            imageHeight = 24,
            imageCoords = function(info)
                local atlasID = Addon.db.profile[info[#info-3]][info[#info-2]].atlasID
                if atlasID then
                    return getAtlasCoords(atlasID)
                end
            end
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasID = {
            type = "select",
            order = 120,
            name = "Texture",
            values = function() return getPointerAtlasIDs() end,
            sorting = function() return getSortedPointerAtlasIDKeys() end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] = value
                local texture = getPointerTextureByAtlasID(value)
                Addon.db.profile[info[#info-3]][info[#info-2]].textureScale = texture and texture.textureScale or 1
                Addon.db.profile[info[#info-3]][info[#info-2]].textureRotate = (texture and texture.textureRotate) and 1 or -1
                Addon:UpdateHUDSettings()
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.textureScale = {
            type = "range",
            order = 130,
            name = "Scale",
            min = 0,
            max = 3,
            step = 0.01,
            isPercent = true,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.textureRotate = {
            type = "toggle",
            order = 140,
            name = "Edge rotation",
            desc = "When enabled, the pointer will flip when at the top side of the compass and rotate 90° when on the edge.",
            width = "full",
            get = function(info)
                return Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] and Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] > 0
            end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] = value and 1 or -1
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasCustom = {
            type = "input",
            order = 150,
            name = "Custom atlas ID",
            desc = "AtlasID of the texture. You can enter your own. Try WeakAuras' internal texture browser to pick one.",
            width = "full",
            get = function(info)
                return Addon.db.profile[info[#info-3]][info[#info-2]].atlasID
            end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]].atlasID = value
                Addon:UpdateHUDSettings()
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.headerTurnIn = {
            type = "header",
            order = 200,
            name = "Turn-in pointer"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasAltIDPreview = {
            type = "description",
            order = 210,
            name = "",
            width = 1/6,
            image = function(info)
                local atlasID = Addon.db.profile[info[#info-3]][info[#info-2]].atlasAltID
                if atlasID then
                    return getAtlasTexture(atlasID)
                end
                return nil
            end,
            imageWidth = 24,
            imageHeight = 24,
            imageCoords = function(info)
                local atlasID = Addon.db.profile[info[#info-3]][info[#info-2]].atlasAltID
                if atlasID then
                    return getAtlasCoords(atlasID)
                end
            end
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasAltID = {
            type = "select",
            order = 220,
            name = "Texture",
            values = function() return getPointerAtlasIDs() end,
            sorting = function() return getSortedPointerAtlasIDKeys() end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] = value
                local texture = getPointerTextureByAtlasID(value)
                Addon.db.profile[info[#info-3]][info[#info-2]].textureAltScale = texture and texture.textureScale or 1
                Addon.db.profile[info[#info-3]][info[#info-2]].textureAltRotate = (texture and texture.textureRotate) and 1 or -1
                Addon:UpdateHUDSettings()
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.textureAltScale = {
            type = "range",
            order = 230,
            name = "Scale",
            min = 0,
            max = 3,
            step = 0.01,
            isPercent = true,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.textureAltRotate = {
            type = "toggle",
            order = 240,
            name = "Edge rotation",
            desc = "When enabled, the pointer will flip when at the top side of the compass and rotate 90° when on the edge.",
            width = "full",
            get = function(info)
                return Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] and Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] > 0
            end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]][info[#info]] = value and 1 or -1
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.atlasAltCustom = {
            type = "input",
            order = 250,
            name = "Custom atlas ID",
            desc = "AtlasID of the texture. You can enter your own. Try WeakAuras' internal texture browser to pick one.",
            width = "full",
            get = function(info)
                return Addon.db.profile[info[#info-3]][info[#info-2]].atlasAltID
            end,
            set = function(info, value)
                Addon.db.profile[info[#info-3]][info[#info-2]].atlasAltID = value
                Addon:UpdateHUDSettings()
            end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.copyFrom = {
            type = "select",
            order = 5,
            name = "Copy text setting from",
            values = function() return Addon:GetPointerTypes() end,
            get = function(info)
                return ""
            end,
            set = function(info, value)
                Addon:CopyPointerSettings(value, info[#info-2], info[#info-1])
            end
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.headerDistance = {
            type = "header",
            order = 19,
            name = "Distance text"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.showDistance = {
            type = "toggle",
            order = 20,
            name = "Show",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceOffset = {
            type = "range",
            order = 30,
            name = "Vertical adjustment",
            min = -20,
            max = 20,
            step = 0.5,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceCustomFont = {
            type = "toggle",
            order = 40,
            name = "Use custom font",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceFont = {
            type = "select",
            order = 50,
            name = "Font",
            width = 1,
            dialogControl = "LSM30_Font",
            values = AceGUIWidgetLSMlists['font'],
            disabled = function() return not Options.Pointers[questPointerIdent .. k].distanceCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceFontSize = {
            type = "range",
            order = 60,
            name = "Size",
            width = 3/4,
            min = 2,
            max = 36,
            step = 0.5,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].distanceCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceFontFlags = {
            type = "select",
            order = 70,
            name = "Outline",
            width = 3/4,
            values = {
                [""] = "None",
                ["OUTLINE"] = "Normal",
                ["THICKOUTLINE"] = "Thick",
            },
            disabled = function() return not Options.Pointers[questPointerIdent .. k].distanceCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.distanceFontColor = {
            type = "color",
            order = 80,
            name = "Color",
            width = 1/2,
            hasAlpha = true,
            get = function(info)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                return color.r, color.g, color.b, color.a
            end,
            set = function (info, r, g, b, a)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                color.r = r
                color.g = g
                color.b = b
                color.a = a
                Addon:UpdateHUDSettings()
            end,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].distanceCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.headerTTA = {
            type = "header",
            order = 89,
            name = "Time to arrive"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.showTTA = {
            type = "toggle",
            order = 90,
            name = "Show",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaOffset = {
            type = "range",
            order = 100,
            name = "Vertical adjustment",
            min = -20,
            max = 20,
            step = 0.5,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaCustomFont = {
            type = "toggle",
            order = 110,
            name = "Use custom font",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaFont = {
            type = "select",
            order = 120,
            name = "Font",
            width = 1,
            dialogControl = "LSM30_Font",
            values = AceGUIWidgetLSMlists['font'],
            disabled = function() return not Options.Pointers[questPointerIdent .. k].ttaCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaFontSize = {
            type = "range",
            order = 130,
            name = "Size",
            width = 3/4,
            min = 2,
            max = 36,
            step = 0.5,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].ttaCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaFontFlags = {
            type = "select",
            order = 140,
            name = "Outline",
            width = 3/4,
            values = {
                [""] = "None",
                ["OUTLINE"] = "Normal",
                ["THICKOUTLINE"] = "Thick",
            },
            disabled = function() return not Options.Pointers[questPointerIdent .. k].ttaCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.ttaFontColor = {
            type = "color",
            order = 150,
            name = "Color",
            width = 1/2,
            hasAlpha = true,
            get = function(info)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                return color.r, color.g, color.b, color.a
            end,
            set = function (info, r, g, b, a)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                color.r = r
                color.g = g
                color.b = b
                color.a = a
                Addon:UpdateHUDSettings()
            end,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].ttaCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.headerQuest = {
            type = "header",
            order = 159,
            name = "Quest name"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.showQuest = {
            type = "toggle",
            order = 160,
            name = "Show",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questOffset = {
            type = "range",
            order = 170,
            name = "Vertical adjustment",
            min = -20,
            max = 20,
            step = 0.5,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questCustomFont = {
            type = "toggle",
            order = 180,
            name = "Use custom font",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questFont = {
            type = "select",
            order = 190,
            name = "Font",
            width = 1,
            dialogControl = "LSM30_Font",
            values = AceGUIWidgetLSMlists['font'],
            disabled = function() return not Options.Pointers[questPointerIdent .. k].questCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questFontSize = {
            type = "range",
            order = 200,
            name = "Size",
            width = 3/4,
            min = 2,
            max = 36,
            step = 0.5,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].questCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questFontFlags = {
            type = "select",
            order = 210,
            name = "Outline",
            width = 3/4,
            values = {
                [""] = "None",
                ["OUTLINE"] = "Normal",
                ["THICKOUTLINE"] = "Thick",
            },
            disabled = function() return not Options.Pointers[questPointerIdent .. k].questCustomFont end,
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Texts.args.questFontColor = {
            type = "color",
            order = 220,
            name = "Color",
            width = 1/2,
            hasAlpha = true,
            get = function(info)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                return color.r, color.g, color.b, color.a
            end,
            set = function (info, r, g, b, a)
                local color = Options[info[#info-3]][info[#info-2]][info[#info]]
                color.r = r
                color.g = g
                color.b = b
                color.a = a
                Addon:UpdateHUDSettings()
            end,
            disabled = function() return not Options.Pointers[questPointerIdent .. k].questCustomFont end,
        }
    end

    self.Defaults.profile.Pointers = pointersDefaults
    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", self.Defaults, true)
    SupertrackerOptions.args.Pointers.args = pointersOptionsArgs
    TrackingOption.args.POITrack = POITrackOptions
    TrackingOption.args.Group = GroupOptions
    TrackingOption.args.GatherMate = GatherMateOptions
    self.Options.args.Supertracker = SupertrackerOptions
    self.Options.args.TrackingIntegrations = TrackingOption
    self.Options.args.Profiles = AceDBOptions:GetOptionsTable(self.db)
    self.Options.args.Profiles.order = 900

    AceConfig:RegisterOptionsTable(Const.METADATA.NAME, self.Options)
    _, Addon.categoryID = AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, nil, nil, "Tabs")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Supertracker", Const.METADATA.NAME, "Supertracker")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Minimap tracking", Const.METADATA.NAME, "TrackingIntegrations")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Profiles", Const.METADATA.NAME, "Profiles")
end

function Addon:RefreshConfig()
    Options = self.db.profile
    self:UpdateHUDSettings()
end

function Addon:OnEnable()
    addToLSM()

    Addon:InitializeDataBroker()
    player.name = UnitName("player")
    player.realm = GetRealmName()

    self:UpdateHUDSettings()
    HUD:SetScript('OnUpdate', onUpdate)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChange)
    self:RegisterEvent("PLAYER_MAP_CHANGED", OnZoneChange)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChange)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", OnGroup)
    self:RegisterEvent("ZONE_CHANGED", OnEvent)
    self:RegisterEvent("QUEST_ACCEPTED", OnEvent)
    self:RegisterEvent("QUEST_LOG_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_POI_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_TURNED_IN", OnEvent)
    self:RegisterEvent("USER_WAYPOINT_UPDATED", OnEvent)
    self:RegisterEvent("WAYPOINT_UPDATE", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_CHANGED", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_PATH_UPDATED", OnEvent)


    if TomTom then
        self:SecureHook(TomTom, "SetCrazyArrow", tomtomSetCrazyArrow)
        self:SecureHook(TomTom, "ClearWaypoint", tomtomClearWaypoint)
        self:SecureHook(TomTom, "HideWaypoint", tomtomClearWaypoint)
    end

    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

function Addon:OnDisable()
    HUD:SetScript('OnUpdate', nil)
end

function Addon:OnInitialize()
    Addon:ConstructDefaultsAndOptions()
    Options = self.db.profile
    createHUD()
end
