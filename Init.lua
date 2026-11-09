-- Creates the addon object and the environment shared by CompassHUD's Lua files.
--
-- Every file loaded after this one starts with:
--     local ADDON_NAME, Addon = ...
--     setfenv(1, Addon.env)
-- Its top-level names (functions, state, option tables) then live in Addon.env and are visible to
-- all the other files, without being globals and without counting against Lua's limit of 200
-- local variables per file. Names not defined there (WoW API, other addons) come from _G.
-- A real global must be written as _G.name.

local ADDON_NAME, Addon = ...

LibStub("AceAddon-3.0"):NewAddon(Addon, ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")

Addon.env = setmetatable({
    Addon = Addon,
    ADDON_NAME = ADDON_NAME,
}, { __index = _G })

-- WoW API functions that return objects with a mixin (positions as Vector2DMixin, colors as
-- ColorMixin, ...) look the mixin up in the calling function's environment directly, without the
-- _G fallback ("unable to find mixin or metatable"). Copy Blizzard's mixins into the shared
-- environment; they are defined before addons load, and these are references to the same tables.
for name, value in pairs(_G) do
    if type(name) == "string" and type(value) == "table" and name:sub(-5) == "Mixin" then
        rawset(Addon.env, name, value)
    end
end

-- Keybinding labels (Bindings.xml). Set here, first: Options.lua reads them while it loads.
BINDING_HEADER_COMPASSHUD = "CompassHUD"
BINDING_NAME_COMPASSHUD_SUPERTRACK = "Toggle Supertracking for Minimap icon"
