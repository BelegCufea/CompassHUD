-- Core: the HUD frame, update loop, super-tracked target resolution, events, TomTom hooks and the
-- addon lifecycle (OnInitialize/OnEnable/OnDisable). Marker types live in Markers/, settings in Options.lua.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

-- Lua built-ins used in update loops, local so they don't go through the shared environment
local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")

local GetTitleForQuestID = C_QuestLog.GetTitleForQuestID
local GetQuestZoneID = C_TaskQuest.GetQuestZoneID
local GetQuestLocation = C_TaskQuest.GetQuestLocation
local GetWorldQuestsOnMap = C_TaskQuest.GetQuestsOnMap
local GetTaskQuestInfoByQuestID = C_TaskQuest.GetQuestInfoByQuestID
local GetAvailableQuestLines = C_QuestLine and C_QuestLine.GetAvailableQuestLines
local GetUserWaypoint = C_Map.GetUserWaypoint
local GetSuperTrackedQuestID = C_SuperTrack.GetSuperTrackedQuestID
local GetSuperTrackedMapPin = C_SuperTrack.GetSuperTrackedMapPin
local GetSuperTrackedVignette = C_SuperTrack.GetSuperTrackedVignette
local GetHighestPrioritySuperTrackingType = C_SuperTrack.GetHighestPrioritySuperTrackingType
local GetAreaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo
local GetTaxiNodesForMap = C_TaxiMap.GetTaxiNodesForMap
local GetVignettePosition = C_VignetteInfo.GetVignettePosition
local GetVignetteInfo = C_VignetteInfo.GetVignetteInfo

function updateHeading()
    if HUD.heading and HUD.heading.text and player.angle then
        local heading = (360 - (player.angle * (180 / math.pi))) % 360
        if Options.HeadingDecimals >= 0 then
            local multiplier = 10^Options.HeadingDecimals
            heading = math.floor(heading * multiplier + 0.5) / multiplier
        else
            local multiplier = Options.HeadingDecimals * 5 * -1
            heading = math.floor((heading + multiplier/2) / multiplier) * multiplier
        end

        --Zee-ro fix
        if heading == 0 and Options.HeadingTrueNorth then
            heading = 360
        end

        HUD.heading.text:SetText(heading)
    end
end

function updateHUD(force)
    local facing = readPlayerFacing() or 0
    if force or facing ~= currentFacing then
        local coord = (facing < PI and 0.5 or 1) - (facing * ADJ_FACTOR)
        -- rotate texture
        HUD.compassTexture:SetTexCoord(coord - adjCoord, coord + adjCoord, 0, 1)
        -- rotate letters
        HUD.compassCustom.mask:ClearAllPoints()
        HUD.compassCustom.mask:SetPoint('TOP', HUD.compassCustom, 'TOP', (1/2 - coord) * textureWidth, 0)
        currentFacing = facing
    end
    updatePlayerCoords()
    updateHeading()
    setQuestsIcons()
    setGroupIcons()
    setGatherMateNodes()
    setPOITrackNodes()
    setQuestieNodes()
    updateSpeech()
end

function onUpdate(_, elapsed)
    if player.inInstance then return end

    timer = timer + elapsed
    if timer < (1 / Options.Interval) then return end
    timer = 0
    groupThrottle = groupThrottle + 1
    gatherMateThrottle = gatherMateThrottle + 1
    poiTrackThrottle = poiTrackThrottle + 1
    questieThrottle = questieThrottle + 1
    updateHUD(false)
end

function tomtomSetCrazyArrow(self, uid, dist, title)
    if not Options.Pointers[questPointerIdent .. tomTom].enabled then return end
    if not uid then return end
    if type(uid) ~= "table" then return end
    local questID = tomTom
    local questType = tomTom
    local completed = false
    if title and title:find("^Turn in: ") then
        completed = true
    end
    updateQuest(questID, uid[2], uid[3], uid[1], questType, title, completed)
    tomTomActive = TomTom:GetKey(uid)
    questPointsTable[tomTom].track = true
end

