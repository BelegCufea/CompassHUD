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

-- (state kept in one table, like the other marker modules)
questieNodes = {
    framePool = {},
    seen = {},       -- icons found by the current scan
    heading = nil,   -- shown node closest to the facing direction (supertrack keybinding, speech)
    map = nil,       -- Questie's map module, once found
    broken = false,  -- something expected was missing: stop trying for this session
    l10n = nil,      -- Questie's translation function
}
questiePointTable = {}

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

function questieLoaded()
    return IsAddOnLoaded("Questie") and true or false
end

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

local function nodeTitle(node)
    if Options.QuestieShowType and node.typeLabel then
        return (node.name or "") .. " (" .. node.typeLabel .. ")"
    end
    return node.name or ""
end

function updateQuestieNode(node)
    local frame = node.frame
    local scale = Options.Scale * Options.IconScale * Options.QuestieScale
    frame:SetSize(iconSize * Options.QuestieScale, iconSize * Options.QuestieScale)
    setPointerFont(frame.DistanceText, scale, Options.QuestieDistanceCustomFont, Options.QuestieDistanceFont, Options.QuestieDistanceFontSize, Options.QuestieDistanceFontFlags, Options.QuestieDistanceFontColor)
    setPointerFont(frame.TimeText, scale, Options.QuestieTtaCustomFont, Options.QuestieTtaFont, Options.QuestieTtaFontSize, Options.QuestieTtaFontFlags, Options.QuestieTtaFontColor)
    setPointerFont(frame.Title, scale, Options.QuestieTitleCustomFont, Options.QuestieTitleFont, Options.QuestieTitleFontSize, Options.QuestieTitleFontFlags, Options.QuestieTitleFontColor)
    setTitleWidth(frame.Title)
    frame.Title:SetText(nodeTitle(node))

    node.flipped = Options.QuestieOffset > 0
    layoutNodeTexts(frame, node.flipped, Options.QuestieShowDistance, Options.QuestieShowTTA, Options.QuestieShowTitle,
        Options.QuestieDistanceOffset, Options.QuestieTtaOffset, Options.QuestieTitleOffset)
    -- lets questPointerSetTexts skip work for hidden texts
    frame.distanceHidden = not Options.QuestieShowDistance
    frame.timeHidden = not Options.QuestieShowTTA
end

local function acquireFrame()
    local frame = table.remove(questieNodes.framePool)
    if frame then
        return frame
    end
    frame = CreateFrame("FRAME", nil, HUD)
    frame:SetSize(iconSize, iconSize)
    frame:SetPoint("CENTER")
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetAllPoints(frame)
    frame:Hide()
    frame.DistanceText = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.DistanceText:SetJustifyV("TOP")
    frame.DistanceText:SetSize(0, 16)
    frame.TimeText = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.TimeText:SetJustifyV("TOP")
    frame.TimeText:SetSize(0, 16)
    frame.Title = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.Title:SetJustifyV("TOP")
    frame.Title:SetSize(0, 16)
    frame.type = "Questie"
    frame.elapsed = 0
    frame:SetScript("OnUpdate", questPointerSetTexts)
    return frame
end

local function releaseNode(key)
    local node = questiePointTable[key]
    questiePointTable[key] = nil
    if node == questieNodes.heading then
        questieNodes.heading = nil
    end
    if node and node.frame then
        local frame = node.frame
        frame:Hide()
        -- per-target text state must not carry over to the next node using this frame
        frame.minDistance = nil
        frame.ttaLastDistance = nil
        table.insert(questieNodes.framePool, frame)
        node.frame = nil
    end
end

