-- Settings UI: the AceConfig options tables and their construction (per pointer type options and defaults).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local Const = Addon.CONST
local Debug = Addon.DEBUG
local AceDBOptions      = LibStub("AceDBOptions-3.0")
local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Speech tab -> What to read out. Each marker source adds its toggle when it registers
-- (registerMarkerSource, Markers/Common.lua).
speechSourceArgs = {
    SpeechSourcesDesc = {
        type = "description",
        order = 1,
        name = "Of everything selected here, the one closest to the direction you are facing is read out. Icons are only read out while they are turned on in Minimap tracking.",
        width = "full",
    },
    SpeechSupertracked = {
        type = "toggle",
        order = 10,
        name = "Supertracked target",
        desc = "The quest, map pin, POI or vignette you are tracking.",
        width = 1,
    },
    SpeechTomTomArrow = {
        type = "toggle",
        order = 15,
        name = "TomTom crazy arrow",
        desc = "The waypoint of TomTom's crazy arrow (the TomTom pointer).",
        width = 1,
        hidden = function() return not TomTom end,
    },
}

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
                        UseMeters = {
                            type = "toggle",
                            name = "Use Meters instead of Yards",
                            desc = "If enabled, distances will be shown in meters instead of yards. (1 yard = 0.9144 meters)",
                            width = 1.5,
                            order = 28,
                        },
                        RoundDistance = {
                            type = "toggle",
                            name = "Show distances as whole numbers",
                            desc = "If enabled, distances under 1000 are rounded to whole yards/meters instead of showing a decimal (e.g. 46 instead of 45.6).",
                            width = 1.5,
                            order = 28.5,
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
                        BlankScaleRow = { type = "description", order = 45, fontSize = "small",name = "",width = "full", },
                        Scale = {
                            type = "range",
                            name = "Scale",
                            desc = "Overall scale of the compass and everything on it.",
                            order = 50,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            bigStep = 0.05,
                            isPercent = true,
                        },
                        IconScale = {
                            type = "range",
                            name = "Marker scale",
                            desc = "Size of all markers on the compass (supertracker pointers, minimap icons, party/raid members, gathering nodes) and their texts. Separate from the compass size; each marker type has its own scale on top of this.",
                            order = 55,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            isPercent = true,
                        },
                        ResetSize = {
                            type = "execute",
                            name = "Reset size",
                            desc = "Sets Scale, Width, Height and Marker scale back to their defaults (100%, Size by: Scale).",
                            order = 60,
                            confirm = true,
                            confirmText = "Reset the compass and marker size to the defaults?",
                            func = function()
                                Options.SizeMode = "SCALE"
                                Options.Scale = 1
                                Options.HorizontalScale = 1
                                Options.VerticalScale = 1
                                Options.IconScale = 1
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        BlankScale = { type = "description", order = 69, fontSize = "small",name = "",width = "full", },
                        SizeMode = {
                            type = "select",
                            name = "Size by",
                            desc = "Scale: width and height in percent of the default size.\nPixels: exact width and height of the compass, border included (before the overall Scale).\nThe markers keep their own size (Marker scale) either way.",
                            order = 70,
                            values = { SCALE = "Scale", PIXELS = "Pixels" },
                            sorting = { "SCALE", "PIXELS" },
                            style = "dropdown",
                            set = function(info, value)
                                if value == "PIXELS" and Options.SizeMode ~= "PIXELS" then
                                    -- start from the current size
                                    Options.Width = round(HUD:GetWidth())
                                    Options.Height = round(HUD:GetHeight())
                                end
                                Options.SizeMode = value
                                Addon:UpdateHUDSettings()
                            end,
                        },
                        Width = {
                            type = "range",
                            name = "Width (pixels)",
                            order = 71,
                            min = 20,
                            max = 4000,
                            softMin = 100,
                            softMax = 2500,
                            step = 1,
                            hidden = function() return Options.SizeMode ~= "PIXELS" end,
                        },
                        Height = {
                            type = "range",
                            name = "Height (pixels)",
                            order = 72,
                            min = 4,
                            max = 300,
                            softMin = 8,
                            softMax = 100,
                            step = 1,
                            hidden = function() return Options.SizeMode ~= "PIXELS" end,
                        },
                        HorizontalScale = {
                            type = "range",
                            name = "Width",
                            order = 71,
                            hidden = function() return Options.SizeMode == "PIXELS" end,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            isPercent = true,
                        },
                        VerticalScale = {
                            type = "range",
                            name = "Height",
                            order = 72,
                            hidden = function() return Options.SizeMode == "PIXELS" end,
                            min = 0.01,
                            max = 5,
                            softMin = 0.2,
                            softMax = 3,
                            step = 0.01,
                            isPercent = true,
                        },
                        BlankStrata = { type = "description", order = 99, fontSize = "small",name = "",width = "full", },
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
                            order = 101,
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
                        PointerFontGroup = {
                            type = "group",
                            order = 90,
                            name = "Pointer font",
                            inline = true,
                            args = {
                                PointerFontDesc = {
                                    type = "description",
                                    order = 1,
                                    name = "|cnACCOUNT_WIDE_FONT_COLOR:Default font for all pointer texts (supertracker, minimap tracking, party/raid names, gathering nodes). Texts with their own custom font enabled keep using it. Party/raid names keep their own color setting.|r",
                                    fontSize = "medium",
                                    width = "full",
                                },
                                PointerFontCustom = {
                                    type = "toggle",
                                    order = 10,
                                    name = "Use custom pointer font",
                                    desc = "If disabled, the game's default font (GameFontNormal) is used.",
                                    width = "full",
                                },
                                PointerFont = {
                                    type = "select",
                                    order = 20,
                                    name = "Font",
                                    width = 1,
                                    dialogControl = "LSM30_Font",
                                    values = AceGUIWidgetLSMlists['font'],
                                    disabled = function() return not Options.PointerFontCustom end,
                                },
                                PointerFontSize = {
                                    type = "range",
                                    order = 30,
                                    name = "Size",
                                    width = 3/4,
                                    min = 2,
                                    max = 36,
                                    step = 0.5,
                                    disabled = function() return not Options.PointerFontCustom end,
                                },
                                PointerFontFlags = {
                                    type = "select",
                                    order = 40,
                                    name = "Outline",
                                    width = 3/4,
                                    values = {
                                        [""] = "None",
                                        ["OUTLINE"] = "Normal",
                                        ["THICKOUTLINE"] = "Thick",
                                    },
                                    disabled = function() return not Options.PointerFontCustom end,
                                },
                                PointerFontColor = {
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
                                    disabled = function() return not Options.PointerFontCustom end,
                                },
                                PointerTitleMaxWidth = {
                                    type = "range",
                                    order = 60,
                                    name = "Max title width",
                                    desc = "Longer titles of the supertracker, minimap icon and gathering node pointers are cut off with \"...\". 0 = no limit.",
                                    width = "full",
                                    min = 0,
                                    max = 1000,
                                    softMax = 600,
                                    step = 5,
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
                Speech = {
                    type = "group",
                    order = 50,
                    name = "Speech",
                    args = {
                        SpeechDesc = {
                            type = "description",
                            order = 1,
                            name = "|cnACCOUNT_WIDE_FONT_COLOR:Reads out the name of what is in front of you on the compass, with the game's text to speech. Each one is read once, when you turn to face it.|r\n",
                            fontSize = "medium",
                            width = "full",
                        },
                        SpeechEnabled = {
                            type = "toggle",
                            order = 10,
                            name = "Read out what you are facing",
                            width = "full",
                            disabled = function() return not speechAvailable() end,
                        },
                        SpeechSources = {
                            type = "group",
                            order = 20,
                            name = "What to read out",
                            inline = true,
                            disabled = function() return not Options.SpeechEnabled end,
                            args = speechSourceArgs,
                        },
                        SpeechDistance = {
                            type = "toggle",
                            order = 30,
                            name = "Also read out the distance",
                            desc = "E.g. \"Innkeeper Farley, 45 yards\". Yards or meters as set on the General tab.",
                            width = "full",
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechOnlyShownNames = {
                            type = "toggle",
                            order = 31,
                            name = "Only read out names shown on the compass",
                            desc = "Read something out only while its name is shown on the compass. With a texts visibility angle, that is only the icon showing its texts (see the Texts tab of each section in Minimap tracking).",
                            width = "full",
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechDegrees = {
                            type = "range",
                            order = 50,
                            name = "Facing angle",
                            desc = "Something counts as in front of you when it is at most this many degrees left or right of the direction you are facing.",
                            min = 1,
                            max = 45,
                            step = 1,
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechDelay = {
                            type = "range",
                            order = 60,
                            name = "Delay (seconds)",
                            desc = "How long you have to face something before it is read out, so turning quickly does not read out everything you pass.",
                            min = 0,
                            max = 3,
                            step = 0.1,
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        BlankVoice = { type = "description", order = 69, fontSize = "small",name = "",width = "full", },
                        SpeechVoice = {
                            type = "select",
                            order = 70,
                            name = "Voice",
                            width = 1.6,
                            values = function() return getSpeechVoices() end,
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechTest = {
                            type = "execute",
                            order = 75,
                            name = "Test",
                            func = function() speakText(Const.METADATA.NAME .. " text to speech") end,
                            disabled = function() return not speechAvailable() end,
                        },
                        BlankRate = { type = "description", order = 79, fontSize = "small",name = "",width = "full", },
                        SpeechRate = {
                            type = "range",
                            order = 80,
                            name = "Rate",
                            min = -10,
                            max = 10,
                            step = 1,
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechVolume = {
                            type = "range",
                            order = 90,
                            name = "Volume",
                            min = 0,
                            max = 100,
                            step = 1,
                            disabled = function() return not Options.SpeechEnabled end,
                        },
                        SpeechChannelNote = {
                            type = "description",
                            order = 100,
                            name = "\nThe game plays text to speech outside its sound channels (Master, Dialog, ...), so it has its own volume here.",
                            width = "full",
                        },
                    },
                },
            },
        },
    },
}

SupertrackerOptions = {
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

TrackingOption = {
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

-- Options of one marker text (distance, time to arrive, title): header, show, vertical adjustment
-- and custom font. 'key' is the option name part (e.g. "QuestieDistance"), 'show' the name of
-- its Show option (e.g. "QuestieShowDistance").
local function markerTextOptions(args, key, show, header, order)
    local function noCustomFont() return not Options[key .. "CustomFont"] end
    args["Header" .. key] = { type = "header", order = order, name = header }
    args[show] = { type = "toggle", order = order + 10, name = "Show" }
    args[key .. "Offset"] = { type = "range", order = order + 20, name = "Vertical adjustment", min = -20, max = 20, step = 0.5 }
    args[key .. "CustomFont"] = { type = "toggle", order = order + 30, name = "Use custom font" }
    args[key .. "Font"] = {
        type = "select", order = order + 40, name = "Font", width = 1,
        dialogControl = "LSM30_Font", values = AceGUIWidgetLSMlists['font'], disabled = noCustomFont,
    }
    args[key .. "FontSize"] = { type = "range", order = order + 50, name = "Size", width = 3/4, min = 2, max = 36, step = 0.5, disabled = noCustomFont }
    args[key .. "FontFlags"] = {
        type = "select", order = order + 60, name = "Outline", width = 3/4,
        values = { [""] = "None", ["OUTLINE"] = "Normal", ["THICKOUTLINE"] = "Thick" }, disabled = noCustomFont,
    }
    args[key .. "FontColor"] = {
        type = "color", order = order + 70, name = "Color", width = 1/2, hasAlpha = true, disabled = noCustomFont,
        get = function(info)
            local color = Addon.db.profile[info[#info]]
            return color.r, color.g, color.b, color.a
        end,
        set = function(info, r, g, b, a)
            local color = Addon.db.profile[info[#info]]
            color.r, color.g, color.b, color.a = r, g, b, a
            Addon:UpdateHUDSettings()
        end,
    }
end

-- Filter tab of the minimap icons: one row per icon type (show + any distance), and a box for
-- each type with options of its own. The values are kept in POITrackFilter / POITrackWholeZone.
local ANY_DISTANCE_DESC = "Show these icons at any distance, not only within the scanning radius: everything the game lists for the current map (for flight points this can be the whole continent)."

-- a checkbox for one entry of the POITrackFilter or POITrackWholeZone table
local function filterToggle(order, name, desc, tableName, key, width)
    return {
        type = "toggle",
        order = order,
        name = name,
        desc = desc,
        width = width,
        get = function() return Addon.db.profile[tableName][key] or false end,
        set = function(_, value)
            Addon.db.profile[tableName][key] = value
            Addon:UpdateHUDSettings()
        end,
    }
end

-- icon types without options of their own, in the order shown
local placeTypes = {
    { poiTypeEnum.HUB, "Hubs (cities, towns)" },
    { poiTypeEnum.EVENT, "Events" },
    { poiTypeEnum.DELVE, "Delves" },
    { poiTypeEnum.INSTANCE, "Dungeons and raids" },
    { poiTypeEnum.PORTAL, "Teleports" },
    { poiTypeEnum.LINK, "Links (shortcuts, paths)" },
    { poiTypeEnum.RACE, "Dragonriding races" },
    { poiTypeEnum.VIGNETTE, "Vignettes (rares, treasures)" },
    { poiTypeEnum.OTHER, "Other places" },
}

local placeArgs = {}
for index, place in ipairs(placeTypes) do
    local key, label = place[1], place[2]
    placeArgs[key .. "Show"] = filterToggle(index * 10, label, nil, "POITrackFilter", key, 1.2)
    placeArgs[key .. "AnyDistance"] = filterToggle(index * 10 + 1, "Any distance", ANY_DISTANCE_DESC, "POITrackWholeZone", key, 0.9)
    placeArgs[key .. "Break"] = { type = "description", order = index * 10 + 2, name = "", width = "full" }
end

local poiTrackFilterArgs = {
    FilterDescription = {
        type = "description",
        order = 0,
        name = "Choose which icons are shown on the compass.",
        fontSize = "medium",
        width = "full",
    },
    Places = {
        type = "group",
        order = 10,
        name = "Places",
        args = placeArgs,
    },
    FlightPoints = {
        type = "group",
        order = 20,
        name = "Flight points",
        args = {
            Show = filterToggle(1, "Show", "Flight points of your faction.", "POITrackFilter", poiTypeEnum.TAXI, 0.5),
            AnyDistance = filterToggle(2, "Any distance", ANY_DISTANCE_DESC, "POITrackWholeZone", poiTypeEnum.TAXI, 0.8),
            Closest = filterToggle(3, "Only the closest one", "Show only the flight point closest to you.", "POITrackFilter", poiTypeEnum.TAXI .. "_min", 1.0),
        },
    },
    WorldQuests = {
        type = "group",
        order = 30,
        name = "World quests",
        args = {
            POITrackWQFilter = {
                type = "select",
                order = 1,
                name = "Show",
                desc = "Which world quests are shown.",
                width = 1.0,
                values = function() return getPOIFrackWQFilter() end,
            },
            POITrackWQWholeZone = {
                type = "toggle",
                order = 2,
                name = "Any distance",
                desc = ANY_DISTANCE_DESC,
                width = 0.9,
            },
        },
    },
    Quests = {
        type = "group",
        order = 15,
        name = "Quests",
        desc = "Quests from your quest log.",
        args = {
            QuestsDescription = {
                type = "description",
                order = 0,
                name = "Quests from your quest log that have a place on the current map: the objective area, or the turn-in when complete.",
                width = "full",
            },
            Show = filterToggle(1, "Show", "Quests from your quest log that have a place on the current map.", "POITrackFilter", poiTypeEnum.QUEST, 0.5),
            AnyDistance = filterToggle(2, "Any distance", ANY_DISTANCE_DESC, "POITrackWholeZone", poiTypeEnum.QUEST, 0.8),
            POITrackQuestCurrentZone = {
                type = "toggle",
                order = 3,
                name = "Only this zone",
                desc = "Only quests in the zone you are in. Without it, quests of neighboring places shown on the map are included too (e.g. Stormwind while in Elwynn Forest).",
                width = 1.0,
            },
            POITrackQuestWhich = {
                type = "select",
                order = 4,
                name = "Progress",
                desc = "Show all quests, only the ones still in progress, or only the ones ready to turn in.",
                width = 1.0,
                values = { both = "All", active = "In progress", complete = "Ready to turn in" },
                sorting = { "both", "active", "complete" },
            },
            QuestsSpacer = { type = "description", order = 4.5, name = "", width = 0.15 },
            POITrackQuestIcon = {
                type = "select",
                order = 5,
                name = "Icon",
                desc = "Like the supertracker: the icons of your supertracker pointer settings for each quest type.\nGame quest icons: the game's quest marks.",
                width = 1.0,
                values = { pointer = "Like the supertracker", game = "Game quest icons" },
                sorting = { "pointer", "game" },
            },
        },
    },
}

-- Texts tab of the minimap icons: the faced-icon settings, then the three texts
local poiTrackTextArgs = {
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
        desc = "Set the opacity of the text labels for icon near the heading.\nThis option is only enabled when 'Texts visibility angle' is greater than 0.",
        min = 0,
        max = 1,
        softMin = 0.1,
        softMax = 1,
        step = 0.01,
        isPercent = true,
        disabled = function() return Options.POITrackTextsDegrees == 0 end,
    },
}
markerTextOptions(poiTrackTextArgs, "POITrackDistance", "POITrackShowDistance", "Distance text", 100)
markerTextOptions(poiTrackTextArgs, "POITrackTta", "POITrackShowTTA", "Time to arrive", 200)
markerTextOptions(poiTrackTextArgs, "POITrackTitle", "POITrackShowTitle", "Icon name", 300)

POITrackOptions = {
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
            -- one sub-tab per kind of icon, so each fits without scrolling
            childGroups = "tab",
            args = poiTrackFilterArgs,
        },
        Texts = {
            type = "group",
            order = 30,
            name = "Texts",
            args = poiTrackTextArgs,
        },
        Supertracking = {
            type = "group",
            order = 40,
            name = "Supertracking",
            args = {
                POITrackWaypointNote = {
                    type = "description",
                    order = 9,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:This feature attempts to set world supertracking for currently facing minimap icon as if you had clicked the POI on the World Map.\nIf no valid POI is found, a user waypoint will be set instead.|r\n\n",
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
                        -- bindings can't be changed in combat
                        if InCombatLockdown() then return end
                        local oldKey1, oldKey2 = GetBindingKey("COMPASSHUD_SUPERTRACK")
                        if oldKey1 then SetBinding(oldKey1) end
                        if oldKey2 then SetBinding(oldKey2) end
                        if key and key ~= "" then
                            SetBinding(key, "COMPASSHUD_SUPERTRACK")
                        end
                        -- without this the change is lost at logout
                        SaveBindings(GetCurrentBindingSet())
                    end,
                },
                HidePOIAtTarget = {
                    type = "toggle",
                    name = "Hide icon at the tracked target",
                    desc = "If an icon is at the same place (within 10 yards) as the quest, map pin or POI the game is tracking, show only the supertracker pointer. The icon comes back as soon as the game tracks something else. The keybind can still toggle its tracking.",
                    width = "full",
                    order = 20,
                },
                HeaderPOITrackTexture = {
                    type = "header",
                    order = 108,
                    name = "User Waypoint Texture"
                },
                POITrackTextureNote = {
                    type = "description",
                    order = 109,
                    name = "|cnACCOUNT_WIDE_FONT_COLOR:Only applies if a user waypoint is used.\nOtherwise, the settings in Supertracker for the relevant pointer category are applied.|r\n\n",
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

GroupOptions = {
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

-- Settings of an integration marker module (Markers/Common.lua): the same layout for each, with
-- option names <prefix><setting> mirroring the minimap icons' POITrack<setting>.
--   prefix  option name prefix ("Questie", "GatherMate")
--   info    { name, order, description, hidden, enabledDesc, what (e.g. "icon"), titleHeader,
--             extraArgs (more options on the General tab) }
local function markerModuleOptions(prefix, info)
    -- greyed out while the module uses the minimap icons' settings
    local function usesMinimapSettings() return Options[prefix .. "UseMinimapSettings"] end
    local what = info.what
    local general = {
        ModuleDescription = {
            type = "description",
            order = 0,
            name = "|cnACCOUNT_WIDE_FONT_COLOR:" .. info.description .. "|r\n",
            fontSize = "medium",
        },
        [prefix .. "Enabled"] = { type = "toggle", order = 10, name = "Enabled", desc = info.enabledDesc, width = 1.2 },
        [prefix .. "UseMinimapSettings"] = {
            type = "toggle",
            order = 11,
            name = "Use minimap icons settings",
            desc = "Use the settings of Minimap tracking -> Minimap icons (radius, throttle, position, scale, opacity, texts) instead of the ones below and on the Texts tab.",
            width = 1.2,
        },
        [prefix .. "Supertrack"] = {
            type = "toggle",
            order = 12,
            name = "Use supertracker keybinding",
            desc = "The supertrack keybinding of the minimap icons (Minimap icons -> Supertracking) also tracks the " .. what .. " you face, with its name and icon (a quest in your quest log is tracked as the quest).",
            width = 1.2,
        },
        -- the same setting as on the Speech tab
        ["Speech" .. prefix] = {
            type = "toggle",
            order = 13,
            name = "Use text to speech",
            desc = "Read out the " .. what .. " you face (the same setting as on the Speech tab). Text to speech itself is turned on on the Speech tab.",
            width = 1.2,
            disabled = function() return not Options.SpeechEnabled end,
        },
        [prefix .. "Radius"] = {
            type = "range",
            order = 20,
            name = "Scanning radius",
            desc = "Only " .. what .. "s within this distance are shown. 0 = the whole zone.",
            disabled = usesMinimapSettings,
            min = 0,
            max = 5000,
            softMax = 2000,
            step = 1,
            bigStep = 10,
        },
        [prefix .. "Interval"] = {
            type = "range",
            order = 30,
            name = "Update throttle",
            desc = "Interval between scans for " .. what .. "s, relative to the 'Update Frequency' set on the 'General' tab.\nAt 30 with an 'Update Frequency' of 60 (defaults), they are scanned twice per second.",
            disabled = usesMinimapSettings,
            min = 1,
            max = 300,
            softMax = 120,
            step = 1,
        },
        [prefix .. "HideAtTarget"] = {
            type = "toggle",
            order = 40,
            name = "Hide " .. what .. " at the tracked target",
            desc = "While the game tracks a target at the place of a " .. what .. ", only its supertracker pointer is shown.",
            width = "full",
            disabled = usesMinimapSettings,
        },
        ["Header" .. prefix .. "Node"] = { type = "header", order = 50, name = "Icon" },
        [prefix .. "Offset"] = {
            type = "range", order = 60, name = "Vertical adjustment", disabled = usesMinimapSettings,
            min = -64, max = 64, step = 0.5,
        },
        [prefix .. "Scale"] = {
            type = "range", order = 70, name = "Scale", disabled = usesMinimapSettings,
            min = 0, max = 3, step = 0.01, isPercent = true,
        },
        ["Header" .. prefix .. "Opacity"] = { type = "header", order = 100, name = "Opacity" },
        [prefix .. "OpacityDescription"] = {
            type = "description",
            order = 110,
            name = "Farther " .. what .. "s fade from the maximum to the minimum opacity at the scanning radius (1000 yards when it is 0).",
            fontSize = "medium",
        },
        [prefix .. "OpacityMin"] = {
            type = "range", order = 120, name = "Minimum opacity", disabled = usesMinimapSettings,
            min = 0, max = 1, step = 0.01, isPercent = true,
        },
        [prefix .. "OpacityMax"] = {
            type = "range", order = 130, name = "Maximum opacity", disabled = usesMinimapSettings,
            min = 0, max = 1, step = 0.01, isPercent = true,
        },
        [prefix .. "OpacityMinRadius"] = {
            type = "range", order = 140, name = "Full opacity within",
            desc = what:gsub("^%l", string.upper) .. "s closer than this keep the maximum opacity.",
            disabled = usesMinimapSettings, min = 0, max = 2000, softMax = 500, step = 1,
        },
    }
    for key, option in pairs(info.extraArgs or {}) do
        general[key] = option
    end

    local texts = {
        [prefix .. "TextsDegrees"] = {
            type = "range",
            order = 10,
            name = "Texts visibility angle",
            desc = "Texts are shown only on the " .. what .. " you face within this angle. 0 = texts on every " .. what .. ".",
            min = 0,
            max = 30,
            step = 0.5,
        },
        [prefix .. "OpacitySelected"] = {
            type = "range",
            order = 20,
            name = "Opacity of visible texts",
            desc = "Opacity of the " .. what .. " whose texts are shown.",
            min = 0.1,
            max = 1,
            step = 0.01,
            isPercent = true,
            disabled = function() return Options[prefix .. "TextsDegrees"] == 0 end,
        },
    }
    markerTextOptions(texts, prefix .. "Distance", prefix .. "ShowDistance", "Distance text", 100)
    markerTextOptions(texts, prefix .. "Tta", prefix .. "ShowTTA", "Time to arrive", 200)
    markerTextOptions(texts, prefix .. "Title", prefix .. "ShowTitle", info.titleHeader, 300)

    return {
        type = "group",
        order = info.order,
        name = info.name,
        childGroups = "tab",
        hidden = info.hidden,
        args = {
            Settings = { type = "group", order = 10, name = "General", args = general },
            Texts = { type = "group", order = 20, name = "Texts", disabled = usesMinimapSettings, args = texts },
        },
    }
end

GatherMateOptions = markerModuleOptions("GatherMate", {
    name = "GatherMate2 / GatherLite",
    order = 1010,
    description = "Shows gathering nodes from GatherMate2, or from GatherLite when GatherMate2 is not loaded. Which node types is decided by the addon's own settings.",
    -- only with one of the two addons loaded
    hidden = function() return not (GatherMate2 or GatherLite) end,
    what = "node",
    titleHeader = "Node name",
})

QuestieOptions = markerModuleOptions("Questie", {
    name = "Questie",
    order = 1020,
    description = "Shows the icons Questie places on the minimap. Which ones is decided by Questie's own settings.",
    hidden = function() return not questieLoaded() end,
    enabledDesc = "Questie has no public interface for its icons, so a Questie update may turn this off until CompassHUD is updated.",
    what = "icon",
    titleHeader = "Name",
    extraArgs = {
        QuestieShowType = {
            type = "toggle",
            order = 14,
            name = "Show the type after the name",
            desc = "Adds the kind of icon in parentheses after the name, e.g. \"Innkeeper Farley (Innkeeper)\" or \"Princess Must Die! (Turn-in)\".",
            width = "full",
        },
    },
})

TomTomOptions = markerModuleOptions("TomTom", {
    name = "TomTom",
    order = 1030,
    description = "Shows your TomTom waypoints on the current map. The crazy arrow's waypoint is shown as the TomTom pointer instead. The supertracker keybinding makes the waypoint you face the crazy arrow's target.",
    hidden = function() return not TomTom end,
    what = "waypoint",
    titleHeader = "Waypoint name",
    extraArgs = {
        TomTomOtherZones = {
            type = "toggle",
            order = 14,
            name = "Waypoints from other zones",
            desc = "Also show waypoints set on other maps of the continent you are on (e.g. in the zone around a city). Off: only waypoints set on the map you are on.",
            width = "full",
        },
    },
})

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
                -- copy tables (colors), so the two pointer types can be edited independently afterwards
                Addon.db.profile.Pointers[to][k] = type(v) == "table" and CopyTable(v) or v
            end
        end
        AceConfigRegistry:NotifyChange(Const.METADATA.NAME)
        Addon:UpdateHUDSettings()
    end
    StaticPopup_Show(copyPointersDialogName)
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
            if ((v.atlasIDavailable and v.atlasIDturnin and v.atlasIDavailable == v.atlasIDturnin) or (v.atlasIDavailable and not v.atlasIDturnin)) and not atlasIDExists(v.atlasIDavailable) then
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

    -- Fills the preview rows of the Presets page for the selected texture preset.
    -- Built when the preset changes (and once at start), not in the option's get, so reading
    -- the setting does not itself request another options refresh.
    local function buildPresetPreviews()
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
    end

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
                    return texturePreset
                end,
                set = function(info, value)
                    texturePreset = value
                    buildPresetPreviews()
                    AceConfigRegistry:NotifyChange(Const.METADATA.NAME)
                end,
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
        pointersDefaults[questPointerIdent .. k].textureAltRotate = (preset.textureRotateTurnin and 1) or (reference and reference.textureRotateTurnin and 1) or (reference and reference.textureRotateAvailable and 1) or (preset.textureRotateAvailable and 1) or 0
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
    -- The TomTom pointer's settings live on the TomTom page (Crazy arrow tab), next to the
    -- waypoints. Its options read and write Options.Pointers[<pointer type>] by their place in the
    -- tree (two levels up), so the tab keeps the key "Pointers" and the pointer type's key.
    local arrowKey = questPointerIdent .. tomTom
    local arrowOptions = pointersOptionsArgs[arrowKey]
    pointersOptionsArgs[arrowKey] = nil
    arrowOptions.inline = true
    arrowOptions.name = ""
    arrowOptions.order = 10
    TomTomOptions.args.Pointers = {
        type = "group",
        order = 30,
        name = "Crazy arrow",
        get = SupertrackerOptions.args.Pointers.get,
        set = SupertrackerOptions.args.Pointers.set,
        args = {
            ArrowDescription = {
                type = "description",
                order = 0,
                name = "The waypoint of TomTom's crazy arrow is shown as a pointer, like the target the game tracks.\n",
                fontSize = "medium",
            },
            HideTomTomAtTarget = {
                type = "toggle",
                order = 1,
                name = "Hide duplicate TomTom pointer",
                desc = "If the crazy arrow's waypoint is at the same place (within 10 yards) as the quest, map pin or POI the game is tracking, show only the game's pointer. The TomTom pointer comes back as soon as the game tracks something else.",
                width = "full",
                get = function() return Options.HideTomTomAtTarget end,
                set = function(_, value)
                    Options.HideTomTomAtTarget = value
                    Addon:UpdateHUDSettings()
                end,
            },
            -- the same setting as on the Speech tab
            SpeechTomTomArrow = {
                type = "toggle",
                order = 2,
                name = "Use text to speech",
                desc = "Read out the crazy arrow's waypoint when you face it (the same setting as on the Speech tab). Text to speech itself is turned on on the Speech tab.",
                width = "full",
                disabled = function() return not Options.SpeechEnabled end,
                get = function() return Options.SpeechTomTomArrow end,
                set = function(_, value) Options.SpeechTomTomArrow = value end,
            },
            -- the pointer type's worldmapTexture: the texture given with the target (setSupertrackTarget)
            ArrowTomTomIcon = {
                type = "toggle",
                order = 3,
                name = "Use TomTom's icon",
                desc = "Show the waypoint icon of TomTom's minimap theme for the pointer, both in progress and for a turn-in, instead of the textures below.",
                width = "full",
                get = function() return Options.Pointers[arrowKey].worldmapTexture end,
                set = function(_, value)
                    Options.Pointers[arrowKey].worldmapTexture = value
                    Addon:UpdateHUDSettings()
                end,
            },
            [arrowKey] = arrowOptions,
        },
    }
    TrackingOption.args.POITrack = POITrackOptions
    TrackingOption.args.Group = GroupOptions
    TrackingOption.args.GatherMate = GatherMateOptions
    TrackingOption.args.Questie = QuestieOptions
    TrackingOption.args.TomTom = TomTomOptions
    self.Options.args.Supertracker = SupertrackerOptions
    buildPresetPreviews()
    self.Options.args.TrackingIntegrations = TrackingOption
    self.Options.args.Profiles = AceDBOptions:GetOptionsTable(self.db)
    self.Options.args.Profiles.order = 900

    AceConfig:RegisterOptionsTable(Const.METADATA.NAME, self.Options)
    _, Addon.categoryID = AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, nil, nil, "Tabs")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Supertracker", Const.METADATA.NAME, "Supertracker")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Minimap tracking", Const.METADATA.NAME, "TrackingIntegrations")
    AceConfigDialog:AddToBlizOptions(Const.METADATA.NAME, "Profiles", Const.METADATA.NAME, "Profiles")
end
