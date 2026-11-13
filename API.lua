-- CompassHUD's public interface for other addons: the global table CompassHUD.
--
-- Only what is documented in docs/API.md is promised; within a major API version fields and
-- functions are only added, never changed or removed. CompassHUD's own files use the same calls,
-- so the interface cannot drift away from what the addon itself needs.
--
-- The HUD frame itself is CompassHUDFrame (not part of the promised interface).

local ADDON_NAME, Addon = ...
setfenv(1, Addon.env)

local pairs, ipairs, type, pcall, error, tostring, select = pairs, ipairs, type, pcall, error, tostring, select
local math, string = math, string

local HBD = LibStub("HereBeDragons-2.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local API = {}
_G.CompassHUD = API

-- Raised only when something promised changes in a way that is not an addition.
API.API_VERSION = 1

-- Keybinding "Toggle Supertracking for Minimap icon" (Bindings.xml, binding COMPASSHUD_SUPERTRACK):
-- supertracks the minimap icon (or other marker) the player faces, or stops tracking it.
function API.SupertrackMinimapIcon()
    supertrackPOITrack()
end

-- Not promised, may change any time: the addon object (AceAddon), for inspecting CompassHUD in
-- DevTool/ViragDevTool. Its env field holds the state and functions shared by CompassHUD's files.
API.Debug = Addon

------------------------------------------------------------------------------------------------
-- Marker sources (see registerMarkerSource in Markers/Common.lua for the shared machinery)
------------------------------------------------------------------------------------------------

-- A source's function failing this many times turns the source off until the next /reload.
local MAX_ERRORS = 5

-- Settings every marker source has (<id><name>), which a source may give its own default in 'defaults'.
local SHARED_SETTINGS = {
    UseMinimapSettings = true, Supertrack = true, HideAtTarget = true,
}
for name in pairs(markerSourceDefaults) do SHARED_SETTINGS[name] = true end

-- Defaults of the shared settings a public source starts with, unless its 'defaults' say otherwise.
local SOURCE_DEFAULTS = {
    UseMinimapSettings = true, -- the Minimap icons' radius, look and texts
    Supertrack         = true,
    HideAtTarget       = true,
}

-- Calls a function of a source; an error goes to the game's error handler (BugGrabber shows it)
-- and counts towards turning the source off. Returns ok and the function's first result.
local function call(source, fn, ...)
    if source.failed then return false end
    local ok, result = pcall(fn, ...)
    if ok then return true, result end
    source.errors = source.errors + 1
    geterrorhandler()(result)
    if source.errors >= MAX_ERRORS and not source.failed then
        source.failed = true
        Addon:Print(string.format("The marker source \"%s\" kept failing and is turned off until the next /reload.", source.publicName))
        restyleMarkerSource(source)
    end
    return false
end

-- The source's function 'fn' wrapped in call() (nil stays nil).
local function protect(source, fn)
    if fn == nil then return nil end
    return function(...)
        local _, result = call(source, fn, ...)
        return result
    end
end

-- World position (on the player's continent) from x, y (world) or mapX, mapY on mapID (0-1).
-- Returns x, y and the map of map coordinates, or nil when the place is not on this continent.
local function worldPosition(x, y, mapID)
    if mapID then
        local xWorld, yWorld, instance = HBD:GetWorldCoordinatesFromZone(x, y, mapID)
        if xWorld and yWorld and instance == player.instance then
            return xWorld, yWorld, mapID
        end
        return nil
    end
    if type(x) == "number" and type(y) == "number" then
        return x, y
    end
end

-- The object a source's scan gets: where the player is, and the calls that report its markers.
local Scan = {}
Scan.__index = Scan

-- The marker reported under 'key' by an earlier scan (kept by this scan), or nil. A marker added
-- while the player was on another map is dropped: add it again.
function Scan:Get(key)
    local source = self.source
    local node = markerNode(source, key)
    if node and node.instance ~= player.uiMapID then
        releaseMarkerNode(source, key)
        return nil
    end
    return node
end

-- Adds the marker 'fields' under 'key' (replacing one with the same key). Place: x, y in world
-- coordinates, or mapX, mapY (0-1) on mapID. Returns the marker, or nil if its place is not on
-- the player's continent.
function Scan:Add(key, fields)
    local source = self.source
    if key == nil or type(fields) ~= "table" then
        error("CompassHUD: Add(key, fields) needs a key and a table", 2)
    end
    if source.nodes[key] then
        releaseMarkerNode(source, key)
    end
    local x, y, mapID
    if fields.mapID then
        x, y, mapID = worldPosition(fields.mapX, fields.mapY, fields.mapID)
    else
        x, y = worldPosition(fields.x, fields.y)
    end
    if not x then return nil end
    -- the marker table is the fields table; fields the shared code owns are set here
    fields.x, fields.y = x, y
    fields.instance, fields.frame, fields.angle, fields.distance = nil, nil, nil, nil
    fields.atlasName = fields.atlas
    fields.waypointMapID = mapID or fields.waypointMapID
    return newMarkerNode(source, key, fields)
end

-- Moves the marker under 'key': x, y in world coordinates, or map coordinates (0-1) on mapID.
-- Returns false if the new place is not on the player's continent (the marker stays).
function Scan:Move(key, x, y, mapID)
    local node = self.source.nodes[key]
    if not node then return false end
    local xWorld, yWorld, map = worldPosition(x, y, mapID)
    if not xWorld then return false end
    if map then
        node.mapX, node.mapY, node.mapID, node.waypointMapID = x, y, map, map
    end
    moveMarkerNode(node, xWorld, yWorld)
    return true
end

-- Removes the marker under 'key' now (markers not reported by a scan are removed anyway).
function Scan:Remove(key)
    releaseMarkerNode(self.source, key)
end

-- What RegisterMarkerSource returns: the source's settings and a rescan request.
local Handle = {}
Handle.__index = Handle

-- The source's setting 'name' (a shared one like "Radius", or one of its own 'options'). For a
-- multiselect option with 'item': whether that item is chosen (items never set use the option's default).
function Handle:GetSetting(name, item)
    local value = Options[self.id .. name]
    if item ~= nil and type(value) == "table" then
        local chosen = value[item]
        if chosen == nil then
            return self.multiDefaults[name] or false
        end
        return chosen
    end
    return value
end

-- Scan again on the next update (e.g. the source's data changed).
function Handle:Rescan()
    self.source.throttle = math.huge
end

local OPTION_TYPES = { toggle = true, select = true, multiselect = true }

-- AceConfig options for a source's own settings ('options' list), on the General tab after the
-- shared toggles. Their defaults go into 'defaults'.
local function sourceOptionArgs(source, handle, options, defaults)
    local args = {}
    for index, option in ipairs(options) do
        local key, kind = option.key, option.type
        if type(key) ~= "string" or not OPTION_TYPES[kind] then
            error("CompassHUD: options[" .. index .. "] needs a key and a type (toggle, select or multiselect)", 3)
        end
        local name = source.prefix .. key
        local onChange = protect(source, option.onChange)
        local function changed()
            handle:Rescan()
            if onChange then onChange(handle) end
            Addon:UpdateHUDSettings()
        end
        local values = option.values
        if type(values) == "function" then values = protect(source, values) end
        local arg = {
            type = kind,
            order = 14 + index / 100,
            name = option.name or key,
            desc = option.desc,
            width = "full",
            values = values,
        }
        if kind == "multiselect" then
            -- only the choices differing from the default are stored: new items start at the default
            local default = option.default and true or false
            handle.multiDefaults[key] = default
            defaults[key] = {}
            arg.get = function(_, item) return handle:GetSetting(key, item) end
            arg.set = function(_, item, value)
                if value == default then
                    Options[name][item] = nil
                else
                    Options[name][item] = value
                end
                changed()
            end
        else
            defaults[key] = option.default
            arg.set = function(_, value)
                Options[name] = value
                changed()
            end
        end
        args[name] = arg
    end
    return args
end

-- Registers a marker source; see docs/API.md. Returns a handle (GetSetting, Rescan).
function API.RegisterMarkerSource(def)
    if type(def) ~= "table" then
        error("CompassHUD: RegisterMarkerSource needs a table", 2)
    end
    local id = def.id
    if type(id) ~= "string" or not id:match("^%a%w*$") then
        error("CompassHUD: RegisterMarkerSource: id must be letters and digits, starting with a letter", 2)
    end
    local profile = Addon.Defaults.profile
    if profile[id .. "Enabled"] ~= nil or profile[id .. "Radius"] ~= nil or profile[id .. "TitleFont"] ~= nil then
        error("CompassHUD: RegisterMarkerSource: the id \"" .. id .. "\" is already in use", 2)
    end
    if type(def.scan) ~= "function" then
        error("CompassHUD: RegisterMarkerSource: scan must be a function", 2)
    end
    local name = type(def.name) == "string" and def.name or id
    local options = type(def.options) == "table" and def.options or {}
    for _, option in ipairs(options) do
        local key = type(option) == "table" and option.key
        if type(key) == "string" and (SHARED_SETTINGS[key] or profile[id .. key] ~= nil) then
            error("CompassHUD: RegisterMarkerSource: the option key \"" .. key .. "\" is already in use", 2)
        end
    end

    local source = { prefix = id, publicName = name, errors = 0 }
    local handle = setmetatable({ id = id, source = source, multiDefaults = {} }, Handle)
    local scan = setmetatable({ source = source }, Scan)

    local defaults = {}
    for setting, value in pairs(SOURCE_DEFAULTS) do defaults[setting] = value end
    for setting, value in pairs(type(def.defaults) == "table" and def.defaults or {}) do
        if SHARED_SETTINGS[setting] then
            defaults[setting] = value
        elseif Addon.db then
            -- (a newer API's setting on an older CompassHUD is ignored, not an error)
            Addon.DEBUG:Info("RegisterMarkerSource " .. id .. ": unknown setting in defaults: " .. tostring(setting))
        end
    end
    local extraArgs = sourceOptionArgs(source, handle, options, defaults)

    local isAvailable = protect(source, def.isAvailable)
    source.isAvailable = function()
        return not source.failed and (not isAvailable or isAvailable() and true or false)
    end
    source.title = protect(source, def.title)
    source.supertrack = protect(source, def.supertrack)
    source.bypassesRadius = protect(source, def.bypassesRadius)
    local userScan = def.scan
    source.scan = function(_, mapX, mapY, radius)
        scan.uiMapID, scan.instance = player.uiMapID, player.instance
        scan.x, scan.y = player.x, player.y
        scan.mapX, scan.mapY, scan.radius = mapX, mapY, radius
        if not call(source, userScan, scan) then
            -- a failed scan reported only part of the markers: keep the others until the next one
            for key in pairs(source.nodes) do source.seen[key] = true end
        end
    end
    source.defaults = defaults
    local speech = type(def.speech) == "table" and def.speech or {}
    -- the same order for all: the Speech tab and Minimap tracking list them alphabetically
    source.speech = {
        order = 100,
        default = speech.default and true or false,
        name = speech.name or name,
        desc = speech.desc or ("The markers shown by Minimap tracking -> " .. name .. " (turn them on there)."),
    }

    registerMarkerSource(source)
    source.throttle = math.huge -- scan on the first update

    source.optionsPage = markerModuleOptions(id, {
        name = name,
        order = 1100,
        description = type(def.description) == "string" and def.description or "",
        -- (not hidden when the source failed: its page may hold more, e.g. TomTom's crazy arrow tab)
        hidden = function()
            if not def.isAvailable then return false end
            local ok, available = pcall(def.isAvailable)
            return ok and not available
        end,
        enabledDesc = def.enabledDesc,
        what = type(def.what) == "string" and def.what or "marker",
        titleHeader = type(def.titleHeader) == "string" and def.titleHeader or "Name",
        extraArgs = extraArgs,
    })

    -- registered after CompassHUD set up its settings (another addon): add them now
    if Addon.db then
        Addon.db:RegisterDefaults(Addon.Defaults)
        TrackingOption.args[id] = source.optionsPage
        AceConfigRegistry:NotifyChange(Addon.CONST.METADATA.NAME)
    end
    return handle
end
