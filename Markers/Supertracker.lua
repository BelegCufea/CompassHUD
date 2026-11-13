-- The supertracker pointer: the one target the game tracks (quest, map pin, POI/vignette pin, user
-- waypoint) plus the TomTom arrow target. Not a marker module (Markers/Common.lua): one target at a
-- time, fed by events (setSupertrackTarget), with its own look per pointer type (Options.Pointers).
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local HBD               = LibStub("HereBeDragons-2.0")
local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local IsTaskQuestActive = C_TaskQuest.IsActive
local GetBestMapForUnit = C_Map.GetBestMapForUnit
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedVignette = C_SuperTrack.GetSuperTrackedVignette
local ClearAllSuperTracked = C_SuperTrack.ClearAllSuperTracked
local GetHighestPrioritySuperTrackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType
local GetNextWaypointForMapTracker = C_SuperTrack.GetNextWaypointForMap

function updatePointerFrame(questPointer)
    local scale = Options.Scale * Options.IconScale
    local options = Options.Pointers[questPointer.pointerType]
    local pointer = supertrackTargets[questPointer.questID]
    local completed = pointer.completed
    questPointer.position = options.pointerOffset * textureHeight * -1
    local size = iconSize * (completed and options.textureAltScale or options.textureScale) * (questPointer.scaleMultiplier or 1.5)
    questPointer:SetSize(size, size)

    setPointerFont(questPointer.DistanceText, scale, options.distanceCustomFont, options.distanceFont, options.distanceFontSize, options.distanceFontFlags, options.distanceFontColor)
    setPointerFont(questPointer.TimeText, scale, options.ttaCustomFont, options.ttaFont, options.ttaFontSize, options.ttaFontFlags, options.ttaFontColor)
    setPointerFont(questPointer.QuestText, scale, options.questCustomFont, options.questFont, options.questFontSize, options.questFontFlags, options.questFontColor)
    setTitleWidth(questPointer.QuestText)

    local point = "TOP"
    local relativePoint = "BOTTOM"
    local distanceTextPosition = -options.distanceOffset + 2
    local timeTextPosition = - ((options.showDistance and (textLineHeight(questPointer.DistanceText))) or 0) - options.ttaOffset + 2
    local questTextPosition = - ((options.showDistance and (textLineHeight(questPointer.DistanceText))) or 0) - ((options.showTTA and (textLineHeight(questPointer.TimeText))) or 0) - options.questOffset + 4
    local cropX, cropY = pointer.crop / iconSize, pointer.crop / iconSize
    -- an icon that is a part of a texture sheet (applyPointerTexture) keeps its part, unflipped
    local iconCoords = pointer.iconTexCoords
    if iconCoords then
        questPointer.texture:SetTexCoord(iconCoords[1], iconCoords[2], iconCoords[3], iconCoords[4])
    else
        questPointer.texture:SetTexCoord(cropX, 1 - cropX, cropY, 1 - cropY)
    end
    questPointer.flipped = false
    if questPointer.position > 0 then
        questPointer.flipped = true
        if not iconCoords and (pointer.rotateIcon or (completed and (options.textureAltRotate == 1)) or (not completed and (options.textureRotate == 1))) then
            questPointer.texture:SetTexCoord(cropX, 1 - cropX, 1 - cropY, cropY)
        end
        point = "BOTTOM"
        relativePoint = "TOP"
        distanceTextPosition = ((options.showTTA and (textLineHeight(questPointer.TimeText))) or 0) + options.distanceOffset - 12
        timeTextPosition = options.ttaOffset - 12
        local questText = pointer.text
        if questText and questText:match("%S") and options.showQuest then
            questTextPosition = options.questOffset - 6
            timeTextPosition = timeTextPosition + (textLineHeight(questPointer.QuestText))
            distanceTextPosition = distanceTextPosition + (textLineHeight(questPointer.QuestText))
        end
    end

    questPointer.DistanceText:ClearAllPoints()
    questPointer.DistanceText:SetPoint(point, questPointer, relativePoint, 0, distanceTextPosition)
    questPointer.TimeText:ClearAllPoints()
    questPointer.TimeText:SetPoint(point, questPointer, relativePoint, 0, timeTextPosition)
    questPointer.QuestText:ClearAllPoints()
    questPointer.QuestText:SetPoint(point, questPointer, relativePoint, 0, questTextPosition)

    questPointer.DistanceText:SetShown(options.showDistance)
    questPointer.TimeText:SetShown(options.showTTA)
    -- lets questPointerSetTexts skip the speed/arrival work for a hidden time text. The distance is
    -- always computed for quest pointers (minDistance: arrival at a supertracked vignette).
    questPointer.timeHidden = not options.showTTA
    questPointer.QuestText:SetShown(options.showQuest)

    if pointer.circle then
        questPointer.texture:AddMaskTexture(questPointer.mask)
        questPointer.mask:Show()
        questPointer.border:Show()
    else
        questPointer.texture:RemoveMaskTexture(questPointer.mask)
        questPointer.mask:Hide()
        questPointer.border:Hide()
    end
