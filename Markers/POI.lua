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


POI_TRACK_WORLD_QUEST = "WorldQuest" -- world quests have their own bypass toggle

-- The minimap icons as a marker source (Markers/Common.lua): each scan reports the icons of the
-- current map that pass the filters; the others (another map, filtered out, killed, looted,
-- expired, turned in) give their frame back to the pool. The game API records become the nodes.
poiNodes = registerMarkerSource({
    prefix = "POITrack",
    speechOption = "SpeechPOI", -- older name
    speech = {
        order = 20,
        default = true,
        name = "Minimap icons",
        desc = "The icons shown by Minimap tracking -> Minimap icons (turn them on there).",
    },
    -- tracked = the icon the supertrack keybinding set a user waypoint for (supertrackPOITrack)
})

-- "Bypass scanning radius" per icon type (checked at draw time, so a change applies right away)
function poiNodes.bypassesRadius(poi)
    return poiTrackBypassesRadius(poi)
end

-- Whether the game's user waypoint 'point' (UiMapPoint) is the one set for the remembered icon
-- 'tracked' (poiNodes.tracked). The game stores the position slightly rounded, so it is compared
-- with a small tolerance (a ten-thousandth of the map, below a yard on most maps).
function isTrackedWaypoint(point, tracked)
    return tracked and point and point.uiMapID == tracked.instance and point.position
        and math.abs(point.position.x - tracked.xZone) < 0.0001
        and math.abs(point.position.y - tracked.yZone) < 0.0001
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

-- Reports an icon found by the scan under 'id': the node it already has, or a new node made of the
-- game API record 'data' at zone position xZone, yZone of the current map (icon size 'scale').
local function reportIcon(id, data, xZone, yZone, scale, trackType)
    local node = markerNode(poiNodes, id)
    if not node then
        local x, y = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
        if not (x and y) then return end
        data.x, data.y, data.scale = x, y, scale
        data.instance = player.uiMapID
        node = newMarkerNode(poiNodes, id, data)
    end
    node.trackType = trackType
    return node
end

-- Reports an area POI (of the list for 'poiType') if its type passes the filter.
local function reportAreaPOI(poiID, poiType)
    local id = poiType .. "_" .. poiID
    -- current game data first; the continent cache (filled once per session) only as a fallback,
    -- so an event or other dynamic POI does not keep details from when the continent was cached
    local poi = poiNodes.nodes[id] or GetAreaPOIInfo(player.uiMapID, poiID)
        or (poiCache[poiID] and poiCache[poiID][player.uiMapID] and poiCache[poiID][player.uiMapID].poi)
    if not (poi and poi.position) then return end
    if not poi.atlasName then
        local options = Options.Pointers[getPointerType(nil, selectedPin)]
        poi.atlasName = options.atlasID
    end
    local trackType = poiType == poiTypeEnum.OTHER and poiTrackTypeByAtlas(poi, poiTypeEnum.OTHER) or poiType
    if Options.POITrackFilter[trackType] then
        reportIcon(id, poi, poi.position.x, poi.position.y, 1.3, trackType)
    end
end

local areaPOILists = {
    { poiTypeEnum.OTHER, GetAreaPOIForMap },
    { poiTypeEnum.DELVE, GetDelvesForMap },
    { poiTypeEnum.EVENT, GetEventsForMap },
    { poiTypeEnum.HUB, GetQuestHubsForMap },
    { poiTypeEnum.RACE, GetDragonridingRacesForMap },
}

local function scanAreaPOIs()
    local filter = Options.POITrackFilter
    for _, list in ipairs(areaPOILists) do
        local poiType, getList = list[1], list[2]
        -- area POIs of the "other" list can also be portals
        local wanted = filter[poiType] or (poiType == poiTypeEnum.OTHER and filter[poiTypeEnum.PORTAL])
        local poiIDs = wanted and getList and getList(player.uiMapID)
        if poiIDs then
            for _, poiID in ipairs(poiIDs) do
                reportAreaPOI(poiID, poiType)
            end
        end
    end
end

