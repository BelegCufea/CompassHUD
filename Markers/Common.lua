-- Shared by all marker types: distance/arrival texts, pointer types, fonts, text layout, SuperTracker retexture.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestInfo = C_QuestLog.GetInfo
local GetQuestRewardCurrencyInfo = C_QuestLog.GetQuestRewardCurrencyInfo
local RequestPreloadRewardData = C_TaskQuest.RequestPreloadRewardData
local GetQuestClassification = C_QuestInfoSystem.GetQuestClassification
local IsSuperTrackingAnything = C_SuperTrack.IsSuperTrackingAnything
local GetGlidingInfo = C_PlayerInfo.GetGlidingInfo

function setTime(frame, distance, speed)
    if speed and speed > 0 then
        local eta = math.abs(distance / speed)
        local minutes = math.floor(eta / 60)
        local seconds = math.floor(eta % 60)
        local tta = string.format("%d:%02.f", minutes, seconds)
        frame.TimeText:SetText(tta)
    else
        frame.TimeText:SetText("***")
    end
end

function questPointerSetTexts(frame, dt)
    if player.inInstance then return end
    frame.elapsed = frame.elapsed + dt
    if frame.distanceHidden and frame.timeHidden then return end
    frame.distance = HBD:GetWorldDistance(frame.instance, player.x, player.y, frame.x, frame.y)
    if not frame.distance then
        frame:Hide()
        return
    end
    if not frame.minDistance or frame.minDistance > frame.distance then
        frame.minDistance = frame.distance
    end
    frame:Show()
    local distance = frame.distance * (Options.UseMeters and 0.9144 or 1)
    if Options.RoundDistance then
        -- BreakUpLargeNumbers shows a decimal below 1000 for non-integer values
        distance = math.floor(distance + 0.5)
    end
    frame.DistanceText:SetText(BreakUpLargeNumbers(distance))
    if frame.timeHidden then return end
    if frame.elapsed >= 1 then
        frame.elapsed = 0
        -- Moving away from the target (distance grew since the last check): no arrival time,
        -- shown like standing still instead of a time that is never reached
        local lastDistance = frame.ttaLastDistance
        frame.ttaLastDistance = frame.distance
        if lastDistance and frame.distance > lastDistance + 0.5 then
            setTime(frame, frame.distance, 0)
            return
        end
        -- GetUnitSpeed returns 0 (truthy) when standing still, so "player or vehicle" never reached the vehicle
        local speed = GetUnitSpeed(UnitInVehicle("player") and "vehicle" or "player")
        -- GetUnitSpeed does not report skyriding speed; the gliding info does
        local isGliding, _, forwardSpeed = GetGlidingInfo()
        if isGliding and forwardSpeed and not issecretvalue(forwardSpeed) and forwardSpeed > 0 then
            speed = forwardSpeed
        end
        
        -- NEW: Detect if speed is a secret value using 12.0 API
        if not speed or issecretvalue(speed) then
            -- Fallback: calculate speed from distance change (original delta method)
            -- each delayed check keeps its own start distance (a shared frame field could be
            -- overwritten by the next check before this one runs)
            local startDistance = frame.distance
            C_Timer.After(1, function()
                local currentDistance = HBD:GetWorldDistance(frame.instance, player.x, player.y, frame.x, frame.y)
                local deltaSpeed = 0
                if currentDistance then
                    -- approach speed: positive when getting closer, else no arrival time
                    deltaSpeed = math.max(startDistance - currentDistance, 0)
                end
                setTime(frame, currentDistance, deltaSpeed)
            end)
        else
            -- Safe: speed is a normal number (or can be converted)
            local safeSpeed = tonumber(speed) or 0
            setTime(frame, frame.distance, safeSpeed)
        end
    end
end

function getPointerCategory(questID, questType)
    local category = questType or questUnknown
    if questType < 0 then
        return questPointers[category] and category or questUnknown
    end
    category = GetQuestClassification(questID) or questUnknown
    if category == Enum.QuestClassification.Recurring then
        local questIndex = GetLogIndexForQuestID(questID)
        if not questIndex then return questUnknown end
        local questInfo = GetQuestInfo(questIndex)
        category = (questInfo and questInfo.frequency + 100) or category
    end
    return category
