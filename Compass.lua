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
	if not questID or not supertrackTargets[questID] then return end
    local point = supertrackTargets[questID]
    return relativeAngle(point.instance, point.x, point.y)
end

-- Fade toward the edges: opacity by the place on the strip, t = 0 in the middle, 1 at the edge.
-- Not fading: EdgeFadeInner; from EdgeFadeStart to the edge it goes to EdgeFadeOuter along the curve.
local fadeCurves = {
    LINEAR = function(u) return u end,
    EASE_IN = function(u) return u * u end,
    EASE_OUT = function(u) return 1 - (1 - u) * (1 - u) end,
    SMOOTH = function(u) return u * u * (3 - 2 * u) end,
}

function edgeFadeAt(t)
    local start, inner = Options.EdgeFadeStart, Options.EdgeFadeInner
    if t <= start then return inner end
    local u = start < 1 and (t - start) / (1 - start) or 1
    if u > 1 then u = 1 end
    local curve = fadeCurves[Options.EdgeFadeCurve] or fadeCurves.LINEAR
    return inner + (Options.EdgeFadeOuter - inner) * curve(u)
end

-- The fade of a marker at an angle from the facing (radians); 1 when fading is off or the part
-- (option key, e.g. "EdgeFadeMarkers") is not faded.
function edgeFade(part, angle)
    if not (Options.EdgeFade and Options[part]) or not angle then return 1 end
    return edgeFadeAt(math.abs(angle) / (math.rad(Options.Degrees) / 2))
end

-- The fade of a marker held at the edge (its target is outside the field of view).
function edgeFadeHeld(part)
    if not Options.EdgeFadeHeld then return 1 end
    return edgeFade(part, math.rad(Options.Degrees) / 2)
end

-- A texture or color can't fade along its width, so a faded one is drawn as slices, each with a
-- gradient between the fade at its two ends (piecewise linear along the curve).
local FADE_SLICES = 32

local function setSliceGradient(slice, i, r, g, b, a)
    local left = edgeFadeAt(math.abs(2 * (i - 1) / FADE_SLICES - 1))
    local right = edgeFadeAt(math.abs(2 * i / FADE_SLICES - 1))
    slice:SetGradient("HORIZONTAL", CreateColor(r, g, b, a * left), CreateColor(r, g, b, a * right))
end

-- An edge line (HUD.edgeTOP/edgeBOTTOM) or its faded slices.
local function layoutEdgeLine(key, shown, point, relativePoint, y)
    local line = HUD[key]
    local fade = shown and Options.EdgeFade and Options.EdgeFadeLines
    local slices = HUD[key .. "Slices"]
    line:SetShown(shown and not fade)
    if not fade then
        if slices then
            for _, slice in ipairs(slices) do slice:Hide() end
        end
        return
    end
    slices = slices or {}
    HUD[key .. "Slices"] = slices
    local width = HUD:GetWidth()
    local sliceWidth = width / FADE_SLICES
    local color = Options.LineColor
    for i = 1, FADE_SLICES do
        local slice = slices[i] or HUD:CreateTexture(nil, "OVERLAY")
        slices[i] = slice
        slice:SetTexture("Interface\\BUTTONS\\WHITE8X8")
        slice:ClearAllPoints()
        slice:SetSize(sliceWidth, Options.LineThickness)
        slice:SetPoint(point, HUD, relativePoint, -width / 2 + (i - 0.5) * sliceWidth, y)
        setSliceGradient(slice, i, color.r, color.g, color.b, color.a)
        slice:Show()
    end
end

-- The compass texture as faded slices (HUD.compassSlices), when the compass fades.
local function layoutCompassSlices(fade)
    local slices = HUD.compassSlices
    if not fade then
        if slices then
            for _, slice in ipairs(slices) do slice:Hide() end
        end
        return
    end
    slices = slices or {}
    HUD.compassSlices = slices
    local inset = Options.BorderThickness + 1
    local sliceWidth = (HUD:GetWidth() - 2 * inset) / FADE_SLICES
    for i = 1, FADE_SLICES do
        local slice = slices[i] or HUD:CreateTexture(nil, "BORDER")
        slices[i] = slice
        slice:SetTexture(Options.CompassTextureTexture)
        slice:ClearAllPoints()
        slice:SetPoint("TOPLEFT", HUD, "TOPLEFT", inset + (i - 1) * sliceWidth, -inset)
        slice:SetPoint("BOTTOMRIGHT", HUD, "BOTTOMLEFT", inset + i * sliceWidth, inset)
        setSliceGradient(slice, i, 1, 1, 1, 1)
        slice:Show()
    end
