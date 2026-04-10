-- Rotorflight Voice Telemetry Script for TX16S/V16
-- Simple version: uses standard CRSF telemetry
-- Place in: SCRIPTS/TELEMETRY/rf_voice.lua

local voiceFiles = {
    -- Arm/Disarm
    ["DISARMED"] = "rf_disarmed",
    ["DISABLED"] = "rf_arm_fail",
    -- Flight modes
    ["ANGLE"] = "rf_angle",
    ["HORIZON"] = "rf_horizon",
    ["NORMAL"] = "rf_acro",
    ["RESCUE"] = "rf_rescue",
    ["GPS-RESCUE"] = "rf_rescue",
    ["FAILSAFE"] = "rf_failsafe",
    -- Governor
    ["IDLE"] = "rf_gov_off",
    ["ACTIVE"] = "rf_gov_on",
    ["SPOOLUP"] = "rf_gov_on",
}

-- State tracking
local lastState = {
    armed = nil,
    flightMode = "",
    failsafe = false,
}

-- Debounce settings
local debounce = 2000  -- 2 seconds
local lastPlayTime = 0
local lastPlayedFile = ""

-- Get language folder
local function getLangFolder()
    local model = getModel()
    if model then
        local lang = string.match(model, "%[([a-z]+)%]")
        if lang and (lang == "zh" or lang == "en") then
            return lang
        end
    end
    return "en"
end

-- Play voice file
local function playVoice(name)
    local now = getTime()
    
    -- Same file debounce
    if name == lastPlayedFile and now - lastPlayTime < debounce then
        return
    end
    
    local lang = getLangFolder()
    local baseDir = "/SOUNDS/" .. lang .. "/rf"
    
    -- Check file exists
    local fpath = baseDir .. "/" .. name .. ".wav"
    if not io.exists(fpath) then
        -- Fallback to English
        fpath = "/SOUNDS/en/rf/" .. name .. ".wav"
        if not io.exists(fpath) then
            return
        end
    end
    
    playFile(fpath)
    lastPlayedFile = name
    lastPlayTime = now
end

-- Main telemetry callback
local function onTelemReceive(packet)
    local sensId = packet[1]
    local frameId = packet[2]
    
    -- Flight mode frame (0x21)
    if frameId == 33 then  -- 0x21
        local data = ""
        for i = 3, #packet - 1 do
            if packet[i] > 0 then
                data = data .. string.char(packet[i])
            end
        end
        
        local armed = string.find(data, "%*") ~= nil
        local mode = string.gsub(data, "%*", "")
        
        if armed ~= lastState.armed then
            if armed then
                playVoice("rf_armed")
            else
                playVoice("rf_disarmed")
            end
            lastState.armed = armed
        end
        
        if mode ~= lastState.flightMode then
            local voice = voiceFiles[mode]
            if voice then
                playVoice(voice)
            end
            lastState.flightMode = mode
        end
    end
    
    -- Battery sensor (0x08)
    if frameId == 8 then
        local voltage = (packet[3] * 256 + packet[4]) / 10
        if voltage > 0 and voltage < 100 then
            -- Check for low voltage
            if voltage < 37 then
                playVoice("rf_cell_crit")
            elseif voltage < 40 then
                playVoice("rf_cell_low")
            end
        end
    end
    
    -- GPS frame (0x02)
    if frameId == 2 then  -- 0x02 GPS
        local sats = packet[10]
        if sats and sats >= 5 then
            -- GPS fixed
            if not lastState.failsafe and sats >= 5 then
                -- Could play GPS fix voice here but maybe too frequent
            end
        end
    end
end

-- Initialize
local function init()
    lastState.armed = nil
    lastState.flightMode = ""
    lastState.failsafe = false
    return 0
end

-- Run
local function run(event)
    if event == EVT_TELEM then
        local packet = multiBuffer()
        if packet then
            onTelemReceive(packet)
        end
    end
    return 0
end

return { init = init, run = run }