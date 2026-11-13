-- Looks: ready-made looks for the whole compass, on the Looks tab. A look changes only how things
-- look (textures, fonts, colors, borders, backgrounds, text offsets), never size, position, field
-- of view, strata, filters or which markers are shown. Applying a look first sets every look
-- setting to its default, then the look's own values, so a look always ends up the same.
-- Try keeps a copy of the look settings before it, for Revert; "New profile" puts the look into a
-- copy of the current profile instead.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, next, tostring = pairs, ipairs, type, next, tostring
local string, table = string, table

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LSM = LibStub("LibSharedMedia-3.0")
local pcall = pcall

------------------------------------------------------------------------------------------------
-- The look settings
------------------------------------------------------------------------------------------------

-- Settings of the profile that are part of the look (besides CompassCustom*, the marker texts'
-- fonts and the pointer types' looks, added in lookKeys).
local LOOK_SETTINGS = {
    -- frame
    "Transparency", "Border", "BorderThickness", "BorderColor", "Background", "BackgroundColor",
    -- central pin, arrow of a pointer staying at the edge, edge line
    "PinVisible", "PinTexture", "StayArrow", "StayAtlasID",
    "Line", "LineThickness", "LinePosition", "LineColor",
    -- compass strip: texture, or custom letters (CompassCustom*)
    "UseCustomCompass", "CompassTextureTexture",
    -- heading box
    "HeadingTransparency", "HeadingBorder", "HeadingBorderThickness", "HeadingBorderColor",
    "HeadingBackground", "HeadingBackgroundColor", "HeadingFont", "HeadingFontSize",
    "HeadingFontFlags", "HeadingFontColor", "HeadingFontPositionV", "HeadingFontPositionH",
    -- the font of all marker texts without a font of their own
    "PointerFontCustom", "PointerFont", "PointerFontSize", "PointerFontFlags", "PointerFontColor",
    -- party/raid markers
    "GroupTexture", "GroupZoneTexture",
}

-- A text's own font settings (<text><suffix>)
local FONT_SUFFIXES = { "CustomFont", "Font", "FontSize", "FontFlags", "FontColor" }

-- The party/raid name plates' look (<GroupPartyName|GroupRaidName><suffix>)
local GROUP_NAME_SUFFIXES = {
    "CustomFont", "Font", "FontSize", "FontFlags", "FontColor", "ClassColor",
    "Border", "BorderThickness", "BorderClass", "BorderColor",
    "Background", "BackgroundClass", "BackgroundColor",
}

-- A pointer type's look (Options.Pointers[<type>].<field>)
local POINTER_FIELDS = {
    "atlasID", "atlasAltID", "textureScale", "textureAltScale", "textureRotate", "textureAltRotate",
    "pointerOffset",
}
for _, text in ipairs({ "distance", "tta", "quest" }) do
    for _, suffix in ipairs(FONT_SUFFIXES) do
        table.insert(POINTER_FIELDS, text .. suffix)
    end
end

-- All profile settings (top level) a look covers; the marker sources registered so far included.
local function lookKeys()
    local keys = {}
    for _, key in ipairs(LOOK_SETTINGS) do keys[#keys + 1] = key end
    for key in pairs(Addon.Defaults.profile) do
        if key:find("^CompassCustom") then keys[#keys + 1] = key end
    end
    for _, module in ipairs(markerModules) do
        for _, text in ipairs({ "Distance", "Tta", "Title" }) do
            for _, suffix in ipairs(FONT_SUFFIXES) do
                keys[#keys + 1] = module.prefix .. text .. suffix
            end
        end
    end
    for _, plate in ipairs({ "GroupPartyName", "GroupRaidName" }) do
        for _, suffix in ipairs(GROUP_NAME_SUFFIXES) do
            keys[#keys + 1] = plate .. suffix
        end
    end
    return keys
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = copy(v) end
    return result
end

-- The current look settings, for Revert.
local function takeSnapshot()
    local snapshot = { keys = {}, pointers = {} }
    for _, key in ipairs(lookKeys()) do
        snapshot.keys[key] = copy(Options[key])
    end
    for typeKey, pointer in pairs(Options.Pointers) do
        local fields = {}
        for _, field in ipairs(POINTER_FIELDS) do fields[field] = copy(pointer[field]) end
        snapshot.pointers[typeKey] = fields
    end
    return snapshot
end

local function restoreSnapshot(snapshot)
    for key, value in pairs(snapshot.keys) do
        Options[key] = copy(value)
    end
    for typeKey, fields in pairs(snapshot.pointers) do
        local pointer = Options.Pointers[typeKey]
        if pointer then
            for _, field in ipairs(POINTER_FIELDS) do pointer[field] = copy(fields[field]) end
        end
    end
end

------------------------------------------------------------------------------------------------
-- The looks
------------------------------------------------------------------------------------------------

-- Each look: id, name, desc, and what differs from the default look:
--   settings  { [profile setting] = value } of LOOK_SETTINGS / CompassCustom* / group name plates
--   text      { font, size, flags, color }: the font of all marker texts (pointers, minimap icons,
--             other sources); texts with their own custom font follow it too
--             (settings and text may be functions returning the table, called when applied)
--   pointers  a texture preset (texturePresets, Data.lua) for the pointer textures
--   available optional function() -> whether the look can be offered (e.g. its UI addon is loaded)
local function rgb(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

-- The frame, heading box and party/raid name plates in one style: border (LSM name), its
-- thickness and color, background (LSM name) and its color.
local function frameSettings(settings, border, thickness, borderColor, background, backgroundColor)
    settings.Border, settings.BorderThickness, settings.BorderColor = border, thickness, borderColor
    settings.Background, settings.BackgroundColor = background, backgroundColor
    settings.HeadingBorder, settings.HeadingBorderThickness, settings.HeadingBorderColor = border, thickness, borderColor
    settings.HeadingBackground, settings.HeadingBackgroundColor = background, backgroundColor
    for _, plate in ipairs({ "GroupPartyName", "GroupRaidName" }) do
        settings[plate .. "Border"], settings[plate .. "BorderThickness"], settings[plate .. "BorderColor"] = border, thickness, borderColor
        settings[plate .. "Background"], settings[plate .. "BackgroundColor"] = background, backgroundColor
    end
    return settings
end

-- The custom letters: main (N, E, S, W), secondary (NE, ...) and degrees, each { font, size,
-- flags, color } or false (not shown).
local function letterSettings(settings, main, secondary, degrees)
    settings.UseCustomCompass = true
    for part, style in pairs({ Main = main, Secondary = secondary, Degrees = degrees }) do
        if style then
            settings["CompassCustom" .. part .. "Font"] = style.font
            settings["CompassCustom" .. part .. "Size"] = style.size
            settings["CompassCustom" .. part .. "Flags"] = style.flags
            settings["CompassCustom" .. part .. "Color"] = style.color
        else
            settings["CompassCustom" .. part .. "Visible"] = false
        end
    end
    return settings
end

-- An edge line: "TOP", "BOTTOM" or "BOTH", thickness, color.
local function lineSettings(settings, where, thickness, color)
    settings.Line, settings.LineThickness, settings.LinePosition, settings.LineColor = where, thickness, 0, color
    return settings
end

-- The heading text in the same font as the letters.
local function headingFont(settings, font, size, flags, color)
    settings.HeadingFont, settings.HeadingFontSize, settings.HeadingFontFlags, settings.HeadingFontColor = font, size, flags, color
    return settings
end

local WHITE, LIGHT_GREY, GREY = rgb(0.95, 0.95, 0.95), rgb(0.70, 0.72, 0.76), rgb(0.50, 0.52, 0.55)
local GOLD, PALE_GOLD = rgb(1, 0.82, 0), rgb(0.93, 0.85, 0.66)

-- Clean: flat and dark, thin border, white and grey letters, no degrees (modern and minimal UIs).
local function cleanSettings()
    local s = frameSettings({}, "CompassHUD Pixel", 1, rgb(0, 0, 0, 1), "Solid", rgb(0.06, 0.06, 0.07, 0.75))
    letterSettings(s,
        { font = "Arial Narrow", size = 14, flags = "OUTLINE", color = WHITE },
        { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = LIGHT_GREY },
        false)
    headingFont(s, "Arial Narrow", 14, "OUTLINE", WHITE)
    return s
end

-- Fade: no border, a dark band that fades out to both sides (the gradient), white letters.
local function fadeSettings()
    local s = frameSettings({}, "None", 1, rgb(0, 0, 0, 0), "CompassHUD gradient", rgb(0, 0, 0, 0.7))
    letterSettings(s,
        { font = "Arial Narrow", size = 15, flags = "OUTLINE", color = WHITE },
        { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = LIGHT_GREY },
        { font = "Arial Narrow", size = 9, flags = "OUTLINE", color = GREY })
    headingFont(s, "Arial Narrow", 14, "OUTLINE", WHITE)
    return s
end

-- Line: no frame and no background, a thin line on top; outlined letters read on any background.
local function lineOnlySettings()
    local s = frameSettings({}, "None", 1, rgb(0, 0, 0, 0), "None", rgb(0, 0, 0, 0))
    lineSettings(s, "TOP", 1, rgb(1, 1, 1, 0.6))
    letterSettings(s,
        { font = "Arial Narrow", size = 15, flags = "OUTLINE", color = WHITE },
        { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = LIGHT_GREY },
        false)
    headingFont(s, "Arial Narrow", 14, "OUTLINE", WHITE)
    return s
end

-- Gilded: no frame, gold lines above and below a faint gradient, gold and parchment letters.
local function gildedSettings()
    local s = frameSettings({}, "None", 1, rgb(0, 0, 0, 0), "CompassHUD gradient", rgb(0, 0, 0, 0.45))
    lineSettings(s, "BOTH", 1, rgb(1, 0.82, 0, 0.8))
    letterSettings(s,
        { font = "Friz Quadrata TT", size = 13, flags = "OUTLINE", color = GOLD },
        { font = "Friz Quadrata TT", size = 11, flags = "OUTLINE", color = PALE_GOLD },
        { font = "Friz Quadrata TT", size = 8, flags = "OUTLINE", color = rgb(0.78, 0.72, 0.58) })
    headingFont(s, "Friz Quadrata TT", 14, "OUTLINE", GOLD)
    return s
end

-- Night: dark glass with a cyan accent line below, cyan main letters.
local function nightSettings()
    local s = frameSettings({}, "CompassHUD Pixel", 1, rgb(0.20, 0.55, 0.65, 0.6), "Solid", rgb(0.02, 0.04, 0.07, 0.8))
    lineSettings(s, "BOTTOM", 2, rgb(0.25, 0.85, 1, 0.9))
    letterSettings(s,
        { font = "Arial Narrow", size = 14, flags = "OUTLINE", color = rgb(0.35, 0.90, 1) },
        { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = rgb(0.75, 0.85, 0.90) },
        { font = "Arial Narrow", size = 9, flags = "", color = rgb(0.40, 0.55, 0.62) })
    headingFont(s, "Arial Narrow", 14, "OUTLINE", rgb(0.35, 0.90, 1))
    return s
end

-- Classic gold: the game's dialog style, gold trim and parchment tones, Friz Quadrata.
local function classicSettings()
    local s = frameSettings({}, "Blizzard Dialog Gold", 3, rgb(1, 1, 1, 1), "Blizzard Dialog Background Dark", rgb(1, 1, 1, 0.9))
    letterSettings(s,
        { font = "Friz Quadrata TT", size = 13, flags = "OUTLINE", color = rgb(1, 0.82, 0) },
        { font = "Friz Quadrata TT", size = 11, flags = "OUTLINE", color = rgb(0.93, 0.85, 0.66) },
        { font = "Friz Quadrata TT", size = 8, flags = "", color = rgb(0.78, 0.72, 0.58) })
    headingFont(s, "Friz Quadrata TT", 14, "OUTLINE", rgb(1, 0.82, 0))
    return s
end

-- Forever: WoW: Forever's warm style, dark leather, copper trim and antique gold lettering.
local function foreverSettings()
    local s = frameSettings({}, "Blizzard Dialog", 3, rgb(0.85, 0.58, 0.36, 1), "Solid", rgb(0.10, 0.07, 0.05, 0.85))
    letterSettings(s,
        { font = "Morpheus", size = 15, flags = "OUTLINE", color = rgb(0.92, 0.74, 0.42) },
        { font = "Friz Quadrata TT", size = 11, flags = "OUTLINE", color = rgb(0.80, 0.56, 0.36) },
        { font = "Friz Quadrata TT", size = 8, flags = "", color = rgb(0.68, 0.58, 0.46) })
    headingFont(s, "Morpheus", 15, "OUTLINE", rgb(0.92, 0.74, 0.42))
    s.Line, s.LineThickness, s.LinePosition, s.LineColor = "BOTTOM", 1, 1, rgb(0.72, 0.45, 0.25, 0.9)
    return s
end

-- Forever, frameless: copper lines above and below a fading leather-brown band.
local function foreverFadeSettings()
    local s = frameSettings({}, "None", 1, rgb(0, 0, 0, 0), "CompassHUD gradient", rgb(0.16, 0.10, 0.06, 0.75))
    lineSettings(s, "BOTH", 1, rgb(0.78, 0.50, 0.28, 0.9))
    letterSettings(s,
        { font = "Morpheus", size = 15, flags = "OUTLINE", color = rgb(0.92, 0.74, 0.42) },
        { font = "Friz Quadrata TT", size = 11, flags = "OUTLINE", color = rgb(0.80, 0.56, 0.36) },
        false)
    headingFont(s, "Morpheus", 15, "OUTLINE", rgb(0.92, 0.74, 0.42))
    return s
end

-- A font by its LibSharedMedia name, if LSM has it; else the first of the fallbacks it has.
local function knownFont(name, ...)
    if type(name) == "string" and LSM:IsValid("font", name) then return name end
    for _, fallback in ipairs({ ... }) do
        if LSM:IsValid("font", fallback) then return fallback end
    end
    return "Arial Narrow"
end

local function colorOf(c, a)
    if type(c) ~= "table" then return nil end
    return rgb(c.r or c[1] or 1, c.g or c[2] or 1, c.b or c[3] or 1, a or c.a or c[4] or 1)
end

-- ElvUI's engine with its settings, once ElvUI is set up.
local function elvUI()
    local E = type(ElvUI) == "table" and ElvUI[1]
    return E and E.db and E.db.general and E.media and E or nil
end

-- ElvUI: its pixel border and transparent backdrop, its font, accent color for the main letters.
local function elvUIStyle()
    local E, general = elvUI(), nil
    general = E.db.general
    local font = knownFont(general.font, "PT Sans Narrow", "Expressway")
    local flags = type(general.fontStyle) == "string" and general.fontStyle or "OUTLINE"
    local size = type(general.fontSize) == "number" and general.fontSize or 12
    local accent = colorOf(E.media.rgbvaluecolor) or rgb(0.09, 0.52, 0.82)
    return font, flags, size, accent
end

local function elvUISettings()
    local E = elvUI()
    local font, flags, _, accent = elvUIStyle()
    local s = frameSettings({}, "CompassHUD Pixel", 1, colorOf(E.media.bordercolor, 1) or rgb(0, 0, 0),
        "Solid", colorOf(E.media.backdropfadecolor) or rgb(0.06, 0.06, 0.06, 0.8))
    letterSettings(s,
        { font = font, size = 14, flags = flags, color = accent },
        { font = font, size = 12, flags = flags, color = rgb(0.9, 0.9, 0.9) },
        { font = font, size = 9, flags = flags, color = rgb(0.55, 0.55, 0.55) })
    headingFont(s, font, 14, flags, rgb(1, 1, 1))
    return s
end

local function elvUIText()
    local font, flags, size = elvUIStyle()
    return { font = font, size = size, flags = flags, color = rgb(1, 1, 1) }
end

-- EllesmereUI: its dark panel with a faint light border, its font and accent color.
local function ellesmere()
    local EUI = EllesmereUI
    return type(EUI) == "table" and type(EUI.GetFontName) == "function" and EUI or nil
end

local function ellesmereStyle()
    local EUI = ellesmere()
    local ok, name = pcall(EUI.GetFontName)
    local font = knownFont(ok and name, "Expressway", "Arial Narrow")
    local flags = ""
    if type(EUI.GetFontOutlineFlag) == "function" then
        local found, flag = pcall(EUI.GetFontOutlineFlag)
        -- (its SLUG flag is its own: only the outline is kept)
        flags = found and type(flag) == "string" and flag:gsub(",?%s*SLUG", ""):gsub("^%s+", ""):gsub("%s+$", "") or ""
    end
    local accent = rgb(12 / 255, 210 / 255, 157 / 255)
    if type(EUI.GetAccentColor) == "function" then
        local found, r, g, b = pcall(EUI.GetAccentColor)
        if found and type(r) == "number" then accent = rgb(r, g, b) end
    end
    return font, flags, accent
end

local function ellesmereSettings()
    local EUI = ellesmere()
    local font, flags, accent = ellesmereStyle()
    local bg = EUI.DARK_BG
    local background = type(bg) == "table" and rgb(bg.r or bg[1] or 0.069, bg.g or bg[2] or 0.058, bg.b or bg[3] or 0.047, 0.8)
        or rgb(0.069, 0.058, 0.047, 0.8)
    local s = frameSettings({}, "CompassHUD Pixel", 1, colorOf(EUI.BORDER_COLOR) or rgb(1, 1, 1, 0.05), "Solid", background)
    letterSettings(s,
        { font = font, size = 14, flags = flags, color = accent },
        { font = font, size = 12, flags = flags, color = rgb(0.9, 0.9, 0.9) },
        { font = font, size = 9, flags = flags, color = rgb(0.55, 0.55, 0.55) })
    headingFont(s, font, 14, flags, rgb(1, 1, 1))
    return s
end

local function ellesmereText()
    local font, flags = ellesmereStyle()
    return { font = font, size = 12, flags = flags, color = rgb(1, 1, 1) }
end

local WHITE_TEXT = { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = rgb(0.92, 0.92, 0.92) }
local GOLD_TEXT = { font = "Friz Quadrata TT", size = 12, flags = "OUTLINE", color = GOLD }
local FOREVER_TEXT = { font = "Friz Quadrata TT", size = 12, flags = "OUTLINE", color = rgb(0.95, 0.85, 0.65) }

looks = {
    {
        id = "Clean",
        name = "Clean",
        desc = "Flat and dark with a thin border, white and grey letters, no degree numbers. Fits modern and minimal interfaces.",
        settings = cleanSettings,
        text = WHITE_TEXT,
    },
    {
        id = "Fade",
        name = "Fade",
        desc = "No frame: a dark band behind the letters that fades out to both sides, white letters.",
        settings = fadeSettings,
        text = WHITE_TEXT,
    },
    {
        id = "Line",
        name = "Line",
        desc = "No frame and no background, just a thin line on top and outlined white letters, no degree numbers.",
        settings = lineOnlySettings,
        text = WHITE_TEXT,
    },
    {
        id = "Night",
        name = "Night",
        desc = "Dark glass with a cyan line below, cyan main letters.",
        settings = nightSettings,
        text = { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = rgb(0.80, 0.92, 0.96) },
    },
    {
        id = "Classic",
        name = "Classic gold",
        desc = "The game's own dialog style: gold trim, dark background, gold and parchment letters in Friz Quadrata.",
        settings = classicSettings,
        text = GOLD_TEXT,
    },
    {
        id = "Gilded",
        name = "Gilded",
        desc = "No frame: gold lines above and below a faint fading band, gold and parchment letters.",
        settings = gildedSettings,
        text = GOLD_TEXT,
    },
    {
        id = "Forever",
        name = "Forever",
        desc = "In the style of WoW: Forever: dark leather, copper trim and antique gold lettering.",
        settings = foreverSettings,
        text = FOREVER_TEXT,
    },
    {
        id = "ForeverFade",
        name = "Forever, no frame",
        desc = "Forever's colors without a frame: copper lines above and below a fading leather-brown band.",
        settings = foreverFadeSettings,
        text = FOREVER_TEXT,
    },
    {
        id = "ElvUI",
        name = "ElvUI",
        desc = "Matches your ElvUI: its pixel border and transparent backdrop, its font and accent color. Read from ElvUI when you apply it, so try it again after changing ElvUI's colors.",
        available = function() return elvUI() ~= nil end,
        settings = elvUISettings,
        text = elvUIText,
    },
    {
        id = "EllesmereUI",
        name = "EllesmereUI",
        desc = "Matches your EllesmereUI: its dark panel with a faint border, its font and accent color. Read from EllesmereUI when you apply it, so try it again after changing its theme.",
        available = function() return ellesmere() ~= nil end,
        settings = ellesmereSettings,
        text = ellesmereText,
    },
    {
        id = "Original",
        name = "Original",
        desc = "CompassHUD's look on a fresh install: gold border, gold and cyan letters. Also undoes all your own look changes.",
    },
}

-- Puts a look into the current profile: every look setting to its default, then the look's own.
function applyLook(look)
    local defaults = Addon.Defaults.profile
    for _, key in ipairs(lookKeys()) do
        Options[key] = copy(defaults[key])
    end
    for typeKey, pointer in pairs(Options.Pointers) do
        local default = defaults.Pointers[typeKey]
        if default then
            for _, field in ipairs(POINTER_FIELDS) do pointer[field] = copy(default[field]) end
        end
    end
    -- (a function: values read when applied, e.g. a UI addon's current font and colors)
    local settings, text = look.settings, look.text
    if type(settings) == "function" then settings = settings() end
    if type(text) == "function" then text = text() end
    for key, value in pairs(settings or {}) do
        Options[key] = copy(value)
    end
    if text then
        Options.PointerFontCustom = true
        Options.PointerFont = text.font or Options.PointerFont
        Options.PointerFontSize = text.size or Options.PointerFontSize
        Options.PointerFontFlags = text.flags or Options.PointerFontFlags
        Options.PointerFontColor = copy(text.color or Options.PointerFontColor)
    end
    if look.pointers then
        applyTexturePreset(look.pointers)
    end
    Addon:UpdateHUDSettings()
end

------------------------------------------------------------------------------------------------
-- Try, Keep, Revert, New profile
------------------------------------------------------------------------------------------------

-- The look being tried: { look, snapshot (the look settings before the first Try) }
local lookTry

local function refreshOptions()
    AceConfigRegistry:NotifyChange(Addon.CONST.METADATA.NAME)
end

-- A snapshot as text (keys sorted), to tell whether the look settings changed.
local function serialize(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. serialize(value[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function tryLook(look)
    if not lookTry then
        local snapshot = takeSnapshot()
        -- the player's own look, kept in the profile (Restore my own look), also after Keep and
        -- /reload; not replaced while the compass still has a kept look unchanged (LookKept)
        if not (Options.LookBackup and Options.LookKept == serialize(snapshot)) then
            Options.LookBackup = snapshot
        end
        -- trying another look keeps the settings from before the first one, for Revert
        lookTry = { snapshot = snapshot }
    end
    lookTry.look = look
    applyLook(look)
    refreshOptions()
end

local function keepLook()
    lookTry = nil
    Options.LookKept = serialize(takeSnapshot())
    refreshOptions()
end

-- Back to the look from before the first look was tried in this profile.
local function restoreOwnLook()
    if not Options.LookBackup then return end
    lookTry = nil
    restoreSnapshot(Options.LookBackup)
    Options.LookKept = nil
    Addon:UpdateHUDSettings()
    refreshOptions()
end

local function revertLook()
    if lookTry then
        restoreSnapshot(lookTry.snapshot)
        lookTry = nil
        Addon:UpdateHUDSettings()
    end
    refreshOptions()
end

-- Another profile chosen (or copied, reset): a look being tried belongs to the previous one.
function dropLookTry()
    lookTry = nil
end

------------------------------------------------------------------------------------------------
-- The Looks tab: a row per look with Try; while it is being tried, Keep and Revert in its row.
------------------------------------------------------------------------------------------------

local function trying(look)
    return lookTry ~= nil and lookTry.look == look
end

local looksArgs = {
    LooksDesc = {
        type = "description",
        order = 1,
        name = "|cnACCOUNT_WIDE_FONT_COLOR:Ready-made looks for the whole compass: frame, letters, fonts, colors and pointer textures. They don't change its size, position or what it shows. Try one: it is shown on the compass right away, then Keep it or Revert to the look you had. Tweak it further in the other tabs.|r\n",
        fontSize = "medium",
    },
    -- the player's own look, saved when a look was first tried in this profile
    OwnLook = {
        type = "group",
        order = 5,
        inline = true,
        name = "Your own look",
        hidden = function() return not Options.LookBackup end,
        args = {
            Desc = {
                type = "description",
                order = 1,
                name = "The look you had before you first tried one here. Brings it back, also after you kept another look.",
                fontSize = "medium",
            },
            Restore = {
                type = "execute",
                order = 2,
                name = "Restore",
                func = restoreOwnLook,
            },
        },
    },
}

for index, look in ipairs(looks) do
    looksArgs["Look" .. look.id] = {
        type = "group",
        order = 10 + index,
        inline = true,
        name = function() return trying(look) and (look.name .. "  |cnGREEN_FONT_COLOR:(trying)|r") or look.name end,
        hidden = look.available and function() return not look.available() end,
        args = {
            Desc = {
                type = "description",
                order = 1,
                name = look.desc,
                fontSize = "medium",
            },
            Try = {
                type = "execute",
                order = 2,
                name = "Try",
                desc = "Show this look on the compass now; then Keep or Revert here.",
                func = function() tryLook(look) end,
                hidden = function() return trying(look) end,
            },
            Keep = {
                type = "execute",
                order = 3,
                name = "Keep",
                desc = "Keep this look.",
                func = keepLook,
                hidden = function() return not trying(look) end,
            },
            Revert = {
                type = "execute",
                order = 4,
                name = "Revert",
                desc = "Go back to the look you had before trying.",
                func = revertLook,
                hidden = function() return not trying(look) end,
            },
        },
    }
end

Addon.Options.args.Tabs.args.Looks = {
    type = "group",
    order = 15,
    name = "Looks",
    args = looksArgs,
}