end

-- The HUD's backdrop (BackdropTemplate pieces): the background (Center) and the top and bottom
-- border (TopEdge/BottomEdge) span the width, so they are hidden and drawn as faded slices with
-- the piece's texture and coordinates; corners and side borders sit at the edge and get its
-- opacity. Called after SetBackdrop and its colors (UpdateHUDSettings). The pieces' opacity is
-- never changed: the backdrop keeps the color's opacity there (vertex color, which the client
-- shares with SetAlpha), so colors come from the settings (BackgroundColor/BorderColor).
local FRAME_WIDE_PIECES = { Center = "BackgroundColor", TopEdge = "BorderColor", BottomEdge = "BorderColor" }
local FRAME_EDGE_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "LeftEdge", "RightEdge" }

local function lerp(a, b, f) return a + (b - a) * f end

local function fadeFramePiece(piece, slices, fade, color, wrap)
    if slices then
        for _, slice in ipairs(slices) do slice:Hide() end
    end
    if not piece then return slices end
    -- hidden by an earlier fade: back (SetBackdrop may already have shown it)
    if piece.compassFadeHidden then
        piece.compassFadeHidden = nil
        piece:Show()
    end
    if not fade or not piece:GetTexture() then return slices end
    local hudLeft, hudBottom, half = HUD:GetLeft(), HUD:GetBottom(), HUD:GetWidth() / 2
    local left, right, top, bottom = piece:GetLeft(), piece:GetRight(), piece:GetTop(), piece:GetBottom()
    -- not laid out yet: left as it is
    if not (hudLeft and hudBottom and left and right and top and bottom) or half <= 0 or right <= left then
        return slices
    end
    piece.compassFadeHidden = true
    piece:Hide()
    slices = slices or {}
    local ulx, uly, llx, lly, urx, ury, lrx, lry = piece:GetTexCoord()
    local r, g, b, a = color.r, color.g, color.b, color.a
    local layer, sublevel = piece:GetDrawLayer()
    local texture = piece:GetTexture()
    local blend = piece:GetBlendMode()
    left, right = left - hudLeft, right - hudLeft
    local width = (right - left) / FADE_SLICES
    for i = 1, FADE_SLICES do
        local slice = slices[i] or HUD:CreateTexture(nil, layer, nil, sublevel)
        slices[i] = slice
        slice:SetDrawLayer(layer, sublevel)
        slice:SetTexture(texture, wrap, wrap)
        slice:SetBlendMode(blend)
        local f0, f1 = (i - 1) / FADE_SLICES, i / FADE_SLICES
        slice:SetTexCoord(lerp(ulx, urx, f0), lerp(uly, ury, f0), lerp(llx, lrx, f0), lerp(lly, lry, f0),
            lerp(ulx, urx, f1), lerp(uly, ury, f1), lerp(llx, lrx, f1), lerp(lly, lry, f1))
        local x0, x1 = left + (i - 1) * width, left + i * width
        slice:ClearAllPoints()
        slice:SetPoint("TOPLEFT", HUD, "BOTTOMLEFT", x0, top - hudBottom)
        slice:SetPoint("BOTTOMRIGHT", HUD, "BOTTOMLEFT", x1, bottom - hudBottom)
        local fadeLeft = edgeFadeAt(math.min(math.abs(x0 - half) / half, 1))
        local fadeRight = edgeFadeAt(math.min(math.abs(x1 - half) / half, 1))
        slice:SetGradient("HORIZONTAL", CreateColor(r, g, b, a * fadeLeft), CreateColor(r, g, b, a * fadeRight))
        slice:Show()
    end
    return slices
end

function fadeHUDFrame()
    local fade = Options.EdgeFade and Options.EdgeFadeFrame
    HUD.frameSlices = HUD.frameSlices or {}
    for name, colorKey in pairs(FRAME_WIDE_PIECES) do
        -- the backdrop tiles the border (repeating coordinates), not the background (tile is not set)
        local wrap = name ~= "Center" and "REPEAT" or "CLAMP"
        HUD.frameSlices[name] = fadeFramePiece(HUD[name], HUD.frameSlices[name], fade, Options[colorKey], wrap)
    end
    -- corners and side borders: the border color at the edge's opacity; without fading the
    -- backdrop has just set the border color itself
    if fade then
        local color, edge = Options.BorderColor, edgeFadeAt(1)
        for _, name in ipairs(FRAME_EDGE_PIECES) do
            if HUD[name] then HUD[name]:SetVertexColor(color.r, color.g, color.b, color.a * edge) end
        end
    end
end

