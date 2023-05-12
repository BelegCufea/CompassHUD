local Addon = select(2, ...)

local CONST = {}
Addon.CONST = CONST

CONST.METADATA = {
    NAME = GetAddOnMetadata(..., "Title"),
    VERSION = GetAddOnMetadata(..., "Version")
}