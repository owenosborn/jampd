-- Main Organelle script with sequencer and presets
local OGUI = require("lib/ogui").OGUI
local Sequencer = require("lib/sequencer").Sequencer
local Presets = require("lib/presets").Presets
local Latch = require("lib/latch").Latch
local SubJam = require("lib/subjam")

-- sub jam 
local pattern_subjam = nil
local pattern_files = {}

-- State
local seq = nil
local ogui = nil
local aux_pressed = false
local knob_values = {0, 0, 0, 0}
local transpose = 0
local notes_held = 0
local presets = nil
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

-- note flow: notein -> latch -> subjam arp -> sequencer -> output
function init(jam)
    -- Create Organelle UI with msgout callback
    ogui = OGUI.new(function(...)
        jam.msgout(...)
    end)
    
    -- latches notes, enabled with shift button function, routes to subjam
    latch = Latch.new(function(n, v)
        if pattern_subjam and pattern_subjam.notein then
            -- Route to pattern's notein
              pattern_subjam.notein(n, v)
        end
    end)

    -- create sequencer, output goes to main jam output
    seq = Sequencer.new({
        tpb = jam.tpb,
        max_events = 1000,
        output = function(type, ...)
            if type == "note" then
                local note, velocity, duration = ...
                jam.noteout(note, velocity, duration)
            elseif type:match("^knob%d$") then
                local knob_type, value = ...
                jam.msgout("knobs", knob_type, value)
            end
        end
    })
    
    presets = Presets.new("presets")
    
    -- Scan patterns folder
    scanPatterns()
    
    displayKnobs()
    ogui:led(OGUI.LED_OFF)
end

function tick(jam)
    seq:tick()
    
    -- Tick pattern if loaded
    if pattern_subjam and pattern_subjam.tick then
        pattern_subjam.tick()
    end
end