local function scanMapLinks()
    local filter = Options.POITrackFilter
    local links = (filter[poiTypeEnum.PORTAL] or filter[poiTypeEnum.LINK]) and GetMapLinksForMap(player.uiMapID)
    for _, poi in ipairs(links or {}) do
        local id = poiTypeEnum.LINK .. "_" .. poi.areaPoiID
        local trackType = poiTrackTypeByAtlas(poiNodes.nodes[id] or poi, poiTypeEnum.LINK)
        if filter[trackType] then
            reportIcon(id, poi, poi.position.x, poi.position.y, 1.3, trackType)
        end
    end
end

local function scanDungeonEntrances()
    local entrances = Options.POITrackFilter[poiTypeEnum.INSTANCE] and GetDungeonEntrancesForMap(player.uiMapID)
    for _, entrance in ipairs(entrances or {}) do
        reportIcon(poiTypeEnum.INSTANCE .. "_" .. entrance.areaPoiID, entrance, entrance.position.x,
            entrance.position.y, 1.3, poiTypeEnum.INSTANCE)
    end
end

-- Usable flight points; with "closest only" (Taxi_min) just the closest one.
local function scanFlightPoints()
    local taxis = Options.POITrackFilter[poiTypeEnum.TAXI] and GetTaxiNodesForMap(player.uiMapID)
    if not taxis then return end
    local closestOnly = Options.POITrackFilter[poiTypeEnum.TAXI .. "_min"]
    local closest, closestDistance = nil, math.huge
    for _, taxi in ipairs(taxis) do
        if isTaxiNodeUsable(taxi) then
            if closestOnly then
                local x, y = HBD:GetWorldCoordinatesFromZone(taxi.position.x, taxi.position.y, player.uiMapID)
                local distance = x and y and HBD:GetWorldDistance(player.uiMapID, player.x, player.y, x, y)
                if distance and distance < closestDistance then
                    closest, closestDistance = taxi, distance
                end
            else
                reportIcon(poiTypeEnum.TAXI .. "_" .. taxi.nodeID, taxi, taxi.position.x, taxi.position.y, 1.2, poiTypeEnum.TAXI)
            end
        end
    end
    if closest then
        reportIcon(poiTypeEnum.TAXI .. "_" .. closest.nodeID, closest, closest.position.x, closest.position.y, 1.2, poiTypeEnum.TAXI)
    end
end

local function scanVignettes()
    local vignetteGUIDs = Options.POITrackFilter[poiTypeEnum.VIGNETTE] and GetVignettes()
    for _, vignetteGUID in ipairs(vignetteGUIDs or {}) do
        local vignetteInfo = GetVignetteInfo(vignetteGUID)
        local position = GetVignettePosition(vignetteGUID, player.uiMapID)
        if vignetteInfo and position then
            local id = poiTypeEnum.VIGNETTE .. "_" .. vignetteInfo.vignetteGUID
            local node = poiNodes.nodes[id]
            if node then
                -- vignettes can move (e.g. wandering rares): refresh the position on every scan
                local x, y = HBD:GetWorldCoordinatesFromZone(position.x, position.y, player.uiMapID)
                if x and y then
                    moveMarkerNode(node, x, y)
                end
            end
            reportIcon(id, vignetteInfo, position.x, position.y, 1.3, poiTypeEnum.VIGNETTE)
        end
    end
end

local function scanWorldQuests()
    local mapWQ = GetWorldQuestsOnMap(player.uiMapID)
    -- local copy: falling back to "All" while World Quest Tracker is not loaded must not change the saved setting
    local wqFilter = Options.POITrackWQFilter
    if wqFilter == "None" or not mapWQ then return end
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
        if isTask(wq.questID) and wq.mapID == player.uiMapID and (wqFilter == "All" or trackedWQ[wq.questID]) then
            local id = "WorldQuest_" .. wq.questID
            if not poiNodes.nodes[id] then
                wq.name = GetTitleForQuestID(wq.questID)
                wq.atlasName = "completiondialog-warwithincampaign-worldquests-icon"
                wq.circle = true
            end
            local node = reportIcon(id, wq, wq.x, wq.y, 1, POI_TRACK_WORLD_QUEST)
            -- the reward icon, once the game has loaded it
            if node and not node.texture then
                node.texture = getWQicon(wq.questID)
                if node.texture then
                    node.frame.texture:SetTexture(node.texture)
                end
            end
        end
    end
end