end

function getPointerType(questID, questType)
    local questClassification = getPointerCategory(questID, questType)
    return questPointerIdent .. (questPointers[questClassification] and questClassification or questUnknown)
end

function isTask(questID)
    local classification = GetQuestClassification(questID)
    return
        (classification == Enum.QuestClassification.BonusObjective)
        or (classification == Enum.QuestClassification.WorldQuest)
end

function getWQicon(questID)
    local icon
    RequestPreloadRewardData(questID)
    local reward = GetQuestRewardCurrencyInfo(questID, 1, false)
    local _, itemTexture = GetQuestLogRewardInfo(1, questID)
    local gold = GetQuestLogRewardMoney(questID)
    if gold > 0 then
        icon = [[Interface\Icons\INV_Misc_Coin_02]]
    else
        icon = itemTexture or (reward and reward.texture)
    end
    return icon
end

-- The game's SuperTracker icon (SuperTrackedFrame) is changed from one place only, for the active
-- Blizzard super-tracked target (quest, user waypoint, or POI/vignette pin). Other entries in
-- questPointsTable (earlier targets, TomTom) never touch it. When retexturing does not apply,
-- the icon is handed back to the game once.
function updateSuperTrackedTexture(activeID)
    local questPoint = activeID and questPointsTable[activeID]
    local frame = questPoint and questPoint.frame
    local options = frame and Options.Pointers[frame.pointerType]
    local moreArgs = questPoint and questPoint.moreArgs
    local icon = SuperTrackedFrame.Icon

    if not (options and (options.stRetexture or (moreArgs and moreArgs.stRetexture)) and IsSuperTrackingAnything()) then
        if STtexture.applied then
            if STtexture.masked then
                icon:RemoveMaskTexture(STtexture.mask)
                STtexture.masked = false
            end
            if STtexture.mask then
                STtexture.mask:Hide()
            end
            if STtexture.border then
                STtexture.border:Hide()
            end
            icon:SetScale(1)
            if STtexture.iconSize then
                icon:SetSize(STtexture.iconSize, STtexture.iconSize)
            end
            -- let the game set its own icon again
            if SuperTrackedFrame.UpdateIcon then
                SuperTrackedFrame:UpdateIcon()
            end
            STtexture.applied = false
            STtexture.last.valid = false
        end
        return
    end

    -- === Ensure mask and border exist ===
    if not STtexture.iconSize then
        STtexture.iconSize = icon:GetWidth()
    end

    if not STtexture.mask then
        STtexture.mask = SuperTrackedFrame:CreateMaskTexture()
        STtexture.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        STtexture.mask:SetAllPoints(icon)
        STtexture.mask:Hide()
    end

    if not STtexture.border then
        STtexture.border = SuperTrackedFrame:CreateTexture(nil, "OVERLAY", nil, 1)
        STtexture.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
        STtexture.border:SetAllPoints(icon)
        STtexture.border:Hide()
    end

    -- the game sets its own icon on its own events: forget what was applied, so it is applied again
    if not STtexture.hooked and SuperTrackedFrame.UpdateIcon then
        hooksecurefunc(SuperTrackedFrame, "UpdateIcon", function()
            STtexture.last.valid = false
        end)
        STtexture.hooked = true
    end

    -- === Texture or atlas, same choice as applyPointerTexture ===
    local texture, atlas
    if questPoint.texture and options.worldmapTexture then
        texture = questPoint.texture
    elseif questPoint.atlasName and (options.worldmapTexture or (moreArgs and moreArgs.worldmapTexture)) then
        atlas = questPoint.atlasName
    else
        atlas = questPoint.completed and options.atlasAltID or options.atlasID
    end
    local scale = (questPoint.completed and options.textureAltScale or options.textureScale) * (frame.scaleMultiplier or 1)
    local circle = questPoint.circle and true or false

    -- Runs on every HUD update: change the icon only when something differs from what was applied
    -- (or the game replaced it with its own atlas), so frames that watch it (Edit Mode, other
    -- addons) are not made to re-layout all the time.
    local last = STtexture.last
    if STtexture.applied and last.valid and last.texture == texture and last.atlas == atlas
        and last.scale == scale and last.circle == circle then
        -- with a texture applied the icon has no atlas; an atlas there means the game set its own
        if not icon.GetAtlas or icon:GetAtlas() == atlas then
            return
        end
    end
    last.valid, last.texture, last.atlas, last.scale, last.circle = true, texture, atlas, scale, circle

    if texture then
        icon:SetTexture(texture)
    else
        icon:SetAtlas(atlas)
    end
    icon:SetSize(STtexture.iconSize, STtexture.iconSize)
    icon:SetScale(scale)

    -- === Apply or remove mask/border ===
    if circle then
        if not STtexture.masked then
            icon:AddMaskTexture(STtexture.mask)
            STtexture.masked = true
        end
        STtexture.mask:SetScale(scale)
        STtexture.border:SetScale(scale)
        STtexture.mask:Show()
        STtexture.border:Show()
    else
        if STtexture.masked then
            icon:RemoveMaskTexture(STtexture.mask)
            STtexture.masked = false
        end
        STtexture.mask:Hide()
        STtexture.border:Hide()
    end
    STtexture.applied = true