function tomtomClearWaypoint(self, uid)
    if not uid then return end
    if type(uid) ~= "table" then return end
    local tomTomRemoved = TomTom:GetKey(uid)
    if tomTomRemoved and tomTomActive == tomTomRemoved and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
end

-- Effective HUD visibility: outside an instance and the Visibility macro condition says "show".
-- Both the zone handler and the attribute driver go through this, so neither overrides the other.
-- Before the driver has set the attribute (nil) the HUD counts as shown.
function shouldShowHUD()
    -- always shown while the game's Edit Mode is open, so it can be found and moved (EditMode.lua)
    if editModeActive then return true end
    local state = HUD:GetAttribute("state-hudvisibility")
    return (state == nil or state == "show") and not player.inInstance
end

function createHUD()
    HUD = CreateFrame('Frame', ADDON_NAME, UIParent, "BackdropTemplate")
    HUD:SetPoint("CENTER")
    HUD:SetClampedToScreen(true)
    HUD:RegisterForDrag("LeftButton")

    HUD:SetScript("OnAttributeChanged", function(self, name, value)
        if name == "state-hudvisibility" then
            Addon:SetVisibility(shouldShowHUD())
        end
    end)

    HUD.SupertrackMinimapIcon = function(self)
        supertrackPOITrack()
    end
end

-- Title of the TomTom waypoint at the same place as a user map pin.
-- Some addons copy TomTom waypoints into a Blizzard user waypoint, which has no name.
-- This works for any addon that sets the TomTom waypoint (Questie, BtWQuests, ...).
tomTomTitleCache = {}
function getTomTomWaypointTitle(uiMapID, x, y)
    if not (TomTom and type(TomTom.waypoints) == "table" and uiMapID and x and y) then return end
    -- target lookups can still run several times a second: reuse the last result for the same pin for a moment
    local cache, now = tomTomTitleCache, GetTime()
    if cache.uiMapID == uiMapID and cache.x == x and cache.y == y and cache.expires and now < cache.expires then
        return cache.title
    end
    local bestTitle, bestDistance
    for _, mapWaypoints in pairs(TomTom.waypoints) do
        for _, uid in pairs(mapWaypoints) do
            local title = type(uid) == "table" and uid.title
            if title and title ~= "" and uid[1] and uid[2] and uid[3] then
                local distance = HBD:GetZoneDistance(uiMapID, x, y, uid[1], uid[2], uid[3])
                if distance and distance <= SAME_POINT_YARDS and (not bestDistance or distance < bestDistance) then
                    bestTitle, bestDistance = title, distance
                end
            end
        end
    end
    cache.uiMapID, cache.x, cache.y, cache.title, cache.expires = uiMapID, x, y, bestTitle, now + 1 -- reuse for one second
    return bestTitle
end

-- Name and position of an available quest ("!" quest offer pin).
-- GetTitleForQuestID is often empty for quests not in the quest log, so the
-- name comes from the world map pin, or from the data that the pin is built from.
questOfferCache = {}
function getQuestOfferInfo(questID, uiMapID)
    -- The pin on the open world map already holds the quest name and its position
    if WorldMapFrame:IsVisible() then
        for pin in WorldMapFrame:EnumerateAllPins() do
            if pin.questID == questID and pin.questName and pin.GetPosition then
                local x, y = pin:GetPosition()
                if x and y then
                    local atlasName = type(pin.questIcon) == "string" and pin.questIcon or nil
                    return pin.questName, x, y, WorldMapFrame:GetMapID(), atlasName
                end
            end
        end
    end

    if not uiMapID then return end

    -- Quest givers
    if GetAvailableQuestLines then
        for _, info in ipairs(GetAvailableQuestLines(uiMapID) or {}) do
            if info.questID == questID and info.x and info.y then
                return info.questName, info.x, info.y, uiMapID
            end
        end
    end

    -- Bonus objectives and other task quests
    if GetWorldQuestsOnMap then
        for _, info in ipairs(GetWorldQuestsOnMap(uiMapID) or {}) do
            if info.questID == questID and info.x and info.y then
                local name = GetTaskQuestInfoByQuestID and GetTaskQuestInfoByQuestID(questID)
                return name, info.x, info.y, uiMapID
            end
        end
    end
