local Addon = select(2, ...)

local DEBUG = {}
Addon.DEBUG = DEBUG

local Const = Addon.CONST

local nameColor = "|cnNORMAL_FONT_COLOR:"
local printColor = "|cnBATTLENET_FONT_COLOR:"

function DEBUG:Print(...)
    if Addon.Print then
        Addon:Print(...)
    else
        print(printColor .. Const.METADATA.NAME .. ":|r ", ...)
    end
end

function DEBUG:Info(...)
    if not Addon.db.profile.Debug then return end

    local numParams = select("#", ...)
    if numParams == 0 then return end
    local name
    if numParams > 1 then name = select(numParams, ...) end

    local values = {...}
    local str = ""
    local lastParam = numParams - 1 + (((numParams == 1) and 1) or 0)

    for i = 1, lastParam do
        local value = values[i]
        if type(value) == "table" then
            str = str .. "[table_" .. i .."]"
            self:Table(value, Const.METADATA.NAME .. "_" .. i)
        elseif type(value) == "function" then
            str = str .. "[function_" .. i .."]"
            self:Table(value, Const.METADATA.NAME .. "_" .. i)
        else
            str = str .. tostring(value)
        end
        if i < lastParam then
            str = str .. ", "
        end
    end
    if name then
        self:Print(nameColor .. name .. ":|r ", str)
    else
        self:Print(str)

    end
end

function DEBUG:Table(value, name)
    if not Addon.db.profile.Debug then return end
    if not name then name = Const.METADATA.NAME end

    if ViragDevTool_AddData then
        ViragDevTool_AddData(value, Const.METADATA.NAME .. "_" .. name)
    end

    if DevTool and DevTool.AddData then
        DevTool:AddData(value, Const.METADATA.NAME .. "_" .. name)
    end
end