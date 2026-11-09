-- Party and raid member markers.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local pairs, ipairs, next, type, select, tostring, tonumber = pairs, ipairs, next, type, select, tostring, tonumber
local math, string, table, wipe = math, string, table, wipe

local LSM               = LibStub("LibSharedMedia-3.0")
local HBD               = LibStub("HereBeDragons-2.0")
local GetClassColor = C_ClassColor.GetClassColor

function createGroupMemberIcon(unit)
    local groupPointer = CreateFrame("FRAME", nil, HUD)
    HUD.groups[unit] = groupPointer
	groupPointer:SetSize(textureHeight, textureHeight)
	groupPointer:SetPoint("CENTER");
	groupPointer.texture = groupPointer:CreateTexture(nil, "ARTWORK")
	groupPointer.texture:SetAllPoints(groupPointer)
	groupPointer.texture:SetAtlas(Options.GroupTexture)
	groupPointer:Hide()
    groupPointer.Name = CreateFrame('Frame', nil, HUD, "BackdropTemplate")
    groupPointer.Name:SetParent(groupPointer)
    groupPointer.Name.text = groupPointer.Name:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupPointer.Name.text:SetJustifyV("MIDDLE")
    groupPointer.Name.text:SetJustifyH("CENTER")
    groupPointer.Name.text:ClearAllPoints()
    groupPointer.Name.text:SetPoint("CENTER", groupPointer.Name, "CENTER", 0, 0)
    groupPointer.Name.text:SetParent(groupPointer.Name)
	return groupPointer
end

function updateGroupMemberTexts(unit)
    if not groupPointsTable or not groupPointsTable[unit] then return end
    local v = groupPointsTable[unit]
    local scale = Options.Scale * Options.VerticalScale
    local differentZone = player.instance ~= v.instance
    local flipped = (differentZone and Options.GroupZoneOffset > 0) or (not differentZone and Options.GroupOffset > 0)
    v.frame.Name:ClearAllPoints()
    v.frame.Name:SetPoint(flipped and "BOTTOM" or "TOP", v.frame, flipped and "TOP" or "BOTTOM", 0, v.type == "party" and Options.GroupPartyNameOffset or Options.GroupRaidNameOffset)
    if v.type == "raid" then
        setPointerFont(v.frame.Name.text, scale, Options.GroupRaidNameCustomFont, Options.GroupRaidNameFont, Options.GroupRaidNameFontSize, Options.GroupRaidNameFontFlags, false)
    else
        setPointerFont(v.frame.Name.text, scale, Options.GroupPartyNameCustomFont, Options.GroupPartyNameFont, Options.GroupPartyNameFontSize, Options.GroupPartyNameFontFlags, false)
    end
    local nameTextColor = (v.type == "raid") and Options.GroupRaidNameFontColor or Options.GroupPartyNameFontColor
    if ((v.type == "party" and Options.GroupPartyNameClassColor) or (v.type == "raid" and Options.GroupRaidNameClassColor)) and v.classColor then
        v.frame.Name.text:SetTextColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
        v.frame.Name.text:SetTextColor(nameTextColor.r, nameTextColor.g, nameTextColor.b, nameTextColor.a)
    end
	local nameBackdrop = {
		bgFile = LSM:Fetch("background", (v.type == "raid") and Options.GroupRaidNameBackground or Options.GroupPartyNameBackground),
		edgeFile = LSM:Fetch("border", (v.type == "raid") and Options.GroupRaidNameBorder or Options.GroupPartyNameBorder),
		edgeSize = (v.type == "raid") and Options.GroupRaidNameBorderThickness or Options.GroupPartyNameBorderThickness,
		insets = { left = 0, right = 0, top = 0, bottom = 0 }
	}
	v.frame.Name:SetBackdrop(nameBackdrop)
    local nameBackgroundColor = (v.type == "raid") and Options.GroupRaidNameBackgroundColor or Options.GroupPartyNameBackgroundColor
    if ((v.type == "party" and Options.GroupPartyNameBackgroundClass) or (v.type == "raid" and Options.GroupRaidNameBackgroundClass)) and v.classColor then
        v.frame.Name:SetBackdropColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
        v.frame.Name:SetBackdropColor(nameBackgroundColor.r, nameBackgroundColor.g, nameBackgroundColor.b, nameBackgroundColor.a)
    end
    local nameBorderColor = (v.type == "raid") and Options.GroupRaidNameBorderColor or Options.GroupPartyNameBorderColor
    if ((v.type == "party" and Options.GroupPartyNameBorderClass) or (v.type == "raid" and Options.GroupRaidNameBorderClass)) and v.classColor then
        v.frame.Name:SetBackdropBorderColor(v.classColor.r, v.classColor.g, v.classColor.b, 1)
    else
	    v.frame.Name:SetBackdropBorderColor(nameBorderColor.r, nameBorderColor.g, nameBorderColor.b, nameBorderColor.a)
    end
end

