-- Questie markers: the icons Questie places on the minimap (available quests, turn-ins, quest
-- objectives, townsfolk chosen in its menu) as markers of their own module, with own settings
-- (Minimap tracking -> Questie). Which icons exist is left to Questie's own settings: icons it hides
-- (icon.hidden) are skipped. Questie has no public API for its icons, so its map module is read
-- directly and every table and field is presence-checked; when something is missing the module
-- turns itself off for the session.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, pcall, tostring = pairs, ipairs, type, pcall, tostring
local math, table, wipe = math, table, wipe

local HBD = LibStub("HereBeDragons-2.0")
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local GetTradeSkillDisplayName = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName

function questieLoaded()
    return IsAddOnLoaded("Questie") and true or false
end

-- a marker source (Markers/Common.lua), plus Questie's own state
questieNodes = registerMarkerSource({
    prefix = "Questie",
    isAvailable = questieLoaded,
    speech = {
        order = 30,
        default = true,
        name = "Questie icons",
        desc = "The icons shown by Minimap tracking -> Questie (turn them on there).",
    },
    -- the minimap icons' values, which are used instead while UseMinimapSettings is on
    defaults = {
        UseMinimapSettings = true,
        ShowType           = true,
        Supertrack         = true,
        HideAtTarget       = true,
    },
    map = nil,       -- Questie's map module, once found
    broken = false,  -- something expected was missing: stop trying for this session
    l10n = nil,      -- Questie's translation function
})

-- Questie icon types (data.Type): the label shown in parentheses, and whether the quest is in the
-- quest log (then the supertrack keybinding tracks the quest itself)
local questTypes = {
    available = { label = "Available quest" },
    complete = { label = "Turn-in", inLog = true },
    monster = { label = "Objective", inLog = true },
    object = { label = "Objective", inLog = true },
    item = { label = "Objective", inLog = true },
    event = { label = "Objective", inLog = true },
}

-- Questie keys its profession trainers by skill line; names for clients without the trade skill API
local professionNames = {
    [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
    [182] = "Herbalism", [185] = "Cooking", [186] = "Mining", [197] = "Tailoring",
    [202] = "Engineering", [333] = "Enchanting", [356] = "Fishing", [393] = "Skinning",
    [755] = "Jewelcrafting", [773] = "Inscription", [794] = "Archaeology",
}

local function getQuestieMap()
    if questieNodes.map or questieNodes.broken then return questieNodes.map end
    if not (questieLoaded() and Questie and Questie.API and Questie.API.isReady and QuestieLoader) then return end
    local ok, map = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieMap")
    if ok and type(map) == "table" and type(map.questIdFrames) == "table" and type(map.manualFrames) == "table" then
        questieNodes.map = map
        local found, l10n = pcall(QuestieLoader.ImportModule, QuestieLoader, "l10n")
        questieNodes.l10n = found and l10n or nil
    else
        questieNodes.broken = true
        Addon.DEBUG:Print("Questie map module not found, Questie markers are off")
    end
    return questieNodes.map
end

-- The kind of icon: quest icon type, or the townsfolk category of Questie's menu
local function typeLabel(data, category)
    if data.Type ~= "manual" then
        return questTypes[data.Type] and questTypes[data.Type].label
    end
    if type(category) == "number" then
        local ok, name = GetTradeSkillDisplayName and pcall(GetTradeSkillDisplayName, category)
        return (ok and name) or professionNames[category]
    end
    if type(category) == "string" then
        -- same words as Questie's menu, in its language
        local l10n = questieNodes.l10n
        local ok, text = l10n and pcall(l10n, category)
        return (ok and type(text) == "string" and text) or category
    end
end

-- name, and the kind of icon in parentheses if enabled (also read out by Speech.lua)
function questieTitle(node)
    if Options.QuestieShowType and node.typeLabel then
        return (node.name or "") .. " (" .. node.typeLabel .. ")"
    end
    return node.name or ""
end
questieNodes.title = questieTitle

-- One Questie minimap icon frame -> one node, if it is on this map, shown by Questie and in range.
local function addIcon(frameName, category)
    local icon = _G[frameName]
    if not (icon and icon.miniMapIcon and icon.UiMapID == player.uiMapID and not icon.hidden and icon.x and icon.y) then return end
    local data = icon.data
    if not (type(data) == "table" and data.Type) then return end
    -- (the scanning radius is checked when drawing, as for the other icon sections)
    local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(icon.x / 100, icon.y / 100, player.uiMapID)
    if not (xWorld and yWorld) then return end

    local key = frameName
    local node = markerNode(questieNodes, key)
    if node and node.questieData ~= data then
        -- Questie reuses its frames: another icon now, build the node again
        releaseMarkerNode(questieNodes, key)
        node = nil
    end
    if not node then
        local quest = data.Type ~= "manual" and data.QuestData
        local questType = questTypes[data.Type]
        newMarkerNode(questieNodes, key, {
            questieData = data,
            -- quest title for quest icons, NPC/object name for townsfolk
            name = (quest and quest.name) or data.Name,
            typeLabel = typeLabel(data, category),
            questID = questType and questType.inLog and data.Id or nil,
            -- (a question mark icon if Questie's is unknown)
            texture = icon.texture and icon.texture:GetTexture(),
            x = xWorld, y = yWorld,
        })
    else
        moveMarkerNode(node, xWorld, yWorld)
    end
end

-- icons gone, hidden by Questie, out of range or on another map are not reported and give their
-- frame back (Markers/Common.lua)
function questieNodes.scan()
    local map = getQuestieMap()
    if not map then return end
    -- quest icons: { [questId] = { [frameName] = frameName } }
    for _, names in pairs(map.questIdFrames) do
        if type(names) == "table" then
            for name in pairs(names) do
                addIcon(name)
            end
        end
    end
    -- townsfolk chosen in Questie's menu: { [category] = { [npcId] = { frameName, ... } } }
    for category, ids in pairs(map.manualFrames) do
        if type(ids) == "table" then
            for _, names in pairs(ids) do
                if type(names) == "table" then
                    for _, name in ipairs(names) do
                        addIcon(name, category)
                    end
                end
            end
        end
    end
end
