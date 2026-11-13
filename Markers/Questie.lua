-- Questie markers: the icons Questie places on the minimap (available quests, turn-ins, quest
-- objectives, townsfolk chosen in its menu) as markers of their own module, with own settings
-- (Minimap tracking -> Questie). Which icons exist is left to Questie's own settings: icons it hides
-- (icon.hidden) are skipped. Questie has no public API for its icons, so its map module is read
-- directly and every table and field is presence-checked; when something is missing the module
-- turns itself off for the session.
-- Uses only the public interface for the marker source (CompassHUD.RegisterMarkerSource, API.lua).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type, pcall, tostring = pairs, ipairs, type, pcall, tostring

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local GetTradeSkillDisplayName = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName

local function questieLoaded()
    return IsAddOnLoaded("Questie") and true or false
end

-- Questie's own state
local questieMap        -- Questie's map module, once found
local questieBroken     -- something expected was missing: stop trying for this session
local questieL10n       -- Questie's translation function

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
    if questieMap or questieBroken then return questieMap end
    if not (questieLoaded() and Questie and Questie.API and Questie.API.isReady and QuestieLoader) then return end
    local ok, map = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieMap")
    if ok and type(map) == "table" and type(map.questIdFrames) == "table" and type(map.manualFrames) == "table" then
        questieMap = map
        local found, l10n = pcall(QuestieLoader.ImportModule, QuestieLoader, "l10n")
        questieL10n = found and l10n or nil
    else
        questieBroken = true
        Addon.DEBUG:Print("Questie map module not found, Questie markers are off")
    end
    return questieMap
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
        local l10n = questieL10n
        local ok, text = l10n and pcall(l10n, category)
        return (ok and type(text) == "string" and text) or category
    end
end

local source -- the registration's handle (settings)

-- One Questie minimap icon frame -> one marker, if it is on this map and shown by Questie.
-- (the scanning radius is checked when drawing, as for the other icon sections)
local function addIcon(scan, frameName, category)
    local icon = _G[frameName]
    if not (icon and icon.miniMapIcon and icon.UiMapID == scan.uiMapID and not icon.hidden and icon.x and icon.y) then return end
    local data = icon.data
    if not (type(data) == "table" and data.Type) then return end
    local xZone, yZone = icon.x / 100, icon.y / 100

    local key = frameName
    local node = scan:Get(key)
    -- Questie reuses its frames: another icon now, build the marker again
    if node and node.data ~= data then
        node = nil
    end
    if not node then
        local quest = data.Type ~= "manual" and data.QuestData
        local questType = questTypes[data.Type]
        scan:Add(key, {
            mapID = scan.uiMapID, mapX = xZone, mapY = yZone,
            data = data,
            -- quest title for quest icons, NPC/object name for townsfolk
            name = (quest and quest.name) or data.Name,
            typeLabel = typeLabel(data, category),
            questID = questType and questType.inLog and data.Id or nil,
            -- (a question mark icon if Questie's is unknown)
            texture = icon.texture and icon.texture:GetTexture(),
        })
    else
        scan:Move(key, xZone, yZone, scan.uiMapID)
    end
end

source = CompassHUD.RegisterMarkerSource({
    id = "Questie",
    name = "Questie",
    description = "Shows the icons Questie places on the minimap. Which ones is decided by Questie's own settings.",
    enabledDesc = "Questie has no public interface for its icons, so a Questie update may turn this off until CompassHUD is updated.",
    what = "icon",
    isAvailable = questieLoaded,
    options = {
        {
            key = "ShowType",
            type = "toggle",
            name = "Show the type after the name",
            desc = "Adds the kind of icon in parentheses after the name, e.g. \"Innkeeper Farley (Innkeeper)\" or \"Princess Must Die! (Turn-in)\".",
            default = true,
        },
    },
    speech = {
        default = true,
        name = "Questie icons",
        desc = "The icons shown by Minimap tracking -> Questie (turn them on there).",
    },

    -- icons gone, hidden by Questie or on another map are not reported and are removed
    scan = function(scan)
        local map = getQuestieMap()
        if not map then return end
        -- quest icons: { [questId] = { [frameName] = frameName } }
        for _, names in pairs(map.questIdFrames) do
            if type(names) == "table" then
                for name in pairs(names) do
                    addIcon(scan, name)
                end
            end
        end
        -- townsfolk chosen in Questie's menu: { [category] = { [npcId] = { frameName, ... } } }
        for category, ids in pairs(map.manualFrames) do
            if type(ids) == "table" then
                for _, names in pairs(ids) do
                    if type(names) == "table" then
                        for _, name in ipairs(names) do
                            addIcon(scan, name, category)
                        end
                    end
                end
            end
        end
    end,

    -- name, and the kind of icon in parentheses if enabled (also read out by Speech.lua)
    title = function(node)
        if source:GetSetting("ShowType") and node.typeLabel then
            return (node.name or "") .. " (" .. node.typeLabel .. ")"
        end
        return node.name or ""
    end,
})