-- Scan patterns folder for jam files
function scanPatterns()
    pattern_files = {}
    local handle = io.popen("ls -1 patterns/*.lua 2>/dev/null | sort")
    if handle then
        for line in handle:lines() do
            table.insert(pattern_files, line)
        end
        handle:close()
    end
    print("Found " .. #pattern_files .. " patterns")
end

function patternSelect(i)
    if i < 1 or i > #pattern_files then
        print("Pattern " .. i .. " out of range")
        displayModal("No pattern")
        return
    end
    
    local filepath = pattern_files[i]
    print("Loading pattern: " .. filepath)
    
    -- Load pattern as SubJam with output routed to sequencer
    pattern_subjam = SubJam.load(filepath, jam, function(type, ...)
        if type == "note" then
            local note, velocity, duration = ...
            -- Send to sequencer for recording
            seq:recordNote(note, velocity, duration)
            -- And send to actual output
            jam.noteout(note, velocity, duration)
        end
    end)
    
    -- Extract just the filename for display
    local filename = filepath:match("([^/]+)%.lua$") or tostring(i)
    displayModalTwoLines("Pattern", filename)
end

-- Display all knob values on OLED
function displayKnobs()
    for i = 1, 4 do
        local cfg = knob_configs[i]
        local display_val = cfg[2](knob_values[i])
        ogui:setLine(i, string.format("%d: %s: " .. cfg[1], i, cfg[3], display_val))
    end
end

-- Display aux function menu (2 functions per line)
function displayAuxMenu()
    for line = 1, 5 do
        local left_label = aux_labels[line]
        if line == 1 then
            left_label = seq:isPlaying() and "Stop" or "Play"
        end
        ogui:setLine(line, string.format("%-8s | %-8s", left_label, aux_labels[line + 5]))
    end
end

-- Display modal dialog with box and large font
function displayModal(text)
    ogui:fillArea(10, 13, 108, 38, OGUI.COLOR_BLACK)
    ogui:box(10, 13, 108, 38, OGUI.COLOR_WHITE)
    ogui:println(20, 25, OGUI.SIZE_16, OGUI.COLOR_WHITE, text)
    ogui:flip()
end

-- Display two-line modal dialog with box and large font
function displayModalTwoLines(line1, line2)
    ogui:fillArea(10, 13, 108, 48, OGUI.COLOR_BLACK)
    ogui:box(10, 13, 108, 48, OGUI.COLOR_WHITE)
    ogui:println(20, 19, OGUI.SIZE_16, OGUI.COLOR_WHITE, line1)
    ogui:println(20, 40, OGUI.SIZE_16, OGUI.COLOR_WHITE, line2)
    ogui:flip()
end

-- Aux Functions Table
local auxFunctions = {
    -- Function 1: Start/Stop playback
    function()
        if seq:isPlaying() then
            seq:stop()
            ogui:led(OGUI.LED_OFF)
            displayModal("Stopped")
        elseif seq:isStopped() then 
            if seq:hasEvents() then
                seq:play()
                ogui:led(OGUI.LED_GREEN)
                displayModal("Playing")
            else
                displayModal("Empty")        
            end
        elseif seq:isArmed() then
            seq:stop()
            ogui:led(OGUI.LED_OFF)
            displayModal("Stopped")
        end
    end,
    
    -- Function 2: Arm recording
    function()
        if seq:isStopped() or seq:isPlaying() then
            seq:stop()
            seq:arm()
            ogui:led(OGUI.LED_PURPLE)
            displayModal("Armed")
        elseif seq:isArmed() then
            seq:stop()
            ogui:led(OGUI.LED_OFF)
            displayModal("Stopped")
        end
    end,
    
    -- Function 3: Previous preset
    function()
        local settings = presets:prev()
        if settings then
            applyPreset(settings)
            if seq:hasEvents() then
                seq:play()
                ogui:led(OGUI.LED_GREEN)
            end
            displayModalTwoLines("Preset", presets:getDisplayString())
        else 
            displayModal("No preset")
        end
    end,
    
    -- Function 4: Save preset
    function()
        if seq:isRecording() then
            displayModal("Stop recording first")
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
            displayModalTwoLines("Save", presets:getDisplayString())
        end
    end,
    
    -- Function 5: Next preset
    function()
        local settings = presets:next()
        if settings then
            applyPreset(settings)
            if seq:hasEvents() then
                seq:play()
                ogui:led(OGUI.LED_GREEN)
            end
            displayModalTwoLines("Preset", presets:getDisplayString())
        else 
            displayModal("No preset")
        end
    end,
    
    -- Function 6: Transpose down by octave
    function()
        transpose = math.max(-24, transpose - 12)
        displayModalTwoLines("Octave", string.format("%+d", transpose / 12))
    end,
    
    -- Function 7: Transpose up by octave
    function()
        transpose = math.min(24, transpose + 12)
        displayModalTwoLines("Octave", string.format("%+d", transpose / 12))
    end,
    
    -- Function 8: Latch toggle
    function() 
        latch:toggle()
        if latch.enabled then 
            displayModalTwoLines("Latch", "On")      
        else 
            displayModalTwoLines("Latch", "Off")  
        end
    end,
    
    -- Function 9: Placeholder
    function() end,
    
    -- Function 10: Delete preset (requires two taps)
    function()
        if presets.current_index == 0 or presets:count() == 0 then
            displayModal("No preset")
            return
        end
        
        if not delete_armed then
            delete_armed = true
            displayModalTwoLines("Delete ", presets:getDisplayString() .. "?")
        else
            if presets:delete() then
                delete_armed = false
                displayModalTwoLines("Deleted", " ")
                local settings = presets:load(presets.current_index)
                if settings then
                    applyPreset(settings)
                end
            end
        end
    end
}

-- Helper to apply loaded preset
function applyPreset(settings)
    if seq:isPlaying() then
        seq:stop()
        ogui:led(OGUI.LED_OFF)
    end
    
    for i = 1, 4 do
        knob_values[i] = settings["knob" .. i] or 0
        jam.msgout("knobs", "knob" .. i, knob_values[i])
    end
    
    if settings.sequence then 
        seq:deserialize(settings.sequence)
    end
end

-- Input handlers
function notein(jam, n, v)
    notes_held = notes_held + (v > 0 and 1 or -1)
    notes_held = math.max(0, notes_held)
    
    local transposed_note = n + transpose
    
    if aux_pressed then
        if v > 0 then
            for i, key in ipairs(aux_keys) do
                if n == key then
                    if i ~= 10 then
                        delete_armed = false
                    end
                    auxFunctions[i]()
                    return
                end
            end
            for i, key in ipairs(pattern_select_keys) do
                if n == key then
                    patternSelect(i)
                    return
                end
            end
        end
    else
        if seq:isArmed() and v > 0 then
            seq:startRecording()
            ogui:led(OGUI.LED_RED)
        end
        latch:notein(transposed_note, v)
    end
end

-- Aux button handler
function aux(jam, v)
    if v == 1 then
        if seq:isRecording() then
            seq:endRecording()
            seq:play()
            ogui:led(OGUI.LED_GREEN)
            return
        end
        
        if notes_held == 0 then
            aux_pressed = true
            ogui:clear()
            displayAuxMenu()
        end
    else
        if aux_pressed then
            aux_pressed = false
            delete_armed = false
            ogui:clear()
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
        ogui:setLine(knob_num, string.format("%d: %s: " .. cfg[1], knob_num, cfg[3], display_val))
    end
    
    jam.msgout("knobs", "knob" .. knob_num, v)
    
    if seq:isArmed() then
        seq:startRecording()
        ogui:led(OGUI.LED_RED)
    end
    seq:recordKnob(knob_num, v)
end

-- Knob handlers
function knob1(jam, v) handleKnob(jam, 1, v) end
function knob2(jam, v) handleKnob(jam, 2, v) end
function knob3(jam, v) handleKnob(jam, 3, v) end
function knob4(jam, v) handleKnob(jam, 4, v) end