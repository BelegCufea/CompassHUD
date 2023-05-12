local Addon = select(2, ...)

local DEBUG = {}
Addon.DEBUG = DEBUG

local Const = Addon.CONST

function DEBUG:Info(value, name)
    if not Addon.db.profile.Debug then return end
    if not name then name = Const.METADATA.NAME end

    if type(value) == "table" then
        self:Table(value, name)
        Addon:Print(name .. " is table - more info using /dev chat command (DevTool addon must be installed!)")
    else
        Addon:Print(name, value)
    end
end

function DEBUG:Table(value, name)
    if not Addon.db.profile.Debug then return end
    if not name then name = Const.METADATA.NAME end

    if DevTool then
        DevTool:AddData(value, Const.METADATA.NAME .. "_" .. name)
    end
end