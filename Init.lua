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