function updateGroupMember(unit)
    if not groupPointsTable[unit] then
        groupPointsTable[unit] = { type = string.gsub(unit, "%d+$", "")}
    end
    local wasActive = groupPointsTable[unit].active
    local wasClass = groupPointsTable[unit].className
    groupPointsTable[unit].active = false
    if not groupPointsTable[unit].frame then
        groupPointsTable[unit].frame = createGroupMemberIcon(unit)
        wasClass = "NONE"
    end
    if UnitExists(unit) then
        local x, y, instance = HBD:GetUnitWorldPosition(unit)
        local className, classFile = UnitClass(unit)

        if className then
            groupPointsTable[unit].className = className
            groupPointsTable[unit].classColor = GetClassColor(classFile)
        else
            groupPointsTable[unit].className = nil
            groupPointsTable[unit].classColor = groupPointsTable[unit].type == "party" and Options.GroupPartyNameFontColor or Options.GroupRaidNameFontColor
        end
        if x and y and instance then
            groupPointsTable[unit].x = x
            groupPointsTable[unit].y = y
            groupPointsTable[unit].instance = instance
            groupPointsTable[unit].name, groupPointsTable[unit].realm = UnitName(unit)
            groupPointsTable[unit].realm = groupPointsTable[unit].realm or player.realm
            groupPointsTable[unit].active = true
            if player.x and player.y then
                groupPointsTable[unit].distance = HBD:GetWorldDistance(instance, player.x, player.y, x, y)
            end
        end
    end
    if groupPointsTable[unit].name == player.name and groupPointsTable[unit].realm == player.realm then
        groupPointsTable[unit].active = false
    end
    if not wasClass or wasClass ~= groupPointsTable[unit].className then
        updateGroupMemberTexts(unit)
    end
    if wasActive and not groupPointsTable[unit].active then
        groupPointsTable[unit].frame:Hide()
    end
end

function updateGroupTexts()
    for k, _ in pairs(groupPointsTable) do
        updateGroupMemberTexts(k)
    end
end

function setGroupStrataLevels()
    local activeUnits = {}
    for unit, data in pairs(groupPointsTable) do
        if data.active and data.distance then
            table.insert(activeUnits, { unit = unit, distance = data.distance })
        end
    end
    table.sort(activeUnits, function(a, b)
        return a.distance > b.distance
    end)
    for rank, item in ipairs(activeUnits) do
        groupPointsTable[item.unit].strataLevel = rank+1
    end
end

function setGroupIcons()
    if not player.groupType or player.groupType == "none" then return end
    if player.groupType == "party" and not Options.GroupShowParty then return end
    if player.groupType == "raid" and not Options.GroupShowRaid then return end
    if groupThrottle and groupThrottle >= Options.GroupInterval then
        groupThrottle = 0
        local groupSize = player.groupType == "raid" and 40 or player.groupType == "party" and 4
        for i = 1,groupSize do
            updateGroupMember(player.groupType..i)
        end
        -- draw order by distance: distances only change here, so sort only after this refresh
        setGroupStrataLevels()
    end
    for _, v in pairs(groupPointsTable) do
        if v and v.frame then
            local shown = false
            local markerRotate = 0
            local differentZone = player.instance ~= v.instance
            local size = textureHeight * (differentZone and Options.GroupZoneScale or Options.GroupScale)
            local flipped = (differentZone and Options.GroupZoneOffset > 0 and Options.GroupZoneRotate == 1) or (not differentZone and Options.GroupOffset > 0 and Options.GroupRotate == 1)
            if v.active and player.angle then
                if v.x and v.y and v.instance then
                    local angle = relativeAngle(v.instance, v.x, v.y)
                    if angle then
                        local visible = math.rad(Options.Degrees)/2
                        if angle < visible and angle > -visible then
                            v.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * angle, differentZone and Options.GroupZoneOffset or Options.GroupOffset)
                            shown = true
                        elseif Options.GroupStay then
                            local side = math.abs(angle)/angle
                            if (differentZone and (Options.GroupZoneRotate == 1)) or (not differentZone and (Options.GroupRotate == 1)) then
                                markerRotate = PI/2 * side * ((flipped and 1) or -1)
                            end
                            v.frame:SetPoint("CENTER", HUD, "CENTER", texturePosition() * side * visible, differentZone and Options.GroupZoneOffset or Options.GroupOffset)
                            shown = true
                        end
                    end
                end
            end
            shown = shown and (Options.GroupShowAllZones or not differentZone)
            v.frame:SetShown(shown)
            if shown then
                v.frame:SetSize(size, size)
                v.frame:SetAlpha(differentZone and Options.GroupZoneTransparency or 1)
                v.frame:SetFrameLevel(Options.Level + (v.strataLevel or 0) + ((not differentZone and 50) or 0))
                v.frame.texture:SetTexCoord(0, 1, flipped and 1 or 0, flipped and 0 or 1)
                v.frame.texture:SetAtlas(differentZone and Options.GroupZoneTexture or Options.GroupTexture)
                v.frame.texture:SetDesaturated(differentZone and Options.GroupZoneDesaturate)
                v.frame.texture:SetRotation(markerRotate)
                v.frame.Name.text:SetText(v.name)
                local sizeX, sizeY = v.frame.Name.text:GetSize()
                sizeX = sizeX or textureHeight
                sizeY = sizeY or textureHeight
                v.frame.Name:SetSize(sizeX + 4, sizeY + 4)
                v.frame.Name:SetShown((player.groupType == "party" and Options.GroupPartyNameShow) or (player.groupType == "raid" and Options.GroupRaidNameShow))
            end
        end
    end
end
