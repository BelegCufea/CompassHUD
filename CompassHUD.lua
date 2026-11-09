local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

-- Lua built-ins used in update loops, local so they don't go through the shared environment
local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

_G.BINDING_HEADER_COMPASSHUD = "CompassHUD"
_G.BINDING_NAME_COMPASSHUD_SUPERTRACK = "Toggle Supertracking for Minimap icon"

local Const = Addon.CONST
local Debug = Addon.DEBUG

local AceDBOptions      = LibStub("AceDBOptions-3.0")
local AceConfig         = LibStub("AceConfig-3.0")
local AceConfigDialog   = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")

local GetPlayerFacing = GetPlayerFacing
local GetQuestsOnMap = C_QuestLog.GetQuestsOnMap
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestInfo = C_QuestLog.GetInfo
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetMapForQuestPOIs = C_QuestLog.GetMapForQuestPOIs
local GetNextWaypoint = C_QuestLog.GetNextWaypoint
local GetNextWaypointForMap = C_QuestLog.GetNextWaypointForMap
local GetQuestAdditionalHighlights = C_QuestLog.GetQuestAdditionalHighlights
local IsQuestComplete = C_QuestLog.IsComplete
local GetQuestRewardCurrencyInfo = C_QuestLog.GetQuestRewardCurrencyInfo
local GetNumWorldQuestWatches = C_QuestLog.GetNumWorldQuestWatches
local GetQuestIDForWorldQuestWatchIndex = C_QuestLog.GetQuestIDForWorldQuestWatchIndex
local GetQuestZoneID = C_TaskQuest.GetQuestZoneID
local GetQuestLocation = C_TaskQuest.GetQuestLocation
local IsTaskQuestActive = C_TaskQuest.IsActive
local RequestPreloadRewardData = C_TaskQuest.RequestPreloadRewardData
local GetWorldQuestsOnMap = C_TaskQuest.GetQuestsOnMap
local GetTaskQuestInfoByQuestID = C_TaskQuest.GetQuestInfoByQuestID
local GetAvailableQuestLines = C_QuestLine and C_QuestLine.GetAvailableQuestLines
local GetQuestClassification = C_QuestInfoSystem.GetQuestClassification
local GetMapInfo = C_Map.GetMapInfo
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetMapLinksForMap = C_Map.GetMapLinksForMap
local CanSetUserWaypointOnMap = C_Map.CanSetUserWaypointOnMap
local SetUserWaypoint = C_Map.SetUserWaypoint
local GetMapChildrenInfo = C_Map.GetMapChildrenInfo
local ClearUserWaypoint = C_Map.ClearUserWaypoint
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedMapPin = C_SuperTrack.GetSuperTrackedMapPin
local GetSuperTrackedVignette = C_SuperTrack.GetSuperTrackedVignette
local ClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
local GetHighestPrioritySuperTrackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType
local GetNextWaypointForMapTracker = C_SuperTrack.GetNextWaypointForMap
local IsSuperTrackingAnything = C_SuperTrack.IsSuperTrackingAnything
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
local GetClassColor = C_ClassColor.GetClassColor
local GetAtlasInfo = C_Texture.GetAtlasInfo
local GetTaxiNodesForMap = C_TaxiMap.GetTaxiNodesForMap
local GetVignettes = C_VignetteInfo.GetVignettes
local GetVignettePosition = C_VignetteInfo.GetVignettePosition
local GetVignetteInfo = C_VignetteInfo.GetVignetteInfo
local GetGlidingInfo = C_PlayerInfo.GetGlidingInfo

function updateGatherMateNode(node)
    local scale = Options.Scale * Options.VerticalScale * Options.GatherMateScale
    node.frame:SetSize(textureHeight * Options.GatherMateScale, textureHeight * Options.GatherMateScale)
    setPointerFont(node.frame.DistanceText, scale, Options.GatherMateDistanceCustomFont, Options.GatherMateDistanceFont, Options.GatherMateDistanceFontSize, Options.GatherMateDistanceFontFlags, Options.GatherMateDistanceFontColor)
    setPointerFont(node.frame.TimeText, scale, Options.GatherMateTtaCustomFont, Options.GatherMateTtaFont, Options.GatherMateTtaFontSize, Options.GatherMateTtaFontFlags, Options.GatherMateTtaFontColor)
    setPointerFont(node.frame.Title, scale, Options.GatherMateTitleCustomFont, Options.GatherMateTitleFont, Options.GatherMateTitleFontSize, Options.GatherMateTitleFontFlags, Options.GatherMateTitleFontColor)

    node.flipped = Options.GatherMateOffset > 0
    layoutNodeTexts(node.frame, node.flipped, Options.GatherMateShowDistance, Options.GatherMateShowTTA, Options.GatherMateShowTitle,
        Options.GatherMateDistanceOffset, Options.GatherMateTtaOffset, Options.GatherMateTitleOffset)
    -- lets questPointerSetTexts skip work for hidden texts
    node.frame.distanceHidden = not Options.GatherMateShowDistance
    node.frame.timeHidden = not Options.GatherMateShowTTA