end

-- Frames of quest pointers whose quest is no longer tracked (see setSupertrackerPointers), for reuse:
-- WoW never frees frames.
pointerFramePool = {}

function createPointerFrame(questID, questType)
    local pointerType = getPointerType(questID, questType)
    if not Options.Pointers[pointerType] then
        return
    end
    if not Options.Pointers[pointerType].enabled then return end
    local questPointer = table.remove(pointerFramePool)
    if questPointer then
        -- a reused frame: everything else is set by setSupertrackTarget/updatePointerFrame
        HUD.pointers[questID] = questPointer
        questPointer.questID = questID
        questPointer.pointerType = pointerType
        questPointer:SetSize(iconSize, iconSize)
        questPointer:ClearAllPoints()
        questPointer:SetPoint("CENTER")
        questPointer:Hide()
        questPointer.texture:SetAtlas(Options.Pointers[pointerType].atlasID)
        questPointer.arrowTexture:Hide()
        questPointer.elapsed = 0
        updatePointerFrame(questPointer)
        return questPointer
    end
    questPointer = CreateFrame("FRAME", nil, HUD)
    HUD.pointers[questID] = questPointer
	questPointer.questID = questID
    questPointer.pointerType = pointerType
	questPointer:SetSize(iconSize, iconSize)
	questPointer:SetPoint("CENTER");
	questPointer:Hide()

    questPointer.texture = questPointer:CreateTexture(nil, "ARTWORK")
    questPointer.texture:SetAllPoints(questPointer)
    questPointer.texture:SetAtlas(Options.Pointers[pointerType].atlasID)
    questPointer.mask = questPointer:CreateMaskTexture()
    questPointer.mask:SetTexture("Interface/Masks/CircleMaskScalable", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    questPointer.mask:SetAllPoints(questPointer.texture)
    questPointer.mask:Hide()
    questPointer.border = questPointer:CreateTexture(nil, "OVERLAY", nil, 1)
    questPointer.border:SetAtlas("ui-frame-genericplayerchoice-portrait-border")
    questPointer.border:SetAllPoints(questPointer.texture)
    questPointer.border:Hide()

    questPointer.arrowTexture = questPointer:CreateTexture(nil, "BACKGROUND")
    questPointer.arrowTexture:SetAllPoints(questPointer)
	questPointer.arrowTexture:SetAtlas(Options.StayAtlasID)
    questPointer.arrowTexture:Hide()

    questPointer.DistanceText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.DistanceText:SetJustifyV("TOP")
    questPointer.DistanceText:SetSize(0, 16)
    questPointer.DistanceText:SetParent(questPointer)

    questPointer.TimeText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.TimeText:SetJustifyV("TOP")
    questPointer.TimeText:SetSize(0, 16)
    questPointer.TimeText:SetParent(questPointer)

    questPointer.QuestText = questPointer:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    questPointer.QuestText:SetJustifyV("TOP")
    questPointer.QuestText:SetSize(0, 16)
    questPointer.QuestText:SetParent(questPointer)

    updatePointerFrame(questPointer)

    questPointer.elapsed = 0
    questPointer:SetScript("OnUpdate", questPointerSetTexts)
	return questPointer
end

-- Two targets closer than this are the same place (e.g. an addon's TomTom waypoint and its map pin copy)
SAME_POINT_YARDS = 10
-- The game's super-tracked target while its pointer is enabled and on the player's continent, else nil.
-- Set by setSupertrackerPointers on every update; other marker types use it to avoid a second marker there.
shownGameTarget = nil

function setSupertrackerPointers()
    local vignetteGUID = GetSuperTrackedVignette()
    local supertrackingType = GetHighestPrioritySuperTrackingType()
    local isTrackingUserWaypoint = (supertrackingType == Enum.SuperTrackingType.UserWaypoint)
    local trackingTypes = {[Enum.SuperTrackingType.MapPin] = true, [Enum.SuperTrackingType.Vignette] = true}
    local isTrackingPOI = trackingTypes[supertrackingType]
    local trackedQuest = GetSuperTrackedQuestID()
    local _, _, playerInstance = HBD:GetPlayerWorldPosition()
    if trackedQuest and isTask(trackedQuest) and not IsTaskQuestActive(trackedQuest) then
        trackedQuest = 0
    end

    -- the game's own super-tracked target (TomTom is not one of them)
    local activeID = (trackedQuest and trackedQuest > 0 and trackedQuest)
        or (isTrackingUserWaypoint and mapPin)
        or (isTrackingPOI and selectedPin)
        or nil

    -- A TomTom waypoint at the game's target (addons often set both) is shown once, as the game's
    -- pointer, if that one is enabled. Checked on every update, so the TomTom pointer is back as
    -- soon as the game tracks something else.
    local target = activeID and supertrackTargets[activeID]
    shownGameTarget = target and target.x and target.y and target.frame and target.instance == playerInstance
        and Options.Pointers[target.frame.pointerType].enabled and target or nil

    local hideTomTom = false
    local tt = supertrackTargets[tomTom]
    -- The TomTom pointer follows TomTom's arrow: gone when the arrow has no waypoint any more
    -- (cleared or removed in any way, not all of which go through the hooked functions), hidden
    -- while TomTom hides its arrow (e.g. the waypoint is on another continent). With TomTom's
    -- arrow turned off in its settings, only the first applies.
    if tt and TomTom then
        if TomTom.IsCrazyArrowEmpty and TomTom:IsCrazyArrowEmpty() then
            tt.track = false
        end
        local arrowOn = TomTom.profile and TomTom.profile.arrow and TomTom.profile.arrow.enable
        tt.arrowHidden = arrowOn and TomTomCrazyArrow and not TomTomCrazyArrow:IsShown() or false
    end
    -- "Use TomTom's arrow": follow a change of TomTom's minimap theme (it sends no message for it)
    if tt and tt.frame and Options.Pointers[tt.frame.pointerType].worldmapTexture then
        local icon = tomTomArrowIcon()
        if icon ~= tt.texture then
            tt.texture = icon
            applyPointerTexture(tt)
            updatePointerFrame(tt.frame)
        end
    end
    if Options.HideTomTomAtTarget and tt and tt.track and tt.x and tt.y and target and target.x and target.y
        and target.instance == tt.instance and target.frame and Options.Pointers[target.frame.pointerType].enabled then
        local distance = HBD:GetWorldDistance(target.instance, tt.x, tt.y, target.x, target.y)
        hideTomTom = distance ~= nil and distance <= SAME_POINT_YARDS
    end

	for questID, quest in pairs(supertrackTargets) do
        -- A quest that is no longer the tracked one is dropped (it was tracked once and stayed for the
        -- session); its frame is reused. Tracking it again creates a new entry on the next event.
        if questID > 0 and questID ~= trackedQuest then
            supertrackTargets[questID] = nil
            if quest.frame then
                local frame = quest.frame
                frame:Hide()
                frame.minDistance = nil
                frame.ttaLastDistance = nil
                HUD.pointers[questID] = nil
                table.insert(pointerFramePool, frame)
            end
            quest = nil
        end
        if not quest then
            -- dropped above
        else
        local questHide = (questID == tomTom) and (hideTomTom or quest.arrowHidden)
        if quest.moreArgs and quest.moreArgs.vignetteGUID and quest.moreArgs.vignetteGUID == vignetteGUID and quest.frame and quest.frame.minDistance and quest.frame.minDistance < 10 then
            questHide = true
            ClearAllSuperTracked()
        end
		if not questHide and ((not Options.HideFar or (quest.instance == playerInstance)) and ((questID == trackedQuest) or (questID == mapPin and isTrackingUserWaypoint) or (questID == selectedPin and isTrackingPOI) or (questID == tomTom and quest.track))) then
			local angle = getPlayerFacingAngle(questID)
			if quest.frame and angle then
                if Options.Pointers[quest.frame.pointerType].enabled then
                    local visible = math.rad(Options.Degrees)/2
                    local arrowShow = false
                    local pointerRotate = 0
                    if angle < visible and angle > -visible then
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, quest.frame.position)
                        quest.frame:Show()
                    elseif Options.PointerStay then
                        local side = math.abs(angle)/angle
                        local option = Options.Pointers[quest.frame.pointerType]
                        -- "a or b and not c" parsed as "a or (b and not c)": compute the flag once instead
                        local rotates = quest.rotateIcon or (quest.completed and option.textureAltRotate == 1) or (not quest.completed and option.textureRotate == 1)
                        if rotates and not quest.overrideRotation then
                            pointerRotate = (PI/2 * side * ((quest.frame.flipped and 1) or -1))
                        elseif Options.StayArrow then
                            local width, height = quest.frame.texture:GetSize()
                            local offsetX = side * (width * 0.75 + 3)
                            quest.frame.arrowTexture:ClearAllPoints()
                            quest.frame.arrowTexture:SetPoint("CENTER", quest.frame, "CENTER", offsetX, 0)
                            quest.frame.arrowTexture:SetSize(width, height)
                            quest.frame.arrowTexture:SetScale(0.75)
                            quest.frame.arrowTexture:SetRotation(PI/2 * side * -1)
                            arrowShow = true
                        end
                        quest.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * side * visible, quest.frame.position)
                        quest.frame:Show()
                    else
                        quest.frame:Hide()
                    end
                    quest.frame.arrowTexture:SetShown(arrowShow)
                    quest.frame.texture:SetRotation(pointerRotate)
                else
                    quest.frame:Hide()
                end
            elseif quest.frame then
                -- no position or heading right now: hide instead of leaving the pointer frozen
                quest.frame:Hide()
            end
        else
            if quest.frame then
			    quest.frame:Hide()
            end
		end
        end -- not dropped
	end

    updateSuperTrackedTexture(activeID)
