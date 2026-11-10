-- Minimap icon markers (area POIs, flight points, vignettes, world quests, ...) and the supertrack keybind.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local HBD               = LibStub("HereBeDragons-2.0")
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetQuestsOnMap = C_QuestLog.GetQuestsOnMap
local IsQuestComplete = C_QuestLog.IsComplete
local GetNumWorldQuestWatches = C_QuestLog.GetNumWorldQuestWatches
local GetQuestIDForWorldQuestWatchIndex = C_QuestLog.GetQuestIDForWorldQuestWatchIndex
local GetWorldQuestsOnMap = C_TaskQuest.GetQuestsOnMap
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetMapLinksForMap = C_Map.GetMapLinksForMap
local CanSetUserWaypointOnMap = C_Map.CanSetUserWaypointOnMap
local SetUserWaypoint = C_Map.SetUserWaypoint
local ClearUserWaypoint = C_Map.ClearUserWaypoint
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedMapPin = C_SuperTrack.GetSuperTrackedMapPin
local GetSuperTrackedVignette = C_SuperTrack.GetSuperTrackedVignette
local ClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
local GetHighestPrioritySuperTrackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType
local SetSuperTrackedQuestID = C_SuperTrack.SetSuperTrackedQuestID
local SetSuperTrackedMapPin = C_SuperTrack.SetSuperTrackedMapPin
local SetSuperTrackedUserWaypoint = C_SuperTrack.SetSuperTrackedUserWaypoint
local SetSuperTrackedVignette = C_SuperTrack.SetSuperTrackedVignette
local GetAreaPOIForMap =  C_AreaPoiInfo.GetAreaPOIForMap
local GetDelvesForMap =  C_AreaPoiInfo.GetDelvesForMap
local GetEventsForMap =  C_AreaPoiInfo.GetEventsForMap
local GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo
local GetQuestHubsForMap = C_AreaPoiInfo.GetQuestHubsForMap
local GetDragonridingRacesForMap = C_AreaPoiInfo.GetDragonridingRacesForMap
local GetDungeonEntrancesForMap = C_EncounterJournal.GetDungeonEntrancesForMap
local GetTaxiNodesForMap = C_TaxiMap.GetTaxiNodesForMap
local GetVignettes = C_VignetteInfo.GetVignettes
local GetVignettePosition = C_VignetteInfo.GetVignettePosition
local GetVignetteInfo = C_VignetteInfo.GetVignetteInfo

function updatePOITrackNode(poi)
    local scale = Options.Scale * Options.IconScale * Options.POITrackScale
    poi.frame:SetSize(iconSize * Options.POITrackScale * (poi.scale or 1), iconSize * Options.POITrackScale * (poi.scale or 1))
    setPointerFont(poi.frame.DistanceText, scale, Options.POITrackDistanceCustomFont, Options.POITrackDistanceFont, Options.POITrackDistanceFontSize, Options.POITrackDistanceFontFlags, Options.POITrackDistanceFontColor)
    setPointerFont(poi.frame.TimeText, scale, Options.POITrackTtaCustomFont, Options.POITrackTtaFont, Options.POITrackTtaFontSize, Options.POITrackTtaFontFlags, Options.POITrackTtaFontColor)
    setPointerFont(poi.frame.Title, scale, Options.POITrackTitleCustomFont, Options.POITrackTitleFont, Options.POITrackTitleFontSize, Options.POITrackTitleFontFlags, Options.POITrackTitleFontColor)
    setTitleWidth(poi.frame.Title)

    poi.flipped = Options.POITrackOffset > 0
    layoutNodeTexts(poi.frame, poi.flipped, Options.POITrackShowDistance, Options.POITrackShowTTA, Options.POITrackShowTitle,
        Options.POITrackDistanceOffset, Options.POITrackTtaOffset, Options.POITrackTitleOffset)
end

function updatePoiTrack()
    for _, pois in pairs(poiTrackPointTable) do
        for _, poi in pairs(pois) do
            if not Options.POITrackEnabled then
                poi.visible = false
                if poi.frame then
                    poi.frame:Hide()
                end
            end
            if poi.frame then
                updatePOITrackNode(poi)
            end
        end
    end
end

