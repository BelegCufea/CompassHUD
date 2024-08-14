local Addon = select(2, ...)

local CONST = {}
Addon.CONST = CONST

CONST.METADATA = {
    NAME = C_AddOns.GetAddOnMetadata(..., "Title"),
    VERSION = C_AddOns.GetAddOnMetadata(..., "Version")
}