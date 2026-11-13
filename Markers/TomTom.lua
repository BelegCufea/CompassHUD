-- TomTom waypoint markers: the TomTom waypoints on the player's continent (or only the current
-- map) as a marker source, except the crazy arrow's one, which is the TomTom supertracker pointer
-- (Markers/Supertracker.lua). TomTom.waypoints ({ [uiMapID] = { [key] = { m, x, y, title = } } },
-- zone coordinates 0-1) is read the way TomTom's own slash commands do; everything is
-- presence-checked.
-- Uses only the public interface for the marker source (CompassHUD.RegisterMarkerSource, API.lua),
-- like another addon would; the crazy arrow's pointer state is CompassHUD's own.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, type = pairs, type

local function tomTomLoaded()
    return TomTom ~= nil and type(TomTom.waypoints) == "table"
end

-- The key of the crazy arrow's waypoint while TomTom's pointer is tracking it.
local function arrowKey()
    local arrow = supertrackTargets[tomTom]
    return arrow and arrow.track and tomTomActive or nil
end

local FALLBACK_ICON = "Interface\\AddOns\\TomTom\\Images\\GoldGreenDot"

local FALLBACK_ARROW = "Interface\\AddOns\\TomTom\\Images\\MinimapArrow-Green"

-- A texture of TomTom's minimap theme ('getter': GetThemeDotTexture or GetThemeArrowTexture).
local function themeTexture(getter)
    local registry = TomTom and TomTom.waypointThemeRegistry
    local minimap = TomTom and TomTom.profile and TomTom.profile.minimap
    return registry and registry[getter] and minimap and registry[getter](registry, minimap.theme)
end

-- The icon TomTom uses for waypoints on the minimap.
function tomTomWaypointIcon()
    return themeTexture("GetThemeDotTexture") or FALLBACK_ICON
end

-- The arrow TomTom shows at the minimap edge for waypoints out of range: the TomTom pointer's
-- texture with "Use TomTom's arrow" (it turns like the rotating pointer textures).
function tomTomArrowIcon()
    return themeTexture("GetThemeArrowTexture") or FALLBACK_ARROW
end

-- The waypoints of one map; waypoints off the player's continent are not added (Add returns nil).
-- The crazy arrow's one ('arrow') is hidden: it is shown as the TomTom pointer, but stays the
-- faced marker for the keybinding, which then clears the arrow.
local function scanMap(scan, uiMapID, waypoints, arrow, icon)
    for key, waypoint in pairs(waypoints) do
        local xZone, yZone = waypoint[2], waypoint[3]
        if type(xZone) == "number" and type(yZone) == "number" then
            local node = scan:Get(key)
            -- TomTom's minimap theme changed: the icon too
            if not node or node.texture ~= icon then
                node = scan:Add(key, {
                    mapID = uiMapID, mapX = xZone, mapY = yZone,
                    name = type(waypoint.title) == "string" and waypoint.title or "TomTom waypoint",
                    texture = icon,
                    data = waypoint,
                })
            end
            if node then
                node.hidden = key == arrow
            end
        end
    end
end

local source
source = CompassHUD.RegisterMarkerSource({
    id = "TomTom",
    name = "TomTom",
    description = "Shows your TomTom waypoints on the current map. The crazy arrow's waypoint is shown as the TomTom pointer instead. The supertracker keybinding makes the waypoint you face the crazy arrow's target, or clears the arrow when you face its waypoint.",
    what = "waypoint",
    titleHeader = "Waypoint name",
    isAvailable = tomTomLoaded,
    defaults = {
        Radius = 0, -- waypoints are few and set on purpose: the whole zone
    },
    options = {
        {
            key = "OtherZones",
            type = "toggle",
            name = "Waypoints from other zones",
            desc = "Also show waypoints set on other maps of the continent you are on (e.g. in the zone around a city). Off: only waypoints set on the map you are on.",
            default = true,
        },
    },
    speech = {
        default = true,
        name = "TomTom waypoints",
        desc = "The waypoints shown by Minimap tracking -> TomTom (turn them on there). The crazy arrow's waypoint is read out with the supertracked target.",
    },

    scan = function(scan)
        local arrow, icon = arrowKey(), tomTomWaypointIcon()
        if source:GetSetting("OtherZones") then
            for uiMapID, waypoints in pairs(TomTom.waypoints) do
                if type(waypoints) == "table" then
                    scanMap(scan, uiMapID, waypoints, arrow, icon)
                end
            end
        elseif type(TomTom.waypoints[scan.uiMapID]) == "table" then
            scanMap(scan, scan.uiMapID, TomTom.waypoints[scan.uiMapID], arrow, icon)
        end
    end,

    -- The crazy arrow's waypoint can be faced at any distance, as its pointer is shown at any distance.
    bypassesRadius = function(node)
        return node.hidden
    end,

    -- Supertrack keybinding: the faced waypoint becomes the crazy arrow's target (it then shows as
    -- the TomTom pointer instead of a marker); on the crazy arrow's waypoint it clears the arrow
    -- (the waypoint stays, as with "Clear waypoint from arrow" in TomTom's menu).
    supertrack = function(node)
        local waypoint = node.data
        if not waypoint then return false end
        if node.hidden then
            if TomTom.ClearCrazyArrowPoint then
                -- before the clear: TomTom may set the closest waypoint right away (hook sets it again)
                supertrackTargets[tomTom].track = false
                TomTom:ClearCrazyArrowPoint(false)
            end
            source:Rescan()
            return true
        end
        if not TomTom.SetCrazyArrow then return false end
        local arrival = waypoint.arrivaldistance or (TomTom.profile and TomTom.profile.arrow and TomTom.profile.arrow.arrival)
        TomTom:SetCrazyArrow(waypoint, arrival, waypoint.title)
        source:Rescan()
        return true
    end,
})
