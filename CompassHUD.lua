local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

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
local IsWorldQuest = C_QuestLog.IsWorldQuest
local GetQuestAdditionalHighlights = C_QuestLog.GetQuestAdditionalHighlights
local ReadyForTurnIn = C_QuestLog.ReadyForTurnIn
local GetQuestZoneID = C_TaskQuest.GetQuestZoneID
local GetQuestLocation = C_TaskQuest.GetQuestLocation
local GetQuestClassification = C_QuestInfoSystem.GetQuestClassification
local GetMapInfo = C_Map.GetMapInfo
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local IsSuperTrackingUserWaypoint = C_SuperTrack.IsSuperTrackingUserWaypoint

local Options
local HUD
local timer = 0
local player = {x = 0, y = 0, angle = 0, instance = "none"}
local tomTomActive
local questPointsTable = {}
local HBDmaps = {}
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
local textureWidth, textureHeight = 2048, 16
local texturePosition = textureWidth * ADJ_FACTOR
local adjCoord, currentFacing

local questUnknown = -999
local tomTom = -200
local mapPin = -100

local texturePreset = "classic"
local questPointerIdent = "pointer_"
local pointerTextures = {
    ["User pin"] = {
        atlasID = "Waypoint-MapPin-Minimap-Tracked",
    },
    ["Arrow Gold small"] = {
        atlasID = "Rotating-MinimapGuideArrow",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Arrow Gold"] = {
        atlasID = "MiniMap-QuestArrow",
        textureRotate = true,
    },
    ["Arrow Blue"] = {
        atlasID = "MiniMap-VignetteArrow",
        textureRotate = true,
    },
    ["Arrow Red"] = {
        atlasID = "MiniMap-DeadArrow",
        textureRotate = true,
    },
    ["Other"] = {
        atlasID = "128-Store-Main",
        textureScale = 0.8,
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
    ["Arrow Green small"] = {
        atlasID = "Rotating-MinimapGroupArrow",
        textureScale = 1.35,
        textureRotate = true,
    },
    ["Arrow Blue small"] = {
        atlasID = "Rotating-MinimapArrow",
        textureScale = 1.35,
        textureRotate = true,
    },
}

local questPointers = {
	[tomTom] = {
        name = "TomTom",
        atlasID = "Rotating-MinimapGroupArrow",
    },
	[questUnknown] = {
        name = "Unknown pointer",
        atlasID = "128-Store-Main",
    },
    [mapPin] = {
        name = "User map pin",
        atlasID = "Waypoint-MapPin-Minimap-Tracked",
    },
	[Enum.QuestClassification.Important] = {
        name = "Important",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "quest-important-available",
        atlasIDturnin = "quest-important-turnin",
    },
	[Enum.QuestClassification.Legendary] = {
        name = "Legendary",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "quest-legendary-available",
        atlasIDturnin = "quest-legendary-turnin",
    },
	[Enum.QuestClassification.Campaign] = {
        name = "Campaign",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "Quest-Campaign-Available",
        atlasIDturnin = "Quest-Campaign-TurnIn",
    },
	[Enum.QuestClassification.Calling] = {
        name = "Calling",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "callings-available",
        atlasIDturnin = "callings-turnin",
    },
	[Enum.QuestClassification.Meta] = {
        name = "Meta",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "quest-wrapper-available",
        atlasIDturnin = "quest-wrapper-turnin",
    },
	[Enum.QuestClassification.Normal] = {
        name = "Quest",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "QuestNormal",
        atlasIDturnin = "QuestTurnin",
    },
	[Enum.QuestClassification.Questline] = {
        name = "Questline",
        atlasID = "MiniMap-QuestArrow",
        atlasIDavailable = "QuestNormal",
        atlasIDturnin = "QuestTurnin",
    },
	[Enum.QuestClassification.BonusObjective] = {
        name = "Bonus",
        atlasID = "MiniMap-VignetteArrow",
        atlasIDavailable = "VignetteEvent",
        atlasIDturnin = "VignetteEvent",
    },
	[Enum.QuestClassification.Threat] = {
        name = "Threat",
        atlasID = "MiniMap-VignetteArrow",
        atlasIDavailable = "vignettekillboss",
        atlasIDturnin = "vignettekillboss",
    },
	[Enum.QuestClassification.WorldQuest] = {
        name = "WorldQuest",
        atlasID = "Rotating-MinimapGuideArrow",
        atlasIDavailable = "completiondialog-warwithincampaign-worldquests-icon",
        atlasIDturnin = "completiondialog-warwithincampaign-worldquests-icon",
    },
	[Enum.QuestFrequency.Daily + 100] = {
        name = "Daily",
        atlasID = "MiniMap-VignetteArrow",
        atlasIDavailable = "quest-recurring-available",
        atlasIDturnin = "quest-recurring-turnin",
    },
	[Enum.QuestFrequency.Weekly + 100] = {
        name = "Weekly",
        atlasID = "MiniMap-VignetteArrow",
        atlasIDavailable = "quest-recurring-available",
        atlasIDturnin = "quest-recurring-turnin",
    },
    [Enum.QuestFrequency.ResetByScheduler + 100] = {
        name = "Scheduled",
        atlasID = "MiniMap-VignetteArrow",
        atlasIDavailable = "quest-recurring-available",
        atlasIDturnin = "quest-recurring-turnin",
    },
}

Addon.Defaults = {
    profile = {
        Enabled         = true,
        Debug           = false,
        PositionX       = -1,
        PositionY       = -1,
		Degrees         = 180,
	    Interval        = 60,
		Level           = 500,
		Lock            = false,
		Scale           = 1,
		Strata          = 'HIGH',
        Transparency    = 1,
        Border          = 'Blizzard Dialog Gold',
        BorderThickness = 2.5,
        BorderColor     = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        Background      = 'Blizzard Tooltip',
        BackgroundColor = {r = 1, g = 1, b = 1, a = 1},
        PointerTexture = [[Interface\MainMenuBar\UI-ExhaustionTickNormal]],
        PointerStay = true,
        Line = '',
        LineThickness = 1,
        LinePosition = 0,
        LineColor = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        UseCustomCompass = true,
        CompassTextureTexture = [[Interface\Addons\]] .. ADDON_NAME .. [[\Media\CompassHUD]],
        CompassCustomMainVisible = true,
        CompassCustomSecondaryVisible = true,
        CompassCustomDegreesVisible = true,
        CompassCustomDegreesSpan = 15,
        CompassCustomMainFont = 'Arial Narrow',
        CompassCustomSecondaryFont = 'Arial Narrow',
        CompassCustomDegreesFont = 'Arial Narrow',
        CompassCustomMainSize = 14,
        CompassCustomSecondarySize = 12,
        CompassCustomDegreesSize = 9,
        CompassCustomMainPosition = -3,
        CompassCustomSecondaryPosition = -3,
        CompassCustomDegreesPosition = -5,
        CompassCustomMainColor = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        CompassCustomSecondaryColor = {r = 0, g = 1, b = 1, a = 1},
        CompassCustomDegreesColor = {r = 1, g = 1, b = 1, a = 1},
        CompassCustomMainFlags = 'OUTLINE',
        CompassCustomSecondaryFlags = 'OUTLINE',
        CompassCustomDegreesFlags = '',
        CompassCustomTicksPosition = 'TOP',
        CompassCustomTicksForce = false,
        Visibility = "[petbattle] hide; show",
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
    local atlasInfo = C_Texture.GetAtlasInfo(atlasID)
    if not atlasInfo then return nil end
    return atlasInfo.file
end

local function getAtlasCoords(atlasID)
    local atlasInfo = C_Texture.GetAtlasInfo(atlasID)
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

Addon.Options = {
    type = "group",
    name = Const.METADATA.NAME,
    childGroups = "tab",
    args = {
        Settings = {
            type = "group",
            order = 10,
            name = "Settings",
            get = function(info)
                return Addon.db.profile[info[#info]]
            end,
            set = function(info, value)
                Addon.db.profile[info[#info]] = value
                Addon:UpdateHUDSettings()
            end,
            args = {
                Enabled = {
                    type = "toggle",
                    name = "Enabled",
                    width = "full",
                    order = 10,
                    hidden = true,
                },
                Lock = {
                    type = "toggle",
                    name = "Lock compass",
                    width = "full",
                    order = 20,
                },
                PointerStay = {
                    type = "toggle",
                    name = "Pointers stays on HUD",
                    desc = "When pointers go beyond the boundaries of the compass HUD, they will transform into sideways arrows and remain positioned at the edge of the HUD.",
                    width = "full",
                    order = 25,
                },
                Interval = {
                    type = "range",
                    order = 30,
                    name = "Number of updates per second",
                    min = 1,
                    max = 600,
                    softMin = 5,
                    softMax = 120,
                    step = 1,
                    bigStep = 5,
                },
                Degrees = {
                    type = "range",
                    order = 40,
                    name = "Degrees shown",
                    min = 45,
                    max = 360,
                    softMin = 90,
                    softMax = 270,
                    step = 1,
                    bigStep = 5,
                },
                Scale = {
                    type = "range",
                    order = 50,
                    name = "Scale",
                    min = 0.01,
                    max = 2,
                    softMin = 0.5,
                    softMax = 1.5,
                    step = 0.01,
                    bigStep = 0.05,
                    isPercent = true,
                },
                Strata = {
                    type = "select",
                    order = 60,
                    name = "Strata",
                    values = function()
                        return getStrateLevels()
                    end,
                    sorting = strataLevels,
                    style = "dropdown",
                },
                Level  = {
                    type = "range",
                    order = 70,
                    name = "Position in Strata",
                    min = 0,
                    max = 1000,
                    softMin = 0,
                    softMax = 1000,
                    step = 1,
                    bigStep = 10,
                },
                Transparency = {
                    type = "range",
                    order = 80,
                    name = "Transparency",
                    min = 0,
                    max = 1,
                    softMin = 0,
                    softMax = 1,
                    step = 0.01,
                    bigStep = 0.05,
                    isPercent = true,
                },
                Blank0 = { type = "description", order = 89, fontSize = "small",name = "",width = "full", },
                Border = {
                    type = "select",
                    order = 90,
                    name = "Border",
                    dialogControl = "LSM30_Border",
                    values = AceGUIWidgetLSMlists.border,
                },
                BorderColor = {
                    type = "color",
                    order = 100,
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
                    order = 110,
                    name = "Border thickness",
                    min = 1,
                    max = 24,
                    step = 0.5,
                },
                Background = {
                    type = "select",
                    order = 120,
                    name = "Background",
                    dialogControl = "LSM30_Background",
                    values = AceGUIWidgetLSMlists['background'],
                },
                BackgroundColor = {
                    type = "color",
                    order = 130,
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
                    order = 200,
                    name = "Edge line",
                    inline = true,
                    args = {
                        Line = {
                            type = "select",
                            order = 210,
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
                            order = 220,
                            name = "Thickness",
                            min = 1,
                            max = 24,
                            step = 0.5,
                        },
                        LinePosition = {
                            type = "range",
                            order = 230,
                            name = "Vertical adujustment",
                            min = -16,
                            max = 16,
                            step = 0.5,
                        },
                        LineColor = {
                            type = "color",
                            order = 240,
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
                Visibility = {
                    type = "input",
                    order = 490,
                    name = "Visibility State",
                    desc = "This works like a macro, you can run different situations to get the compass to show/hide differently.\nExample: '[petbattle][combat] hide;show' to hide in combat and during pet battles.",
                    width = "full",
                },
                --Blank2 = { type = "description", order = 500, fontSize = "small",name = "",width = "full", },
                Center = {
                    type = "execute",
                    order = 510,
                    name = "Center HUD horizontaly",
                    func = function() Addon:ResetPosition(true, false) end
                },
                Reset = {
                    type = "execute",
                    order = 520,
                    name = "Reset HUD position",
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
        CompassHUD = {
            type = "group",
            order = 20,
            name = "Compass HUD settings",
            get = function(info)
                return Addon.db.profile[info[#info]]
            end,
            set = function(info, value)
                Addon.db.profile[info[#info]] = value
                Addon:UpdateHUDSettings()
            end,
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
        Pointers = {
            type = "group",
            order = 30,
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

local function GetQuestPOIInfo(questID)
    -- try to get waypoint
    local completed = ReadyForTurnIn(questID)
    local uiMapID, x, y = GetNextWaypoint(questID)
    if x and y then
        Debug:Info("portal", uiMapID, x, y, completed)
        return uiMapID, x, y, completed
    end

    -- try to get waypoint from Blizzard?
    uiMapID = GetQuestAdditionalHighlights(questID)
    uiMapID = uiMapID or GetMapForQuestPOIs()
    if uiMapID and uiMapID > 0 then
        -- try to get waypoint when clicked on mapPin
        x, y = GetNextWaypointForMap(questID, uiMapID)
        if x and y then
            Debug:Info("waypoint", uiMapID, x, y, completed)
            return uiMapID, x, y, completed
        end
        -- try to parse all quests on current Map
        local quests = GetQuestsOnMap(uiMapID)
        for _, quest in pairs(quests) do
            if quest.questID == questID then
                Debug:Info("map", uiMapID, quest.x, quest.y, completed)
                return uiMapID, quest.x, quest.y, completed
            end
       end
    end
    -- fallback when quest coordinates were not found earlier (parse all quests on all maps until found)
    for _, mapId in ipairs(HBDmaps) do
        local mapInfo = GetMapInfo(mapId)
        if mapInfo.mapType == 3 then
            local quests = GetQuestsOnMap(mapId)
            for _, quest in pairs(quests) do
                if quest.questID == questID then
                    Debug:Info("parse", mapId, quest.x, quest.y, completed)
                    return mapId, quest.x, quest.y, completed
                end
           end
        end
    end
end

local function getMapId(questID)
    local uiMapID = GetMapForQuestPOIs()
    if uiMapID and uiMapID > 0 then return uiMapID end
    for _, mapId in ipairs(HBDmaps) do
        local quests = GetQuestsOnMap(mapId)
        for _, quest in pairs(quests) do
           if quest.questID == questID then
              local mapInfo = GetMapInfo(mapId)
              if mapInfo.mapType == 3 then
                 return mapId
              end
           end
        end
    end
end

local function updatePlayerCoords()
    if player.instance ~= "none" then return end

    player.x, player.y = HBD:GetPlayerWorldPosition()
    player.mapId = HBD:GetPlayerZone()
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
    -- compass texture
    HUD.compassTexture = HUD.compassTexture or HUD:CreateTexture(nil, "BORDER")
    HUD.compassTexture:SetTexture(Options.CompassTextureTexture)
    HUD.compassTexture:ClearAllPoints()
    HUD.compassTexture:SetPoint('TOPLEFT', HUD, 'TOPLEFT', Options.BorderThickness + 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMLEFT', HUD, 'BOTTOMLEFT', Options.BorderThickness + 1, Options.BorderThickness + 1)
    HUD.compassTexture:SetPoint('TOPRIGHT', HUD, 'TOPRIGHT', -Options.BorderThickness - 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMRIGHT', HUD, 'BOTTOMRIGHT', -Options.BorderThickness - 1, Options.BorderThickness + 1)

    -- static frame to display compass leters and numbers with clipchildren
    HUD.compassCustom = HUD.compassCustom or CreateFrame('Frame', ADDON_NAME .. '_directions', HUD)
    HUD.compassCustom:SetSize(textureWidth / 2, textureHeight)
    HUD.compassCustom:SetPoint('TOP', HUD, 'TOP', 0, 0)
    HUD.compassCustom:SetClipsChildren(true)

    -- movable frame to reflect player facing
    HUD.compassCustom.mask = HUD.compassCustom.mask or CreateFrame('Frame', ADDON_NAME .. '_directions', HUD.compassCustom)
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
            letters[k*side] = letters[k*side] or HUD.compassCustom.mask:CreateFontString(ADDON_NAME .. '_directions_' .. k*side, "OVERLAY", "GameFontNormal")
            letters[k*side]:SetText(v.letter)
            letters[k*side]:SetJustifyV("TOP")
            letters[k*side]:SetSize(0, 16)
            letters[k*side]:SetParent(HUD.compassCustom.mask)
            letters[k*side]:ClearAllPoints()
            letters[k*side].data = v

            if v.main then
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomMainPosition)
                letters[k*side]:SetFont(lettersMainFont, Options.CompassCustomMainSize, Options.CompassCustomMainFlags)
                letters[k*side]:SetTextColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                letters[k*side]:SetShown(Options.CompassCustomMainVisible)
            else
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomSecondaryPosition)
                letters[k*side]:SetFont(lettersSecondaryFont, Options.CompassCustomSecondarySize, Options.CompassCustomSecondaryFlags)
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
            degrees[i] = degrees[i] or HUD.compassCustom.mask:CreateFontString(ADDON_NAME .. '_degrees_' .. i, "OVERLAY", "GameFontNormal")
            degrees[i]:SetText(((i > 0) and i) or (360 + i))
            degrees[i]:SetJustifyV("TOP")
            degrees[i]:SetSize(0, 16)
            degrees[i]:ClearAllPoints()
            degrees[i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth + 1, Options.CompassCustomDegreesPosition)
            degrees[i]:SetParent(HUD.compassCustom.mask)
            degrees[i]:SetFont(degreesFont, Options.CompassCustomDegreesSize, Options.CompassCustomDegreesFlags)
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
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" ..  tickPosition .. "_" .. i, "OVERLAY")
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
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" ..  tickPosition .. "_" .. i, "OVERLAY")
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

    HUD.compassTexture:SetShown(not Options.UseCustomCompass)
    HUD.compassCustom:SetShown(Options.UseCustomCompass)
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
    if player.instance ~= "none" then return end

    frame.distance = HBD:GetWorldDistance(questPointsTable[frame.questID].instance, player.x, player.y, questPointsTable[frame.questID].x, questPointsTable[frame.questID].y)
    if not frame.distance then
        frame:Hide()
        return
    end
    frame:Show()
    frame.DistanceText:SetText(BreakUpLargeNumbers(frame.distance))
    frame.elapsed = frame.elapsed + dt
    if frame.elapsed >= 1 then
        frame.elapsed = 0
        local speed = GetUnitSpeed("player") or GetUnitSpeed("vehicle")
        if not speed or speed == 0 then -- delta
            frame.oldDistance = frame.distance
            C_Timer.After(1, function()
                local currentDistance = HBD:GetWorldDistance(questPointsTable[frame.questID].instance, player.x, player.y, questPointsTable[frame.questID].x, questPointsTable[frame.questID].y)
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

local function getPointerType(questID, questType)
    local index = questType or questUnknown
    if questType < 0 then
        return questPointerIdent .. index
    end
    local questClassification = GetQuestClassification(questID) or questUnknown
    if questClassification == Enum.QuestClassification.Recurring then
        local questIndex = GetLogIndexForQuestID(questID)
        if not questIndex then return questPointerIdent .. questUnknown end
        local questInfo = GetQuestInfo(questIndex)
        questClassification = (questInfo and questInfo.frequency + 100) or questClassification
    end
    Debug:Info("Classification", questPointers[questClassification] and questPointers[questClassification].name or "Unknown")
    return questPointerIdent .. (questPointers[questClassification] and questClassification or questUnknown)
end

local function updateQuestIcon(questPointer)
    local options = Options.Pointers[questPointer.pointerType]
    local completed = questPointsTable[questPointer.questID].completed
    questPointer.position = options.pointerOffset * textureHeight * -1
    local size = textureHeight * 1.5 * (completed and options.textureAltScale or options.textureScale)
    questPointer:SetSize(size, size)

    local gameFontNormal = { fontColor = {}}
    gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags = GameFontNormal:GetFont()
    gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a = GameFontNormal:GetTextColor()

    if options.distanceCustomFont then
        local font = LSM:Fetch("font", options.distanceFont)
        questPointer.DistanceText:SetFont(font, options.distanceFontSize, options.distanceFontFlags)
        questPointer.DistanceText:SetTextColor(options.distanceFontColor.r, options.distanceFontColor.g, options.distanceFontColor.b, options.distanceFontColor.a)
    else
        questPointer.DistanceText:SetFont(gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags)
        questPointer.DistanceText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if options.ttaCustomFont then
        local font = LSM:Fetch("font", options.ttaFont)
        questPointer.TimeText:SetFont(font, options.ttaFontSize, options.ttaFontFlags)
        questPointer.TimeText:SetTextColor(options.ttaFontColor.r, options.ttaFontColor.g, options.ttaFontColor.b, options.ttaFontColor.a)
    else
        questPointer.TimeText:SetFont(gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags)
        questPointer.TimeText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end
    if options.questCustomFont then
        local font = LSM:Fetch("font", options.questFont)
        questPointer.QuestText:SetFont(font, options.questFontSize, options.questFontFlags)
        questPointer.QuestText:SetTextColor(options.questFontColor.r, options.questFontColor.g, options.questFontColor.b, options.questFontColor.a)
    else
        questPointer.QuestText:SetFont(gameFontNormal.font, gameFontNormal.fontSize, gameFontNormal.fontFlags)
        questPointer.QuestText:SetTextColor(gameFontNormal.fontColor.r, gameFontNormal.fontColor.g, gameFontNormal.fontColor.b, gameFontNormal.fontColor.a)
    end

    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = -options.distanceOffset + 2
    local timeTextPosition = - ((options.showDistance and (options.distanceFontSize * 1.2)) or 0) - options.ttaOffset + 2
    local questTextPosition = - ((options.showDistance and (options.distanceFontSize * 1.2)) or 0) - ((options.showTTA and (options.ttaFontSize * 1.2)) or 0) - options.questOffset + 4
    questPointer.texture:SetTexCoord(0, 1, 0, 1)
    questPointer.flipped = false
    if questPointer.position > 0 then
        questPointer.flipped = true
        if completed and (options.textureAltRotate == 1) or (options.textureRotate == 1) then
            questPointer.texture:SetTexCoord(0, 1, 1, 0)
        end
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((options.showTTA and (options.ttaFontSize * 1.2)) or 0) + options.distanceOffset - 12
        timeTextPosition = options.ttaOffset - 12
        local questText = questPointsTable[questPointer.questID].text
        if questText and questText:match("%S") and options.showQuest then
            questTextPosition = options.questOffset - 6
            timeTextPosition = timeTextPosition + (options.questFontSize * 1.2)
            distanceTextPosition = distanceTextPosition + (options.questFontSize * 1.2)
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
end

local function createQuestIcon(questID, questType)
    local pointerType = getPointerType(questID, questType)
    if not Options.Pointers[pointerType] then
        Debug:Info("Quest type not found", pointerType)
        return
    end
    if not Options.Pointers[pointerType].enabled then return end

    local questPointer = CreateFrame("FRAME", ADDON_NAME..questID, HUD)
	questPointer.questID = questID
    questPointer.pointerType = pointerType
	questPointer:SetSize(textureHeight, textureHeight)
	questPointer:SetPoint("CENTER");
	questPointer.texture = questPointer:CreateTexture(ADDON_NAME..questID.."Texture")
	questPointer.texture:SetAllPoints(questPointer)
	questPointer.texture:SetAtlas(Options.Pointers[pointerType].atlasID)
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
    local isTrackingUserWaypoint = IsSuperTrackingUserWaypoint() and GetUserWaypoint()
    local trackedQuest = GetSuperTrackedQuestID()
	for questID, quest in pairs(questPointsTable) do
		if (questID == trackedQuest) or (questID == mapPin and isTrackingUserWaypoint) or (questID == tomTom and quest.track) then
			local angle = getPlayerFacingAngle(questID)
			if quest.frame and angle then
                if Options.Pointers[quest.frame.pointerType].enabled then
                    local visible = math.rad(Options.Degrees)/2
                    if angle < visible and angle > -visible then
                        quest.frame.texture:SetRotation(0)
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition * angle, quest.frame.position)
                        quest.frame:Show()
                    elseif Options.PointerStay then
                        local side = math.abs(angle)/angle
                        local option = Options.Pointers[quest.frame.pointerType]
                        if quest.completed and (option.textureAltRotate == 1) or (option.textureRotate == 1) then
                                quest.frame.texture:SetRotation(PI/2 * side * ((quest.frame.flipped and 1) or -1))
                        end
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition * side * visible, quest.frame.position)
                        quest.frame:Show()
                    else
                        quest.frame:Hide()
                    end
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
end

local function updateHUD(force)
    local facing = GetPlayerFacing() or 0
    if force or facing ~= currentFacing then
        local coord = (facing < PI and 0.5 or 1) - (facing * ADJ_FACTOR)
        --rotate texture
        HUD.compassTexture:SetTexCoord(coord - adjCoord, coord + adjCoord, 0, 1)
        -- rotate letters
        HUD.compassCustom.mask:ClearAllPoints()
        HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', (1/2 - coord) * textureWidth, 0)
        currentFacing = facing
    end
    updatePlayerCoords()
    setQuestsIcons()
end

local function updatePointerTextures()
    for _, v in pairs(questPointsTable) do
        local options = Options.Pointers[v.frame.pointerType]
        v.frame.texture:SetAtlas(v.completed and options.atlasAltID or options.atlasID)
    end
end

local function onUpdate(_, elapsed)
    if player.instance ~= "none" then return end

    timer = timer + elapsed
    if timer < (1 / Options.Interval) then return end
    timer = 0
    updateHUD(false)
end

local function createHUD()
    HUD = CreateFrame('Frame', ADDON_NAME, UIParent, "BackdropTemplate")
    HUD:SetPoint("CENTER")
    HUD:SetClampedToScreen(true)
    HUD:RegisterForDrag("LeftButton")

    HUD.pointer = HUD:CreateTexture(nil, "ARTWORK")
    HUD.pointer:SetTexture(Options.PointerTexture)
    HUD.pointer:SetSize(textureHeight * 1.5, textureHeight * 1.5)
	HUD.pointer:SetPoint('TOP', HUD, 'TOP', 0, 6)
    HUD:SetScript("OnAttributeChanged", function(self, name, value)
        if name == "state-hudvisibility" then
            if value == "show" then
                if player.instance == "none" then
                    HUD:Show()
                    HUD:SetScript('OnUpdate', onUpdate)
                end
            elseif value == "hide" then
                HUD:Hide()
                HUD:SetScript('OnUpdate', nil)
            end
        end
    end)
end

local function updateQuest(questID, x, y, uiMapID, questType, title, completed)
    if type(questPointsTable[questID]) ~= "table" then
        questPointsTable[questID] = {}
    end
    local lx, ly, instance = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    title = title or GetTitleForQuestID(questID) or ""
    questPointsTable[questID].x = lx
    questPointsTable[questID].y = ly
    questPointsTable[questID].mapId = uiMapID
    questPointsTable[questID].instance = instance
    questPointsTable[questID].text = title
    questPointsTable[questID].completed = completed
    if not questPointsTable[questID].frame then
        questPointsTable[questID].frame = createQuestIcon(questID, questType)
    end
    questPointsTable[questID].frame.QuestText:SetText(title)
    local options = Options.Pointers[questPointsTable[questID].frame.pointerType]
    questPointsTable[questID].frame.texture:SetAtlas(completed and options.atlasAltID or options.atlasID)
end

local function tomtomSetCrazyArrow(self, uid, dist, title)
    if not Options.Pointers[questPointerIdent .. tomTom].enabled then return end
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

local function tomtomRemoveWaypoint(self, uid)
    local tomTomRemoved = TomTom:GetKey(uid)
    if tomTomActive == tomTomRemoved then
        questPointsTable[tomTom].track = false
    end
end

local function OnEvent(event,...)
    Debug:Info(event)
    if event == "PLAYER_ENTERING_WORLD" then
        local _, instanceType = IsInInstance()
        player.instance = instanceType
        if player.instance == "none" then
            HUD:Show()
            HUD:SetScript('OnUpdate', onUpdate)
        else
            HUD:Hide()
            HUD:SetScript('OnUpdate',nil)
        end
    end
    if TomTom and TomTom:IsCrazyArrowEmpty() and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
    local questID = GetSuperTrackedQuestID()
    local completed = false
    Debug:Info("questID", questID)
    -- figure how to track Quest offers
    local STtype, STtypeID = C_SuperTrack.GetSuperTrackedMapPin()
    if STtype then Debug:Info("ST type", STtype) end
    if STtypeID then Debug:Info("ST type ID", STtypeID) end
    if questID and questID > 0 then
        local x, y, uiMapID
    	if IsWorldQuest(questID) then
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
        local point = GetUserWaypoint()
        if IsSuperTrackingUserWaypoint() and point then
            updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, nil, completed)
        end
    end
    setQuestsIcons()
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
    for _, pointer in pairs(Addon.Options.args.Pointers.args) do
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
            if k ~= "name" and k ~= "value" and k ~= "enabled" and optionNames[k] then
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
        local currentScale = HUD:GetScale()
        local currentWidth = HUD:GetWidth()
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
    for k, v in pairs(questPointers) do
        local name = k > 100 and "Recurring" or  v.name
        if (v.atlasIDavailable and v.atlasIDturnin and v.atlasIDavailable == v.atlasIDturnin) or (v.atlasIDavailable and not v.atlasIDturnin) and not atlasIDExists(v.atlasIDavailable) then
            pointerTextures[name] = { atlasID = v.atlasIDavailable }
            if v.atlasIDavailableScale then
                pointerTextures[name].textureScale = v.atlasIDavailableScale
            end
            if v.atlasIDavailableRotate then
                pointerTextures[name].textureRotate = v.atlasIDavailableRotate
            end
        else
            if v.atlasIDavailable and not atlasIDExists(v.atlasIDavailable) then
                pointerTextures[name.." available"] = { atlasID = v.atlasIDavailable }
                if v.atlasIDavailableScale then
                    pointerTextures[name.." available"].textureScale = v.atlasIDavailableScale
                end
                if v.atlasIDavailableRotate then
                    pointerTextures[name.." available"].textureRotate = v.atlasIDavailableRotate
                end
            end
            if v.atlasIDturnin and not atlasIDExists(v.atlasIDturnin) then
                pointerTextures[name.." turn-in"] = { atlasID = v.atlasIDturnin }
                if v.atlasIDturninScale then
                    pointerTextures[name.." turn-in"].textureScale = v.atlasIDturninScale
                end
                if v.atlasIDturninRotate then
                    pointerTextures[name.." turn-in"].textureRotate = v.atlasIDturninRotate
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
                values = {
                    ["classic"] = "Classic",
                    ["tww"] = "Modern",
                },
                get = function(info)
                    local previews = Addon.Options.args.Pointers.args.Presets.args.Preview.args
                    wipe(previews)
                    for k, v in pairs(questPointers) do
                        local atlasID = (texturePreset == "classic" and v.atlasID) or v.atlasIDavailable or v.atlasID
                        local atlasAltID = (texturePreset == "classic" and v.atlasID) or v.atlasIDturnin or v.atlasIDavailable or v.atlasID
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
                            name = v.name,
                            width = 5/6,
                        }
                    end
                    Debug:Table("Previews", previews)
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
                    for k, v in pairs(Addon.db.profile.Pointers) do
                        local questPointer = questPointers[v.value]
                        if questPointer then
                            if texturePreset == "classic" then
                                v.atlasID = questPointer.atlasID
                                v.atlasAltID = questPointer.atlasID
                            elseif texturePreset == "tww" then
                                v.atlasID = questPointer.atlasIDavailable or questPointer.atlasID
                                v.atlasAltID = questPointer.atlasIDturnin or questPointer.atlasID
                            end
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
        -- defaults
        pointersDefaults[questPointerIdent .. k] = {value = k}
        pointersDefaults[questPointerIdent .. k].name = v.name
        pointersDefaults[questPointerIdent .. k].texture = v.texture
        pointersDefaults[questPointerIdent .. k].atlasID = v.atlasID
        pointersDefaults[questPointerIdent .. k].atlasAltID = v.atlasID
        pointersDefaults[questPointerIdent .. k].textureScale = v.textureScale or getPointerTextureByAtlasID(v.atlasID).textureScale or 1
        pointersDefaults[questPointerIdent .. k].textureAltScale = v.textureScale or getPointerTextureByAtlasID(v.atlasID).textureScale or 1
        pointersDefaults[questPointerIdent .. k].textureRotate = (v.textureRotate and 1) or (getPointerTextureByAtlasID(v.atlasID).textureRotate and 1) or 0
        pointersDefaults[questPointerIdent .. k].textureAltRotate = (v.textureRotate and 1) or (getPointerTextureByAtlasID(v.atlasID).textureRotate and 1) or 0
        pointersDefaults[questPointerIdent .. k].pointerOffset = (v.name == "TomTom") and -1.1 or v.pointerOffset or 1
        pointersDefaults[questPointerIdent .. k].enabled = v.enabled or true
        pointersDefaults[questPointerIdent .. k].showDistance = v.showDistance or true
        pointersDefaults[questPointerIdent .. k].showTTA = v.showTTA or true
        pointersDefaults[questPointerIdent .. k].showQuest = v.showQuest or true
        pointersDefaults[questPointerIdent .. k].distanceOffset = v.distanceOffset or 0
        pointersDefaults[questPointerIdent .. k].ttaOffset = v.ttaOffset or 0
        pointersDefaults[questPointerIdent .. k].questOffset = v.questOffset or 0
        pointersDefaults[questPointerIdent .. k].distanceCustomFont = v.distanceCustomFont or false
        pointersDefaults[questPointerIdent .. k].distanceFont = v.distanceFont or "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].distanceFontSize = v.distanceFontSize or 12
        pointersDefaults[questPointerIdent .. k].distanceFontColor = v.distanceFontColor or {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].distanceFontFlags = v.distanceFontFlags or ""
        pointersDefaults[questPointerIdent .. k].ttaCustomFont = v.ttaCustomFont or false
        pointersDefaults[questPointerIdent .. k].ttaFont = v.ttaFont or "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].ttaFontSize = v.ttaFontSize or 12
        pointersDefaults[questPointerIdent .. k].ttaFontColor = v.ttaFontColor or {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].ttaFontFlags = v.ttaFontFlags or ""
        pointersDefaults[questPointerIdent .. k].questCustomFont = v.questCustomFont or false
        pointersDefaults[questPointerIdent .. k].questFont = v.questFont or "Friz Quadrata TT"
        pointersDefaults[questPointerIdent .. k].questFontSize = v.questFontSize or 12
        pointersDefaults[questPointerIdent .. k].questFontColor = v.questFontColor or {r = 255/255, g = 215/255, b = 0/255, a = 1}
        pointersDefaults[questPointerIdent .. k].questFontFlags = v.questFontFlags or ""

        -- options
        pointersOptionsArgs[questPointerIdent .. k] = {
            type = "group",
            order = k+10,
            childGroups = "tab",
            name = v.name,
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
            name = "Enable poniter",
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.copyFrom = {
            type = "select",
            order = 10,
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
            order = 20,
            name = "Combined options"
        }
        pointersOptionsArgs[questPointerIdent .. k].args.Textures.args.pointerOffset = {
            type = "range",
            order = 30,
            name = "Vertical adjustment",
            min = -5,
            max = 5,
            step = 0.01,
            isPercent = true,
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

    self.Options.args.Pointers.args = pointersOptionsArgs
    self.Options.args.Profiles = AceDBOptions:GetOptionsTable(self.db)
    self.Options.args.Profiles.order = 80
    AceConfig:RegisterOptionsTable(Const.METADATA.NAME, self.Options)
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME)
end

function Addon:RefreshConfig()
    Options = self.db.profile
    self:UpdateHUDSettings()
end

function Addon:OnEnable()
    HBDmaps = HBD:GetAllMapIDs()
    table.sort(HBDmaps, function(a, b) return a > b end)
    self:UpdateHUDSettings()
    HUD:SetScript('OnUpdate', onUpdate)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnEvent)
    self:RegisterEvent("ZONE_CHANGED", OnEvent)
    self:RegisterEvent("QUEST_ACCEPTED", OnEvent)
    self:RegisterEvent("QUEST_LOG_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_POI_UPDATE", OnEvent)
    self:RegisterEvent("USER_WAYPOINT_UPDATED", OnEvent)
    self:RegisterEvent("WAYPOINT_UPDATE", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_CHANGED", OnEvent)


    if TomTom then
        self:SecureHook(TomTom, "SetCrazyArrow", tomtomSetCrazyArrow)
        self:SecureHook(TomTom, "RemoveWaypoint", tomtomRemoveWaypoint)
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