end

-- Gathering nodes on the HUD. gatherMatePointTable holds only the nodes found by the latest scan
-- (within the scanning radius of the player, keyed per node). Nodes that leave that set give their
-- frame back to a pool, so neither the table nor the per-tick draw loop grows with the session.
-- (state kept in one table: the main chunk is close to Lua's limit of 200 local variables)
gatherNodes = {
    framePool = {},
    seen = {},          -- nodes found by the current scan
    liteTypes = { "mining", "herbalism", "containers", "fishing" }, -- GatherLite node types
    liteObjects = {},   -- object ID -> GatherLite object (GetNodeObject searches its whole list)
}

function acquireGatherNodeFrame()
    local frame = table.remove(gatherNodes.framePool)
    if frame then
        return frame
    end
    frame = CreateFrame("FRAME", nil, HUD)
    frame:SetSize(textureHeight, textureHeight)
    frame:SetPoint("CENTER")
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetAllPoints(frame)
    frame:Hide()
    frame.DistanceText = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.DistanceText:SetJustifyV("TOP")
    frame.DistanceText:SetSize(0, 16)
    frame.DistanceText:SetParent(frame)
    frame.TimeText = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.TimeText:SetJustifyV("TOP")
    frame.TimeText:SetSize(0, 16)
    frame.TimeText:SetParent(frame)
    frame.Title = frame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    frame.Title:SetJustifyV("TOP")
    frame.Title:SetSize(0, 16)
    frame.Title:SetParent(frame)
    frame.type = "GatherMate"
    frame.elapsed = 0
    frame:SetScript("OnUpdate", questPointerSetTexts)
    return frame
end

function releaseGatherNode(key)
    local node = gatherMatePointTable[key]
    gatherMatePointTable[key] = nil
    if node and node.frame then
        local frame = node.frame
        frame:Hide()
        -- per-target text state must not carry over to the next node using this frame
        frame.minDistance = nil
        frame.ttaLastDistance = nil
        table.insert(gatherNodes.framePool, frame)
    end
end

-- Adds a node found by a scan (world coordinates, icon texture, title), or keeps the existing one.
function addGatherNode(key, xWorld, yWorld, icon, title)
    gatherNodes.seen[key] = true
    if gatherMatePointTable[key] then
        return
    end
    local node = { visible = true, instance = player.uiMapID, x = xWorld, y = yWorld }
    local frame = acquireGatherNodeFrame()
    frame.texture:SetTexture(icon)
    frame.Title:SetText(title or "")
    frame.instance, frame.x, frame.y = node.instance, xWorld, yWorld
    node.frame = frame
    gatherMatePointTable[key] = node
    updateGatherMateNode(node)
end

-- GatherMate2 node source. These are GatherMate2's long-standing public methods plus three of its
-- tables; every one is checked, so a change in GatherMate2 means no nodes rather than Lua errors.
function scanGatherMate2(zoneX, zoneY)
    local gm = GatherMate2
    if not (gm and gm.db_types and gm.Visible and gm.nodeTextures and gm.FindNearbyNode and gm.DecodeLoc and gm.GetNameForNode) then
        return
    end
    for _, dbType in pairs(gm.db_types) do
        if gm.Visible[dbType] then
            for coord, nodeID in gm:FindNearbyNode(player.uiMapID, zoneX, zoneY, dbType, Options.GatherMateRadius) do
                local key = dbType .. ":" .. coord
                if gatherMatePointTable[key] then
                    gatherNodes.seen[key] = true
                else
                    local xZone, yZone = gm:DecodeLoc(coord)
                    local xWorld, yWorld = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                    if xWorld and yWorld then
                        local icon = gm.nodeTextures[dbType] and gm.nodeTextures[dbType][nodeID]
                        addGatherNode(key, xWorld, yWorld, icon, gm:GetNameForNode(dbType, nodeID))
                    end
                end
            end
        end
    end
end

-- GatherLite node source (WoW: Forever), used when GatherMate2 is not loaded. GatherLite has no
-- documented API: these are its own functions, each one checked, so a change in GatherLite means
-- no nodes rather than Lua errors. Its node records are stable tables, so they serve as keys.

function getGatherLiteObject(gl, objectID)
    local object = gatherNodes.liteObjects[objectID]
    if object == nil then
        object = gl:GetNodeObject(objectID) or false
        gatherNodes.liteObjects[objectID] = object
    end
    return object or nil
end

function scanGatherLite()
    local gl = GatherLite
    if not (gl and gl.IsLoaded and gl.GetNearbyZoneNodes and gl.EnsureNodeWorld and gl.GetNodeObject) or not gl:IsLoaded() then
        return
    end
    local zoneX, zoneY, mapID = HBD:GetPlayerZonePosition(true)
    if not (zoneX and zoneY and mapID and player.instance and player.x and player.y) then
        return
    end
    local radius = Options.GatherMateRadius
    local usePredefined = not (gl.db and gl.db.global and gl.db.global.usePredefined == false)
    for _, nodeType in ipairs(gatherNodes.liteTypes) do
        -- follow GatherLite's own minimap tracking toggles, like GatherMate2's display filter
        if not gl.GetNodeTracking or gl:GetNodeTracking("minimap", nodeType) then
            for _, node in ipairs(gl:GetNearbyZoneNodes(nodeType, mapID, player.instance, zoneX, zoneY, radius) or {}) do
                if gatherMatePointTable[node] then
                    gatherNodes.seen[node] = true
                elseif not (node.predefined and not usePredefined) and not (gl.IsIgnored and gl:IsIgnored(node.object)) then
                    if not (node.worldX and node.worldY and node.instance) then
                        gl:EnsureNodeWorld(node)
                    end
                    if node.instance == player.instance and node.worldX and node.worldY then
                        -- GatherLite returns whole index cells: keep only nodes within the radius
                        local distance = HBD:GetWorldDistance(player.instance, player.x, player.y, node.worldX, node.worldY)
                        local object = distance and distance <= radius and getGatherLiteObject(gl, node.object)
                        if object then
                            -- GatherLite's locale keys for node names are "node.<name>" (as in its own tooltips)
                            local title = gl.translate and gl:translate("node." .. object.name) or object.name
                            addGatherNode(node, node.worldX, node.worldY, object.icon, title)
                        end
                    end
                end
            end
        end
    end
end

function updateGatherMate()
    for key, node in pairs(gatherMatePointTable) do
        if not Options.GatherMateEnabled then
            releaseGatherNode(key)
        elseif node.frame then
            updateGatherMateNode(node)
        end
    end
end

function setGatherMateNodes()
    -- GatherMate2 if loaded, else GatherLite
    if not Options.GatherMateEnabled or not (GatherMate2 or GatherLite) then return end
    if gatherMateThrottle and gatherMateThrottle >= Options.GatherMateInterval then
        gatherMateThrottle = 0
        local x, y = HBD:GetZoneCoordinatesFromWorld(player.x, player.y, player.uiMapID, false)
        if x and y then
            wipe(gatherNodes.seen)
            if GatherMate2 then
                scanGatherMate2(x, y)
            else
                scanGatherLite()
            end
            -- nodes no longer in range (or on another map) give their frame back to the pool
            for key in pairs(gatherMatePointTable) do
                if not gatherNodes.seen[key] then
                    releaseGatherNode(key)
                end
            end
        end
    end
    for _, node in pairs(gatherMatePointTable) do
        local shown = false
        if node.visible and player.angle then
            if node.x and node.y and node.instance then
                local angle = relativeAngle(node.instance, node.x, node.y)
                if angle then
                    local visible = math.rad(Options.Degrees)/2
                    if angle < visible and angle > -visible then
                        node.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, Options.GatherMateOffset)
                        shown = true
                    end
                end
            end
        end
        node.frame:SetShown(shown)
    end
    HUD.gathermateNodes = gatherMatePointTable
