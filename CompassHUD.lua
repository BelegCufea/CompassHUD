local ADDON_NAME = ...
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

local Const = Addon.CONST
local Debug = Addon.DEBUG

local AceDBOptions    = LibStub("AceDBOptions-3.0")
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LSM             = LibStub("LibSharedMedia-3.0")
local HBD             = LibStub("HereBeDragons-2.0")

local GetPlayerFacing = GetPlayerFacing
local GetQuestsOnMap = C_QuestLog.GetQuestsOnMap
local GetQuestType = C_QuestLog.GetQuestType
local GetMapForQuestPOIs = C_QuestLog.GetMapForQuestPOIs
local IsWorldQuest = C_QuestLog.IsWorldQuest
local GetQuestZoneID = C_TaskQuest.GetQuestZoneID
local GetQuestLocation = C_TaskQuest.GetQuestLocation
local GetMapInfo = C_Map.GetMapInfo
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local IsSuperTrackingUserWaypoint = C_SuperTrack.IsSuperTrackingUserWaypoint

local Options
local HUD
local timer = 0
local player = {x = 0, y = 0, angle = 0, instance = ""}
local worldQuest = -50
local mapPin = -100
local tomTom = -200
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

local questTextures = {
	[tomTom] = "Interface\\MINIMAP\\MiniMap-VignetteArrow",
	[mapPin] = "Interface\\MINIMAP\\Minimap-Waypoint-MapPin-Tracked",
	[worldQuest] = "Interface\\MINIMAP\\SuperTrackerArrow",
	[0] = "Interface\\MINIMAP\\MiniMap-QuestArrow",
	[1] = "Interface\\MINIMAP\\MiniMap-VignetteArrow",
}

