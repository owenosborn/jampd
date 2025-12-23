-- organelle-mother.lua
-- Mother jam using organelle_track module

local OGUI = require("lib/ogui").OGUI
local Track = require("lib/organelle_track").Track

-- State
local ogui = nil
local track = nil
local aux_pressed = false
local notes_held = 0
local delete_armed = false

-- Aux function keys (black keys starting from C#)
local aux_keys = {61, 63, 66, 68, 70, 73, 75, 78, 80, 82}
local pattern_select_keys = {60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83}

-- Aux function labels
local aux_labels = {
    "Play", "Arm", "<", "Save", ">",
    "Oct-", "Oct+", "Latch", ".", "Delete"
}

-- Knob display configs: {format_string, value_transform_function, label}
local knob_configs = {
    {"%d%%", function(v) return math.floor(v * 100) end, "Wave Mix"},
    {"%d Hz", function(v) return math.floor(v * 7900 + 100) end, "Cutoff"},
    {"%d%%", function(v) return math.floor(v * 100) end, "Resonance"},
    {"%d ms", function(v) return math.floor(v * 600) end, "Glide"}
}

function init(jam)
    -- Create Organelle UI
    ogui = OGUI.new(function(...)
        jam.msgout(...)
    end)
    
    -- Create track with output callback
    track = Track.new(jam, 1, function(type, ...)
        if type == "note" then
            local note, velocity, duration = ...
            jam.noteout(note, velocity, duration)
        elseif type:match("^knob%d$") then
            local knob_type, value = ...
            jam.msgout("knobs", knob_type, value)
        end
    end)
    
    -- Load initial pattern if available
    if track:getPatternCount() > 0 then
        track:loadPattern(1)
    end
    
    displayKnobs()
    ogui:led(OGUI.LED_OFF)
end

function tick(jam)
    track:tick()
end

-- Input handlers
function notein(jam, n, v)
    -- Track note on/off for aux mode blocking
    notes_held = notes_held + (v > 0 and 1 or -1)
    notes_held = math.max(0, notes_held)
    
    if aux_pressed then
        -- Aux mode: handle shift menu
        if v > 0 then
            handleAuxMenu(n)
        end
    else
        -- Normal mode: route to track
        track:notein(n, v)
        updateLED()
    end
end

function handleAuxMenu(note)
    -- Check aux function keys
    for i, key in ipairs(aux_keys) do
        if note == key then
            if i ~= 10 then
                delete_armed = false
            end
            auxFunctions[i]()
            return
        end
    end
    
    -- Check pattern selection keys
    for i, key in ipairs(pattern_select_keys) do
        if note == key then
            local pattern_name = track:loadPattern(i)
            if pattern_name then
                displayModalTwoLines("Pattern", pattern_name)
            else
                displayModal("No pattern")
            end
            return
        end
    end
end

-- Aux button handler
function aux(jam, v)
    if v == 1 then
        -- Aux pressed: end recording if active, otherwise enter menu
        local state = track:getSeqState()
        if state == "RECORDING" then
            track:endRecording()
            ogui:led(OGUI.LED_GREEN)
            return
        end
        
        -- Only enter aux mode if no notes held
        if notes_held == 0 then
            aux_pressed = true
            ogui:clear()
            displayAuxMenu()
        end
    else
        -- Aux released
        if aux_pressed then
            aux_pressed = false
            delete_armed = false
            ogui:clear()
            displayKnobs()
        end
    end
end

-- Knob handlers
local function handleKnob(jam, knob_num, v)
    track:setKnob(knob_num, v)
    
    if not aux_pressed then
        local cfg = knob_configs[knob_num]
        local display_val = cfg[2](v)
        ogui:setLine(knob_num, string.format("%d: %s: " .. cfg[1], knob_num, cfg[3], display_val))
    end
    
    updateLED()
end

function knob1(jam, v) handleKnob(jam, 1, v) end
function knob2(jam, v) handleKnob(jam, 2, v) end
function knob3(jam, v) handleKnob(jam, 3, v) end
function knob4(jam, v) handleKnob(jam, 4, v) end

-- Aux Functions
auxFunctions = {
    -- Function 1: Start/Stop playback
    function()
        local result = track:togglePlayback()
        if result == "playing" then
            ogui:led(OGUI.LED_GREEN)
            displayModal("Playing")
        elseif result == "stopped" then
            ogui:led(OGUI.LED_OFF)
            displayModal("Stopped")
        elseif result == "empty" then
            displayModal("Empty")
        end
    end,
    
    -- Function 2: Arm recording
    function()
        local result = track:toggleArm()
        if result == "armed" then
            ogui:led(OGUI.LED_PURPLE)
            displayModal("Armed")
        elseif result == "stopped" then
            ogui:led(OGUI.LED_OFF)
            displayModal("Stopped")
        end
    end,
    
    -- Function 3: Previous preset
    function()
        local display = track:prevPreset()
        if display then
            if track:hasEvents() then
                track:startPlayback()  -- Start playing
                ogui:led(OGUI.LED_GREEN)
            end
            displayModalTwoLines("Preset", display)
        else
            displayModal("No preset")
        end
    end,
    
    -- Function 4: Save preset
    function()
        if track:getSeqState() == "RECORDING" then
            displayModal("Stop recording first")
            return
        end
        
        if track:savePreset() then
            displayModalTwoLines("Saved", track:getPresetDisplay())
        end
    end,
    
    -- Function 5: Next preset
    function()
        local display = track:nextPreset()
        if display then
            if track:hasEvents() then
                track:startPlayback()  -- Start playing
                ogui:led(OGUI.LED_GREEN)
            end
            displayModalTwoLines("Preset", display)
        else
            displayModal("No preset")
        end
    end,
    
    -- Function 6: Transpose down by octave
    function()
        local octaves = track:transposeDown()
        displayModalTwoLines("Octave", string.format("%+d", octaves))
    end,
    
    -- Function 7: Transpose up by octave
    function()
        local octaves = track:transposeUp()
        displayModalTwoLines("Octave", string.format("%+d", octaves))
    end,
    
    -- Function 8: Latch toggle
    function()
        local enabled = track:toggleLatch()
        displayModalTwoLines("Latch", enabled and "On" or "Off")
    end,
    
    -- Function 9: Placeholder
    function() end,
    
    -- Function 10: Delete preset (requires two taps)
    function()
        if track:getCurrentPresetIndex() == 0 or track:getPresetCount() == 0 then
            displayModal("No preset")
            return
        end
        
        if not delete_armed then
            delete_armed = true
            displayModalTwoLines("Delete", track:getPresetDisplay() .. "?")
        else
            if track:deletePreset() then
                delete_armed = false
                displayModalTwoLines("Deleted", " ")
                -- Load current preset (shifted after delete)
                local display = track:prevPreset()
                track:stopPlayback()
                ogui:led(OGUI.LED_OFF)
                if display then
                    displayModalTwoLines("Preset", display)
                end
            end
        end
    end
}

-- UI Helper Functions
function displayKnobs()
    for i = 1, 4 do
        local cfg = knob_configs[i]
        local value = track:getKnob(i)
        local display_val = cfg[2](value)
        ogui:setLine(i, string.format("%d: %s: " .. cfg[1], i, cfg[3], display_val))
    end
end

function displayAuxMenu()
    for line = 1, 5 do
        local left_label = aux_labels[line]
        if line == 1 then
            local state = track:getSeqState()
            left_label = (state == "PLAYING") and "Stop" or "Play"
        end
        ogui:setLine(line, string.format("%-8s | %-8s", left_label, aux_labels[line + 5]))
    end
end

function displayModal(text)
    ogui:fillArea(10, 13, 108, 38, OGUI.COLOR_BLACK)
    ogui:box(10, 13, 108, 38, OGUI.COLOR_WHITE)
    ogui:println(20, 25, OGUI.SIZE_16, OGUI.COLOR_WHITE, text)
    ogui:flip()
end

function displayModalTwoLines(line1, line2)
    ogui:fillArea(10, 13, 108, 48, OGUI.COLOR_BLACK)
    ogui:box(10, 13, 108, 48, OGUI.COLOR_WHITE)
    ogui:println(20, 19, OGUI.SIZE_16, OGUI.COLOR_WHITE, line1)
    ogui:println(20, 40, OGUI.SIZE_16, OGUI.COLOR_WHITE, line2)
    ogui:flip()
end

function updateLED()
    local state = track:getSeqState()
    if state == "RECORDING" then
        ogui:led(OGUI.LED_RED)
    elseif state == "PLAYING" then
        ogui:led(OGUI.LED_GREEN)
    elseif state == "ARMED" then
        ogui:led(OGUI.LED_PURPLE)
    else
        ogui:led(OGUI.LED_OFF)
    end
end