end

function updatePOITrackNode(poi)
    local scale = Options.Scale * Options.VerticalScale * Options.POITrackScale
    poi.frame:SetSize(textureHeight * Options.POITrackScale * (poi.scale or 1), textureHeight * Options.POITrackScale * (poi.scale or 1))
    setPointerFont(poi.frame.DistanceText, scale, Options.POITrackDistanceCustomFont, Options.POITrackDistanceFont, Options.POITrackDistanceFontSize, Options.POITrackDistanceFontFlags, Options.POITrackDistanceFontColor)
    setPointerFont(poi.frame.TimeText, scale, Options.POITrackTtaCustomFont, Options.POITrackTtaFont, Options.POITrackTtaFontSize, Options.POITrackTtaFontFlags, Options.POITrackTtaFontColor)
    setPointerFont(poi.frame.Title, scale, Options.POITrackTitleCustomFont, Options.POITrackTitleFont, Options.POITrackTitleFontSize, Options.POITrackTitleFontFlags, Options.POITrackTitleFontColor)

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
    poiTrackNode:SetSize(textureHeight, textureHeight)
    poiTrackNode:ClearAllPoints()
    poiTrackNode:SetPoint("CENTER")
    poiTrackNode:Hide()
    poiTrackNode.texture:SetAtlas(data.atlasName)
    poiTrackNode.texture:SetSize(textureHeight, textureHeight)
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

