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

function DEBUG:Info(name, ...)
    if not Addon.db.profile.Debug then return end

    local numParameters = select("#", ...)
    local values = ((not name and numParameters == 0) and {""}) or {...}
    if type(name) ~= "string" or select("#", ...) == 0 then
        table.insert(values, 1, name)
        numParameters = numParameters + 1
        name = nil
    end

    local str = ""
    for i = 1, #values do
        local value = values[i]
        if type(value) == "table" then
            str = str .. "[" .. (name and (name .. "_") or "") .. "table_" .. i .."]"
            self:Table(Const.METADATA.NAME .. "_" .. (name and (name .. "_") or "") .. "table_" .. i, value)
        elseif type(value) == "function" then
            str = str .. "[" .. (name and (name .. "_") or "") .. "function_" .. i .."]"
            self:Table(Const.METADATA.NAME .. "_" .. (name and (name .. "_") or "") .. "function_" .. i, value)
        else
            str = str .. tostring(value)
        end
        if i < #values then
            str = str .. ", "
        end
    end

    if numParameters > #values then
        str = str .. ", nil"
    end

    if name then
        self:Print(nameColor .. name .. ":|r ", str)
    else
        self:Print(str)

    end
end

function DEBUG:Table(name, value)
    if not Addon.db.profile.Debug then return end
    if not value then
        value = name
        name = Const.METADATA.NAME
    end

    if ViragDevTool_AddData then
        ViragDevTool_AddData(value, Const.METADATA.NAME .. "_" .. name)
    end

    if DevTool and DevTool.AddData then
        DevTool:AddData(value, Const.METADATA.NAME .. "_" .. name)
    end
end