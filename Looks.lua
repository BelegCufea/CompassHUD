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

-- The custom letters: main (N, E, S, W), secondary (NE, ...) and degrees, each { font, size, flags, color }.
local function letterSettings(settings, main, secondary, degrees)
    settings.UseCustomCompass = true
    for part, style in pairs({ Main = main, Secondary = secondary, Degrees = degrees }) do
        settings["CompassCustom" .. part .. "Font"] = style.font
        settings["CompassCustom" .. part .. "Size"] = style.size
        settings["CompassCustom" .. part .. "Flags"] = style.flags
        settings["CompassCustom" .. part .. "Color"] = style.color
    end
    return settings
end

-- The heading text in the same font as the letters.
local function headingFont(settings, font, size, flags, color)
    settings.HeadingFont, settings.HeadingFontSize, settings.HeadingFontFlags, settings.HeadingFontColor = font, size, flags, color
    return settings
end

-- Clean: flat and dark, thin border, white and grey letters (fits modern and minimal UIs).
local function cleanSettings()
    local s = frameSettings({}, "CompassHUD Pixel", 1, rgb(0, 0, 0, 1), "Solid", rgb(0.06, 0.06, 0.07, 0.75))
    letterSettings(s,
        { font = "Arial Narrow", size = 14, flags = "OUTLINE", color = rgb(0.95, 0.95, 0.95) },
        { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = rgb(0.62, 0.64, 0.68) },
        { font = "Arial Narrow", size = 9, flags = "", color = rgb(0.5, 0.52, 0.55) })
    headingFont(s, "Arial Narrow", 14, "OUTLINE", rgb(0.95, 0.95, 0.95))
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

looks = {
    {
        id = "Default",
        name = "Default",
        desc = "CompassHUD's own look: gold border, gold and cyan letters, gold arrows. Also brings back the default look after your own changes.",
    },
    {
        id = "Clean",
        name = "Clean",
        desc = "Flat and dark with a thin border, white and grey letters. Fits modern and minimal interfaces.",
        settings = cleanSettings,
        text = { font = "Arial Narrow", size = 12, flags = "OUTLINE", color = rgb(0.92, 0.92, 0.92) },
    },
    {
        id = "Classic",
        name = "Classic gold",
        desc = "The game's own dialog style: gold trim, dark background, gold and parchment letters in Friz Quadrata.",
        settings = classicSettings,
        text = { font = "Friz Quadrata TT", size = 12, flags = "OUTLINE", color = rgb(1, 0.82, 0) },
    },
    {
        id = "Forever",
        name = "Forever",
        desc = "In the style of WoW: Forever: dark leather, copper trim and antique gold lettering.",
        settings = foreverSettings,
        text = { font = "Friz Quadrata TT", size = 12, flags = "OUTLINE", color = rgb(0.95, 0.85, 0.65) },
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

-- A copy of the current profile (as it was before trying a look), named after the look, with the look.
local function newProfileWithLook(look)
    local db = Addon.db
    if lookTry then
        restoreSnapshot(lookTry.snapshot)
        lookTry = nil
    end
    local existing = {}
    for _, name in ipairs(db:GetProfiles()) do existing[name] = true end
    local name, n = look.name, 1
    while existing[name] do
        n = n + 1
        name = look.name .. " " .. n
    end
    local current = db:GetCurrentProfile()
    db:SetProfile(name)
    db:CopyProfile(current)
    applyLook(look)
    Addon:Print(string.format("New profile \"%s\" with the look \"%s\" (Profiles to switch back).", name, look.name))
    refreshOptions()
end

------------------------------------------------------------------------------------------------
-- The Looks tab
------------------------------------------------------------------------------------------------

local looksArgs = {
    LooksDesc = {
        type = "description",
        order = 1,
        name = "|cnACCOUNT_WIDE_FONT_COLOR:Ready-made looks for the whole compass: frame, letters, fonts, colors and pointer textures. They don't change its size, position or what it shows. Try one, then keep it or go back to your own look, and tweak it further in the other tabs.|r\n",
        fontSize = "medium",
    },
    Trying = {
        type = "group",
        order = 5,
        inline = true,
        name = function() return lookTry and ("Trying: " .. lookTry.look.name) or "" end,
        hidden = function() return not lookTry end,
        args = {
            Keep = {
                type = "execute",
                order = 1,
                name = "Keep",
                desc = "Keep this look.",
                func = keepLook,
            },
            Revert = {
                type = "execute",
                order = 2,
                name = "Revert",
                desc = "Go back to your look from before trying.",
                func = revertLook,
            },
        },
    },
    RestoreOwn = {
        type = "execute",
        order = 6,
        name = "Restore my own look",
        desc = "Bring back your own look from before you first tried a look in this profile, also after Keep.",
        width = 1.5,
        hidden = function() return not Options.LookBackup or lookTry ~= nil end,
        func = restoreOwnLook,
    },
}

for index, look in ipairs(looks) do
    looksArgs["Look" .. look.id] = {
        type = "group",
        order = 10 + index,
        inline = true,
        name = look.name,
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
                desc = "Put this look on the compass now; then Keep or Revert at the top.",
                func = function() tryLook(look) end,
                disabled = function() return lookTry and lookTry.look == look end,
            },
            NewProfile = {
                type = "execute",
                order = 3,
                name = "New profile",
                desc = "Copy your current profile into a new one named after this look, with this look. Your current profile stays as it was.",
                func = function() newProfileWithLook(look) end,
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
