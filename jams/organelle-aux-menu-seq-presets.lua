-- Main Organelle script with sequencer
local oled = require("lib/oled")
local Sequencer = require("lib/sequencer").Sequencer
local Presets = require("lib/presets").Presets

-- State variables
local seq = nil
local aux_pressed = false
local knob_values = {0, 0, 0, 0}
local transpose = 0
local notes_held = 0
local presets = nil

-- Aux function keys (black keys starting from C#)
local aux_keys = {61, 63, 66, 68, 70, 73, 75, 78, 80, 82}

-- Aux function labels
local aux_labels = {
    "Play", "Record", "<", "Save", ">",
    "Oct-", "Oct+", ".", ".", "."
}

function init(jam)
    seq = Sequencer.new(1000)
    presets = Presets.new("presets")
    displayKnobs()
    jam.msgout("oled", "/led", 0)
end

function tick(jam)
    seq:tick(jam)
end

-- Display all knob values on OLED
function displayKnobs()
    local percent1 = math.floor(knob_values[1] * 100)
    oled.setLine(jam, 1, string.format("1: Wave Mix: %d%%", percent1))
    
    local hz = math.floor(knob_values[2] * 7900 + 100)
    oled.setLine(jam, 2, string.format("2: Cutoff: %d Hz", hz))
    
    local percent3 = math.floor(knob_values[3] * 100)
    oled.setLine(jam, 3, string.format("3: Resonance: %d%%", percent3))
    
    local ms = math.floor(knob_values[4] * 600)
    oled.setLine(jam, 4, string.format("4: Glide: %d ms", ms))
end

-- Display aux function menu (2 functions per line)
function displayAuxMenu()
    for line = 1, 5 do
        local left_idx = line
        local right_idx = line + 5
        
        -- Get label, but override for function 1 based on state
        local left_label = aux_labels[left_idx]
        if left_idx == 1 then
            left_label = seq:isPlaying() and "Stop" or "Play"
        end
        
        local text = string.format("%-8s | %-8s", 
            left_label,
            aux_labels[right_idx])
        oled.setLine(jam, line, text)
    end
end

-- Display transpose as a modal dialog with box and large font
function displayTransposeModal(jam)
    oled.fillArea(jam, 10, 13, 108, 38, oled.COLOR_BLACK)
    oled.box(jam, 10, 13, 108, 38, oled.COLOR_WHITE)
    
    local octaves = transpose / 12
    local text = string.format("Octave: %+d", octaves)
    oled.println(jam, 20, 25, oled.SIZE_16, oled.COLOR_WHITE, text)
    
    oled.flip(jam)
end

-- Display modal dialog with box and large font
function displayModal(jam, text)
    oled.fillArea(jam, 10, 13, 108, 38, oled.COLOR_BLACK)
    oled.box(jam, 10, 13, 108, 38, oled.COLOR_WHITE)
    oled.println(jam, 20, 25, oled.SIZE_16, oled.COLOR_WHITE, text)
    oled.flip(jam)
end

-- Input handlers
function notein(jam, n, v)
    -- Track note on/off for aux mode blocking
    if v > 0 then
        notes_held = notes_held + 1
    else
        notes_held = math.max(0, notes_held - 1)
    end
    
    local transposed_note = n + transpose
    
    if aux_pressed then
        -- Aux mode: only handle note-ons for aux functions
        if v > 0 then
            handleAuxNote(jam, n, v)
        end
    else
        -- Normal mode: record and pass through
        -- start recording on note on
        if seq:isArmed() and v > 0 then
            seq:startRecording(jam)
            jam.msgout("oled", "/led", 1)
        end
        seq:recordNote(jam, transposed_note, v)
        jam.noteout(transposed_note, v)
    end
end

-- Handle notes when aux is pressed
function handleAuxNote(jam, n, v)
    if v == 0 then return end
    
    for i, key in ipairs(aux_keys) do
        if n == key then
            executeAuxFunction(jam, i)
            return
        end
    end
end

-- Execute the aux function by index (1-10)
function executeAuxFunction(jam, idx)
    if idx == 1 then
        auxFunction1(jam)
    elseif idx == 2 then
        auxFunction2(jam)
    elseif idx == 3 then
        auxFunction3(jam)
    elseif idx == 4 then
        auxFunction4(jam)
    elseif idx == 5 then
        auxFunction5(jam)
    elseif idx == 6 then
        auxFunction6(jam)
    elseif idx == 7 then
        auxFunction7(jam)
    elseif idx == 8 then
        auxFunction8(jam)
    elseif idx == 9 then
        auxFunction9(jam)
    elseif idx == 10 then
        auxFunction10(jam)
    end
end

-- Aux Functions

-- Function 1: Start/Stop playback
function auxFunction1(jam)
    if seq:isPlaying() then
        seq:stop(jam)
        print("Playback stopped")
        jam.msgout("oled", "/led", 0)
        displayModal(jam, "Stopped")
    elseif seq:isStopped() then 
        if seq:hasEvents() then
            seq:play()
            print("Playback started")
            jam.msgout("oled", "/led", 3)
            displayModal(jam, "Playing")
        else
            print("Seq empty")
            displayModal(jam, "Empty")        
        end
    elseif seq:isArmed() then
        seq:stop(jam)
        print("Arm canceled")
        jam.msgout("oled", "/led", 0)
        displayModal(jam, "Stopped")
    end
end

-- Function 2: Arm recording
function auxFunction2(jam)
    if seq:isStopped() then
        seq:arm()
        print("Recording armed - play a note to start")
        jam.msgout("oled", "/led", 6)
        displayModal(jam, "Armed")
    elseif seq:isArmed() then
        seq:stop(jam)
        print("Arm canceled")
        jam.msgout("oled", "/led", 0)
        displayModal(jam, "Stopped")
    end
end
-- Aux function 3: Previous preset
function auxFunction3(jam)
    local settings = presets:prev()
    if settings then
        applyPreset(jam, settings)
        displayModal(jam, "Preset: " .. presets:getCurrentName())
    end
end

-- Aux function 4: Save preset
function auxFunction4(jam)
    -- Don't save while recording
    if seq:isRecording() then
        print("Cannot save while recording")
        displayModal(jam, "Stop recording first")
        return
    end
    
    local settings = {
        knob1 = knob_values[1],
        knob2 = knob_values[2],
        knob3 = knob_values[3],
        knob4 = knob_values[4]
    }
    
    -- Include sequence if it has events
    if seq:hasEvents() then
        settings.sequence = seq:serialize()
    end
    
    if presets:save(settings) then
        displayModal(jam, "Saved: " .. presets:getCurrentName())
    end
end

-- Aux function 5: Next preset
function auxFunction5(jam)
    local settings = presets:next()
    if settings then
        applyPreset(jam, settings)
        displayModal(jam, "Preset: " .. presets:getCurrentName())
    end
end


-- Helper to apply loaded preset
function applyPreset(jam, settings)
    -- Stop sequencer first to prevent stuck notes
    if seq:isPlaying() then
        seq:stop(jam)
        jam.msgout("oled", "/led", 0)  -- Set LED to stopped state
    end
    
    knob_values[1] = settings.knob1 or 0
    knob_values[2] = settings.knob2 or 0
    knob_values[3] = settings.knob3 or 0
    knob_values[4] = settings.knob4 or 0
    
    -- Send values to synth
    jam.msgout("knobs", "knob1", knob_values[1])
    jam.msgout("knobs", "knob2", knob_values[2])
    jam.msgout("knobs", "knob3", knob_values[3])
    jam.msgout("knobs", "knob4", knob_values[4])
    
    -- Load sequence if present
    if settings.sequence then 
        seq:deserialize(settings.sequence)
        seq:play()
        jam.msgout("oled", "/led", 3)  -- Set LED to playing state
    end

    -- Update display
    displayKnobs()
end

-- Transpose down by octave
function auxFunction6(jam)
    transpose = math.max(-24, transpose - 12)
    print("Transpose: " .. transpose)
    displayTransposeModal(jam)
end

-- Transpose up by octave
function auxFunction7(jam)
    transpose = math.min(24, transpose + 12)
    print("Transpose: " .. transpose)
    displayTransposeModal(jam)
end

function auxFunction8(jam)
    print("Aux Function 8")
end

function auxFunction9(jam)
    print("Aux Function 9")
end

function auxFunction10(jam)
    print("Aux Function 10")
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
        else
            print("Release all notes to enter aux mode")
        end
    else
        -- Aux released
        if aux_pressed then
            aux_pressed = false
            oled.clear(jam)
            displayKnobs()
        end
    end
end

-- Knob handlers
function knob1(jam, v)
    knob_values[1] = v
    if not aux_pressed then
        local percent = math.floor(v * 100)
        oled.setLine(jam, 1, string.format("1: Wave Mix: %d%%", percent))
    end
    jam.msgout("knobs", "knob1", v)
    if seq:isArmed() then
        seq:startRecording(jam)
        jam.msgout("oled", "/led", 1)
    end
    seq:recordKnob(jam, 1, v)  -- Record knob movement
end

function knob2(jam, v)
    knob_values[2] = v
    if not aux_pressed then
        local hz = math.floor(v * 7900 + 100)
        oled.setLine(jam, 2, string.format("2: Cutoff: %d Hz", hz))
    end
    jam.msgout("knobs", "knob2", v)
    if seq:isArmed() then
        seq:startRecording(jam)
        jam.msgout("oled", "/led", 1)
    end
    seq:recordKnob(jam, 2, v)  -- Record knob movement
end

function knob3(jam, v)
    knob_values[3] = v
    if not aux_pressed then
        local percent = math.floor(v * 100)
        oled.setLine(jam, 3, string.format("3: Resonance: %d%%", percent))
    end
    jam.msgout("knobs", "knob3", v)
    if seq:isArmed() then
        seq:startRecording(jam)
        jam.msgout("oled", "/led", 1)
    end
    seq:recordKnob(jam, 3, v)  -- Record knob movement
end

function knob4(jam, v)
    knob_values[4] = v
    if not aux_pressed then
        local ms = math.floor(v * 600)
        oled.setLine(jam, 4, string.format("4: Glide: %d ms", ms))
    end
    jam.msgout("knobs", "knob4", v)
        if seq:isArmed() then
        seq:startRecording(jam)
        jam.msgout("oled", "/led", 1)
    end
    seq:recordKnob(jam, 4, v)  -- Record knob movement
end