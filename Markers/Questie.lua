-- Questie markers: the icons Questie places on the minimap (available quests, turn-ins, quest
-- objectives, townsfolk from its menu) as minimap icon nodes of one type. Which icons are shown is
-- left to Questie's own settings: icons it hides (icon.hidden) are skipped. Questie has no public
-- API for its icons, so its map module is read directly and every table and field is
-- presence-checked; when something is missing the source turns itself off.
-- Called from setPOITrackNodes (Markers/POI.lua).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, pcall = pairs, ipairs, type, pcall
local HBD = LibStub("HereBeDragons-2.0")
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

-- Questie icon types (data.Type) of quests in the quest log: the supertrack keybinding tracks them
local questLogTypes = { complete = true, monster = true, object = true, item = true, event = true }

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
    if not (type(data) == "table" and data.Type and icon.x and icon.y) then return end

    local id = "Questie_" .. frameName
    local node = pois[id]
    if node and node.questieData ~= data then
        -- Questie reuses its frames: another icon now, build the node again
        poiNodes.release(pois, id)
        node = nil
    end
    local xZone, yZone = icon.x / 100, icon.y / 100
    if not node then
        local quest = data.Type ~= "manual" and data.QuestData
        node = addPOITrackNode(id, {
            -- quest title for quest icons, NPC/object name for townsfolk
            name = (quest and quest.name) or data.Name,
            questID = questLogTypes[data.Type] and data.Id or nil,
            atlasName = "QuestNormal", -- replaced by Questie's texture below
            questieData = data,
        }, xZone, yZone, 1)
        local texture = icon.texture and icon.texture:GetTexture()
        if texture then
            node.texture = texture -- also used by the supertracker pointer of a waypoint set for it
            node.frame.texture:SetTexture(texture)
        end
    else
        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
        node.x, node.y = xWorld, yWorld
        node.frame.x, node.frame.y = xWorld, yWorld
    end
    node.trackType = poiTypeEnum.QUESTIE
    node.visible = true
    poiNodes.seen[id] = true
end

-- Adds/refreshes the Questie icons of the current map in 'pois' (poiTrackPointTable[player.uiMapID]).
function setQuestieNodes(pois)
    if not Options.POITrackFilter[poiTypeEnum.QUESTIE] then return end
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
    -- townsfolk chosen in Questie's menu: { [category] = { [npcId] = { frameName, ... } } }
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