-- Vignettes and world quests come and go; other minimap icon types are fixed per map.
function poiNodes.isTransient(poi)
    return poi.trackType == poiTypeEnum.VIGNETTE or poi.trackType == POI_TRACK_WORLD_QUEST
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

            -- vignettes and world quests the game no longer reports (killed, looted, expired,
            -- filtered out) are removed, so this map's list does not grow during the session
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

function updateHeading()
    if HUD.heading and HUD.heading.text and player.angle then
        local heading = (360 - (player.angle * (180 / math.pi))) % 360
        if Options.HeadingDecimals >= 0 then
            local multiplier = 10^Options.HeadingDecimals
            heading = math.floor(heading * multiplier + 0.5) / multiplier
        else
            local multiplier = Options.HeadingDecimals * 5 * -1
            heading = math.floor((heading + multiplier/2) / multiplier) * multiplier
        end

        --Zee-ro fix
        if heading == 0 and Options.HeadingTrueNorth then
            heading = 360
        end

        HUD.heading.text:SetText(heading)
    end
end

function updateHUD(force)
    local facing = GetPlayerFacing() or 0
    if force or facing ~= currentFacing then
        local coord = (facing < PI and 0.5 or 1) - (facing * ADJ_FACTOR)
        -- rotate texture
        HUD.compassTexture:SetTexCoord(coord - adjCoord, coord + adjCoord, 0, 1)
        -- rotate letters
        HUD.compassCustom.mask:ClearAllPoints()
        HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', (1/2 - coord) * textureWidth, 0)
        currentFacing = facing
    end
    updatePlayerCoords()
    updateHeading()
    setQuestsIcons()
    setGroupIcons()
    setGatherMateNodes()
    setPOITrackNodes()
end

function onUpdate(_, elapsed)
    if player.inInstance then return end

    timer = timer + elapsed
    if timer < (1 / Options.Interval) then return end
    timer = 0
    groupThrottle = groupThrottle + 1
    gatherMateThrottle = gatherMateThrottle + 1
    poiTrackThrottle = poiTrackThrottle + 1
    updateHUD(false)
end

function tomtomSetCrazyArrow(self, uid, dist, title)
    if not Options.Pointers[questPointerIdent .. tomTom].enabled then return end
    if not uid then return end
    if type(uid) ~= "table" then return end
    local questID = tomTom
    local questType = tomTom
    local completed = false
    if title and title:find("^Turn in: ") then
        completed = true
    end
    updateQuest(questID, uid[2], uid[3], uid[1], questType, title, completed)
    tomTomActive = TomTom:GetKey(uid)
    questPointsTable[tomTom].track = true
end

function tomtomClearWaypoint(self, uid)
    if not uid then return end
    if type(uid) ~= "table" then return end
    local tomTomRemoved = TomTom:GetKey(uid)
    if tomTomRemoved and tomTomActive == tomTomRemoved and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
end

function supertrackPOITrack()
    if not Options.POITrackEnabled then return end
    if not player.uiMapID or not poiTrackPointTable[player.uiMapID] then
        return
    end

    local poi = poiTrackHeading
    if poi and poi.visible and poi.instance == player.uiMapID then
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
            local poiTracked = { atlasName = poi.atlasName, name = poi.name, x = poi.x, y = poi.y, instance = poi.instance, questID = poi.questID }
            poiTracked.xZone, poiTracked.yZone = HBD:GetZoneCoordinatesFromWorld(poi.x, poi.y, poi.instance, false)
            local pos = CreateVector2D(poiTracked.xZone, poiTracked.yZone)
            local mapPoint = UiMapPoint.CreateFromVector2D(poiTracked.instance, pos)
            poiTrackPointTable[player.uiMapID].tracked = poiTracked
            if stType == Enum.SuperTrackingType.UserWaypoint then
                local userWaypoint = GetUserWaypoint()
                if userWaypoint and userWaypoint.uiMapID == poiTracked.instance and
                    math.floor(userWaypoint.position.x * 100000000 + 0.5) == math.floor(poiTracked.xZone * 100000000 + 0.5) and
                    math.floor(userWaypoint.position.y * 100000000 + 0.5) == math.floor(poiTracked.yZone * 100000000 + 0.5) then
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

