local Addon = select(2, ...)
local ADDON_NAME = ...

local LibDataBroker = LibStub("LibDataBroker-1.1")

local ldbLabelText = "A compass tape for your UI"
local settings = {
    type = "data source",
    label = ADDON_NAME,
    text = Addon.CONST.METADATA.NAME,
    icon = "Interface\\AddOns\\CompassHUD\\textures\\icon",
	notCheckable = true,
    OnTooltipShow = function(tooltip)
        if (tooltip and tooltip.AddLine) then
            tooltip:AddLine(Addon.CONST.METADATA.NAME .. " (v" .. Addon.CONST.METADATA.VERSION .. ")")
            tooltip:AddLine(" ")
            tooltip:AddLine(ldbLabelText, 1, 1, 1)
            tooltip:Show()
        end
    end,
    OnClick = function(self, button, down)
        Settings.OpenToCategory(Addon.categoryID)
    end,
}

function Addon:InitializeDataBroker()
    Addon.BrokerModule = LibDataBroker:NewDataObject(ADDON_NAME, settings)
    Addon.icon = LibStub("LibDBIcon-1.0")
    Addon.icon:Register(Addon.CONST.METADATA.NAME, Addon.BrokerModule, Addon.db.profile.Minimap)
    if Addon.db.profile.Minimap.hide then
        Addon.icon:Hide(Addon.CONST.METADATA.NAME)
    else
        Addon.icon:Show(Addon.CONST.METADATA.NAME)
    end
    if Addon.db.profile.Compartment.hide then
        if Addon.icon:IsButtonInCompartment(Addon.CONST.METADATA.NAME) then
            Addon.icon:RemoveButtonFromCompartment(Addon.CONST.METADATA.NAME)
        end
    else
        if not Addon.icon:IsButtonInCompartment(Addon.CONST.METADATA.NAME) then
            Addon.icon:AddButtonToCompartment(Addon.CONST.METADATA.NAME)
        end
    end
end
