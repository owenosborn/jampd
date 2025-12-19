-- Main Organelle script with sequencer
local oled = require("lib/oled")
local Sequencer = require("lib/sequencer").Sequencer
local Presets = require("lib/presets").Presets
local Latch = require("lib/latch").Latch

-- State
local seq = nil
local aux_pressed = false
local knob_values = {0, 0, 0, 0}
local transpose = 0
local notes_held = 0
local presets = nil
local delete_armed = false  -- Two-tap delete confirmation

-- Aux function keys (black keys starting from C#)
local aux_keys = {61, 63, 66, 68, 70, 73, 75, 78, 80, 82}

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
    seq = Sequencer.new(1000)
    presets = Presets.new("presets")
    latch = Latch.new(function(note, velocity)
        latchOut(jam, note, velocity)
    end)
    displayKnobs()
    jam.msgout("oled", "/led", 0)
end

function tick(jam)
    seq:tick(jam)
end

-- Display all knob values on OLED
function displayKnobs()
    for i = 1, 4 do
        local cfg = knob_configs[i]
        local display_val = cfg[2](knob_values[i])
        oled.setLine(jam, i, string.format("%d: %s: " .. cfg[1], i, cfg[3], display_val))
    end
end

-- Display aux function menu (2 functions per line)
function displayAuxMenu()
    for line = 1, 5 do
        local left_label = aux_labels[line]
        -- Override for function 1 based on sequencer state
        if line == 1 then
            left_label = seq:isPlaying() and "Stop" or "Play"
        end
        oled.setLine(jam, line, string.format("%-8s | %-8s", left_label, aux_labels[line + 5]))
    end
end

-- Display modal dialog with box and large font
function displayModal(jam, text)
    oled.fillArea(jam, 10, 13, 108, 38, oled.COLOR_BLACK)
    oled.box(jam, 10, 13, 108, 38, oled.COLOR_WHITE)
    oled.println(jam, 20, 25, oled.SIZE_16, oled.COLOR_WHITE, text)
    oled.flip(jam)
end

-- Display two-line modal dialog with box and large font
function displayModalTwoLines(jam, line1, line2)
    oled.fillArea(jam, 10, 13, 108, 48, oled.COLOR_BLACK)
    oled.box(jam, 10, 13, 108, 48, oled.COLOR_WHITE)
    oled.println(jam, 20, 19, oled.SIZE_16, oled.COLOR_WHITE, line1)
    oled.println(jam, 20, 40, oled.SIZE_16, oled.COLOR_WHITE, line2)
    oled.flip(jam)
end

-- Aux Functions Table
local auxFunctions = {
    -- Function 1: Start/Stop playback
    function(jam)
        if seq:isPlaying() then
            seq:stop(jam)
            jam.msgout("oled", "/led", 0)
            displayModal(jam, "Stopped")
        elseif seq:isStopped() then 
            if seq:hasEvents() then
                seq:play()
                jam.msgout("oled", "/led", 3)
                displayModal(jam, "Playing")
            else
                displayModal(jam, "Empty")        
            end
        elseif seq:isArmed() then
            seq:stop(jam)
            jam.msgout("oled", "/led", 0)
            displayModal(jam, "Stopped")
        end
    end,
    
    -- Function 2: Arm recording
    function(jam)
        if seq:isStopped() or seq:isPlaying() then
            seq:stop(jam)
            seq:arm()
            jam.msgout("oled", "/led", 6)
            displayModal(jam, "Armed")
        elseif seq:isArmed() then
            seq:stop(jam)
            jam.msgout("oled", "/led", 0)
            displayModal(jam, "Stopped")
        end
    end,
    
    -- Function 3: Previous preset
    function(jam)
        local settings = presets:prev()
        if settings then
            applyPreset(jam, settings)
            if seq:hasEvents() then
                seq:play()
                jam.msgout("oled", "/led", 3)
            end
            displayModalTwoLines(jam, "Preset", presets:getDisplayString())
        else 
            displayModal(jam, "No preset")
        end
    end,
    
    -- Function 4: Save preset
    function(jam)
        if seq:isRecording() then
            displayModal(jam, "Stop recording first")
            return
        end
        
        local settings = {
            knob1 = knob_values[1],
            knob2 = knob_values[2],
            knob3 = knob_values[3],
            knob4 = knob_values[4],
            sequence = seq:hasEvents() and seq:serialize() or nil
        }
        
        if presets:save(settings) then
            displayModalTwoLines(jam, "Save", presets:getDisplayString())
        end
    end,
    
    -- Function 5: Next preset
    function(jam)
        local settings = presets:next()
        if settings then
            applyPreset(jam, settings)
            if seq:hasEvents() then
                seq:play()
                jam.msgout("oled", "/led", 3)
            end
            displayModalTwoLines(jam, "Preset", presets:getDisplayString())
        else 
            displayModal(jam, "No preset")
        end
    end,
    
    -- Function 6: Transpose down by octave
    function(jam)
        transpose = math.max(-24, transpose - 12)
        displayModalTwoLines(jam, "Octave", string.format("%+d", transpose / 12))
    end,
    
    -- Function 7: Transpose up by octave
    function(jam)
        transpose = math.min(24, transpose + 12)
        displayModalTwoLines(jam, "Octave", string.format("%+d", transpose / 12))
    end,
    
    -- Functions 8-9: Placeholders
    function(jam) 
        latch:toggle()
        if latch.enabled then displayModalTwoLines(jam, "Latch", "On")      
        else displayModalTwoLines(jam, "Latch", "Off")  end
    end,
    function(jam) end,
    
    -- Function 10: Delete preset (requires two taps)
    function(jam)
        if presets.current_index == 0 or presets:count() == 0 then
            displayModal(jam, "No preset")
            return
        end
        
        if not delete_armed then
            -- First tap: show confirmation
            delete_armed = true
            displayModalTwoLines(jam, "Delete ", presets:getDisplayString() .. "?")
        else
            -- Second tap: actually delete, and load new 
            if presets:delete() then
                delete_armed = false
                displayModalTwoLines(jam, "Deleted", " ")
                local settings = presets:load(presets.current_index)
                if settings then
                    applyPreset(jam, settings)
                end
            end
        end
    end
}

-- Helper to apply loaded preset
function applyPreset(jam, settings)
    -- Stop sequencer first to prevent stuck notes
    if seq:isPlaying() then
        seq:stop(jam)
        jam.msgout("oled", "/led", 0)
    end
    
    -- Apply knob values
    for i = 1, 4 do
        knob_values[i] = settings["knob" .. i] or 0
        jam.msgout("knobs", "knob" .. i, knob_values[i])
    end
    
    -- Load sequence if present
    if settings.sequence then 
        seq:deserialize(settings.sequence)
    end
end

-- Input handlers
function notein(jam, n, v)
    -- Track note on/off for aux mode blocking
    notes_held = notes_held + (v > 0 and 1 or -1)
    notes_held = math.max(0, notes_held)
    
    local transposed_note = n + transpose
    
    if aux_pressed then
        -- Aux mode: check for aux function triggers
        if v > 0 then
            for i, key in ipairs(aux_keys) do
                if n == key then
                    -- Reset delete confirmation unless we're on function 10
                    if i ~= 10 then
                        delete_armed = false
                    end
                    auxFunctions[i](jam)
                    return
                end
            end
        end
    else
        -- Normal mode: record and pass through
        if seq:isArmed() and v > 0 then
            seq:startRecording(jam)
            jam.msgout("oled", "/led", 1)
        end
        latch:notein(transposed_note, v)
       -- seq:recordNote(jam, transposed_note, v)
       -- jam.noteout(transposed_note, v)
    end
end

function latchOut(jam, n, v)
    print("latch out")
    seq:recordNote(jam, n, v)
    jam.noteout(n, v)
end

-- Aux button handler (1 = pressed, 0 = released)
function aux(jam, v)
    if v == 1 then
        -- Special case: if recording, end it
        if seq:isRecording() then
            seq:endRecording(jam)
            seq:play()
            jam.msgout("oled", "/led", 3)
            return
        end
        
        -- Only enter aux mode if no notes are held
        if notes_held == 0 then
            aux_pressed = true
            oled.clear(jam)
            displayAuxMenu()
        end
    else
        -- Aux released
        if aux_pressed then
            aux_pressed = false
            delete_armed = false  -- Reset delete confirmation
            oled.clear(jam)
            displayKnobs()
        end
    end
end

-- Generic knob handler
local function handleKnob(jam, knob_num, v)
    knob_values[knob_num] = v
    
    if not aux_pressed then
        local cfg = knob_configs[knob_num]
        local display_val = cfg[2](v)
        oled.setLine(jam, knob_num, string.format("%d: %s: " .. cfg[1], knob_num, cfg[3], display_val))
    end
    
    jam.msgout("knobs", "knob" .. knob_num, v)
    
    if seq:isArmed() then
        seq:startRecording(jam)
        jam.msgout("oled", "/led", 1)
    end
    seq:recordKnob(jam, knob_num, v)
end

-- Knob handlers
function knob1(jam, v) handleKnob(jam, 1, v) end
function knob2(jam, v) handleKnob(jam, 2, v) end
function knob3(jam, v) handleKnob(jam, 3, v) end
function knob4(jam, v) handleKnob(jam, 4, v) end