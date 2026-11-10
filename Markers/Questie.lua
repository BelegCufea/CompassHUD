-- Questie markers: the icons Questie places on the minimap (available quests, turn-ins, quest
-- objectives, townsfolk from its menu) as minimap icon nodes. Questie has no public API for its
-- icons, so its map module is read directly and every table and field is presence-checked; when
-- something is missing the source turns itself off. Called from setPOITrackNodes (Markers/POI.lua).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, pcall = pairs, ipairs, type, pcall
local HBD = LibStub("HereBeDragons-2.0")
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

-- Questie icon types (data.Type) to minimap icon filter types
local questieTypes = {
    available = poiTypeEnum.QUESTIE_AVAILABLE,
    complete = poiTypeEnum.QUESTIE_COMPLETE,
    monster = poiTypeEnum.QUESTIE_OBJECTIVE,
    object = poiTypeEnum.QUESTIE_OBJECTIVE,
    item = poiTypeEnum.QUESTIE_OBJECTIVE,
    event = poiTypeEnum.QUESTIE_OBJECTIVE,
    manual = poiTypeEnum.QUESTIE_TOWNSFOLK,
}

local questieMap -- Questie's map module, once found
local questieBroken = false -- something expected was missing: stop trying for this session

function questieLoaded()
    return IsAddOnLoaded("Questie") and true or false
end

local function getQuestieMap()
    if questieMap or questieBroken then return questieMap end
    if not (questieLoaded() and Questie and Questie.API and Questie.API.isReady and QuestieLoader) then return end
    local ok, map = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieMap")
    if ok and type(map) == "table" and type(map.questIdFrames) == "table" and type(map.manualFrames) == "table" then
        questieMap = map
    else
        questieBroken = true
        Addon.DEBUG:Print("Questie map module not found, Questie markers are off")
    end
    return questieMap
end

-- one Questie minimap icon frame -> one node of this map
local function addQuestieIcon(pois, frameName)
    local icon = _G[frameName]
    if not (icon and icon.miniMapIcon and icon.UiMapID == player.uiMapID and not icon.hidden) then return end
    local data = icon.data
    local trackType = type(data) == "table" and questieTypes[data.Type]
    if not (trackType and Options.POITrackFilter[trackType] and icon.x and icon.y) then return end

    local id = "Questie_" .. frameName
    local node = pois[id]
    if node and node.questieData ~= data then
        -- Questie reuses its frames: another icon now, build the node again
        poiNodes.release(pois, id)
        node = nil
    end
    local xZone, yZone = icon.x / 100, icon.y / 100
    if not node then
        local quest = data.QuestData
        local isQuest = trackType ~= poiTypeEnum.QUESTIE_TOWNSFOLK
        node = addPOITrackNode(id, {
            name = (isQuest and quest and quest.name) or data.Name,
            -- turn-ins and objectives are quests in the log: the supertrack keybinding tracks them
            questID = (trackType == poiTypeEnum.QUESTIE_COMPLETE or trackType == poiTypeEnum.QUESTIE_OBJECTIVE) and data.Id or nil,
            atlasName = "QuestNormal", -- replaced by Questie's texture below
            questieData = data,
        }, xZone, yZone, 1)
        local texture = icon.texture and icon.texture:GetTexture()
        if texture then
            node.frame.texture:SetTexture(texture)
        end
    else
        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
        node.x, node.y = xWorld, yWorld
        node.frame.x, node.frame.y = xWorld, yWorld
    end
    node.trackType = trackType
    node.visible = true
    poiNodes.seen[id] = true
end

function questieTypeEnabled()
    local filter = Options.POITrackFilter
    return filter[poiTypeEnum.QUESTIE_AVAILABLE] or filter[poiTypeEnum.QUESTIE_COMPLETE]
        or filter[poiTypeEnum.QUESTIE_OBJECTIVE] or filter[poiTypeEnum.QUESTIE_TOWNSFOLK]
end

-- Adds/refreshes the Questie icons of the current map in 'pois' (poiTrackPointTable[player.uiMapID]).
function setQuestieNodes(pois)
    if not questieTypeEnabled() then return end
    local map = getQuestieMap()
    if not map then return end
    -- quest icons: { [questId] = { [frameName] = frameName } }
    for _, names in pairs(map.questIdFrames) do
        if type(names) == "table" then
            for name in pairs(names) do
                addQuestieIcon(pois, name)
            end
        end
    end
    -- townsfolk: { [category] = { [npcId] = { frameName, ... } } }
    if Options.POITrackFilter[poiTypeEnum.QUESTIE_TOWNSFOLK] then
        for _, ids in pairs(map.manualFrames) do
            if type(ids) == "table" then
                for _, names in pairs(ids) do
                    if type(names) == "table" then
                        for _, name in ipairs(names) do
                            addQuestieIcon(pois, name)
                        end
                    end
                end
            end
        end
    end
end
