-- TomTom waypoint markers: the TomTom waypoints on the player's continent (or only the current
-- map) as a marker source (Markers/Common.lua), except the crazy arrow's one, which is the TomTom
-- supertracker pointer (Markers/Supertracker.lua). TomTom.waypoints
-- ({ [uiMapID] = { [key] = { m, x, y, title = } } }, zone coordinates 0-1) is read the way TomTom's
-- own slash commands do; everything is presence-checked.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, type = pairs, type

local HBD = LibStub("HereBeDragons-2.0")

local function tomTomLoaded()
    return TomTom ~= nil and type(TomTom.waypoints) == "table"
end

tomTomNodes = registerMarkerSource({
    prefix = "TomTom",
    isAvailable = tomTomLoaded,
    defaults = {
        UseMinimapSettings = true,
        Supertrack         = true,
        HideAtTarget       = true,
        Radius             = 0, -- waypoints are few and set on purpose: the whole zone
        OtherZones         = true, -- also waypoints set on other maps of the continent
    },
    speech = {
        order = 50,
        default = true,
        name = "TomTom waypoints",
        desc = "The waypoints shown by Minimap tracking -> TomTom (turn them on there). The crazy arrow's waypoint is read out with the supertracked target.",
    },
})

-- The key of the crazy arrow's waypoint while TomTom's pointer is tracking it.
local function arrowKey()
    local arrow = supertrackTargets[tomTom]
    return arrow and arrow.track and tomTomActive or nil
end

local FALLBACK_ICON = "Interface\\AddOns\\TomTom\\Images\\GoldGreenDot"

-- The icon TomTom uses for waypoints on the minimap (its minimap theme), also used for the TomTom
-- pointer with "Use TomTom's icon".
function tomTomWaypointIcon()
    local registry = TomTom and TomTom.waypointThemeRegistry
    local minimap = TomTom and TomTom.profile and TomTom.profile.minimap
    local texture = registry and registry.GetThemeDotTexture and minimap
        and registry:GetThemeDotTexture(minimap.theme)
    return texture or FALLBACK_ICON
end

-- The waypoints of one map: those on the player's continent (world instance), at their place
-- in world coordinates.
local function scanMap(uiMapID, waypoints, skip, icon)
    for key, waypoint in pairs(waypoints) do
        local xZone, yZone = waypoint[2], waypoint[3]
        if key ~= skip and type(xZone) == "number" and type(yZone) == "number" then
            local node = markerNode(tomTomNodes, key)
            -- built for another map (instance is the player's map when built) or another icon
            if node and (node.instance ~= player.uiMapID or node.texture ~= icon) then
                releaseMarkerNode(tomTomNodes, key)
                node = nil
            end
            if not node then
                local x, y, instance = HBD:GetWorldCoordinatesFromZone(xZone, yZone, uiMapID)
                if x and y and instance == player.instance then
                    newMarkerNode(tomTomNodes, key, {
                        x = x, y = y,
                        name = type(waypoint.title) == "string" and waypoint.title or "TomTom waypoint",
                        texture = icon,
                        waypoint = waypoint,
                    })
                end
            end
        end
    end
end

function tomTomNodes.scan()
    local skip, icon = arrowKey(), tomTomWaypointIcon()
    if Options.TomTomOtherZones then
        for uiMapID, waypoints in pairs(TomTom.waypoints) do
            if type(waypoints) == "table" then
                scanMap(uiMapID, waypoints, skip, icon)
            end
        end
    elseif type(TomTom.waypoints[player.uiMapID]) == "table" then
        scanMap(player.uiMapID, TomTom.waypoints[player.uiMapID], skip, icon)
    end
end

-- Supertrack keybinding: the faced waypoint becomes the crazy arrow's target (it then shows as the
-- TomTom pointer instead of a marker).
function tomTomNodes.supertrack(node)
    if not (TomTom.SetCrazyArrow and node.waypoint) then return false end
    local waypoint = node.waypoint
    local arrival = waypoint.arrivaldistance or (TomTom.profile and TomTom.profile.arrow and TomTom.profile.arrow.arrival)
    TomTom:SetCrazyArrow(waypoint, arrival, waypoint.title)
    return true
end
