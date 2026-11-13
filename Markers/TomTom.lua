-- TomTom waypoint markers: every TomTom waypoint on the current map as a marker source
-- (Markers/Common.lua), except the crazy arrow's one, which is the TomTom supertracker pointer
-- (Markers/Supertracker.lua). TomTom.waypoints ({ [uiMapID] = { [key] = { m, x, y, title = } } },
-- zone coordinates 0-1) is read the way TomTom's own slash commands do; everything is
-- presence-checked.
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

function tomTomNodes.scan()
    local waypoints = TomTom.waypoints[player.uiMapID]
    if type(waypoints) ~= "table" then return end
    local skip = arrowKey()
    for key, waypoint in pairs(waypoints) do
        local xZone, yZone = waypoint[2], waypoint[3]
        if key ~= skip and type(xZone) == "number" and type(yZone) == "number" then
            if not markerNode(tomTomNodes, key) then
                local x, y = HBD:GetWorldCoordinatesFromZone(xZone, yZone, player.uiMapID)
                if x and y then
                    newMarkerNode(tomTomNodes, key, {
                        x = x, y = y,
                        name = type(waypoint.title) == "string" and waypoint.title or "TomTom waypoint",
                        -- TomTom's own waypoint icon (minimap and world map)
                        texture = "Interface\\AddOns\\TomTom\\Images\\GoldGreenDot",
                        waypoint = waypoint,
                    })
                end
            end
        end
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