POI_TRACK_WORLD_QUEST = "WorldQuest" -- world quests have their own bypass toggle

-- Minimap icon frames are reused: WoW never frees frames, so icons that go away (vignettes, world
-- quests) hand theirs back to this pool instead of leaving it behind.
-- (kept in one table: the main chunk is close to Lua's limit of 200 local variables)
poiNodes = {
    framePool = {},
    seen = {}, -- vignettes and world quests the game reported in the current scan
}

function createPOITrackNode(data)
    local poiTrackNode = data.frame or table.remove(poiNodes.framePool)
    if not poiTrackNode then
        poiTrackNode = CreateFrame("FRAME", nil, HUD)
        poiTrackNode.texture = poiTrackNode:CreateTexture(nil, "ARTWORK")
        poiTrackNode.texture:SetAllPoints(poiTrackNode)
        poiTrackNode.mask = poiTrackNode:CreateMaskTexture()
        poiTrackNode.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        poiTrackNode.mask:SetAllPoints(poiTrackNode.texture)
        poiTrackNode.border = poiTrackNode:CreateTexture(nil, "OVERLAY", nil, 1)
        poiTrackNode.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
        poiTrackNode.border:SetAllPoints(poiTrackNode.texture)
        poiTrackNode.DistanceText = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
        poiTrackNode.DistanceText:SetJustifyV("TOP")
        poiTrackNode.DistanceText:SetSize(0, 16)
        poiTrackNode.DistanceText:SetParent(poiTrackNode)
        poiTrackNode.TimeText = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
        poiTrackNode.TimeText:SetJustifyV("TOP")
        poiTrackNode.TimeText:SetSize(0, 16)
        poiTrackNode.TimeText:SetParent(poiTrackNode)
        poiTrackNode.Title = poiTrackNode:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
        poiTrackNode.Title:SetJustifyV("TOP")
        poiTrackNode.Title:SetSize(0, 16)
        poiTrackNode.Title:SetParent(poiTrackNode)
        poiTrackNode.type = "poiTrack"
        poiTrackNode:SetScript("OnUpdate", questPointerSetTexts)
    end
    poiTrackNode:SetSize(iconSize, iconSize)
    poiTrackNode:ClearAllPoints()
    poiTrackNode:SetPoint("CENTER")
    poiTrackNode:Hide()
    poiTrackNode.texture:SetAtlas(data.atlasName)
    poiTrackNode.texture:SetSize(iconSize, iconSize)
    -- round icon with a border (world quests); a reused frame may have had it or not
    if data.circle then
        if not poiTrackNode.masked then
            poiTrackNode.texture:AddMaskTexture(poiTrackNode.mask)
            poiTrackNode.masked = true
        end
        poiTrackNode.border:Show()
    else
        if poiTrackNode.masked then
            poiTrackNode.texture:RemoveMaskTexture(poiTrackNode.mask)
            poiTrackNode.masked = false
        end
        poiTrackNode.border:Hide()
    end
    poiTrackNode.Title:SetText(data.name)
    poiTrackNode.instance = data.instance
    poiTrackNode.x = data.x
    poiTrackNode.y = data.y
    poiTrackNode.elapsed = 0
    poiTrackNode.minDistance = nil
    poiTrackNode.ttaLastDistance = nil
	return poiTrackNode
end

-- Vignettes, world quests and quests come and go; other minimap icon types are fixed per map.
function poiNodes.isTransient(poi)
    return poi.trackType == poiTypeEnum.VIGNETTE or poi.trackType == POI_TRACK_WORLD_QUEST
        or poi.trackType == poiTypeEnum.QUEST
end

-- Whether the game's user waypoint 'point' (UiMapPoint) is the one set for the remembered icon
-- 'tracked' (poiNodes.tracked). The game stores the position slightly rounded, so it is compared
-- with a small tolerance (a ten-thousandth of the map, below a yard on most maps).
function isTrackedWaypoint(point, tracked)
    return tracked and point and point.uiMapID == tracked.instance and point.position
        and math.abs(point.position.x - tracked.xZone) < 0.0001
        and math.abs(point.position.y - tracked.yZone) < 0.0001
end

-- Removes a minimap icon node and puts its frame back into the pool.
function poiNodes.release(pois, id)
    local poi = pois[id]
    pois[id] = nil
    if poi == poiTrackHeading then
        poiTrackHeading = nil
    end
    if poi and poi.frame then
        poi.frame:Hide()
        table.insert(poiNodes.framePool, poi.frame)
        poi.frame = nil
    end
end

-- Each minimap icon node remembers its filter type (poi.trackType). It decides the "Bypass scanning
-- radius" setting at draw time, so a change of that setting applies right away.
function poiTrackBypassesRadius(poi)
    if poi.trackType == POI_TRACK_WORLD_QUEST then
        return Options.POITrackWQWholeZone
    end
    return poi.trackType and Options.POITrackWholeZone[poi.trackType]
end

-- Area POIs and map links with a "TaxiNode..." atlas are portals (flight-path-like map links)
function poiTrackTypeByAtlas(poi, otherType)
    return poi.atlasName and poi.atlasName:sub(1, #("TaxiNode")) == "TaxiNode" and poiTypeEnum.PORTAL or otherType
end

-- Adds a minimap icon node for a game API record 'data' at zone position xZone, yZone of the
-- current map: world coordinates, its frame and scale. The record itself becomes the node.
function addPOITrackNode(id, data, xZone, yZone, scale)
    poiTrackPointTable[player.uiMapID][id] = data
    data.instance = player.uiMapID
    data.x, data.y = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
    data.frame = createPOITrackNode(data)
    data.scale = scale
    updatePOITrackNode(data)
    return data
end

-- Returns the minimap icon node for an area POI, or nil when the game has no details for it (yet).
function setPOITrackNode(poiID, poiType)

    local id = poiType .. "_" .. poiID
    if not poiTrackPointTable[player.uiMapID][id] then
        -- current game data first; the continent cache (filled once per session) only as a fallback,
        -- so an event or other dynamic POI does not keep details from when the continent was cached
        local poi = GetAreaPOIInfo(player.uiMapID, poiID)
            or (poiCache[poiID] and poiCache[poiID][player.uiMapID] and poiCache[poiID][player.uiMapID].poi)
        if not (poi and poi.position) then return end
        if not poi.atlasName then
            local pointerType = getPointerType(nil, selectedPin)
            local options = Options.Pointers[pointerType]
            poi.atlasName = options.atlasID
        end
        addPOITrackNode(id, poi, poi.position.x, poi.position.y, 1.3)
    end
    return poiTrackPointTable[player.uiMapID][id]
end

function setPOITrackNodes()
    if not Options.POITrackEnabled then return end
    if poiTrackThrottle and poiTrackThrottle >= Options.POITrackInterval then
        if poiTrackCurrentMap ~= player.uiMapID then
            for map, pois in pairs(poiTrackPointTable) do
                if map ~= player.uiMapID then
                    for id, poi in pairs(pois) do
                        if poiNodes.isTransient(poi) then
                            -- will be scanned again when the player comes back
                            poiNodes.release(pois, id)
                        elseif poi.frame then
                            poi.visible = false
                            poi.frame:Hide()
                        end
                    end
                end
            end
            poiTrackCurrentMap = player.uiMapID
        end
        for poiID, _ in pairs(poiTrackPointTable and poiTrackPointTable[player.uiMapID]  or {}) do
            poiTrackPointTable[player.uiMapID][poiID].visible = false
        end
        wipe(poiNodes.seen)
        local x, y = HBD:GetZoneCoordinatesFromWorld(player.x, player.y, player.uiMapID, false)
        if x and y then
            if not poiTrackPointTable[player.uiMapID] then
                poiTrackPointTable[player.uiMapID] = {}
            end

            local mapPOIs = GetAreaPOIForMap(player.uiMapID)
            if (Options.POITrackFilter[poiTypeEnum.PORTAL] or Options.POITrackFilter[poiTypeEnum.OTHER]) and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local poi = setPOITrackNode(poiID, poiTypeEnum.OTHER)
                    if poi then
                        poi.trackType = poiTrackTypeByAtlas(poi, poiTypeEnum.OTHER)
                        poi.visible = Options.POITrackFilter[poi.trackType]
                    end
                end
            end

            mapPOIs = GetDelvesForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.DELVE] and  mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local poi = setPOITrackNode(poiID, poiTypeEnum.DELVE)
                    if poi then
                        poi.trackType = poiTypeEnum.DELVE
                        poi.visible = true
                    end
                end
            end

            mapPOIs = GetEventsForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.EVENT] and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local poi = setPOITrackNode(poiID, poiTypeEnum.EVENT)
                    if poi then
                        poi.trackType = poiTypeEnum.EVENT
                        poi.visible = true
                    end
                end
            end

            mapPOIs = GetQuestHubsForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.HUB] and mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local poi = setPOITrackNode(poiID, poiTypeEnum.HUB)
                    if poi then
                        poi.trackType = poiTypeEnum.HUB
                        poi.visible = true
                    end
                end
            end

            mapPOIs = GetDragonridingRacesForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.RACE] and  mapPOIs then
                for _, poiID in ipairs(mapPOIs) do
                    local poi = setPOITrackNode(poiID, poiTypeEnum.RACE)
                    if poi then
                        poi.trackType = poiTypeEnum.RACE
                        poi.visible = true
                    end
                end
            end

            local portalPOIs = GetMapLinksForMap(player.uiMapID)
            if (Options.POITrackFilter[poiTypeEnum.PORTAL] or Options.POITrackFilter[poiTypeEnum.LINK]) and portalPOIs then
                for _, poi in ipairs(portalPOIs) do
                    local id = poiTypeEnum.LINK .."_" .. poi.areaPoiID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        addPOITrackNode(id, poi, poi.position.x, poi.position.y, 1.3)
                    end
                    local node = poiTrackPointTable[player.uiMapID][id]
                    node.trackType = poiTrackTypeByAtlas(node, poiTypeEnum.LINK)
                    node.visible = Options.POITrackFilter[node.trackType]
                end
            end

            local dungeonEntrances = GetDungeonEntrancesForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.INSTANCE] and dungeonEntrances then
                for _, entrance in ipairs(dungeonEntrances) do
                    local id = poiTypeEnum.INSTANCE .. "_" .. entrance.areaPoiID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        addPOITrackNode(id, entrance, entrance.position.x, entrance.position.y, 1.3)
                    end
                    poiTrackPointTable[player.uiMapID][id].visible = true
                    poiTrackPointTable[player.uiMapID][id].trackType = poiTypeEnum.INSTANCE
                end
            end

            local mapTaxis = GetTaxiNodesForMap(player.uiMapID)
            if Options.POITrackFilter[poiTypeEnum.TAXI] and mapTaxis then
                local closestTaxiNode, closesttaxiDistance = nil, math.huge
                for _, taxi in ipairs(mapTaxis) do
                    local id = poiTypeEnum.TAXI .. "_" .. taxi.nodeID
                    if not poiTrackPointTable[player.uiMapID][id] then
                        addPOITrackNode(id, taxi, taxi.position.x, taxi.position.y, 1.2)
                    end
                    poiTrackPointTable[player.uiMapID][id].trackType = poiTypeEnum.TAXI
                    if not isTaxiNodeUsable(taxi) then
                        poiTrackPointTable[player.uiMapID][id].visible = false
                    elseif Options.POITrackFilter[poiTypeEnum.TAXI .. "_min"] then
                        local distance = HBD:GetWorldDistance(player.uiMapID, player.x, player.y, poiTrackPointTable[player.uiMapID][id].x, poiTrackPointTable[player.uiMapID][id].y)
                        if distance and distance < closesttaxiDistance then
                            closesttaxiDistance = distance
                            closestTaxiNode = id
                        end
                        poiTrackPointTable[player.uiMapID][id].visible = false
                    else
                        poiTrackPointTable[player.uiMapID][id].visible = true
                    end
                end
                if Options.POITrackFilter[poiTypeEnum.TAXI .. "_min"] then
                    if closestTaxiNode then
                        poiTrackPointTable[player.uiMapID][closestTaxiNode].visible = true
                    end
                end
            end

            local vignetteGUIDs = GetVignettes()
            if Options.POITrackFilter[poiTypeEnum.VIGNETTE] and vignetteGUIDs then
                for _, vignetteGUID in ipairs(vignetteGUIDs) do
                    local vignetteInfo = GetVignetteInfo(vignetteGUID)
                    local vignettePosition = GetVignettePosition(vignetteGUID, player.uiMapID)
                    if vignetteInfo and vignettePosition then
                        local id = poiTypeEnum.VIGNETTE .. "_" .. vignetteInfo.vignetteGUID
                        local node = poiTrackPointTable[player.uiMapID][id]
                        -- vignettes can move (e.g. wandering rares): refresh the position on every scan
                        local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(vignettePosition.x, vignettePosition.y, player.uiMapID)
                        if not node then
                            addPOITrackNode(id, vignetteInfo, vignettePosition.x, vignettePosition.y, 1.3)
                        else
                            node.x, node.y = xWorld, yWorld
                            node.frame.x, node.frame.y = xWorld, yWorld
                        end
                        poiTrackPointTable[player.uiMapID][id].visible = true
                        poiTrackPointTable[player.uiMapID][id].trackType = poiTypeEnum.VIGNETTE
                        poiNodes.seen[id] = true
                    end
                end
            end

            local mapWQ = GetWorldQuestsOnMap(player.uiMapID)
            -- local copy: falling back to "All" while World Quest Tracker is not loaded must not change the saved setting
            local wqFilter = Options.POITrackWQFilter
            if wqFilter ~= "None" and mapWQ then
                local trackedWQ = {}
                if wqFilter == "Tracked" then
                    for i = 1, GetNumWorldQuestWatches() do
                        trackedWQ[GetQuestIDForWorldQuestWatchIndex(i)] = true
                    end
                elseif wqFilter == "WQTracker" and WorldQuestTrackerAddon then
                    for _, wq in ipairs(WorldQuestTrackerAddon.QuestTrackList or {}) do
                        trackedWQ[wq.questID] = true
                    end
                elseif wqFilter == "WQTracker" then
                    wqFilter = "All"
                end

                for _, wq in ipairs(mapWQ) do
                    if isTask(wq.questID) and (wq.mapID == player.uiMapID) then
                        local id = "WorldQuest_" .. wq.questID
                        if not poiTrackPointTable[player.uiMapID][id] then
                            wq.name = GetTitleForQuestID(wq.questID)
                            wq.atlasName = "completiondialog-warwithincampaign-worldquests-icon"
                            wq.circle = true
                            addPOITrackNode(id, wq, wq.x, wq.y, 1)
                        end
                        if not poiTrackPointTable[player.uiMapID][id].texture then
                            poiTrackPointTable[player.uiMapID][id].texture = getWQicon(wq.questID)
                            if poiTrackPointTable[player.uiMapID][id].texture then
                                local poiTrackNode = poiTrackPointTable[player.uiMapID][id].frame
                                poiTrackNode.texture:SetTexture(poiTrackPointTable[player.uiMapID][id].texture)
                            end
                        end
                        if wqFilter ~= "All" and not trackedWQ[wq.questID] then
                            poiTrackPointTable[player.uiMapID][id].visible = false
                        else
                            poiTrackPointTable[player.uiMapID][id].visible = true
                        end
                        poiTrackPointTable[player.uiMapID][id].trackType = POI_TRACK_WORLD_QUEST
                        poiNodes.seen[id] = true
                    end
                end
            end

            -- quests in the quest log with a place on this map (objective area, or the turn-in when
            -- complete). World quests and bonus objectives have their own type above.
            local mapQuests = Options.POITrackFilter[poiTypeEnum.QUEST] and GetQuestsOnMap(player.uiMapID)
            if mapQuests then
                local onlyComplete = Options.POITrackFilter[poiTypeEnum.QUEST .. "_complete"]
                local pois = poiTrackPointTable[player.uiMapID]
                for _, quest in ipairs(mapQuests) do
                    local questID = quest.questID
                    if questID and quest.x and quest.y and not isTask(questID) then
                        local id = poiTypeEnum.QUEST .. "_" .. questID
                        local completed = IsQuestComplete(questID) and true or false
                        local node = pois[id]
                        if node and node.completed ~= completed then
                            -- completed or no longer: other icon, build the node again
                            poiNodes.release(pois, id)
                            node = nil
                        end
                        if not node then
                            -- same icons as the supertracker pointer of this quest type
                            local options = Options.Pointers[getPointerType(questID, 0)]
                            local atlas = options and (completed and options.atlasAltID or options.atlasID)
                            quest.name = GetTitleForQuestID(questID)
                            quest.completed = completed
                            quest.atlasName = atlas or (completed and "QuestTurnin" or "QuestNormal")
                            node = addPOITrackNode(id, quest, quest.x, quest.y, 1)
                        else
                            -- the place changes with the objectives: refresh it on every scan
                            local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(quest.x, quest.y, player.uiMapID)
                            node.x, node.y = xWorld, yWorld
                            node.frame.x, node.frame.y = xWorld, yWorld
                        end
                        node.trackType = poiTypeEnum.QUEST
                        node.visible = completed or not onlyComplete
                        poiNodes.seen[id] = true
                    end
                end
            end

            -- vignettes, world quests and quests the game no longer reports (killed, looted,
            -- expired, turned in, filtered out) are removed, so this map's list does not grow
            local pois = poiTrackPointTable[player.uiMapID]
            for id, poi in pairs(pois) do
                if poiNodes.isTransient(poi) and not poiNodes.seen[id] then
                    poiNodes.release(pois, id)
                end
            end
        end
        poiTrackThrottle = 0
    end

    local minAngle = 360
    poiTrackHeading = nil
    local effectivePOITrackRadius = Options.POITrackRadius == 0 and Options.POITrackOpacityMaxRadius or Options.POITrackRadius
    -- the fade runs from OpacityMinRadius to the radius; no span (radius == min radius) means no fade instead of 0/0
    local opacitySpan = effectivePOITrackRadius - Options.POITrackOpacityMinRadius
    local opacityFactor = opacitySpan > 0 and (Options.POITrackOpacityMin - Options.POITrackOpacityMax) / opacitySpan or 0
    -- the game's tracked target, if minimap icons at its place should be hidden (see shownGameTarget)
    local target = Options.HidePOIAtTarget and shownGameTarget
    for _, poi in pairs(poiTrackPointTable and poiTrackPointTable[player.uiMapID] or {}) do
        if poi.frame then
            local shown = false
            if poi.visible and player.angle then
                if poi.x and poi.y and poi.instance then
                    poi.distance = HBD:GetWorldDistance(poi.instance, player.x, player.y, poi.x, poi.y)
                    if Options.POITrackRadius == 0 or poiTrackBypassesRadius(poi) or (poi.distance and poi.distance <= Options.POITrackRadius) then
                        -- normalized to -PI..PI before picking the icon closest to the heading
                        local angle = relativeAngle(poi.instance, poi.x, poi.y)
                        poi.angle = angle
                        if angle and abs(angle) < minAngle then
                            minAngle = abs(angle)
                            poiTrackHeading = poi
                        end
                        if angle then
                            local visible = math.rad(Options.Degrees)/2
                            if angle < visible and angle > -visible then
                                poi.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, Options.POITrackOffset)
                                shown = true
                                -- already shown as the supertracker pointer: no second marker. It stays
                                -- selectable above, so the keybinding can still toggle its tracking off.
                                if target then
                                    local distance = HBD:GetWorldDistance(poi.instance, poi.x, poi.y, target.x, target.y)
                                    if distance and distance <= SAME_POINT_YARDS then
                                        shown = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
            poi.frame:SetShown(shown)
            poi.frame.DistanceText:SetShown(Options.POITrackShowDistance and Options.POITrackTextsDegrees == 0)
            poi.frame.distanceHidden= not (Options.POITrackShowDistance and Options.POITrackTextsDegrees == 0)
            poi.frame.TimeText:SetShown(Options.POITrackShowTTA and Options.POITrackTextsDegrees == 0)
            poi.frame.timeHidden = not (Options.POITrackShowTTA and Options.POITrackTextsDegrees == 0)
            poi.frame.Title:SetShown(Options.POITrackShowTitle and Options.POITrackTextsDegrees == 0)
            poi.shown = shown

            poi.opacity = Options.POITrackOpacityMin
            if not poi.distance or (poi.distance < Options.POITrackOpacityMinRadius) then
                poi.opacity = Options.POITrackOpacityMax
            elseif poi.distance <= effectivePOITrackRadius then
                poi.opacity = Options.POITrackOpacityMax + (poi.distance - Options.POITrackOpacityMinRadius) * opacityFactor
            end
            poi.frame:SetAlpha(poi.opacity)
        end
    end
    if (Options.POITrackTextsDegrees > 0) and (minAngle <= math.rad(Options.POITrackTextsDegrees)) then
        local poi = poiTrackHeading
        if poi then
            poi.frame.DistanceText:SetShown(Options.POITrackShowDistance)
            poi.frame.distanceHidden = not Options.POITrackShowDistance
            poi.frame.TimeText:SetShown(Options.POITrackShowTTA)
            poi.frame.timeHidden = not Options.POITrackShowTTA
            poi.frame.Title:SetShown(Options.POITrackShowTitle)
            poi.frame:SetAlpha(Options.POITrackOpacitySelected)
        end
    end
    HUD.minimapIcons = poiTrackPointTable