-- Effective HUD visibility: outside an instance and the Visibility macro condition says "show".
-- Both the zone handler and the attribute driver go through this, so neither overrides the other.
-- Before the driver has set the attribute (nil) the HUD counts as shown.
function shouldShowHUD()
    local state = HUD:GetAttribute("state-hudvisibility")
    return (state == nil or state == "show") and not player.inInstance
end

function createHUD()
    HUD = CreateFrame('Frame', ADDON_NAME, UIParent, "BackdropTemplate")
    HUD:SetPoint("CENTER")
    HUD:SetClampedToScreen(true)
    HUD:RegisterForDrag("LeftButton")

    HUD:SetScript("OnAttributeChanged", function(self, name, value)
        if name == "state-hudvisibility" then
            Addon:SetVisibility(shouldShowHUD())
        end
    end)

    HUD.SupertrackMinimapIcon = function(self)
        supertrackPOITrack()
    end
end

-- Title of the TomTom waypoint at the same place as a user map pin.
-- Some addons copy TomTom waypoints into a Blizzard user waypoint, which has no name.
-- This works for any addon that sets the TomTom waypoint (Questie, BtWQuests, ...).
tomTomTitleCache = {}
function getTomTomWaypointTitle(uiMapID, x, y)
    if not (TomTom and type(TomTom.waypoints) == "table" and uiMapID and x and y) then return end
    -- target lookups can still run several times a second: reuse the last result for the same pin for a moment
    local cache, now = tomTomTitleCache, GetTime()
    if cache.uiMapID == uiMapID and cache.x == x and cache.y == y and cache.expires and now < cache.expires then
        return cache.title
    end
    local bestTitle, bestDistance
    for _, mapWaypoints in pairs(TomTom.waypoints) do
        for _, uid in pairs(mapWaypoints) do
            local title = type(uid) == "table" and uid.title
            if title and title ~= "" and uid[1] and uid[2] and uid[3] then
                local distance = HBD:GetZoneDistance(uiMapID, x, y, uid[1], uid[2], uid[3])
                if distance and distance <= SAME_POINT_YARDS and (not bestDistance or distance < bestDistance) then
                    bestTitle, bestDistance = title, distance
                end
            end
        end
    end
    cache.uiMapID, cache.x, cache.y, cache.title, cache.expires = uiMapID, x, y, bestTitle, now + 1 -- reuse for one second
    return bestTitle
end

-- Name and position of an available quest ("!" quest offer pin).
-- GetTitleForQuestID is often empty for quests not in the quest log, so the
-- name comes from the world map pin, or from the data that the pin is built from.
questOfferCache = {}
function getQuestOfferInfo(questID, uiMapID)
    -- The pin on the open world map already holds the quest name and its position
    if WorldMapFrame:IsVisible() then
        for pin in WorldMapFrame:EnumerateAllPins() do
            if pin.questID == questID and pin.questName and pin.GetPosition then
                local x, y = pin:GetPosition()
                if x and y then
                    local atlasName = type(pin.questIcon) == "string" and pin.questIcon or nil
                    return pin.questName, x, y, WorldMapFrame:GetMapID(), atlasName
                end
            end
        end
    end

    if not uiMapID then return end

    -- Quest givers
    if GetAvailableQuestLines then
        for _, info in ipairs(GetAvailableQuestLines(uiMapID) or {}) do
            if info.questID == questID and info.x and info.y then
                return info.questName, info.x, info.y, uiMapID
            end
        end
    end

    -- Bonus objectives and other task quests
    if GetWorldQuestsOnMap then
        for _, info in ipairs(GetWorldQuestsOnMap(uiMapID) or {}) do
            if info.questID == questID and info.x and info.y then
                local name = GetTaskQuestInfoByQuestID and GetTaskQuestInfoByQuestID(questID)
                return name, info.x, info.y, uiMapID
            end
        end
    end
end

