-- Compass strip: player position and heading, angles to world points, the strip textures and heading text.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")
local GetPlayerFacing = GetPlayerFacing
local issecretvalue = issecretvalue
local GetQuestsOnMap = C_QuestLog.GetQuestsOnMap
local GetMapForQuestPOIs = C_QuestLog.GetMapForQuestPOIs
local GetNextWaypoint = C_QuestLog.GetNextWaypoint
local GetNextWaypointForMap = C_QuestLog.GetNextWaypointForMap
local GetQuestAdditionalHighlights = C_QuestLog.GetQuestAdditionalHighlights
local IsQuestComplete = C_QuestLog.IsComplete

function GetQuestPOIInfo(questID)
    local completed = IsQuestComplete(questID)

    -- try to get waypoint
    local uiMapID, x, y = GetNextWaypoint(questID)
    if uiMapID and x and y then
        return uiMapID, x, y, completed
    end

    -- give me proper uiMapID
    uiMapID = GetQuestUiMapID(questID) or GetQuestAdditionalHighlights(questID)
    if uiMapID and uiMapID > 0 then
        -- try to get waypoint when clicked on mapPin
        x, y = GetNextWaypointForMap(questID, uiMapID)
        if x and y then
            return uiMapID, x, y, completed
        end
        -- try to parse all quests on current Map
        local quests = GetQuestsOnMap(uiMapID)
        for _, quest in pairs(quests) do
            if quest.questID == questID then
                return uiMapID, quest.x, quest.y, completed
            end
       end
    end
end

function getMapId(questID)
    local uiMapID = GetMapForQuestPOIs()
    if uiMapID and uiMapID > 0 then return uiMapID end
end

-- The player's facing, or nil where the game does not give it (dungeons, raids) or gives it as a
-- secret value that addons cannot calculate with.
function readPlayerFacing()
    local facing = GetPlayerFacing()
    if facing == nil or (issecretvalue and issecretvalue(facing)) then return end
    return facing
end

function updatePlayerCoords()
    if player.inInstance then return end

    player.x, player.y, player.instance = HBD:GetPlayerWorldPosition()
    player.uiMapID = HBD:GetPlayerZone()
    player.angle = readPlayerFacing()
end

-- Signed angle (-PI..PI) between the player's facing and a world point.
-- nil when the player position, heading or the vector is not available (HBD returns nil then).
function relativeAngle(instance, x, y)
    if not (player.angle and player.x and player.y and x and y) then return end
    local vector = HBD:GetWorldVector(instance, player.x, player.y, x, y)
    if not vector then return end
    local angle = player.angle - vector
    if angle < 0 then angle = angle + (2 * PI) end
    if angle > PI then angle = angle - (2 * PI) end
    return angle
end

function getPlayerFacingAngle(questID)
	if not questID or not questPointsTable[questID] then return end
    local point = questPointsTable[questID]
    return relativeAngle(point.instance, point.x, point.y)
end

