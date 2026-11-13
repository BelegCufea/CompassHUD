-- HandyNotes markers: the minimap nodes of HandyNotes plugins (MapNotes, the expansion plugins,
-- ...) as a marker source (Markers/Common.lua). Uses HandyNotes' documented plugin interface:
-- HandyNotes.plugins[name]:GetNodes2(uiMapID, minimap) returns an iterator of
-- coord, uiMapID, iconpath, scale, alpha. Names are not part of it: they are read from the node
-- table many plugins pass as the iterator's state (see nodeName). Plugins turned off in HandyNotes,
-- or here (HandyNotesPlugins), are skipped; every plugin call is protected (pcall).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, type, pcall, tostring, tonumber, select, math, table, wipe = pairs, type, pcall, tostring, tonumber, select, math, table, wipe
local GetTime = GetTime
local C_TooltipInfo, C_QuestLog, C_Item, C_CurrencyInfo, C_Spell, C_Map = C_TooltipInfo, C_QuestLog, C_Item, C_CurrencyInfo, C_Spell, C_Map
local GetAchievementInfo, EJ_GetInstanceInfo = GetAchievementInfo, EJ_GetInstanceInfo
local GetAchievementCriteriaInfoByID = GetAchievementCriteriaInfoByID

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

-- A name readable as a plugin's label: "HandyNotes_TheWarWithin" -> "TheWarWithin"; HandyNotes'
-- own notes plugin is called "HandyNotes".
function handyNotesPluginLabel(pluginName)
    local label = tostring(pluginName):gsub("^HandyNotes[_ ]?", "")
    return label ~= "" and label or "HandyNotes (your own notes)"
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

-- NPC names by ID, from the game's tooltip data (as the plugins do it). A name not known yet is
-- asked again on the next read of the plugins.
local npcNames = {}
local function npcName(id)
    id = tonumber(id)
    if not id then return end
    if npcNames[id] then return npcNames[id] end
    local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink
        and C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. id .. "-0000000000")
    local line = data and data.lines and data.lines[1]
    local name = line and line.leftText
    if type(name) == "string" and name ~= "" then
        npcNames[id] = name
        return name
    end
end

local function achievementName(id)
    return GetAchievementInfo and select(2, GetAchievementInfo(id))
end

local function itemName(id)
    return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
end

-- The plugins' placeholders ({npc:123}, {achievement:40606}, ...) as names, like the expansion
-- plugins render them in their tooltips; unknown ones are dropped.
local linkNames = {
    npc = npcName,
    achievement = function(id) return achievementName(id) end,
    quest = function(id) return C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id) end,
    item = function(id) return itemName(id) end,
    currency = function(id)
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        return info and info.name
    end,
    spell = function(id) return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end,
    map = function(id)
        local info = C_Map.GetMapInfo(id)
        return info and info.name
    end,
    area = function(id) return C_Map.GetAreaInfo and C_Map.GetAreaInfo(id) end,
}
linkNames.daily = linkNames.quest

-- {kind:id} with letters after the id kept (Zarillion: {npc:123s}), or {kind:id:extra}
-- (Kemayo: {achievement:id:criteria} is the criteria's name).
local function renderLinks(text)
    return (text:gsub("{(%a+):([^:}]+):?([^}]*)}", function(kind, idText, extra)
        local id, suffix = idText:match("^(%d+)(%l*)$")
        id = tonumber(id)
        if not id then return "" end
        local ok, name
        if kind == "achievement" and tonumber(extra) and GetAchievementCriteriaInfoByID then
            ok, name = pcall(GetAchievementCriteriaInfoByID, id, tonumber(extra))
        end
        if not (ok and type(name) == "string" and name ~= "") then
            local get = linkNames[kind]
            ok, name = false, nil
            if get then ok, name = pcall(get, id) end
        end
        return ok and type(name) == "string" and (name .. suffix) or ""
    end))
end

-- A label without color codes, textures and further lines, placeholders rendered.
local function cleanName(text)
    if type(text) ~= "string" then return end
    text = renderLinks(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
        :gsub("\n.*", "")
    text = text:match("^%s*(.-)%s*$")
    -- the expansion plugins' default label
    if text == "" or text == UNKNOWN then return end
    return text
end

-- A node with a name, label or title (Zarillion's expansion plugins: label, with placeholders;
-- HandyNotes' own notes: title), else a point of Kemayo's plugins ("... Treasures and Rares"),
-- named like their tooltip: the achievement criteria, the NPC, the loot or the achievement.
local function nameOf(data)
    if type(data) ~= "table" then return end
    local name = cleanName(data.name) or cleanName(data.label) or cleanName(data.title)
    if name then return name end
    local achievement = tonumber(data.achievement)
    if achievement and type(data.criteria) == "number" and GetAchievementCriteriaInfoByID then
        name = cleanName((GetAchievementCriteriaInfoByID(achievement, data.criteria)))
    end
    name = name or npcName(data.npc)
    if not name and type(data.loot) == "table" then
        local first = data.loot[1]
        name = itemName(tonumber(type(first) == "table" and (first.id or first[1]) or first))
    end
    return name or (achievement and achievementName(achievement)) or nil
end

-- A MapNotes node: its name, else its NPC (npcID, npcIDs1, ...), its dungeon or raid (id: the
-- dungeon journal's), else the kind of icon (type, e.g. "Jewelcrafting").
local function mapNotesName(data)
    if type(data) ~= "table" then return end
    local name = nameOf(data) or npcName(data.npcID) or npcName(data.npcIDs1)
    if not name and type(data.id) == "number" and type(data.type) == "string"
        and (data.type:find("Dungeon") or data.type:find("Raid")) and EJ_GetInstanceInfo then
        name = EJ_GetInstanceInfo(data.id)
    end
    return name or (type(data.type) == "string" and data.type ~= "" and data.type or nil)
end

-- The node's name, if the plugin passes its node table (coord -> node) as the iterator's state:
-- directly (the expansion plugins: node.label) or as state.data (MapNotes).
local function nodeName(state, coord)
    if type(state) ~= "table" then return end
    local ok, name = pcall(function()
        return nameOf(state[coord]) or (type(state.data) == "table" and mapNotesName(state.data[coord]))
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
        -- built on another map (instance is the player's map when built), the icon changed or the
        -- name is known now (NPC names come from the game's cache)
        if node and (node.instance ~= player.uiMapID or node.iconKey ~= entry.iconKey or node.name ~= entry.name) then
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