end

function resolveSuperTrackedTarget(event,...)
    if TomTom and TomTomCrazyArrow and not TomTomCrazyArrow:IsShown() and questPointsTable[tomTom] then
        questPointsTable[tomTom].track = false
    end
    local questID = GetSuperTrackedQuestID()
    local completed = false
    if questID and questID > 0 then
        local x, y, uiMapID
    	if isTask(questID)  then
            uiMapID = GetQuestZoneID(questID)
            if not uiMapID then
                uiMapID = getMapId(questID)
            end
            if uiMapID then
                x, y = GetQuestLocation(questID, uiMapID)
            end
        else
            uiMapID, x, y, completed = GetQuestPOIInfo(questID)
        end
        if x and y and uiMapID then
            updateQuest(questID, x, y, uiMapID, 0, nil, completed)
        end
    else
        local superTrackingType = GetHighestPrioritySuperTrackingType()
        if superTrackingType == Enum.SuperTrackingType.UserWaypoint then
            local point = GetUserWaypoint()
            if point then
                -- a waypoint set by the supertrack keybinding for a minimap icon: its name and look
                local poiTracked = poiNodes.tracked
                local name
                if isTrackedWaypoint(point, poiTracked) then
                    name = poiTracked.name
                    updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, name, completed, poiTracked.atlasName, poiTracked.texture, {
                        ["stRetexture"] = Options.POITrackSTRetexture,
                        ["worldmapTexture"] = Options.POITrackWorldmapTexture,
                    })
                else
                    name = getTomTomWaypointTitle(point.uiMapID, point.position.x, point.position.y)
                    updateQuest(mapPin, point.position.x, point.position.y, point.uiMapID, mapPin, name, completed)
                end
            end
        end
        local uiMapID = WorldMapFrame:IsVisible() and WorldMapFrame:GetMapID() or player.uiMapID
        if superTrackingType == Enum.SuperTrackingType.MapPin then
            local STtype, STtypeID = GetSuperTrackedMapPin()
            local poiInfo
            local title

            local moreArgs = {
                ["STtype"] = STtype,
                ["STtypeID"] = STtypeID
            }

            -- the pointer already shows this pin (from an earlier event)
            local samePin = questPointsTable[selectedPin] and questPointsTable[selectedPin].moreArgs and questPointsTable[selectedPin].moreArgs.STtype == moreArgs.STtype and questPointsTable[selectedPin].moreArgs.STtypeID == moreArgs.STtypeID

            -- try to get corrent uiMapID
            if samePin then
                uiMapID = questPointsTable[selectedPin].uiMapID
            elseif STtype == 0 and STtypeID and (not uiMapID or not poiCache[STtypeID] or not poiCache[STtypeID][uiMapID]) then
                -- poiCache is keyed by areaPoiID: only area POIs (STtype 0) can be looked up there,
                -- quest offer (1) and taxi node (2) IDs would match unrelated area POIs
                for mapID, _ in pairs(poiCache[STtypeID] or {}) do
                    uiMapID = mapID
                    break
                end
            end

            -- POI
            if (STtype == 0) and uiMapID then
                poiInfo = GetAreaPOIInfo(uiMapID, STtypeID)
            end

            -- Offer
            if STtype == 1 then
                -- A found offer does not move: reuse it until another pin is supertracked,
                -- instead of scanning all map pins again on every QUEST_LOG_UPDATE
                local cached = questOfferCache.questID == STtypeID and questOfferCache
                local name, x, y, mapID, atlasName
                if cached then
                    name, x, y, mapID, atlasName = cached.name, cached.x, cached.y, cached.mapID, cached.atlasName
                else
                    name, x, y, mapID, atlasName = getQuestOfferInfo(STtypeID, uiMapID)
                    if x and y and mapID then
                        questOfferCache = { questID = STtypeID, name = name, x = x, y = y, mapID = mapID, atlasName = atlasName }
                    end
                end
                title = name or GetTitleForQuestID(STtypeID)
                if x and y and mapID then
                    uiMapID = mapID
                    poiInfo = { name = title, position = CreateVector2D(x, y), atlasName = atlasName }
                end
            end

            -- Taxi
            if (STtype == 2) and uiMapID then
                local taxis = GetTaxiNodesForMap(uiMapID)
                if taxis then
                    for _,v in pairs(taxis) do
                        if v.nodeID == STtypeID then
                            poiInfo = v
                            break
                        end
                    end
                end
            end

            if poiInfo then
                updateQuest(selectedPin, poiInfo.position.x, poiInfo.position.y, uiMapID, selectedPin, poiInfo.name, completed, poiInfo.atlasName, nil, moreArgs)
            elseif WorldMapFrame:IsVisible() and event == "SUPER_TRACKING_CHANGED" and not samePin then
                -- No position from the game: approximate it with the cursor, but only right when the pin
                -- was clicked. Later events (QUEST_LOG_UPDATE, ...) keep that position instead of
                -- moving the target to wherever the cursor is then.
                local x, y = WorldMapFrame:GetNormalizedCursorPosition()
                if uiMapID and x and y then
                    updateQuest(selectedPin, x, y, uiMapID, selectedPin, title, completed, nil, nil, moreArgs)
                end
            end
        end
        if (superTrackingType == Enum.SuperTrackingType.Vignette) and uiMapID then
            local vignetteGUID = GetSuperTrackedVignette()
            if vignetteGUID then
                local vignettePosition = GetVignettePosition(vignetteGUID, uiMapID)
                local vignetteInfo = GetVignetteInfo(vignetteGUID)
                if vignettePosition and vignetteInfo then
                    local x, y = vignettePosition:GetXY()
                    if x and y then
                        updateQuest(selectedPin, x, y, uiMapID, selectedPin, vignetteInfo.name, false, vignetteInfo.atlasName, nil, vignetteInfo)
                    end
                end
            end
        end
    end
    setQuestsIcons()
