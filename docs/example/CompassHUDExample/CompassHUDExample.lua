-- Example marker source for CompassHUD (see docs/API.md): four raid target icons around the place
-- where you were when the first scan ran on the current map, and optionally one at the map's
-- center. Settings in CompassHUD's options: Minimap tracking -> Example.

local compass = CompassHUD
if not (type(compass) == "table" and compass.API_VERSION == 1) then return end

-- offset on the map (0-1), raid target icon, name
local DIRECTIONS = {
    N = { 0, -0.02, 1, "North" },
    E = { 0.02, 0, 2, "East" },
    S = { 0, 0.02, 3, "South" },
    W = { -0.02, 0, 4, "West" },
}

local center -- { mapID, x, y }: where the icons are placed around

local source
source = compass.RegisterMarkerSource({
    id = "CompassHUDExample",
    name = "Example",
    description = "Raid target icons around the place where you entered the map (an example for addon authors).",
    what = "icon",
    defaults = {
        Radius = 0, -- the whole zone
    },
    options = {
        { key = "Directions", type = "multiselect", name = "Directions", desc = "Which icons are shown.",
          values = { N = "North", E = "East", S = "South", W = "West" }, default = true },
        { key = "MapCenter", type = "toggle", name = "Map center", desc = "Also an icon at the center of the map.",
          default = false },
    },
    speech = { name = "Example icons", default = false },

    scan = function(scan)
        if not center or center.mapID ~= scan.uiMapID then
            center = { mapID = scan.uiMapID, x = scan.mapX, y = scan.mapY }
        end
        for key, d in pairs(DIRECTIONS) do
            -- Get keeps an icon already added; icons not reported by this scan are removed
            if source:GetSetting("Directions", key) and not scan:Get(key) then
                scan:Add(key, {
                    mapID = center.mapID, mapX = center.x + d[1], mapY = center.y + d[2],
                    texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. d[3],
                    name = d[4],
                })
            end
        end
        if source:GetSetting("MapCenter") and not scan:Get("center") then
            scan:Add("center", {
                mapID = scan.uiMapID, mapX = 0.5, mapY = 0.5,
                texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
                name = "Map center",
            })
        end
    end,

    title = function(node)
        return node.name .. " (example)"
    end,
})
