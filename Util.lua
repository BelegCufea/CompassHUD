-- Helpers: rounding, POI cache, atlas lookups, strata levels, minimap icon filters.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local GetMapInfo = C_Map.GetMapInfo
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetMapChildrenInfo = C_Map.GetMapChildrenInfo
local GetAreaPOIForMap =  C_AreaPoiInfo.GetAreaPOIForMap
local GetDelvesForMap =  C_AreaPoiInfo.GetDelvesForMap
local GetEventsForMap =  C_AreaPoiInfo.GetEventsForMap
local GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo
local GetQuestHubsForMap = C_AreaPoiInfo.GetQuestHubsForMap
local GetDragonridingRacesForMap = C_AreaPoiInfo.GetDragonridingRacesForMap
local GetAtlasInfo = C_Texture.GetAtlasInfo

strataLevels = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "FULLSCREEN",
    "FULLSCREEN_DIALOG",
    "TOOLTIP",
}

function round(n, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(n * power + 0.5) / power
end

function getContinentMapID()
    local mapID = GetBestMapForUnit("player")
    if not mapID then return nil end

    while true do
        local mapInfo = GetMapInfo(mapID)
        if not mapInfo or mapInfo.mapType <= Enum.UIMapType.Continent then
            return mapID
        end

        mapID = mapInfo.parentMapID
        if not mapID or mapID == 0 then return nil end
    end
end

function cacheMapPOIs(mapPOIs, poiType, uiMapID)
    if mapPOIs and #mapPOIs > 0 then
        for _, poiID in ipairs(mapPOIs) do
            if poiID then
                local poi = GetAreaPOIInfo(uiMapID, poiID)
                -- GetAreaPOIInfo may return nothing: skip that POI
                if poi then
                    if not poiCache[poi.areaPoiID] then
                        poiCache[poi.areaPoiID] = {}
                    end
                    poiCache[poi.areaPoiID][uiMapID] = {
                        poiType = poiType,
                        poi = poi
                    }
                end
            end
        end
    end
end

function cachePOIs()
    local continentID = getContinentMapID()
    if continentID and not poiCacheContinents[continentID] then
        local childrenInfo = GetMapChildrenInfo(continentID, 3, true)
        if not childrenInfo or #childrenInfo == 0 then
            return
        end
        for _, childInfo in ipairs(childrenInfo) do
            local uiMapID = childInfo.mapID
            if uiMapID and uiMapID > 0 then
                cacheMapPOIs(GetAreaPOIForMap(uiMapID), poiTypeEnum.OTHER, uiMapID)
                cacheMapPOIs(GetDelvesForMap(uiMapID), poiTypeEnum.DELVE, uiMapID)
                cacheMapPOIs(GetDragonridingRacesForMap(uiMapID), poiTypeEnum.RACE, uiMapID)
                cacheMapPOIs(GetEventsForMap(uiMapID), poiTypeEnum.EVENT, uiMapID)
                cacheMapPOIs(GetQuestHubsForMap(uiMapID), poiTypeEnum.HUB, uiMapID)
            end
        end
        poiCacheContinents[continentID] = true
    end
end

function getPointerAtlasIDs()
    local atlasIDs = {}
    for key, value in pairs(pointerTextures) do
        atlasIDs[value.atlasID] = key
    end
    return atlasIDs
end

function getSortedPointerAtlasIDKeys()
    local sorting = {}
    local sortedKeys = {}
    for key, value in pairs(pointerTextures) do
        table.insert(sortedKeys, {key = value.atlasID, value = key})
    end
    table.sort(sortedKeys, function(a, b) return a.value < b.value end)
    for _, entry in ipairs(sortedKeys) do
        table.insert(sorting, entry.key)
    end
    return sorting
end

function getPointerTextureByAtlasID(atlasID)
    for _, pointerTexture in pairs(pointerTextures) do
        if pointerTexture.atlasID == atlasID then
            return pointerTexture
        end
    end
    return nil
end

function getAtlasTexture(atlasID)
    local atlasInfo = GetAtlasInfo(atlasID)
    if not atlasInfo then return nil end
    return atlasInfo.file
end

function getAtlasCoords(atlasID)
    local atlasInfo = GetAtlasInfo(atlasID)
    if not atlasInfo then return {0,0,0,1,1,0,1,1} end
    return {
        atlasInfo.leftTexCoord,
        atlasInfo.topTexCoord,
        atlasInfo.leftTexCoord,
        atlasInfo.bottomTexCoord,
        atlasInfo.rightTexCoord,
        atlasInfo.topTexCoord,
        atlasInfo.rightTexCoord,
        atlasInfo.bottomTexCoord
    }
end

function getStrateLevels()
    local values = {}
    for i, v in ipairs(strataLevels) do
        values[v] = i .. " - " .. v
    end
    return values
end

-- Mirrors the world map's flight point filter: hide nodes belonging to the opposite faction
function isTaxiNodeUsable(taxi)
    local faction = taxi.faction
    if not faction or not Enum.FlightPathFaction then
        return true
    end
    -- A character without a faction yet (e.g. a new Pandaren) is shown every node instead of none
    local playerFaction = UnitFactionGroup("player")
    if playerFaction ~= "Horde" and playerFaction ~= "Alliance" then
        return true
    end
    if faction == Enum.FlightPathFaction.Horde then
        return playerFaction == "Horde"
    elseif faction == Enum.FlightPathFaction.Alliance then
        return playerFaction == "Alliance"
    end
    return true
end

function getPOITrackFilter()
    local list = {}
    list[poiTypeEnum.TAXI] = "Flightpoints"
    list[poiTypeEnum.TAXI .. "_min"] = "  - only closest flightpoint"
    list[poiTypeEnum.EVENT] = "Events"
    list[poiTypeEnum.INSTANCE] = "Instances (Dungeons, Raids)"
    list[poiTypeEnum.HUB] = "Hubs (Cities, Towns, etc.)"
    list[poiTypeEnum.DELVE] = "Delves"
    list[poiTypeEnum.PORTAL] = "Teleports"
    list[poiTypeEnum.LINK] = "Links (Shortcuts, Connections, Paths)"
    list[poiTypeEnum.VIGNETTE] = "Vignettes"
    list[poiTypeEnum.OTHER] = "Miscellaneous"
    list[poiTypeEnum.RACE] = "Dragonriding races"
    list[poiTypeEnum.QUEST] = "Quests (from the quest log)"
    list[poiTypeEnum.QUEST .. "_complete"] = "  - only ready to turn in"
    if questieLoaded() then
        list[poiTypeEnum.QUESTIE] = "Questie icons (which ones: Questie's settings)"
    end
    return list
end

function getPOITrackWholeZoneFilter()
    local list = getPOITrackFilter()
    list[poiTypeEnum.TAXI .. "_min"] = nil
    list[poiTypeEnum.QUEST .. "_complete"] = nil
    return list
end

function getPOIFrackWQFilter()
    local list = {}
    list["None"] = "None"
    list["All"] = "All"
    list["Tracked"] = "Tracked"
    if WorldQuestTrackerAddon then
        list["WQTracker"] = "World Quest Tracker (WQT)"
    end
    return list
end