end

-- Events that can fire many times in a row (QUEST_LOG_UPDATE comes in bursts). They are merged
-- into one target lookup shortly after the burst. Everything else, especially SUPER_TRACKING_CHANGED
-- (the map pin cursor fallback needs the moment of the click), is handled right away.
burst = {
    delay = 0.2,
    pending = false,
}
burst.events = {
    QUEST_LOG_UPDATE = true,
    QUEST_POI_UPDATE = true,
    SUPER_TRACKING_PATH_UPDATED = true,
}

function OnEvent(event, ...)
    if not burst.events[event] then
        resolveSuperTrackedTarget(event, ...)
        return
    end
    if burst.pending then return end
    burst.pending = true
    C_Timer.After(burst.delay, function()
        burst.pending = false
        resolveSuperTrackedTarget(event)
    end)
end

-- Re-applies all pointer fonts once. A pointer can be created before its font is usable: TomTom
-- restores a saved waypoint at login, possibly before the addon that registers the chosen font with
-- LibSharedMedia has done so (LSM:Fetch then returns the default font). Called when a font is
-- registered and after a loading screen; a burst of calls is merged into one refresh on the next frame.
fontRefreshPending = false
function schedulePointerFontRefresh()
    if fontRefreshPending then return end
    fontRefreshPending = true
    C_Timer.After(0, function()
        fontRefreshPending = false
        for _, quest in pairs(questPointsTable) do
            if quest.frame then
                updateQuestIcon(quest.frame)
            end
        end
        updateGroupTexts()
        updateGatherMate()
        updatePoiTrack()
        updateQuestie()
    end)
end

function onMediaRegistered(_, mediatype)
    if mediatype == "font" then
        schedulePointerFontRefresh()
    end
end

function OnGroup(event, ...)
    local groupType = (IsInRaid() and "raid") or  (IsInGroup() and "party") or "none"
    if groupType ~= (player.groupType or "") then Addon:HideGroupIcons() end
    player.groupType = groupType
end