function updateCompassHUD()
    local scale = Options.Scale * Options.VerticalScale
    -- middle HUD pointer texture
    HUD.pin = HUD.pin or HUD:CreateTexture(nil, "ARTWORK")
    HUD.pin:SetTexture(Options.PinTexture)
    HUD.pin:ClearAllPoints()
    HUD.pin:SetSize(textureHeight * 1.5, textureHeight * 1.5)
	HUD.pin:SetPoint('TOP', HUD, 'TOP', 0, 6)
    HUD.pin:SetShown(Options.PinVisible)

    -- compass texture
    HUD.compassTexture = HUD.compassTexture or HUD:CreateTexture(nil, "BORDER")
    HUD.compassTexture:SetTexture(Options.CompassTextureTexture)
    HUD.compassTexture:ClearAllPoints()
    HUD.compassTexture:SetPoint('TOPLEFT', HUD, 'TOPLEFT', Options.BorderThickness + 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMLEFT', HUD, 'BOTTOMLEFT', Options.BorderThickness + 1, Options.BorderThickness + 1)
    HUD.compassTexture:SetPoint('TOPRIGHT', HUD, 'TOPRIGHT', -Options.BorderThickness - 1, -Options.BorderThickness - 1)
    HUD.compassTexture:SetPoint('BOTTOMRIGHT', HUD, 'BOTTOMRIGHT', -Options.BorderThickness - 1, Options.BorderThickness + 1)

    -- static frame to display compass leters and numbers with clipchildren
    HUD.compassCustom = HUD.compassCustom or CreateFrame('Frame', nil, HUD)
    HUD.compassCustom:SetSize(textureWidth / 2, textureHeight)
    HUD.compassCustom:SetPoint('TOP', HUD, 'TOP', 0, 0)
    HUD.compassCustom:SetClipsChildren(true)

    -- movable frame to reflect player facing
    HUD.compassCustom.mask = HUD.compassCustom.mask or CreateFrame('Frame', nil, HUD.compassCustom)
    HUD.compassCustom.mask:SetSize(textureWidth, textureHeight)
    HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', 0, 0)

    -- top edge line
    HUD.edgeTOP = HUD.edgeTOP or HUD:CreateTexture(nil, "OVERLAY")
    HUD.edgeTOP:SetColorTexture(Options.LineColor.r, Options.LineColor.g, Options.LineColor.b, Options.LineColor.a)
    HUD.edgeTOP:SetHeight(Options.LineThickness)
    HUD.edgeTOP:ClearAllPoints()
    HUD.edgeTOP:SetPoint("BOTTOM", HUD, "TOP", 0, Options.LinePosition)
    HUD.edgeTOP:SetWidth(HUD:GetWidth())
    HUD.edgeTOP:SetShown(Options.Line == "TOP" or Options.Line == "BOTH")

    -- bottom edge lines
    HUD.edgeBOTTOM = HUD.edgeBOTTOM or HUD:CreateTexture(nil, "OVERLAY")
    HUD.edgeBOTTOM:SetColorTexture(Options.LineColor.r, Options.LineColor.g, Options.LineColor.b, Options.LineColor.a)
    HUD.edgeBOTTOM:SetHeight(Options.LineThickness)
    HUD.edgeBOTTOM:ClearAllPoints()
    HUD.edgeBOTTOM:SetPoint("TOP", HUD, "BOTTOM", 0, -Options.LinePosition)
    HUD.edgeBOTTOM:SetWidth(HUD:GetWidth())
    HUD.edgeBOTTOM:SetShown(Options.Line == "BOTTOM" or Options.Line == "BOTH")

    local lettersMainFont = LSM:Fetch("font", Options.CompassCustomMainFont)
    local lettersSecondaryFont = LSM:Fetch("font", Options.CompassCustomSecondaryFont)
    local degreesFont = LSM:Fetch("font", Options.CompassCustomDegreesFont)

    if type(HUD.compassCustom.letters) ~= "table" then
        HUD.compassCustom.letters = {}
    end
    local letters = HUD.compassCustom.letters

    for _, v in pairs(letters) do
        v:Hide()
    end

    for _, side in ipairs({ 1, -1}) do
        for k, v in pairs(directions) do
            letters[k*side] = letters[k*side] or HUD.compassCustom.mask:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            letters[k*side]:SetText(v.letter)
            letters[k*side]:SetJustifyV("TOP")
            letters[k*side]:SetSize(0, 16)
            letters[k*side]:SetParent(HUD.compassCustom.mask)
            letters[k*side]:ClearAllPoints()
            letters[k*side].data = v

            if v.main then
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomMainPosition)
                letters[k*side]:SetFont(lettersMainFont, Options.CompassCustomMainSize * scale, Options.CompassCustomMainFlags)
                letters[k*side]:SetTextColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                letters[k*side]:SetShown(Options.CompassCustomMainVisible)
            else
                letters[k*side]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", ((side == 1 and k) or (k - 360)) / 720 * textureWidth + 1, Options.CompassCustomSecondaryPosition)
                letters[k*side]:SetFont(lettersSecondaryFont, Options.CompassCustomSecondarySize * scale, Options.CompassCustomSecondaryFlags)
                letters[k*side]:SetTextColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
                letters[k*side]:SetShown(Options.CompassCustomSecondaryVisible)
            end
        end
    end

    if type(HUD.compassCustom.degrees) ~= "table" then
        HUD.compassCustom.degrees = {}
    end
    local degrees = HUD.compassCustom.degrees

    for _, v in pairs(degrees) do
        v:Hide()
        v.span = false
    end

    for i = -360, 360, Options.CompassCustomDegreesSpan do
        if math.abs(i) ~= 360 then
            degrees[i] = degrees[i] or HUD.compassCustom.mask:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            degrees[i]:SetText(((i > 0) and i) or (360 + i))
            degrees[i]:SetJustifyV("TOP")
            degrees[i]:SetSize(0, 16)
            degrees[i]:ClearAllPoints()
            degrees[i]:SetPoint("TOP", HUD.compassCustom.mask, "TOP", i / 720 * textureWidth + 1, Options.CompassCustomDegreesPosition)
            degrees[i]:SetParent(HUD.compassCustom.mask)
            degrees[i]:SetFont(degreesFont, Options.CompassCustomDegreesSize * scale, Options.CompassCustomDegreesFlags)
            degrees[i]:SetTextColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
            degrees[i]:SetShown(Options.CompassCustomDegreesVisible)
            degrees[i].span = true
            if letters[i] and letters[i]:IsShown() then
                degrees[i]:Hide()
            end
        end
    end

    if type(HUD.compassCustom.ticks) ~= "table" then
        HUD.compassCustom.ticks = {}
    end
    local ticks = HUD.compassCustom.ticks

    for _, v in pairs(ticks) do
        v:Hide()
    end

    for _, tickPosition in ipairs({"TOP", "BOTTOM"}) do
        for i, v in pairs(letters) do
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(nil, "OVERLAY")
            ticks[tickPosition .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
            if v:IsShown() then
                if v.data.main then
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                else
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
                end
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
            ticks[tickPosition .. i]:SetSize(2, 2)
            ticks[tickPosition .. i]:SetPoint(tickPosition, HUD.compassCustom.mask, tickPosition, i / 720 * textureWidth, -2)
            ticks[tickPosition .. i]:SetParent(HUD.compassCustom.mask)
            if Options.CompassCustomTicksForce then
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
        end

        for i, v in pairs(degrees) do
            ticks[tickPosition .. i] = ticks[tickPosition .. i] or HUD.compassCustom.mask:CreateTexture(nil, "OVERLAY")
            ticks[tickPosition .. i]:SetTexture("Interface\\BUTTONS\\WHITE8X8.BLP")
            if not letters[i] or not letters[i]:IsShown() then
                ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
                ticks[tickPosition .. i]:SetShown(v:IsShown() and ((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH")))
                ticks[tickPosition .. i]:SetSize(2, 4)
            end
            ticks[tickPosition .. i]:SetPoint(tickPosition, HUD.compassCustom.mask, tickPosition, i / 720 * textureWidth, -2)
            ticks[tickPosition .. i]:SetParent(HUD.compassCustom.mask)
            if Options.CompassCustomTicksForce and v.span then
                ticks[tickPosition .. i]:SetShown((Options.CompassCustomTicksPosition == tickPosition) or (Options.CompassCustomTicksPosition == "BOTH"))
            end
        end
    end

    -- heading frame
    HUD.heading = HUD.heading or CreateFrame('Frame', nil, HUD, "BackdropTemplate")
    HUD.heading:SetSize(textureHeight * 2 * Options.HeadingWidth, textureHeight)
    HUD.heading:SetPoint('CENTER', HUD, 'CENTER', 0, Options.HeadingPosition)
    HUD.heading:SetClipsChildren(true)

    HUD.heading:SetScale(Options.HeadingScale)
	HUD.heading:SetFrameLevel(Options.Level+Options.HeadingStrataLevel)
    HUD.heading:SetAlpha(Options.HeadingTransparency)

	local headingBackdrop = {
		bgFile = LSM:Fetch("background", Options.HeadingBackground),
		edgeFile = LSM:Fetch("border", Options.HeadingBorder),
		edgeSize = Options.HeadingBorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	HUD.heading:SetBackdrop(headingBackdrop)
    HUD.heading:SetBackdropColor(Options.HeadingBackgroundColor.r,Options.HeadingBackgroundColor.g, Options.HeadingBackgroundColor.b, Options.HeadingBackgroundColor.a)
	HUD.heading:SetBackdropBorderColor(Options.HeadingBorderColor.r,Options.HeadingBorderColor.g, Options.HeadingBorderColor.b, Options.HeadingBorderColor.a)

    local headingFont = LSM:Fetch("font", Options.HeadingFont)
    HUD.heading.text = HUD.heading.text or HUD.heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    HUD.heading.text:SetJustifyV("MIDDLE")
    HUD.heading.text:SetJustifyH("CENTER")
    HUD.heading.text:SetParent(HUD.heading)
    HUD.heading.text:ClearAllPoints()
    HUD.heading.text:SetPoint("CENTER", HUD.heading, "CENTER", Options.HeadingFontPositionH, Options.HeadingFontPositionV)
    HUD.heading.text:SetFont(headingFont, Options.HeadingFontSize * scale, Options.HeadingFontFlags)
    HUD.heading.text:SetTextColor(Options.HeadingFontColor.r, Options.HeadingFontColor.g, Options.HeadingFontColor.b, Options.HeadingFontColor.a)

    HUD.compassTexture:SetShown(not Options.UseCustomCompass)
    HUD.compassCustom:SetShown(Options.UseCustomCompass)
    HUD.heading:SetShown(Options.HeadingEnabled)

    -- pointers
    HUD.pointers = HUD.pointers or {}

    -- groups
    HUD.groups = HUD.groups or {}
end
