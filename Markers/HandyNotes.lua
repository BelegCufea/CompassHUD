-- HandyNotes markers: the minimap nodes of HandyNotes plugins (MapNotes, the expansion plugins,
-- ...) as a marker source (Markers/Common.lua). Uses HandyNotes' documented plugin interface:
-- HandyNotes.plugins[name]:GetNodes2(uiMapID, minimap) returns an iterator of
-- coord, uiMapID, iconpath, scale, alpha. Names are not part of it: they are read from the node
-- table many plugins pass as the iterator's state (see nodeName). Plugins turned off in HandyNotes,
-- or here (HandyNotesPlugins), are skipped; every plugin call is protected (pcall).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, type, pcall, tostring, math, table, wipe = pairs, type, pcall, tostring, math, table, wipe
local GetTime = GetTime

local HBD = LibStub("HereBeDragons-2.0")

local MAX_NODES = 2000   -- per plugin and scan, against a runaway iterator
local REFRESH = 10       -- seconds: plugin data is read again at least this often

function handyNotesLoaded()
    return HandyNotes ~= nil and type(HandyNotes.plugins) == "table"
end

handyNotesNodes = registerMarkerSource({
    prefix = "HandyNotes",
    isAvailable = handyNotesLoaded,
    defaults = {
        UseMinimapSettings = true,
        Supertrack         = true,
        HideAtTarget       = true,
        Plugins            = {}, -- [plugin name] = false: not shown on the compass
    },
    speech = {
        order = 60,
        default = true,
        name = "HandyNotes icons",
        desc = "The icons shown by Minimap tracking -> HandyNotes (turn them on there).",
    },
    -- the plugins' nodes of the current map, read from the plugins only when needed (cache)
    cache = { uiMapID = nil, time = 0, entries = {} },
})

-- A name readable as a plugin's label: "HandyNotes_TheWarWithin" -> "TheWarWithin".
function handyNotesPluginLabel(pluginName)
    return (tostring(pluginName):gsub("^HandyNotes[_ ]?", ""))
end

-- The plugins HandyNotes has, for the options (name -> label).
function handyNotesPluginList()
    local list = {}
    for pluginName in pairs(handyNotesLoaded() and HandyNotes.plugins or {}) do
        list[pluginName] = handyNotesPluginLabel(pluginName)
    end
    return list
end

-- HandyNotes asks for its plugins' nodes again when they change: so do we.
Addon:RegisterMessage("HandyNotes_NotifyUpdate", function() handyNotesNodes.cache.time = 0 end)

-- A label without color codes, textures, links' placeholders ({npc:123}) and further lines.
local function cleanName(text)
    if type(text) ~= "string" then return end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("{.-}", ""):gsub("\n.*", "")
    text = text:match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

local function nameOf(data)
    if type(data) ~= "table" then return end
    return cleanName(data.name) or cleanName(data.label) or cleanName(data.title)
end

-- The node's name, if the plugin passes its node table (coord -> node) as the iterator's state:
-- directly (the expansion plugins: node.label) or as state.data (MapNotes: node.name).
local function nodeName(state, coord)
    if type(state) ~= "table" then return end
    local ok, name = pcall(function()
        return nameOf(state[coord]) or (type(state.data) == "table" and nameOf(state.data[coord]))
    end)
    return ok and name or nil
end

-- HandyNotes icons: a texture (path or file ID), or a table with icon, texture coordinates and
-- color (as HandyNotes draws them on the minimap).
local function iconOf(iconpath)
    if type(iconpath) == "table" then
        local c = iconpath.tCoordLeft and { iconpath.tCoordLeft, iconpath.tCoordRight, iconpath.tCoordTop, iconpath.tCoordBottom }
        local color = iconpath.r and { r = iconpath.r, g = iconpath.g, b = iconpath.b, a = iconpath.a }
        return iconpath.icon, c, color
    end
    return iconpath
end

-- Reads one plugin's nodes of the current map into the cache.
local function readPlugin(pluginName, handler, entries)
    local uiMapID = player.uiMapID
    local ok, iter, state, value = pcall(handler.GetNodes2, handler, uiMapID, true)
    if not (ok and type(iter) == "function") then return end
    local label = handyNotesPluginLabel(pluginName)
    for _ = 1, MAX_NODES do
        local found, coord, mapID, iconpath, scale = pcall(iter, state, value)
        if not found or coord == nil then return end
        value = coord
        mapID = mapID or uiMapID
        local texture, texCoords, color = iconOf(iconpath)
        if type(coord) == "number" and texture then
            local xZone, yZone = math.floor(coord / 10000) / 10000, (coord % 10000) / 10000
            -- (another map's coordinates, e.g. a sub zone's: world coordinates are the same)
            local x, y, instance = HBD:GetWorldCoordinatesFromZone(xZone, yZone, mapID)
            if x and y and instance == player.instance then
                entries[pluginName .. ":" .. mapID .. ":" .. coord] = {
                    x = x, y = y,
                    name = nodeName(state, coord) or label,
                    texture = texture, texCoords = texCoords, color = color,
                    scale = type(scale) == "number" and math.min(math.max(scale, 0.3), 3) or nil,
                    plugin = label,
                    -- tells a changed icon (e.g. a rare killed) from the same one
                    iconKey = tostring(texture) .. (texCoords and table.concat(texCoords, ",") or "")
                        .. (color and (tostring(color.r) .. tostring(color.g) .. tostring(color.b)) or ""),
                }
            end
        end
    end
end

-- The cache holds the current map's nodes; read again on a map change, a HandyNotes update
-- message, a settings change (see restyle) or after REFRESH seconds.
local function refreshCache()
    local cache = handyNotesNodes.cache
    local now = GetTime()
    if cache.uiMapID == player.uiMapID and now - cache.time < REFRESH then return cache.entries end
    cache.uiMapID, cache.time = player.uiMapID, now
    wipe(cache.entries)
    local profile = HandyNotes.db and HandyNotes.db.profile
    if profile and profile.enabled == false then return cache.entries end
    local enabledPlugins = profile and profile.enabledPlugins
    for pluginName, handler in pairs(HandyNotes.plugins) do
        if type(handler) == "table" and type(handler.GetNodes2) == "function"
            and not (enabledPlugins and enabledPlugins[pluginName] == false)
            and Options.HandyNotesPlugins[pluginName] ~= false then
            readPlugin(pluginName, handler, cache.entries)
        end
    end
    return cache.entries
end

function handyNotesNodes.scan()
    for key, entry in pairs(refreshCache()) do
        local node = markerNode(handyNotesNodes, key)
        -- built on another map (instance is the player's map when built) or the icon changed
        if node and (node.instance ~= player.uiMapID or node.iconKey ~= entry.iconKey) then
            releaseMarkerNode(handyNotesNodes, key)
            node = nil
        end
        if not node then
            local fields = {}
            for k, v in pairs(entry) do fields[k] = v end
            newMarkerNode(handyNotesNodes, key, fields)
        end
    end
end

-- A plugin turned on or off here: read the plugins again on the next scan.
function handyNotesPluginsChanged()
    handyNotesNodes.cache.time = 0
    handyNotesNodes.throttle = math.huge
end