end

-- The icon the supertrack keybinding acts on: the minimap icon or (with its option) the Questie
-- icon closest to the facing direction, whichever is closer.
local function faceTrackedIcon()
    local poi = Options.POITrackEnabled and poiTrackHeading
    if poi and not (poi.visible and poi.instance == player.uiMapID and poi.angle) then
        poi = nil
    end
    local questie = Options.QuestieEnabled and Options.QuestieSupertrack and questieNodes.heading
    if questie and not (questie.frame and questie.instance == player.uiMapID and questie.angle) then
        questie = nil
    end
    if poi and questie then
        return math.abs(questie.angle) < math.abs(poi.angle) and questie or poi
    end
    return poi or questie
end

function supertrackPOITrack()
    if not player.uiMapID then return end

    local poi = faceTrackedIcon()
    if poi then
        local stType = GetHighestPrioritySuperTrackingType()
        if poi.questID then
            if stType == Enum.SuperTrackingType.Quest then
                local questID = GetSuperTrackedQuestID()
                if questID == poi.questID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedQuestID(poi.questID)
        elseif poi.areaPoiID then
            if stType == Enum.SuperTrackingType.MapPin then
                local _, stTypeID = GetSuperTrackedMapPin()
                if stTypeID == poi.areaPoiID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.AreaPOI, poi.areaPoiID)
        elseif poi.nodeID then
            if stType == Enum.SuperTrackingType.MapPin then
                local _, stTypeID = GetSuperTrackedMapPin()
                if stTypeID == poi.nodeID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedMapPin(Enum.SuperTrackingMapPinType.TaxiNode, poi.nodeID)
        elseif poi.vignetteGUID then
            if stType == Enum.SuperTrackingType.Vignette then
                local stVignetteGUID = GetSuperTrackedVignette()
                if stVignetteGUID == poi.vignetteGUID then
                    ClearAllSuperTracked()
                    return
                end
            end
            SetSuperTrackedVignette(poi.vignetteGUID)
        elseif CanSetUserWaypointOnMap(poi.instance) then
            -- remembered, so the supertracker pointer of the waypoint gets the icon's name and look
            local poiTracked = { atlasName = poi.atlasName, texture = poi.texture, name = poi.name, x = poi.x, y = poi.y, instance = poi.instance, questID = poi.questID }
            poiTracked.xZone, poiTracked.yZone = HBD:GetZoneCoordinatesFromWorld(poi.x, poi.y, poi.instance, false)
            local pos = CreateVector2D(poiTracked.xZone, poiTracked.yZone)
            local mapPoint = UiMapPoint.CreateFromVector2D(poiTracked.instance, pos)
            poiNodes.tracked = poiTracked
            if stType == Enum.SuperTrackingType.UserWaypoint then
                local userWaypoint = GetUserWaypoint()
                if userWaypoint and isTrackedWaypoint(userWaypoint, poiTracked) then
                    ClearUserWaypoint()
                    ClearAllSuperTracked()
                    return
                end
            end
            SetUserWaypoint(mapPoint)
            SetSuperTrackedUserWaypoint(true)
        end
    end
end
