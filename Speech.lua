-- Text to speech for accessibility: reads out the marker the player is facing (the minimap icon
-- closest to the heading, or the supertracked target) when it changes.
local ADDON_NAME, Addon = ...
-- shared environment of the addon's files (see Init.lua)
setfenv(1, Addon.env)

local math, ipairs = math, ipairs
local GetTime = GetTime
local HBD = LibStub("HereBeDragons-2.0")
-- SpeakText(voiceID, text, rate, volume, allowOverlappedSpeech), the same on all game versions
local SpeakText = C_VoiceChat and C_VoiceChat.SpeakText
local GetTtsVoices = C_VoiceChat and C_VoiceChat.GetTtsVoices
local GetVoiceOptionID = C_TTSSettings and C_TTSSettings.GetVoiceOptionID

local GAME_VOICE = -1 -- SpeechVoice: the voice chosen in the game's text to speech settings

local speech = {
    candidate = nil, -- marker faced right now
    since = 0,       -- since when it is faced
    spoken = nil,    -- marker read out last; read again only after facing something else
}

function speechAvailable()
    return SpeakText ~= nil
end

-- Options values: the game's voice first, then every voice the system offers.
function getSpeechVoices()
    local list = { [GAME_VOICE] = "Game setting (Text to Speech voice)" }
    for _, voice in ipairs(GetTtsVoices and GetTtsVoices() or {}) do
        list[voice.voiceID] = voice.name
    end
    return list
end

function speakText(text)
    if not (SpeakText and text) then return end
    local voice = Options.SpeechVoice
    if voice == GAME_VOICE or voice == nil then
        voice = GetVoiceOptionID and GetVoiceOptionID(0) or 0
    end
    SpeakText(voice, text, Options.SpeechRate, Options.SpeechVolume, false)
end

local function textFor(name, distance)
    if not Options.SpeechDistance or not distance then return name end
    local value = math.floor(distance * (Options.UseMeters and 0.9144 or 1) + 0.5)
    return name .. ", " .. value .. (Options.UseMeters and " meters" or " yards")
end

-- Called on every HUD update, after the markers are placed (updateHUD).
function updateSpeech()
    if not (Options.SpeechEnabled and SpeakText and player.angle) then return end
    local limit = math.rad(Options.SpeechDegrees)
    local candidate, name, distance

    local target = Options.SpeechSupertracked and shownGameTarget
    if target and target.text then
        local angle = relativeAngle(target.instance, target.x, target.y)
        if angle and math.abs(angle) <= limit then
            limit = math.abs(angle)
            candidate, name = target, target.text
            distance = HBD:GetWorldDistance(target.instance, player.x, player.y, target.x, target.y)
        end
    end

    local poi = Options.SpeechPOI and Options.POITrackEnabled and poiTrackHeading
    if poi and poi.name and poi.angle and poi.frame and poi.frame:IsShown() and math.abs(poi.angle) < limit then
        candidate, name, distance = poi, poi.name, poi.distance
    end

    local now = GetTime()
    if candidate ~= speech.candidate then
        speech.candidate, speech.since = candidate, now
        if not candidate then
            -- facing nothing: the same marker is read again when turned to
            speech.spoken = nil
        end
        return
    end
    if candidate and candidate ~= speech.spoken and now - speech.since >= Options.SpeechDelay then
        speech.spoken = candidate
        speakText(textFor(name, distance))
    end
end