local ADJ_FACTOR = 1 / math.rad(720)
local textureWidth, textureHeight = 2048, 16
local texturePosition = textureWidth * ADJ_FACTOR
local adjCoord, currentFacing

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
        CompassCustomMainColor = {r = 255/255, g = 215/255, b = 0/255, a = 1},
        CompassCustomSecondaryColor = {r = 0, g = 1, b = 1, a = 1},
        CompassCustomDegreesColor = {r = 1, g = 1, b = 1, a = 1},
        CompassCustomMainFlags = 'OUTLINE',
        CompassCustomSecondaryFlags = 'OUTLINE',
        CompassCustomDegreesFlags = '',
        CompassCustomTicksPosition = 'TOP',
    },
}

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
                    values = {
                        ["WORLD"] = "1 - WORLD",
                        ["BACKGROUND"] = "2 - BACKGROUND",
                        ["LOW"] = "3 - LOW",
                        ["MEDIUM"] = "4 - MEDIUM",
                        ["HIGH"] = "5 - HIGH",
                        ["DIALOG"] = "6 - DIALOG",
                        ["FULLSCREEN"] = "7 - FULLSCREEN",
                        ["FULLSCREEN_DIALOG"] = "8 - FULLSCREEN_DIALOG",
                        ["TOOLTIP"] = "9 - TOOLTIP",
                    },
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
                Blank1 = { type = "description", order = 500, fontSize = "small",name = "",width = "full", },
                Center = {
                    type = "execute",
                    order = 510,
                    name = "Center horizontaly",
                    func = function() Addon:ResetPosition(true, false) end
                },
                Reset = {
                    type = "execute",
                    order = 520,
                    name = "Reset position",
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
                                    width = "full",
                                },
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
                            name = "Secondary cardinal directions (NE, SE, SW, NW)",
                            inline = true,
                            args = {
                                CompassCustomSecondaryVisible = {
                                    type = "toggle",
                                    order = 10,
                                    name = "Enabled",
                                    width = "full",
                                },
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
                                    width = 1,
                                },
                                CompassCustomDegreesSpan = {
                                    type = "range",
                                    order = 15,
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
                            width = "full",
                            values = {
                                [""] = "hide ticks",
                                ["TOP"] = "on top",
                                ["BOTTOM"] = "on bottom",
                                ["BOTH"] = "both on top and bottom",
                            },
                        },
                    },
                },
            },
        },
    },
}

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
    for k, v in pairs(directions) do
        letters[k] = letters[k] or HUD.compassCustom.mask:CreateFontString(ADDON_NAME .. '_directions_' .. k, "OVERLAY", "GameFontNormal")
        letters[k]:SetText(v.letter)
        letters[k]:SetJustifyV("TOP")
        letters[k]:SetSize(0, 16)
        letters[k]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", k / 720 * textureWidth + 1, -3)
        letters[k]:SetParent(HUD.compassCustom.mask)
        letters[k].data = v
        if v.main then
            letters[k]:SetFont(lettersMainFont, Options.CompassCustomMainSize, Options.CompassCustomMainFlags)
            letters[k]:SetTextColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
            letters[k]:SetShown(Options.CompassCustomMainVisible)
        else
            letters[k]:SetFont(lettersSecondaryFont, Options.CompassCustomSecondarySize, Options.CompassCustomSecondaryFlags)
            letters[k]:SetTextColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
            letters[k]:SetShown(Options.CompassCustomSecondaryVisible)
        end
    end
    for k, v in pairs(directions) do
        letters[-k] = letters[-k] or HUD.compassCustom.mask:CreateFontString(ADDON_NAME .. '_directions_-' .. k, "OVERLAY", "GameFontNormal")
        letters[-k]:SetText(v.letter)
        letters[-k]:SetJustifyV("TOP")
        letters[-k]:SetSize(0, 16)
        letters[-k]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", (k - 360) / 720 * textureWidth + 1, -3)
        letters[-k]:SetParent(HUD.compassCustom.mask)
        letters[-k].data = v
        if v.main then
            letters[-k]:SetFont(lettersMainFont, Options.CompassCustomMainSize, Options.CompassCustomMainFlags)
            letters[-k]:SetTextColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
            letters[-k]:SetShown(Options.CompassCustomMainVisible)
        else
            letters[-k]:SetFont(lettersSecondaryFont, Options.CompassCustomSecondarySize, Options.CompassCustomSecondaryFlags)
            letters[-k]:SetTextColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
            letters[-k]:SetShown(Options.CompassCustomSecondaryVisible)
        end
    end

    if type(HUD.compassCustom.degrees) ~= "table" then
        HUD.compassCustom.degrees = {}
    end
    local degrees = HUD.compassCustom.degrees

    for _, v in pairs(degrees) do
        v:Hide()
    end

    for i = -360, 360, Options.CompassCustomDegreesSpan do
        if math.abs(i) ~= 360 then
            degrees[i] = degrees[i] or HUD.compassCustom.mask:CreateFontString(ADDON_NAME .. '_degrees_' .. i, "OVERLAY", "GameFontNormal")
            degrees[i]:SetText(((i > 0) and i) or (360 + i))
            degrees[i]:SetJustifyV("TOP")
            degrees[i]:SetSize(0, 16)
            degrees[i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth + 1, -5)
            degrees[i]:SetParent(HUD.compassCustom.mask)
            degrees[i]:SetFont(degreesFont, Options.CompassCustomDegreesSize, Options.CompassCustomDegreesFlags)
            degrees[i]:SetTextColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
            degrees[i]:SetShown(Options.CompassCustomDegreesVisible)
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

    -- top ticks
    for i, v in pairs(letters) do
        ticks["TOP" .. i] = ticks["TOP" .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" .. i, "OVERLAY")
        ticks["TOP" .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
        if v:IsShown() then
            if v.data.main then
                ticks["TOP" .. i]:SetVertexColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
            else
                ticks["TOP" .. i]:SetVertexColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
            end
        end
        ticks["TOP" .. i]:SetSize(2, 2)
        ticks["TOP" .. i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth, -2)
        ticks["TOP" .. i]:SetParent(HUD.compassCustom.mask)
        ticks["TOP" .. i]:SetShown((Options.CompassCustomTicksPosition == "TOP") or (Options.CompassCustomTicksPosition == "BOTH"))
    end

    for i, v in pairs(degrees) do
        ticks["TOP" .. i] = ticks["TOP" .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" .. i, "OVERLAY")
        ticks["TOP" .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
        if v:IsShown() then
            ticks["TOP" .. i]:SetVertexColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
        end
        ticks["TOP" .. i]:SetSize(2, 4)
        ticks["TOP" .. i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth, -2)
        ticks["TOP" .. i]:SetParent(HUD.compassCustom.mask)
        ticks["TOP" .. i]:SetShown((Options.CompassCustomTicksPosition == "TOP") or (Options.CompassCustomTicksPosition == "BOTH"))
    end

    -- bottom ticks
    for i, v in pairs(letters) do
        ticks["BOTTOM" .. i] = ticks["BOTTOM" .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" .. i, "OVERLAY")
        ticks["BOTTOM" .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
        if v:IsShown() then
            if v.data.main then
                ticks["BOTTOM" .. i]:SetVertexColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
            else
                ticks["BOTTOM" .. i]:SetVertexColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
            end
        end
        ticks["BOTTOM" .. i]:SetSize(2, 2)
        ticks["BOTTOM" .. i]:SetPoint("BOTTOM", HUD.compassCustom.mask, "BOTTOM", i / 720 * textureWidth, -2)
        ticks["BOTTOM" .. i]:SetParent(HUD.compassCustom.mask)
        ticks["BOTTOM" .. i]:SetShown((Options.CompassCustomTicksPosition == "BOTTOM") or (Options.CompassCustomTicksPosition == "BOTH"))
    end

    for i, v in pairs(degrees) do
        ticks["BOTTOM" .. i] = ticks["BOTTOM" .. i] or HUD.compassCustom.mask:CreateTexture(ADDON_NAME .. "_ticks_" .. i, "OVERLAY")
        ticks["BOTTOM" .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
        if v:IsShown() then
            ticks["BOTTOM" .. i]:SetVertexColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
        end
        ticks["BOTTOM" .. i]:SetSize(2, 4)
        ticks["BOTTOM" .. i]:SetPoint("BOTTOM", HUD.compassCustom.mask, "BOTTOM", i / 720 * textureWidth, -2)
        ticks["BOTTOM" .. i]:SetParent(HUD.compassCustom.mask)
        ticks["BOTTOM" .. i]:SetShown((Options.CompassCustomTicksPosition == "BOTTOM") or (Options.CompassCustomTicksPosition == "BOTH"))
    end

    HUD.compassTexture:SetShown(not Options.UseCustomCompass)
    HUD.compassCustom:SetShown(Options.UseCustomCompass)
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

local function createQuestIcon(questID, questType)
    local questPointer = CreateFrame("FRAME", ADDON_NAME..questID, HUD)
	questPointer.questID = questID
    questPointer.position = ((questID == tomTom) and textureHeight) or -textureHeight
	questPointer:SetSize(textureHeight * 1.5, textureHeight * 1.5)
	questPointer:SetPoint("CENTER");
	questPointer.texture = questPointer:CreateTexture(ADDON_NAME..questID.."Texture")
	questPointer.texture:SetAllPoints(questPointer)
    local texture = questTextures[questType] or questTextures[1]
	questPointer.texture:SetTexture(texture)
	questPointer:Hide()
    if questID > 0 then
        questPointer:SetScript("OnEvent", function(self, event)
            if event == "QUEST_LOG_UPDATE" then
                if not select(2,QuestPOIGetIconInfo(self.questID)) then
                    questPointer:Hide()
                end
            end
        end)
        questPointer:RegisterEvent("QUEST_LOG_UPDATE")
    end

    local relativePoint = "BOTTOM"
    local distanceTextPosition = 4
    local timeTextPosition = -10
    if questPointer.position + (textureHeight / 2) > 0 then
        questPointer.texture:SetTexCoord(0, 1, 1, 0)
        relativePoint = "TOP"
        distanceTextPosition = 4 + textureHeight
        timeTextPosition = -10 + textureHeight
    end

    questPointer.DistanceText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.DistanceText:SetJustifyV("TOP")
    questPointer.DistanceText:SetSize(0, 16)
    questPointer.DistanceText:SetPoint("TOP", questPointer, relativePoint, 0, distanceTextPosition)
    questPointer.DistanceText:SetParent(questPointer)
    questPointer.TimeText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.TimeText:SetJustifyV("TOP")
    questPointer.TimeText:SetSize(0, 16)
    questPointer.TimeText:SetPoint("TOP", questPointer, relativePoint, 0, timeTextPosition)
    questPointer.TimeText:SetParent(questPointer)

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
                local visible = math.rad(Options.Degrees)/2
				if angle < visible and angle > -visible then
                    local position = texturePosition * angle
					quest.frame:SetPoint("CENTER", HUD, "CENTER", position, quest.frame.position);
					quest.frame:Show()
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

local function OnUpdate(_, elapsed)
    if player.instance ~= "none" then return end

    timer = timer + elapsed
    if timer < (1 / Options.Interval) then return end
    timer = 0
    updateHUD(false)
end

local function updateQuest(questID, x, y, uiMapID, questType)
    if type(questPointsTable[questID]) ~= "table" then
        questPointsTable[questID] = {}
    end
    local lx, ly, instance = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    questPointsTable[questID].x = lx
    questPointsTable[questID].y = ly
    questPointsTable[questID].mapId = uiMapID
    questPointsTable[questID].instance = instance
    if not questPointsTable[questID].frame then
        questPointsTable[questID].frame = createQuestIcon(questID, questType)
    end
end

local function tomtomSetCrazyArrow(self, uid, dist, title)
    local questID = tomTom
    local questType = tomTom
    updateQuest(questID, uid[2], uid[3], uid[1], questType)
    tomTomActive = TomTom:GetKey(uid)
    questPointsTable[tomTom].track = true
end

local function tomtomRemoveWaypoint(self, uid)
    local tomTomRemoved = TomTom:GetKey(uid)
    if tomTomActive == tomTomRemoved then
        questPointsTable[tomTom].track = false
    end
end

local function OnEvent(event)
    Debug:Info(event)
    if event == "PLAYER_ENTERING_WORLD" then
        local _, instanceType = IsInInstance()
        player.instance = instanceType
        if player.instance == "none" then
            HUD:Show()
            HUD:SetScript('OnUpdate', OnUpdate)
        else
            HUD:Hide()
            HUD:SetScript('OnUpdate',nil)
        end
    end
    if TomTom and TomTom:IsCrazyArrowEmpty() and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
    local questID = GetSuperTrackedQuestID()
    if questID and questID > 0 then
        local x, y, questType, uiMapID
    	if IsWorldQuest(questID) then
            uiMapID = GetQuestZoneID(questID)
            if not uiMapID then
                uiMapID = getMapId(questID)
            end
            if uiMapID then
                questType = worldQuest
                x, y = GetQuestLocation(questID, uiMapID)
            end
        else
            _, x, y = QuestPOIGetIconInfo(questID)
            questType = GetQuestType(questID)
            uiMapID = getMapId(questID)
        end
        if x and y and uiMapID then
            Debug:Info(((questType == worldQuest) and "WorldQuest") or "Quest")
            updateQuest(questID, x, y, uiMapID, questType)
        end
    else
        questID = mapPin
        local questType = mapPin
        local point = GetUserWaypoint()
        if IsSuperTrackingUserWaypoint() and point then
            Debug:Info("Map pin")
            updateQuest(questID, point.position.x, point.position.y, point.uiMapID, questType)
        end
    end
    setQuestsIcons()
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

    updateHUD(true)
end

function Addon:OnEnable()
    self.Options.args.Profiles = AceDBOptions:GetOptionsTable(self.db)
    self.Options.args.Profiles.order = 80
    AceConfig:RegisterOptionsTable(Const.METADATA.NAME, self.Options)
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME)

    HBDmaps = HBD:GetAllMapIDs()
    table.sort(HBDmaps, function(a, b) return a > b end)
    self:UpdateHUDSettings()
    HUD:SetScript('OnUpdate', OnUpdate)

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
end

function Addon:OnDisable()
    HUD:SetScript('OnUpdate', nil)
end

function Addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", self.Defaults, true)
    Options = self.db.profile
    createHUD()
end