-- One Questie minimap icon frame -> one node, if it is on this map, shown by Questie and in range.
local function addIcon(frameName, category)
    local icon = _G[frameName]
    if not (icon and icon.miniMapIcon and icon.UiMapID == player.uiMapID and not icon.hidden and icon.x and icon.y) then return end
    local data = icon.data
    if not (type(data) == "table" and data.Type) then return end
    local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(icon.x / 100, icon.y / 100, player.uiMapID)
    if not (xWorld and yWorld) then return end
    if Options.QuestieRadius > 0 then
        local distance = HBD:GetWorldDistance(player.instance, player.x, player.y, xWorld, yWorld)
        if not distance or distance > Options.QuestieRadius then return end
    end

    local key = frameName
    local node = questiePointTable[key]
    if node and node.questieData ~= data then
        -- Questie reuses its frames: another icon now, build the node again
        releaseNode(key)
        node = nil
    end
    if not node then
        local quest = data.Type ~= "manual" and data.QuestData
        local questType = questTypes[data.Type]
        node = {
            questieData = data,
            -- quest title for quest icons, NPC/object name for townsfolk
            name = (quest and quest.name) or data.Name,
            typeLabel = typeLabel(data, category),
            questID = questType and questType.inLog and data.Id or nil,
            texture = icon.texture and icon.texture:GetTexture(),
            instance = player.uiMapID,
        }
        local frame = acquireFrame()
        frame.texture:SetTexture(node.texture or 134400) -- question mark icon if Questie's is unknown
        node.frame = frame
        questiePointTable[key] = node
        updateQuestieNode(node)
    end
    node.x, node.y = xWorld, yWorld
    node.frame.instance, node.frame.x, node.frame.y = node.instance, xWorld, yWorld
    questieNodes.seen[key] = true
end

local function scanQuestie()
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

-- Settings changed: re-apply them to all nodes, or drop all when the module is off.
function updateQuestie()
    for key, node in pairs(questiePointTable) do
        if not Options.QuestieEnabled then
            releaseNode(key)
        elseif node.frame then
            updateQuestieNode(node)
        end
    end
end

function setQuestieNodes()
    if not Options.QuestieEnabled or not questieLoaded() then return end
    if questieThrottle >= Options.QuestieInterval then
        questieThrottle = 0
        if player.x and player.y and player.instance and player.uiMapID then
            wipe(questieNodes.seen)
            scanQuestie()
            -- icons gone, hidden by Questie, out of range or on another map give their frame back
            for key in pairs(questiePointTable) do
                if not questieNodes.seen[key] then
                    releaseNode(key)
                end
            end
        end
    end

    local minAngle = math.huge
    questieNodes.heading = nil
    local visible = math.rad(Options.Degrees) / 2
    -- opacity fades from OpacityMinRadius to the scanning radius; no span means no fade (not 0/0)
    local fadeEnd = Options.QuestieRadius > 0 and Options.QuestieRadius or 1000
    local fadeSpan = fadeEnd - Options.QuestieOpacityMinRadius
    local fadeFactor = fadeSpan > 0 and (Options.QuestieOpacityMin - Options.QuestieOpacityMax) / fadeSpan or 0
    -- the game's tracked target, if icons at its place should be hidden (see shownGameTarget)
    local target = Options.QuestieHideAtTarget and shownGameTarget
    for _, node in pairs(questiePointTable) do
        local shown = false
        local angle = player.angle and relativeAngle(node.instance, node.x, node.y)
        node.angle = angle
        if angle then
            node.distance = HBD:GetWorldDistance(node.instance, player.x, player.y, node.x, node.y)
            if math.abs(angle) < minAngle then
                minAngle = math.abs(angle)
                questieNodes.heading = node
            end
            if angle < visible and angle > -visible then
                node.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, Options.QuestieOffset)
                shown = true
                -- already shown as the supertracker pointer: no second marker
                if target then
                    local distance = HBD:GetWorldDistance(node.instance, node.x, node.y, target.x, target.y)
                    if distance and distance <= SAME_POINT_YARDS then
                        shown = false
                    end
                end
            end
        end
        if shown then
            local distance = node.distance
            local opacity = Options.QuestieOpacityMax
            if distance and distance > Options.QuestieOpacityMinRadius then
                opacity = distance >= fadeEnd and Options.QuestieOpacityMin
                    or Options.QuestieOpacityMax + (distance - Options.QuestieOpacityMinRadius) * fadeFactor
            end
            node.frame:SetAlpha(opacity)
        end
        node.frame:SetShown(shown)
    end
end
