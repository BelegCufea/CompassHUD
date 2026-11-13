-- Gathering node markers from GatherMate2, or GatherLite when GatherMate2 is not loaded.
-- Drawn by the shared marker functions (Markers/Common.lua), like the Questie markers.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local HBD               = LibStub("HereBeDragons-2.0")

-- A marker source (Markers/Common.lua): only the nodes found by the latest scan are kept (within
-- the scanning radius of the player, keyed per node), plus the gathering addons' own state.
gatherNodes = registerMarkerSource({
    prefix = "GatherMate",
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
    liteTypes = { "mining", "herbalism", "containers", "fishing" }, -- GatherLite node types
    liteObjects = {},   -- object ID -> GatherLite object (GetNodeObject searches its whole list)
})

-- Adds a node found by a scan (world coordinates, icon texture, title), or keeps the existing one.
function addGatherNode(key, xWorld, yWorld, icon, title)
    if not markerNode(gatherNodes, key) then
        newMarkerNode(gatherNodes, key, { x = xWorld, y = yWorld, name = title or "", texture = icon })
    end
end

-- GatherMate2 node source. These are GatherMate2's long-standing public methods plus three of its
-- tables; every one is checked, so a change in GatherMate2 means no nodes rather than Lua errors.
function scanGatherMate2(zoneX, zoneY, radius)
    local gm = GatherMate2
    if not (gm and gm.db_types and gm.Visible and gm.nodeTextures and gm.FindNearbyNode and gm.DecodeLoc and gm.GetNameForNode) then
        return
    end
    for _, dbType in pairs(gm.db_types) do
        if gm.Visible[dbType] then
            for coord, nodeID in gm:FindNearbyNode(player.uiMapID, zoneX, zoneY, dbType, radius) do
                local key = dbType .. ":" .. coord
                if not markerNode(gatherNodes, key) then
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

function scanGatherLite(radius)
    local gl = GatherLite
    if not (gl and gl.IsLoaded and gl.GetNearbyZoneNodes and gl.EnsureNodeWorld and gl.GetNodeObject) or not gl:IsLoaded() then
        return
    end
    local zoneX, zoneY, mapID = HBD:GetPlayerZonePosition(true)
    if not (zoneX and zoneY and mapID and player.instance and player.x and player.y) then
        return
    end
    local usePredefined = not (gl.db and gl.db.global and gl.db.global.usePredefined == false)
    for _, nodeType in ipairs(gatherNodes.liteTypes) do
        -- follow GatherLite's own minimap tracking toggles, like GatherMate2's display filter
        if not gl.GetNodeTracking or gl:GetNodeTracking("minimap", nodeType) then
            for _, node in ipairs(gl:GetNearbyZoneNodes(nodeType, mapID, player.instance, zoneX, zoneY, radius) or {}) do
                if markerNode(gatherNodes, node) then
                    -- already shown
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

-- radius: the minimap icons' "whole zone" (0) is taken as their fading distance (markerRadius)
function gatherNodes.scan(_, x, y, radius)
    if GatherMate2 then
        scanGatherMate2(x, y, radius)
    else
        scanGatherLite(radius)
    end
end