-- Quests in the quest log with a place on this map (objective area, or the turn-in when complete).
-- World quests and bonus objectives have their own type above.
local function scanQuests()
    local mapQuests = Options.POITrackFilter[poiTypeEnum.QUEST] and GetQuestsOnMap(player.uiMapID)
    if not mapQuests then return end
    -- both, active (in progress) or complete (ready to turn in)
    local which = Options.POITrackQuestWhich
    local iconStyle = Options.POITrackQuestIcon
    for _, quest in ipairs(mapQuests) do
        local questID = quest.questID
        -- quest.mapID: the map the quest is on (neighboring places are listed too)
        local otherZone = Options.POITrackQuestCurrentZone and quest.mapID and quest.mapID ~= player.uiMapID
        local completed = questID and IsQuestComplete(questID) and true or false
        local wanted = which == "both" or (which == "complete") == completed
        if questID and quest.x and quest.y and not otherZone and wanted and not isTask(questID) then
            local id = poiTypeEnum.QUEST .. "_" .. questID
            local node = poiNodes.nodes[id]
            if node and (node.completed ~= completed or node.iconStyle ~= iconStyle) then
                -- completed or no longer, or another icon style: build the node again
                releaseMarkerNode(poiNodes, id)
                node = nil
            end
            if node then
                -- the place changes with the objectives: refresh it on every scan
                local x, y = HBD:GetWorldCoordinatesFromZone(quest.x, quest.y, player.uiMapID)
                if x and y then
                    moveMarkerNode(node, x, y)
                end
            else
                local atlas
                if iconStyle ~= "game" then
                    -- same icons as the supertracker pointer of this quest type
                    local options = Options.Pointers[getPointerType(questID, 0)]
                    atlas = options and (completed and options.atlasAltID or options.atlasID)
                end
                quest.name = GetTitleForQuestID(questID)
                quest.completed = completed
                quest.iconStyle = iconStyle
                quest.atlasName = atlas or (completed and "QuestTurnin" or "QuestNormal")
            end
            reportIcon(id, quest, quest.x, quest.y, 1, poiTypeEnum.QUEST)
        end
    end
end

function poiNodes.scan()
    scanAreaPOIs()
    scanMapLinks()
    scanDungeonEntrances()
    scanFlightPoints()
    scanVignettes()
    scanWorldQuests()
    scanQuests()
end

-- The icon the supertrack keybinding acts on: the minimap icon or a node of a marker module with
-- "Use supertracker keybinding" (Questie, GatherMate, TomTom), whichever is closest to the facing
-- direction, and its module.
local function faceTrackedIcon()
    local best, bestModule = Options.POITrackEnabled and poiNodes.heading, poiNodes
    if best and not (best.frame and best.instance == player.uiMapID and best.angle) then
        best = nil
    end
    for _, module in ipairs(markerModules) do
        local node = markerModuleHeading(module, "Supertrack")
        if node and (not best or math.abs(node.angle) < math.abs(best.angle)) then
            best, bestModule = node, module
        end
    end
    return best, bestModule
end

function supertrackPOITrack()
    if not player.uiMapID then return end

    local poi, module = faceTrackedIcon()
    -- a source with its own way of tracking (TomTom: the crazy arrow)
    if poi and module.supertrack and module.supertrack(poi) then
        return
    end
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
        else
            -- the map for the waypoint: the icon's own (waypointMapID, e.g. a HandyNotes icon of a
            -- nearby zone, outside the current map) or the current one, if it lies on it
            local waypointMap, xZone, yZone
            for _, mapID in ipairs({ poi.waypointMapID or false, poi.instance or false }) do
                if mapID and CanSetUserWaypointOnMap(mapID) then
                    xZone, yZone = HBD:GetZoneCoordinatesFromWorld(poi.x, poi.y, mapID, false)
                    if xZone and yZone then
                        waypointMap = mapID
                        break
                    end
                end
            end
            if not waypointMap then return end
            -- remembered, so the supertracker pointer of the waypoint gets the icon's name and look
            -- (texCoords, color: a part of a texture sheet and its tint, e.g. HandyNotes icons)
            local poiTracked = { atlasName = poi.atlasName, texture = poi.texture, texCoords = poi.texCoords, color = poi.color,
                name = poi.name, x = poi.x, y = poi.y, instance = waypointMap, questID = poi.questID }
            poiTracked.xZone, poiTracked.yZone = xZone, yZone
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
