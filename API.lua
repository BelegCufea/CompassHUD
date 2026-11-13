-- CompassHUD's public interface for other addons: the global table CompassHUD.
--
-- Only what is documented in docs/API.md is promised; within a major API version fields and
-- functions are only added, never changed or removed. CompassHUD's own files use the same calls,
-- so the interface cannot drift away from what the addon itself needs.
--
-- The HUD frame itself is CompassHUDFrame (not part of the promised interface).

local ADDON_NAME, Addon = ...
setfenv(1, Addon.env)

local API = {}
_G.CompassHUD = API

-- Keybinding "Toggle Supertracking for Minimap icon" (Bindings.xml, binding COMPASSHUD_SUPERTRACK):
-- supertracks the minimap icon (or other marker) the player faces, or stops tracking it.
function API.SupertrackMinimapIcon()
    supertrackPOITrack()
end

-- Not promised, may change any time: the addon object (AceAddon), for inspecting CompassHUD in
-- DevTool/ViragDevTool. Its env field holds the state and functions shared by CompassHUD's files.
API.Debug = Addon
