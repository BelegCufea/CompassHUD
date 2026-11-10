-- Gathering node markers from GatherMate2, or GatherLite when GatherMate2 is not loaded.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local HBD               = LibStub("HereBeDragons-2.0")

function updateGatherMateNode(node)
    local scale = Options.Scale * Options.IconScale * Options.GatherMateScale
    node.frame:SetSize(iconSize * Options.GatherMateScale, iconSize * Options.GatherMateScale)
    setPointerFont(node.frame.DistanceText, scale, Options.GatherMateDistanceCustomFont, Options.GatherMateDistanceFont, Options.GatherMateDistanceFontSize, Options.GatherMateDistanceFontFlags, Options.GatherMateDistanceFontColor)
    setPointerFont(node.frame.TimeText, scale, Options.GatherMateTtaCustomFont, Options.GatherMateTtaFont, Options.GatherMateTtaFontSize, Options.GatherMateTtaFontFlags, Options.GatherMateTtaFontColor)
    setPointerFont(node.frame.Title, scale, Options.GatherMateTitleCustomFont, Options.GatherMateTitleFont, Options.GatherMateTitleFontSize, Options.GatherMateTitleFontFlags, Options.GatherMateTitleFontColor)
    setTitleWidth(node.frame.Title)

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
    frame:SetSize(iconSize, iconSize)
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