-- Turns the compass strip to the facing: coord is the middle of the strip in texture coordinates.
-- With fading, the compass texture's slices and the opacity of the custom compass' letters,
-- degrees and ticks (by their place on the strip) follow.
function rotateCompassStrip(coord)
    HUD.compassTexture:SetTexCoord(coord - adjCoord, coord + adjCoord, 0, 1)
    local slices = HUD.compassSlices
    if slices and slices[1]:IsShown() then
        local step = 2 * adjCoord / FADE_SLICES
        for i, slice in ipairs(slices) do
            local left = coord - adjCoord + (i - 1) * step
            slice:SetTexCoord(left, left + step, 0, 1)
        end
    end
    local custom = HUD.compassCustom
    custom.mask:ClearAllPoints()
    custom.mask:SetPoint('TOP', custom, 'TOP', (1/2 - coord) * textureWidth, 0)
    local fade = Options.EdgeFade and Options.EdgeFadeCompass and Options.UseCustomCompass
    if not fade and not custom.faded then return end
    custom.faded = fade
    -- place on the strip: (degree / 720 + 1/2 - coord) * textureWidth, half the visible width
    -- is adjCoord * textureWidth
    local shift = 1/2 - coord
    for _, list in ipairs({ custom.letters or {}, custom.degrees or {}, custom.ticks or {} }) do
        for _, region in pairs(list) do
            if region.degree then
                local alpha = fade and edgeFadeAt(math.abs(region.degree / 720 + shift) / adjCoord) or 1
                local color = region.fadeColor
                if color then
                    -- a tick: its color's opacity is the texture's own (shared with SetAlpha)
                    region:SetVertexColor(color.r, color.g, color.b, color.a * alpha)
                else
                    region:SetAlpha(alpha)
                end
            end
        end
    end
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
    layoutEdgeLine("edgeTOP", Options.Line == "TOP" or Options.Line == "BOTH", "BOTTOM", "TOP", Options.LinePosition)

    -- bottom edge lines
    HUD.edgeBOTTOM = HUD.edgeBOTTOM or HUD:CreateTexture(nil, "OVERLAY")
    HUD.edgeBOTTOM:SetColorTexture(Options.LineColor.r, Options.LineColor.g, Options.LineColor.b, Options.LineColor.a)
    HUD.edgeBOTTOM:SetHeight(Options.LineThickness)
    HUD.edgeBOTTOM:ClearAllPoints()
    HUD.edgeBOTTOM:SetPoint("TOP", HUD, "BOTTOM", 0, -Options.LinePosition)
    HUD.edgeBOTTOM:SetWidth(HUD:GetWidth())
    layoutEdgeLine("edgeBOTTOM", Options.Line == "BOTTOM" or Options.Line == "BOTH", "TOP", "BOTTOM", -Options.LinePosition)

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
            -- place on the strip in degrees (rotateCompassStrip fades by it)
            letters[k*side].degree = (side == 1 and k) or (k - 360)

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
            degrees[i].degree = i
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
            ticks[tickPosition .. i].degree = i
            if v:IsShown() then
                if v.data.main then
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomMainColor.r, Options.CompassCustomMainColor.g, Options.CompassCustomMainColor.b, Options.CompassCustomMainColor.a)
                    ticks[tickPosition .. i].fadeColor = Options.CompassCustomMainColor
                else
                    ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomSecondaryColor.r, Options.CompassCustomSecondaryColor.g, Options.CompassCustomSecondaryColor.b, Options.CompassCustomSecondaryColor.a)
                    ticks[tickPosition .. i].fadeColor = Options.CompassCustomSecondaryColor
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
            ticks[tickPosition .. i].degree = i
            if not letters[i] or not letters[i]:IsShown() then
                ticks[tickPosition .. i]:SetVertexColor(Options.CompassCustomDegreesColor.r, Options.CompassCustomDegreesColor.g, Options.CompassCustomDegreesColor.b, Options.CompassCustomDegreesColor.a)
                ticks[tickPosition .. i].fadeColor = Options.CompassCustomDegreesColor
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

    -- a fading compass texture is drawn as slices (rotateCompassStrip turns them)
    local fadeTexture = Options.EdgeFade and Options.EdgeFadeCompass and not Options.UseCustomCompass
    layoutCompassSlices(fadeTexture)
    HUD.compassTexture:SetShown(not Options.UseCustomCompass and not fadeTexture)
    HUD.compassCustom:SetShown(Options.UseCustomCompass)
    HUD.heading:SetShown(Options.HeadingEnabled)

    -- pointers
    HUD.pointers = HUD.pointers or {}

    -- groups
    HUD.groups = HUD.groups or {}
end