end

-- Sets a quest pointer's texture from its target data and pointer type settings:
-- the world map texture/atlas if enabled (per type, or per target via moreArgs), else the type's atlas.
-- Shared by setSupertrackTarget and updatePointerTextures so a settings change gives the same result as an event.
function applyPointerTexture(entry)
    local frame = entry.frame
    local options = Options.Pointers[frame.pointerType]
    local moreArgs = entry.moreArgs
    entry.overrideRotation = false
    entry.rotateIcon = false
    entry.iconTexCoords = nil
    entry.circle = entry.category == Enum.QuestClassification.WorldQuest
    frame.scaleMultiplier = 1.5
    local color = nil
    if entry.texture and (options.worldmapTexture or (moreArgs and moreArgs.worldmapTexture)) then
        frame.texture:SetTexture(entry.texture)
        frame.scaleMultiplier = 1
        -- a part of a texture sheet and its tint (e.g. a HandyNotes icon tracked with the keybinding);
        -- the coordinates are applied by updatePointerFrame
        entry.iconTexCoords = moreArgs and moreArgs.texCoords
        color = moreArgs and moreArgs.color
        if frame.pointerType == questPointerIdent .. tomTom then
            -- TomTom's minimap arrow: turns like the rotating pointer textures (at the strip and,
            -- with "Pointers stay on the compass", sideways toward the target)
            entry.rotateIcon = true
        else
            entry.overrideRotation = true
        end
    elseif entry.atlasName and (options.worldmapTexture or (moreArgs and moreArgs.worldmapTexture)) then
        frame.texture:SetAtlas(entry.atlasName)
        entry.overrideRotation = true
        frame.scaleMultiplier = 1
    else
        frame.texture:SetAtlas(entry.completed and options.atlasAltID or options.atlasID)
        entry.circle = false
    end
    frame.texture:SetVertexColor(color and color.r or 1, color and color.g or 1, color and color.b or 1, color and color.a or 1)
