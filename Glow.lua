-- Glow around the compass while the player is inside a quest's area (the blob on the map).
-- Which quests count: the supertracked one, and optionally the other watched ones (the game only
-- tells for watched quests). The supertracked quest has its own look; the others share one (or use
-- the same, "Same as Supertracked"). After some seconds inside, the glow eases down to a weaker one. Follows "Fade toward the edges" (background and border) like the frame's border.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local math, pairs, ipairs = math, pairs, ipairs
local GetTime = GetTime
local CreateColor = CreateColor
-- presence-checked: not on every game version
local IsInsideQuestBlob = C_Minimap and C_Minimap.IsInsideQuestBlob
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetNumQuestWatches = C_QuestLog.GetNumQuestWatches
local GetQuestIDForQuestWatchIndex = C_QuestLog.GetQuestIDForQuestWatchIndex

local CHECK_INTERVAL = 0.2 -- seconds between checks of the quest areas
local FADE_TIME = 0.3      -- seconds to fade the glow in or out
local PULSE_PERIOD = 1.6   -- seconds of one pulse
local SLICES = 32          -- pieces of the top and bottom glow, to fade it along the strip
local CORNER_TEXTURE = [[Interface\Addons\]] .. ADDON_NAME .. [[\Media\GlowCorner]] -- quarter circle, the full opacity at its inner corner

local glow = {
    frame = nil,
    top = nil, bottom = nil,   -- lists of slices
    left = nil, right = nil,   -- textures
    corners = nil,             -- TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT
    kind = nil,    -- "super" or "other": whose look is applied, nil when no quest area is entered
    styled = nil,  -- key of the look applied to the textures
    alpha = 0,     -- current fade, 0-1
    nextCheck = 0,
}