function resolveSuperTrackedTarget(event,...)
    if TomTom and TomTomCrazyArrow and not TomTomCrazyArrow:IsShown() and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
    local questID = GetSuperTrackedQuestID()
    local completed = false
    if questID and questID > 0 then
        local x, y, uiMapID
    	if isTask(questID)  then
            uiMapID = GetQuestZoneID(questID)
            if not uiMapID then
                uiMapID = getMapId(questID)
            end
            if uiMapID then
                x, y = GetQuestLocation(questID, uiMapID)
            end
        else
            uiMapID, x, y, completed = GetQuestPOIInfo(questID)
        end
        if x and y and uiMapID then
            updateQuest(questID, x, y, uiMapID, 0, nil, completed)
        end
    else
        local superTrackingType = GetHighestPrioritySuperTrackingType()
        if superTrackingType == Enum.SuperTrackingType.UserWaypoint then
            local point = GetUserWaypoint()
            if point then
                local poiTracked = poiTrackPointTable[player.uiMapID] and poiTrackPointTable[player.uiMapID].tracked
                local mult = 100000000
                local name, atlasName
                if poiTracked and math.floor(point.position.x * mult + 0.5) == math.floor(poiTracked.xZone * mult + 0.5) and
                    math.floor(point.position.y * mult + 0.5) == math.floor(poiTracked.yZone * mult + 0.5) then
                    name, atlasName = poiTracked.name, poiTracked.atlasName
                    updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, name, completed, atlasName, nil, {
                        ["stRetexture"] = Options.POITrackSTRetexture,
                        ["worldmapTexture"] = Options.POITrackWorldmapTexture,
                    })
                else
                    name = getTomTomWaypointTitle(point.uiMapID, point.position.x, point.position.y)
                    updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, name, completed)
                end
            end
        end
        local uiMapID = WorldMapFrame:IsVisible() and WorldMapFrame:GetMapID() or player.uiMapID
        if superTrackingType == Enum.SuperTrackingType.MapPin then
            local STtype, STtypeID = GetSuperTrackedMapPin()
            local poiInfo
            local title

            local moreArgs = {
                ["STtype"] = STtype,
                ["STtypeID"] = STtypeID
            }

            -- the pointer already shows this pin (from an earlier event)
            local samePin = questPointsTable[selectedPin] and questPointsTable[selectedPin].moreArgs and questPointsTable[selectedPin].moreArgs.STtype == moreArgs.STtype and questPointsTable[selectedPin].moreArgs.STtypeID == moreArgs.STtypeID

            -- try to get corrent uiMapID
            if samePin then
                uiMapID = questPointsTable[selectedPin].uiMapID
            elseif STtype == 0 and STtypeID and (not uiMapID or not poiCache[STtypeID] or not poiCache[STtypeID][uiMapID]) then
                -- poiCache is keyed by areaPoiID: only area POIs (STtype 0) can be looked up there,
                -- quest offer (1) and taxi node (2) IDs would match unrelated area POIs
                for mapID, _ in pairs(poiCache[STtypeID] or {}) do
                    uiMapID = mapID
                    break
                end
            end

            -- POI
            if (STtype == 0) and uiMapID then
                poiInfo = GetAreaPOIInfo(uiMapID, STtypeID)
            end

            -- Offer
            if STtype == 1 then
                -- A found offer does not move: reuse it until another pin is supertracked,
                -- instead of scanning all map pins again on every QUEST_LOG_UPDATE
                local cached = questOfferCache.questID == STtypeID and questOfferCache
                local name, x, y, mapID, atlasName
                if cached then
                    name, x, y, mapID, atlasName = cached.name, cached.x, cached.y, cached.mapID, cached.atlasName
                else
                    name, x, y, mapID, atlasName = getQuestOfferInfo(STtypeID, uiMapID)
                    if x and y and mapID then
                        questOfferCache = { questID = STtypeID, name = name, x = x, y = y, mapID = mapID, atlasName = atlasName }
                    end
                end
                title = name or GetTitleForQuestID(STtypeID)
                if x and y and mapID then
                    uiMapID = mapID
                    poiInfo = { name = title, position = CreateVector2D(x, y), atlasName = atlasName }
                end
            end

            -- Taxi
            if (STtype == 2) and uiMapID then
                local taxis = GetTaxiNodesForMap(uiMapID)
                if taxis then
                    for _,v in pairs(taxis) do
                        if v.nodeID == STtypeID then
                            poiInfo = v
                            break
                        end
                    end
                end
            end

            if poiInfo then
                updateQuest(selectedPin, poiInfo.position.x, poiInfo.position.y, uiMapID, selectedPin, poiInfo.name, completed, poiInfo.atlasName, nil, moreArgs)
            elseif WorldMapFrame:IsVisible() and event == "SUPER_TRACKING_CHANGED" and not samePin then
                -- No position from the game: approximate it with the cursor, but only right when the pin
                -- was clicked. Later events (QUEST_LOG_UPDATE, ...) keep that position instead of
                -- moving the target to wherever the cursor is then.
                local x, y = WorldMapFrame:GetNormalizedCursorPosition()
                if uiMapID and x and y then
                    updateQuest(selectedPin, x, y, uiMapID, selectedPin, title, completed, nil, nil, moreArgs)
                end
            end
        end
        if (superTrackingType == Enum.SuperTrackingType.Vignette) and uiMapID then
            local vignetteGUID = GetSuperTrackedVignette()
            if vignetteGUID then
                local vignettePosition = GetVignettePosition(vignetteGUID, uiMapID)
                local vignetteInfo = GetVignetteInfo(vignetteGUID)
                if vignettePosition and vignetteInfo then
                    local x, y = vignettePosition:GetXY()
                    if x and y then
                        updateQuest(selectedPin, x, y, uiMapID, selectedPin, vignetteInfo.name, false, vignetteInfo.atlasName, nil, vignetteInfo)
                    end
                end
            end
        end
    end
    setQuestsIcons()