-- The HUD is hidden in instances where the game gives no player facing (dungeons, raids): the
-- compass cannot turn there. Other instances, e.g. housing neighborhoods, keep it if the facing
-- is available. player.inInstance means "hidden because of the instance".
-- Returns whether the player is in an instance at all.
function updateInstanceState()
    local inInstance = IsInInstance()
    player.inInstance = (inInstance and not readPlayerFacing()) and true or false
    Addon:SetVisibility(shouldShowHUD())
    return inInstance
end

function OnZoneChange(event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        schedulePointerFontRefresh()
    end
    cachePOIs()
    if updateInstanceState() and player.inInstance then
        -- the facing may only be given a moment after the loading screen: look once more
        C_Timer.After(2, updateInstanceState)
    end
    OnGroup(event, ...)
    OnEvent(event, ...)
end

function Addon:HideGroupIcons()
    for _,v in pairs(groupPointsTable) do
        if v.frame then v.frame:Hide() end
        v.active = false
    end
end

function Addon:SetVisibility(visible)
    if visible then
        HUD:Show()
        HUD:SetScript('OnUpdate', onUpdate)
    else
        HUD:Hide()
        HUD:SetScript('OnUpdate',nil)
    end
end

function Addon:ResetPosition(resetX, resetY)
    if resetX then
        Options.PositionX = (UIParent:GetWidth() / Options.Scale - HUD:GetWidth()) / 2
    end
    if resetY then
        Options.PositionY = (UIParent:GetHeight() - HUD:GetHeight() - 64) / Options.Scale
    end
    HUD:ClearAllPoints()
    HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
end

-- One-time profile updates. Called for every profile that becomes active (login, switch, copy, reset).
function migrateProfile()
    if Options.SizeVersion < 1 then
        -- markers used to be sized by the compass height; keep their size now that it is separate
        Options.IconScale = Options.VerticalScale
        Options.SizeVersion = 1
    end
end

-- Size by pixels: the scales follow from the wanted HUD size (border included), so everything
-- else keeps working with HorizontalScale/VerticalScale, and switching back to scales keeps the size.
local function applyPixelSize()
    local border = Options.BorderThickness * 2
    local innerWidth = math.max(Options.Width - border, 1)
    local innerHeight = math.max(Options.Height - border, 1)
    Options.HorizontalScale = innerWidth * 720 / (Options.Degrees * defaultTextureWidth)
    Options.VerticalScale = innerHeight / defaultTextureHeight
end

function Addon:UpdateHUDSettings()
    if Options.SizeMode == "PIXELS" and Options.Width > 0 and Options.Height > 0 then
        applyPixelSize()
    end
    textureWidth = defaultTextureWidth * Options.HorizontalScale
    textureHeight = defaultTextureHeight * Options.VerticalScale
    iconSize = defaultTextureHeight * Options.IconScale
    local width, height = Options.Degrees / (720 / textureWidth) + Options.BorderThickness * 2, textureHeight + Options.BorderThickness * 2
    adjCoord = Options.Degrees / 1440

    HUD:EnableMouse(not Options.Lock)
    HUD:SetMovable(not Options.Lock)
	if Options.Lock then
		HUD:SetScript('OnDragStart', nil)
		HUD:SetScript('OnDragStop', nil)
		HUD:StopMovingOrSizing()
	else
		HUD:SetScript('OnDragStart', function()
            HUD:StartMoving()
        end)
		HUD:SetScript('OnDragStop', function ()
            HUD:StopMovingOrSizing()
            Options.PositionX = HUD:GetLeft()
            Options.PositionY = HUD:GetBottom()
        end)
	end

    if Options.PositionX < 0 then
        self:ResetPosition(true, true)
    else
        local currentScale = round(HUD:GetScale(), 2)
        local currentWidth = round(HUD:GetWidth(), 2)
        if  currentWidth ~= 0 then

            if currentScale ~= Options.Scale then
                local diffScale = currentScale / Options.Scale
                local center = (Options.PositionX + currentWidth / 2) * diffScale
                Options.PositionX = center - currentWidth / 2
                Options.PositionY = Options.PositionY * diffScale
            end

            if currentWidth ~= width then
                local diffWidth = (currentWidth - width) / 2
                Options.PositionX = Options.PositionX + diffWidth
            end
        end

        HUD:ClearAllPoints()
        HUD:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", Options.PositionX, Options.PositionY)
    end

    HUD:SetSize(width, height)
    HUD:SetScale(Options.Scale)
	HUD:SetFrameStrata(Options.Strata)
	HUD:SetFrameLevel(Options.Level)
    HUD:SetAlpha(Options.Transparency)

	local backdrop = {
		bgFile = LSM:Fetch("background", Options.Background),
		edgeFile = LSM:Fetch("border", Options.Border),
		edgeSize = Options.BorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	HUD:SetBackdrop(backdrop)
    HUD:SetBackdropColor(Options.BackgroundColor.r,Options.BackgroundColor.g, Options.BackgroundColor.b, Options.BackgroundColor.a)
	HUD:SetBackdropBorderColor(Options.BorderColor.r,Options.BorderColor.g, Options.BorderColor.b, Options.BorderColor.a)

    Options.PositionX = HUD:GetLeft()
    Options.PositionY = HUD:GetBottom()

    updateCompassHUD()

    HUD.compassCustom:SetSize(width, height)
    for _, quest in pairs(questPointsTable) do
        if quest.frame then
            updateQuestIcon(quest.frame)
        end
    end
    updateHUD(true)
    updatePointerTextures()
    updateGroupTexts()
    updateGatherMate()
    updatePoiTrack()
    updateQuestie()
    UnregisterAttributeDriver(HUD, 'state-hudvisibility')
    RegisterAttributeDriver(HUD, "state-hudvisibility", Options.Visibility)
end

function Addon:RefreshConfig()
    Options = self.db.profile
    migrateProfile()
    self:UpdateDataBroker()
    -- setGroupIcons stops early when the new profile hides party/raid markers, so hide the
    -- current ones here; it shows them again on its next pass if they are enabled
    self:HideGroupIcons()
    self:UpdateHUDSettings()
end

function Addon:OnEnable()
    addToLSM()

    Addon:InitializeDataBroker()
    player.name = UnitName("player")
    player.realm = GetRealmName()

    self:UpdateHUDSettings()
    -- also needed after a runtime re-enable: the visibility driver only fires on a change,
    -- and OnDisable hid the HUD
    self:SetVisibility(shouldShowHUD())

    registerEditMode()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChange)
    self:RegisterEvent("PLAYER_MAP_CHANGED", OnZoneChange)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChange)
    self:RegisterEvent("GROUP_ROSTER_UPDATE", OnGroup)
    self:RegisterEvent("ZONE_CHANGED", OnEvent)
    self:RegisterEvent("QUEST_ACCEPTED", OnEvent)
    self:RegisterEvent("QUEST_LOG_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_POI_UPDATE", OnEvent)
    self:RegisterEvent("QUEST_TURNED_IN", OnEvent)
    self:RegisterEvent("USER_WAYPOINT_UPDATED", OnEvent)
    self:RegisterEvent("WAYPOINT_UPDATE", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_CHANGED", OnEvent)
    self:RegisterEvent("SUPER_TRACKING_PATH_UPDATED", OnEvent)


    if TomTom then
        self:SecureHook(TomTom, "SetCrazyArrow", tomtomSetCrazyArrow)
        self:SecureHook(TomTom, "ClearWaypoint", tomtomClearWaypoint)
        self:SecureHook(TomTom, "HideWaypoint", tomtomClearWaypoint)
    end

    LSM.RegisterCallback(self, "LibSharedMedia_Registered", onMediaRegistered)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

-- AceEvent and AceHook drop their own registrations on disable; this cleans up what the addon owns.
function Addon:OnDisable()
    -- stop the visibility driver first, or its next change would show the HUD again
    UnregisterAttributeDriver(HUD, 'state-hudvisibility')
    -- hiding the HUD also stops the OnUpdate scripts of all marker frames (they are its children)
    self:SetVisibility(false)
    -- hand the SuperTracker icon back to the game
    updateSuperTrackedTexture(nil)
end

function Addon:OnInitialize()
    Addon:ConstructDefaultsAndOptions()
    Options = self.db.profile
    migrateProfile()
    createHUD()
end