end

function updatePointerTextures()
    for _, v in pairs(supertrackTargets) do
        -- no frame: the pointer category is disabled
        if v.frame and Options.Pointers[v.frame.pointerType] then
            applyPointerTexture(v)
            updatePointerFrame(v.frame)
        end
    end
end

function setSupertrackTarget(questID, x, y, uiMapID, questType, title, completed, atlasName, texture, moreArgs)
    if type(supertrackTargets[questID]) ~= "table" then
        supertrackTargets[questID] = {}
    end
    title = title or GetTitleForQuestID(questID) or ""
    local HBDuiMapID = uiMapID

    -- Use map transitions
    if Options.UseCurrentMap then
        local playerUiMapId = GetBestMapForUnit("player")
        if playerUiMapId and uiMapID ~= playerUiMapId then
            local mx, my, waypointDescription = GetNextWaypointForMapTracker(playerUiMapId)
            if mx and my then
                x, y, HBDuiMapID = mx, my, playerUiMapId
            end
            if waypointDescription then
                title = title .. " (" .. waypointDescription .. ")"
            end
        end
    end

    local lx, ly, instance = HBD:GetWorldCoordinatesFromZone(x, y, HBDuiMapID)
    supertrackTargets[questID].x = lx
    supertrackTargets[questID].y = ly
    supertrackTargets[questID].uiMapID = uiMapID
    supertrackTargets[questID].instance = instance
    supertrackTargets[questID].text = title
    supertrackTargets[questID].completed = completed
    supertrackTargets[questID].atlasName = atlasName
    supertrackTargets[questID].texture = texture
    supertrackTargets[questID].moreArgs = moreArgs
    supertrackTargets[questID].overrideRotation = false
    supertrackTargets[questID].crop = 0
    supertrackTargets[questID].category = getPointerCategory(questID, questType)
    supertrackTargets[questID].circle = false


    if supertrackTargets[questID].category == Enum.QuestClassification.WorldQuest then
        supertrackTargets[questID].texture = getWQicon(questID)
        supertrackTargets[questID].circle = true
    end

    if not supertrackTargets[questID].frame then
        supertrackTargets[questID].frame = createPointerFrame(questID, questType)
    else
        -- The frame is reused for this quest ID: re-check its pointer type, which can change once
        -- classification or frequency data has loaded (it may have started as "Unknown pointer")
        local pointerType = getPointerType(questID, questType)
        if Options.Pointers[pointerType] then
            supertrackTargets[questID].frame.pointerType = pointerType
        end
    end
    -- Disabled pointer categories get no frame. The target data above is kept, and the frame
    -- is created by the next update after the category is enabled again.
    if not supertrackTargets[questID].frame then return end
    supertrackTargets[questID].frame.scaleMultiplier = 1.5
    supertrackTargets[questID].frame.minDistance = nil
    supertrackTargets[questID].frame.ttaLastDistance = nil -- new target: no "moving away" from the old one
    supertrackTargets[questID].frame.QuestText:SetText(title)
    supertrackTargets[questID].frame.type = "Quest"
    supertrackTargets[questID].frame.instance = supertrackTargets[questID].instance
    supertrackTargets[questID].frame.x = supertrackTargets[questID].x
    supertrackTargets[questID].frame.y = supertrackTargets[questID].y
    applyPointerTexture(supertrackTargets[questID])
    updatePointerFrame(supertrackTargets[questID].frame)
end