end

-- Events that can fire many times in a row (QUEST_LOG_UPDATE comes in bursts). They are merged
-- into one target lookup shortly after the burst. Everything else, especially SUPER_TRACKING_CHANGED
-- (the map pin cursor fallback needs the moment of the click), is handled right away.
burst = {
    delay = 0.2,
    pending = false,
}
burst.events = {
    QUEST_LOG_UPDATE = true,
    QUEST_POI_UPDATE = true,
    SUPER_TRACKING_PATH_UPDATED = true,
}

function OnEvent(event, ...)
    if not burst.events[event] then
        resolveSuperTrackedTarget(event, ...)
        return
    end
    if burst.pending then return end
    burst.pending = true
    C_Timer.After(burst.delay, function()
        burst.pending = false
        resolveSuperTrackedTarget(event)
    end)
end

-- Re-applies all pointer fonts once. A pointer can be created before its font is usable: TomTom
-- restores a saved waypoint at login, possibly before the addon that registers the chosen font with
-- LibSharedMedia has done so (LSM:Fetch then returns the default font). Called when a font is
-- registered and after a loading screen; a burst of calls is merged into one refresh on the next frame.
fontRefreshPending = false
function schedulePointerFontRefresh()
    if fontRefreshPending then return end
    fontRefreshPending = true
    C_Timer.After(0, function()
        fontRefreshPending = false
        for _, quest in pairs(questPointsTable) do
            if quest.frame then
                updateQuestIcon(quest.frame)
            end
        end
        updateGroupTexts()
        updateGatherMate()
        updatePoiTrack()
    end)
end

function onMediaRegistered(_, mediatype)
    if mediatype == "font" then
        schedulePointerFontRefresh()
    end
end

function OnGroup(event, ...)
    local groupType = (IsInRaid() and "raid") or  (IsInGroup() and "party") or "none"
    if groupType ~= (player.groupType or "") then Addon:HideGroupIcons() end
    player.groupType = groupType
end

