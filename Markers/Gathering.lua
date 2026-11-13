-- Gathering node markers from GatherMate2, or GatherLite when GatherMate2 is not loaded: only the
-- nodes within the scanning radius of the player, keyed per node.
-- Uses only the public interface for the marker source (CompassHUD.RegisterMarkerSource, API.lua).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, type = pairs, ipairs, type

local HBD = LibStub("HereBeDragons-2.0")

local LITE_TYPES = { "mining", "herbalism", "containers", "fishing" } -- GatherLite node types
local liteObjects = {} -- object ID -> GatherLite object (GetNodeObject searches its whole list)

-- GatherMate2 node source. These are GatherMate2's long-standing public methods plus three of its
-- tables; every one is checked, so a change in GatherMate2 means no nodes rather than Lua errors.
local function scanGatherMate2(scan)
    local gm = GatherMate2
    if not (gm and gm.db_types and gm.Visible and gm.nodeTextures and gm.FindNearbyNode and gm.DecodeLoc and gm.GetNameForNode) then
        return
    end
    for _, dbType in pairs(gm.db_types) do
        if gm.Visible[dbType] then
            for coord, nodeID in gm:FindNearbyNode(scan.uiMapID, scan.mapX, scan.mapY, dbType, scan.radius) do
                local key = dbType .. ":" .. coord
                if not scan:Get(key) then
                    local xZone, yZone = gm:DecodeLoc(coord)
                    scan:Add(key, {
                        mapID = scan.uiMapID, mapX = xZone, mapY = yZone,
                        name = gm:GetNameForNode(dbType, nodeID) or "",
                        texture = gm.nodeTextures[dbType] and gm.nodeTextures[dbType][nodeID],
                    })
                end
            end
        end
    end
end

-- GatherLite node source (WoW: Forever), used when GatherMate2 is not loaded. GatherLite has no
-- documented API: these are its own functions, each one checked, so a change in GatherLite means
-- no nodes rather than Lua errors. Its node records are stable tables, so they serve as keys.

local function getGatherLiteObject(gl, objectID)
    local object = liteObjects[objectID]
    if object == nil then
        object = gl:GetNodeObject(objectID) or false
        liteObjects[objectID] = object
    end
    return object or nil
end

local function scanGatherLite(scan)
    local gl = GatherLite
    if not (gl and gl.IsLoaded and gl.GetNearbyZoneNodes and gl.EnsureNodeWorld and gl.GetNodeObject) or not gl:IsLoaded() then
        return
    end
    local zoneX, zoneY, mapID = HBD:GetPlayerZonePosition(true)
    if not (zoneX and zoneY and mapID and scan.instance and scan.x and scan.y) then
        return
    end
    local radius = scan.radius
    local usePredefined = not (gl.db and gl.db.global and gl.db.global.usePredefined == false)
    for _, nodeType in ipairs(LITE_TYPES) do
        -- follow GatherLite's own minimap tracking toggles, like GatherMate2's display filter
        if not gl.GetNodeTracking or gl:GetNodeTracking("minimap", nodeType) then
            for _, node in ipairs(gl:GetNearbyZoneNodes(nodeType, mapID, scan.instance, zoneX, zoneY, radius) or {}) do
                if scan:Get(node) then
                    -- already shown
                elseif not (node.predefined and not usePredefined) and not (gl.IsIgnored and gl:IsIgnored(node.object)) then
                    if not (node.worldX and node.worldY and node.instance) then
                        gl:EnsureNodeWorld(node)
                    end
                    if node.instance == scan.instance and node.worldX and node.worldY then
                        -- GatherLite returns whole index cells: keep only nodes within the radius
                        local distance = HBD:GetWorldDistance(scan.instance, scan.x, scan.y, node.worldX, node.worldY)
                        local object = distance and distance <= radius and getGatherLiteObject(gl, node.object)
                        if object then
                            -- GatherLite's locale keys for node names are "node.<name>" (as in its own tooltips)
                            local title = gl.translate and gl:translate("node." .. object.name) or object.name
                            scan:Add(node, { x = node.worldX, y = node.worldY, name = title or "", texture = object.icon })
                        end
                    end
                end
            end
        end
    end
end

CompassHUD.RegisterMarkerSource({
    id = "GatherMate",
    name = "GatherMate2 / GatherLite",
    description = "Shows gathering nodes from GatherMate2, or from GatherLite when GatherMate2 is not loaded. Which node types is decided by the addon's own settings.",
    what = "node",
    titleHeader = "Node name",
    -- GatherMate2 if loaded, else GatherLite
    isAvailable = function() return (GatherMate2 or GatherLite) and true or false end,
    -- full opacity (1/1, no fading) keeps the look from before the option existed; texts only on
    -- the faced node (texts visibility angle 2.5, was effectively 0 before v1.8)
    defaults = {
        UseMinimapSettings = false,
        Supertrack         = false,
        HideAtTarget       = true,
        Radius             = 150,
        Interval           = 6,
        Scale              = 0.8,
        OpacityMin         = 1,
        OpacityMax         = 1,
        OpacityMinRadius   = 50,
        ShowDistance       = false,
        ShowTTA            = false,
        ShowTitle          = false,
    },
    speech = {
        default = false,
        name = "Gathering nodes",
        desc = "The herbs, ores and other nodes shown by Minimap tracking -> GatherMate2 / GatherLite (turn them on there).",
    },

    -- scan.radius: the minimap icons' "whole zone" (0) is taken as their fading distance
    scan = function(scan)
        if GatherMate2 then
            scanGatherMate2(scan)
        else
            scanGatherLite(scan)
        end
    end,
})
