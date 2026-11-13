-- Looks: ready-made looks for the whole compass, on the Looks tab. A look changes only how things
-- look (textures, fonts, colors, borders, backgrounds, text offsets), never size, position, field
-- of view, strata, filters or which markers are shown. Applying a look first sets every look
-- setting to its default, then the look's own values, so a look always ends up the same.
-- Try keeps a copy of the look settings before it, for Revert; "New profile" puts the look into a
-- copy of the current profile instead.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, next = pairs, ipairs, type, next
local string, table = string, table

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

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
--   pointers  a texture preset (texturePresets, Data.lua) for the pointer textures
--   available optional function() -> whether the look can be offered (e.g. its UI addon is loaded)
looks = {
    {
        id = "Default",
        name = "Default",
        desc = "CompassHUD's own look: gold border, gold and cyan letters, gold arrows. Also brings back the default look after your own changes.",
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
    for key, value in pairs(look.settings or {}) do
        Options[key] = copy(value)
    end
    local text = look.text
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

local function tryLook(look)
    -- trying another look keeps the settings from before the first one, for Revert
    lookTry = { look = look, snapshot = lookTry and lookTry.snapshot or takeSnapshot() }
    applyLook(look)
    refreshOptions()
end

local function keepLook()
    lookTry = nil
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