function OnZoneChange(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        schedulePointerFontRefresh()
    end
    cachePOIs()
    player.inInstance = IsInInstance()
    Addon:SetVisibility(shouldShowHUD())
    OnGroup(event, ...)
    OnEvent(event, ...)
end

function Addon:HideGroupIcons()
    for _,v in pairs(groupPointsTable) do
        if v.frame then v.frame:Hide() end
        v.active = false
    end
end

function Addon:SetVisibility(visible)
    if visible then
        HUD:Show()
        HUD:SetScript('OnUpdate', onUpdate)
    else
        HUD:Hide()
        HUD:SetScript('OnUpdate',nil)
    end
end

function Addon:ResetPosition(resetX, resetY)
    if resetX then
        Options.PositionX = (UIParent:GetWidth() / Options.Scale - HUD:GetWidth()) / 2
    end
    if resetY then
        Options.PositionY = (UIParent:GetHeight() - HUD:GetHeight() - 64) / Options.Scale
    end
    HUD:ClearAllPoints()
    HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
end

function Addon:UpdateHUDSettings()
    textureWidth = defaultTextureWidth * Options.HorizontalScale
    textureHeight = defaultTextureHeight * Options.VerticalScale
    local width, height = Options.Degrees / (720 / textureWidth) + Options.BorderThickness * 2, textureHeight + Options.BorderThickness * 2
    adjCoord = Options.Degrees / 1440

    HUD:EnableMouse(not Options.Lock)
    HUD:SetMovable(not Options.Lock)
	if Options.Lock then
		HUD:SetScript('OnDragStart', nil)
		HUD:SetScript('OnDragStop', nil)
		HUD:StopMovingOrSizing()
	else
		HUD:SetScript('OnDragStart', function()
            HUD:StartMoving()
        end)
		HUD:SetScript('OnDragStop', function ()
            HUD:StopMovingOrSizing()
            Options.PositionX = HUD:GetLeft()
            Options.PositionY = HUD:GetBottom()
        end)
	end

    if Options.PositionX < 0 then
        self:ResetPosition(true, true)
    else
        local currentScale = round(HUD:GetScale(), 2)
        local currentWidth = round(HUD:GetWidth(), 2)
        if  currentWidth ~= 0 then

            if currentScale ~= Options.Scale then
                local diffScale = currentScale / Options.Scale
                local center = (Options.PositionX + currentWidth / 2) * diffScale
                Options.PositionX = center - currentWidth / 2
                Options.PositionY = Options.PositionY * diffScale
            end

            if currentWidth ~= width then
                local diffWidth = (currentWidth - width) / 2
                Options.PositionX = Options.PositionX + diffWidth
            end
        end

        HUD:ClearAllPoints()
        HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
    end

    HUD:SetSize(width, height)
    HUD:SetScale(Options.Scale)
	HUD:SetFrameStrata(Options.Strata)
	HUD:SetFrameLevel(Options.Level)
    HUD:SetAlpha(Options.Transparency)

	local backdrop = {
		bgFile = LSM:Fetch("background", Options.Background),
		edgeFile = LSM:Fetch("border", Options.Border),
		edgeSize = Options.BorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	HUD:SetBackdrop(backdrop)
    HUD:SetBackdropColor(Options.BackgroundColor.r,Options.BackgroundColor.g, Options.BackgroundColor.b, Options.BackgroundColor.a)
	HUD:SetBackdropBorderColor(Options.BorderColor.r,Options.BorderColor.g, Options.BorderColor.b, Options.BorderColor.a)

    Options.PositionX = HUD:GetLeft()
    Options.PositionY = HUD:GetBottom()

    updateCompassHUD()

    HUD.compassCustom:SetSize(width, height)
    for _, quest in pairs(questPointsTable) do
        if quest.frame then
            updateQuestIcon(quest.frame)
        end
    end
    updateHUD(true)
    updatePointerTextures()
    updateGroupTexts()
    updateGatherMate()
    updatePoiTrack()
    UnregisterAttributeDriver(HUD, 'state-hudvisibility')
    RegisterAttributeDriver(HUD, "state-hudvisibility", Options.Visibility)
end

function Addon:RefreshConfig()
    Options = self.db.profile
    self:UpdateDataBroker()
    -- setGroupIcons stops early when the new profile hides party/raid markers, so hide the
    -- current ones here; it shows them again on its next pass if they are enabled
    self:HideGroupIcons()
    self:UpdateHUDSettings()
end

function Addon:OnEnable()
    addToLSM()

    Addon:InitializeDataBroker()
    player.name = UnitName("player")
    player.realm = GetRealmName()

    self:UpdateHUDSettings()
    -- also needed after a runtime re-enable: the visibility driver only fires on a change,
    -- and OnDisable hid the HUD
    self:SetVisibility(shouldShowHUD())

    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChange)
    self:RegisterEvent("PLAYER_MAP_CHANGED", OnZoneChange)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChange)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", OnGroup)
    self:RegisterEvent("ZONE_CHANGED", OnEvent)
    self:RegisterEvent("QUEST_ACCEPTED", OnEvent)
    self:RegisterEvent("QUEST_LOG_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_POI_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_TURNED_IN", OnEvent)
    self:RegisterEvent("USER_WAYPOINT_UPDATED", OnEvent)
    self:RegisterEvent("WAYPOINT_UPDATE", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_CHANGED", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_PATH_UPDATED", OnEvent)


    if TomTom then
        self:SecureHook(TomTom, "SetCrazyArrow", tomtomSetCrazyArrow)
        self:SecureHook(TomTom, "ClearWaypoint", tomtomClearWaypoint)
        self:SecureHook(TomTom, "HideWaypoint", tomtomClearWaypoint)
    end

    LSM.RegisterCallback(self, "LibSharedMedia_Registered", onMediaRegistered)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

-- AceEvent and AceHook drop their own registrations on disable; this cleans up what the addon owns.
function Addon:OnDisable()
    -- stop the visibility driver first, or its next change would show the HUD again
    UnregisterAttributeDriver(HUD, 'state-hudvisibility')
    -- hiding the HUD also stops the OnUpdate scripts of all marker frames (they are its children)
    self:SetVisibility(false)
    -- hand the SuperTracker icon back to the game
    updateSuperTrackedTexture(nil)
end

function Addon:OnInitialize()
    Addon:ConstructDefaultsAndOptions()
    Options = self.db.profile
    createHUD()
end