-- The corner textures' coordinates: the texture has its inner corner at the bottom right.
local CORNER_COORDS = {
    TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
    BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

function glowAvailable()
    return IsInsideQuestBlob ~= nil
end

-- The look of 'kind': color, size in pixels, pulsing, intensity (0-1).
local function glowStyle(kind)
    if kind == "other" and not Options.GlowOtherSame then
        return Options.GlowOtherColor, Options.GlowOtherSize, Options.GlowOtherPulse, Options.GlowOtherIntensity / 100
    end
    return Options.GlowSuperColor, Options.GlowSuperSize, Options.GlowSuperPulse, Options.GlowSuperIntensity / 100
end

local function createGlow()
    local frame = CreateFrame("Frame", nil, HUD)
    frame:SetAllPoints(HUD)
    frame:SetFrameLevel(math.max(HUD:GetFrameLevel() - 1, 0))
    frame:Hide()
    glow.top, glow.bottom = {}, {}
    for i = 1, SLICES do
        glow.top[i] = frame:CreateTexture(nil, "BACKGROUND")
        glow.bottom[i] = frame:CreateTexture(nil, "BACKGROUND")
        glow.top[i]:SetColorTexture(1, 1, 1, 1)
        glow.bottom[i]:SetColorTexture(1, 1, 1, 1)
    end
    glow.left = frame:CreateTexture(nil, "BACKGROUND")
    glow.right = frame:CreateTexture(nil, "BACKGROUND")
    glow.left:SetColorTexture(1, 1, 1, 1)
    glow.right:SetColorTexture(1, 1, 1, 1)
    glow.corners = {}
    for name, coords in pairs(CORNER_COORDS) do
        local corner = frame:CreateTexture(nil, "BACKGROUND")
        corner:SetTexture(CORNER_TEXTURE)
        corner:SetTexCoord(unpack(coords))
        glow.corners[name] = corner
    end
    frame:SetScript("OnUpdate", function(self, elapsed)
        -- eased off: still inside the area, so only weaker
        local target = glow.kind and (glow.eased and Options.GlowEaseTo / 100 or 1) or 0
        if glow.alpha ~= target then
            local step = elapsed / FADE_TIME
            glow.alpha = target > glow.alpha and math.min(glow.alpha + step, target) or math.max(glow.alpha - step, target)
        end
        if glow.alpha == 0 and not glow.kind then
            self:Hide()
            return
        end
        local _, _, pulse, intensity = glowStyle(glow.styledKind or "super")
        local factor = intensity
        if pulse and glow.kind then
            -- between 50% and 100% of the strength
            factor = factor * (0.75 + 0.25 * math.sin(GetTime() * 2 * math.pi / PULSE_PERIOD))
        end
        self:SetAlpha(glow.alpha * factor)
    end)
    glow.frame = frame
end

-- Sets the textures' size and color; the strongest color is at the compass, fading to nothing
-- outward. With "Fade toward the edges" for the background and border, the glow fades along the
-- strip like the border does: the top and bottom in slices, the sides and corners at the edge's opacity.
local function styleGlow(kind)
    local color, size = glowStyle(kind)
    local fade = Options.EdgeFade and Options.EdgeFadeFrame
    local key = kind .. size .. color.r .. color.g .. color.b .. color.a
        .. (fade and (Options.EdgeFadeStart .. Options.EdgeFadeInner .. Options.EdgeFadeOuter .. Options.EdgeFadeCurve) or "")
        .. HUD:GetWidth()
    if glow.styled == key then return end
    glow.styled = key
    local r, g, b, a = color.r, color.g, color.b, color.a
    local width = HUD:GetWidth()
    local sliceWidth = width / SLICES
    local sideAlpha = a * (fade and edgeFadeAt(1) or 1)

    for i = 1, SLICES do
        local x0, x1 = (i - 1) * sliceWidth, i * sliceWidth
        -- the fade at the middle of the slice (t = 0 in the middle of the strip, 1 at the edge)
        local f = fade and edgeFadeAt(math.abs((x0 + x1) / 2 - width / 2) / (width / 2)) or 1
        local strong, none = CreateColor(r, g, b, a * f), CreateColor(r, g, b, 0)
        local top, bottom = glow.top[i], glow.bottom[i]
        top:ClearAllPoints()
        top:SetPoint("BOTTOMLEFT", HUD, "TOPLEFT", x0, 0)
        top:SetPoint("BOTTOMRIGHT", HUD, "TOPLEFT", x1, 0)
        top:SetHeight(size)
        top:SetGradient("VERTICAL", strong, none)
        bottom:ClearAllPoints()
        bottom:SetPoint("TOPLEFT", HUD, "BOTTOMLEFT", x0, 0)
        bottom:SetPoint("TOPRIGHT", HUD, "BOTTOMLEFT", x1, 0)
        bottom:SetHeight(size)
        bottom:SetGradient("VERTICAL", none, strong)
    end

    local strong, none = CreateColor(r, g, b, sideAlpha), CreateColor(r, g, b, 0)
    glow.left:ClearAllPoints()
    glow.left:SetPoint("TOPRIGHT", HUD, "TOPLEFT", 0, 0)
    glow.left:SetPoint("BOTTOMRIGHT", HUD, "BOTTOMLEFT", 0, 0)
    glow.left:SetWidth(size)
    glow.left:SetGradient("HORIZONTAL", none, strong)
    glow.right:ClearAllPoints()
    glow.right:SetPoint("TOPLEFT", HUD, "TOPRIGHT", 0, 0)
    glow.right:SetPoint("BOTTOMLEFT", HUD, "BOTTOMRIGHT", 0, 0)
    glow.right:SetWidth(size)
    glow.right:SetGradient("HORIZONTAL", strong, none)

    -- the corners sit diagonally outside the HUD's corners
    local corners = glow.corners
    local function place(name, point, relative)
        local corner = corners[name]
        corner:ClearAllPoints()
        corner:SetPoint(point, HUD, relative, 0, 0)
        corner:SetSize(size, size)
        corner:SetVertexColor(r, g, b, sideAlpha)
    end
    place("TOPLEFT", "BOTTOMRIGHT", "TOPLEFT")
    place("TOPRIGHT", "BOTTOMLEFT", "TOPRIGHT")
    place("BOTTOMLEFT", "TOPRIGHT", "BOTTOMLEFT")
    place("BOTTOMRIGHT", "TOPLEFT", "BOTTOMRIGHT")
end

-- "super" while inside the supertracked quest's area, "other" for another watched quest (with
-- with "Also glow for other watched quests"), nil for none. The supertracked quest comes first, so its look wins.
local function enteredQuestArea()
    local superID = GetSuperTrackedQuestID and GetSuperTrackedQuestID()
    if superID and superID ~= 0 and IsInsideQuestBlob(superID) then return "super" end
    if Options.GlowWatched and GetNumQuestWatches and GetQuestIDForQuestWatchIndex then
        for i = 1, GetNumQuestWatches() do
            local questID = GetQuestIDForQuestWatchIndex(i)
            if questID and questID ~= superID and IsInsideQuestBlob(questID) then return "other" end
        end
    end
end

-- Called from updateHUD; the quest areas are checked a few times a second.
function updateGlow(force)
    if not IsInsideQuestBlob then return end
    local now = GetTime()
    if not force and now < glow.nextCheck then return end
    glow.nextCheck = now + CHECK_INTERVAL

    local kind = Options.GlowEnabled and enteredQuestArea() or nil
    if not glow.frame then
        if not kind then return end
        createGlow()
    end
    if kind then
        styleGlow(kind)
        glow.styledKind = kind -- kept while fading out
        glow.frame:Show()
        -- ease off after some seconds inside; a new entry starts the glow again
        glow.enteredAt = glow.enteredAt or now
        glow.eased = Options.GlowEaseAfter > 0 and now - glow.enteredAt >= Options.GlowEaseAfter
    else
        glow.enteredAt, glow.eased = nil, false
    end
    glow.kind = kind -- the frame's OnUpdate fades in or out, and hides itself when faded out
end

-- After a settings change: apply the look again at once.
function refreshGlow()
    glow.styled = nil
    if glow.frame then updateGlow(true) end
end
