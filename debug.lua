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

    local values = {...}
    if type(name) ~= "string" then
        table.insert(values, 1, name)
        name = nil
    end
    if next({...}) == nil then
        if name then
            table.insert(values, 1, name)
        end
        name = nil
    end
    self:Table("values", values)

    local str = ""
    for i = 1, #values do
        local value = values[i]
        if type(value) == "table" then
            str = str .. "[table_" .. i .."]"
            self:Table(Const.METADATA.NAME .. "_" .. i, value)
        elseif type(value) == "function" then
            str = str .. "[function_" .. i .."]"
            self:Table(Const.METADATA.NAME .. "_" .. i, value)
        else
            str = str .. tostring(value)
        end
        if i < #values then
            str = str .. ", "
        end
    end
    if name then
        self:Print(nameColor .. name .. ":|r ", str)
    else
        self:Print(str)

    end
end

function DEBUG:Table(name, value)
    if not Addon.db.profile.Debug then return end
    if not name then name = Const.METADATA.NAME end

    if ViragDevTool_AddData then
        ViragDevTool_AddData(value, Const.METADATA.NAME .. "_" .. name)
    end

    if DevTool and DevTool.AddData then
        DevTool:AddData(value, Const.METADATA.NAME .. "_" .. name)
    end
end