end

-- Applies font to a pointer text: its own custom font if enabled, else the global pointer font if enabled, else GameFontNormal.
-- Pass color = false to leave the text color untouched (caller sets it).
function setPointerFont(fontString, scale, custom, font, size, flags, color)
    if not custom then
        if Options.PointerFontCustom then
            font, size, flags, color = Options.PointerFont, Options.PointerFontSize, Options.PointerFontFlags, (color ~= false) and Options.PointerFontColor
        else
            local gameFont, gameSize, gameFlags = GameFontNormal:GetFont()
            fontString:SetFont(gameFont, gameSize * scale, gameFlags)
            if color ~= false then
                fontString:SetTextColor(GameFontNormal:GetTextColor())
            end
            return
        end
    end
    fontString:SetFont(LSM:Fetch("font", font), size * scale, flags)
    if color then
        fontString:SetTextColor(color.r, color.g, color.b, color.a)
    end
end

-- Line height of a pointer text, from the font actually applied by setPointerFont (size already includes scale).
-- Used to stack distance/time/title texts so they don't overlap whichever font is in effect.
-- Limits a pointer title to Options.PointerTitleMaxWidth (0 = no limit). A single-line font string
-- with a fixed width is cut off by the game with "...".
function setTitleWidth(fontString)
    fontString:SetWordWrap(false)
    fontString:SetWidth(Options.PointerTitleMaxWidth or 0)
end

function textLineHeight(fontString)
    local _, size = fontString:GetFont()
    return (size or 12) * 1.2
end

-- Stacks the distance, time and title texts of a GatherMate or minimap icon node below the icon,
-- or above it when the icon row is flipped (positive offset). Shared by both node types.
function layoutNodeTexts(frame, flipped, showDistance, showTTA, showTitle, distanceOffset, ttaOffset, titleOffset)
    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = distanceOffset
    local timeTextPosition = - ((showDistance and textLineHeight(frame.DistanceText)) or 0) - ttaOffset
    local titlePosition = - ((showDistance and textLineHeight(frame.DistanceText)) or 0) - ((showTTA and textLineHeight(frame.TimeText)) or 0) - titleOffset
    if flipped then
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((showTTA and textLineHeight(frame.TimeText)) or 0) + distanceOffset - 4
        timeTextPosition = ttaOffset - 4
        if showTitle then
            titlePosition = titleOffset - 4
            timeTextPosition = timeTextPosition + textLineHeight(frame.Title) - 4
            distanceTextPosition = distanceTextPosition + textLineHeight(frame.Title) - 4
        end
    end

    frame.DistanceText:ClearAllPoints()
    frame.DistanceText:SetPoint(point, frame, relativePoint, 0, distanceTextPosition)
    frame.TimeText:ClearAllPoints()
    frame.TimeText:SetPoint(point, frame, relativePoint, 0, timeTextPosition)
    frame.Title:ClearAllPoints()
    frame.Title:SetPoint(point, frame, relativePoint, 0, titlePosition)

    frame.DistanceText:SetShown(showDistance)
    frame.TimeText:SetShown(showTTA)
    frame.Title:SetShown(showTitle)
end
