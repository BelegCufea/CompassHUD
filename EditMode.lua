-- The game's Edit Mode: while it is open the HUD shows a selection overlay, can be dragged (also
-- when locked) and opens the options when clicked. Blizzard's Edit Mode systems are not touched
-- (no registration, no hooks into its frames), only its Enter/Exit callbacks are listened to.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local EventRegistry = EventRegistry

local overlay
local COLOR_NORMAL = { r = 0.25, g = 0.6, b = 1, fill = 0.3 }
local COLOR_HOVER = { r = 0.45, g = 0.75, b = 1, fill = 0.45 }

local function setOverlayColor(color)
    overlay:SetBackdropColor(color.r, color.g, color.b, color.fill)
    overlay:SetBackdropBorderColor(color.r, color.g, color.b, 1)
end

local function savePosition()
    Options.PositionX = HUD:GetLeft()
    Options.PositionY = HUD:GetBottom()
end

local function openOptions()
    local name = Addon.CONST.METADATA.NAME
    AceConfigDialog:Open(name)
    AceConfigDialog:SelectGroup(name, "Tabs", "Settings")
end

local function createOverlay()
    overlay = CreateFrame("Frame", nil, HUD, "BackdropTemplate")
    overlay:SetAllPoints(HUD)
    overlay:SetBackdrop({
        bgFile = [[Interface\Buttons\WHITE8X8]],
        edgeFile = [[Interface\Buttons\WHITE8X8]],
        edgeSize = 2,
    })
    setOverlayColor(COLOR_NORMAL)

    overlay.label = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overlay.label:SetPoint("CENTER")
    overlay.label:SetText(Addon.CONST.METADATA.NAME)

    overlay:EnableMouse(true)
    overlay:RegisterForDrag("LeftButton")
    overlay:SetScript("OnEnter", function(self)
        setOverlayColor(COLOR_HOVER)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(Addon.CONST.METADATA.NAME)
        GameTooltip:AddLine("Drag to move, click to open the options.", 1, 1, 1)
        GameTooltip:Show()
    end)
    overlay:SetScript("OnLeave", function()
        setOverlayColor(COLOR_NORMAL)
        GameTooltip:Hide()
    end)
    overlay:SetScript("OnDragStart", function(self)
        self.dragged = true
        HUD:SetMovable(true)
        HUD:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function()
        HUD:StopMovingOrSizing()
        savePosition()
    end)
    overlay:SetScript("OnMouseUp", function(self, button)
        -- a drag also ends with a mouse up: only a plain click opens the options
        if self.dragged then
            self.dragged = false
        elseif button == "LeftButton" then
            openOptions()
        end
    end)
    overlay:Hide()
end

local function onEditModeEnter()
    -- the callbacks stay registered while the addon is disabled
    if not Addon:IsEnabled() then return end
    editModeActive = true
    if not overlay then
        createOverlay()
    end
    -- above all markers of the HUD (frame levels stop at 10000)
    overlay:SetFrameLevel(math.min(HUD:GetFrameLevel() + 500, 10000))
    overlay:Show()
    -- shown even where the Visibility State or an instance would hide it, so it can be found
    Addon:SetVisibility(shouldShowHUD())
end

local function onEditModeExit()
    if not editModeActive then return end
    editModeActive = false
    if overlay then
        overlay:Hide()
        overlay.dragged = false
    end
    HUD:StopMovingOrSizing()
    HUD:SetMovable(not Options.Lock)
    Addon:SetVisibility(shouldShowHUD())
end

local registered = false

-- Called from OnEnable; clients without Edit Mode keep the addon's own unlock/drag only.
function registerEditMode()
    if registered or not (EventRegistry and EditModeManagerFrame) then return end
    EventRegistry:RegisterCallback("EditMode.Enter", onEditModeEnter, Addon)
    EventRegistry:RegisterCallback("EditMode.Exit", onEditModeExit, Addon)
    registered = true
end
