-- lib/sequencer.lua
local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new(max_events)
    local self = setmetatable({}, Sequencer)
    
    self.state = "STOPPED"
    self.events = {}
    self.recording_start_tick = 0
    self.playback_tick = 0
    self.loop_length = 0
    self.event_index = 1
    self.recording_held_notes = {}
    self.playback_held_notes = {}
    self.max_events = max_events or 5000  -- Default limit
    
    return self
end


-- State transitions
function Sequencer:arm()
    self:clear()
    self.state = "ARMED"
    return true
end

function Sequencer:startRecording(jam)
    print("Recording started")
    self.state = "RECORDING"
    self.recording_start_tick = jam.tc
    self.events = {}
    self.recording_held_notes = {}
end

function Sequencer:endRecording(jam)
    if self.state ~= "RECORDING" then return end
    
    local current_beat = (jam.tc - self.recording_start_tick) / jam.tpb
    
    -- Add note-offs for held notes
    for note, _ in pairs(self.recording_held_notes) do
        table.insert(self.events, {
            time = current_beat,
            type = "note",
            note = note,
            velocity = 0
        })
    end
    
    self.recording_held_notes = {}
    self.loop_length = current_beat
    self:stop()
    self:printInfo()
end

function Sequencer:play()
    if #self.events == 0 then return false end
    self.state = "PLAYING"
    self.playback_tick = 0
    self.event_index = 1
    self.playback_held_notes = {}
    return true
end

function Sequencer:stop(jam)
    -- Send note-offs for any held notes
    for note, _ in pairs(self.playback_held_notes) do
        jam.noteout(note, 0)
    end
    self.playback_held_notes = {}
    self.state = "STOPPED"
end

function Sequencer:toggle(jam)
    if self.state == "PLAYING" then
        self:stop(jam)
    elseif self.state == "STOPPED" and #self.events > 0 then
        self:play()
    end
end

-- Recording
-- Core event recording with max check
function Sequencer:recordEvent(jam, event)
    
    if self.state == "RECORDING" then
        -- Check limit before recording
        if #self.events >= self.max_events then
            print("Sequence reached (" .. self.max_events .. " events), not recording")
            return false
        end
        
        -- Add timestamp
        event.time = (jam.tc - self.recording_start_tick) / jam.tpb
        table.insert(self.events, event)
        return true
    end
    
    return false
end

-- Record note (uses recordEvent)
function Sequencer:recordNote(jam, note, velocity)
    local recorded = self:recordEvent(jam, {
        type = "note",
        note = note,
        velocity = velocity
    })
    
    if recorded and self.state == "RECORDING" then
        if velocity > 0 then
            self.recording_held_notes[note] = true
        else
            self.recording_held_notes[note] = nil
        end
    end
end

-- Record knob (uses recordEvent)
function Sequencer:recordKnob(jam, knob_num, value)
    self:recordEvent(jam, {
        type = "knob" .. knob_num,
        value = value
    })
end

-- Playback (call every tick)
function Sequencer:tick(jam)
    if self.state ~= "PLAYING" then return end
    
    local current_beat = self.playback_tick / jam.tpb
    
    -- Play events at current beat
    while self.event_index <= #self.events do
        local event = self.events[self.event_index]
        
        if event.time <= current_beat then
            if event.type == "note" then
                jam.noteout(event.note, event.velocity)
                
                if event.velocity > 0 then
                    self.playback_held_notes[event.note] = true
                else
                    self.playback_held_notes[event.note] = nil
                end
            elseif event.type:match("^knob%d$") then
                -- Send knob event through msgout
                jam.msgout("knobs", event.type, event.value)
            end
            self.event_index = self.event_index + 1
        else
            break
        end
    end
    
    self.playback_tick = self.playback_tick + 1
    
    -- Loop
    if current_beat >= self.loop_length then
        self.playback_tick = 0
        self.event_index = 1
    end
end

-- State queries
function Sequencer:isRecording()
    return self.state == "RECORDING"
end

function Sequencer:isPlaying()
    return self.state == "PLAYING"
end

function Sequencer:isArmed()
    return self.state == "ARMED"
end

function Sequencer:isStopped()
    return self.state == "STOPPED"
end

function Sequencer:hasEvents()
    return #self.events > 0
end

function Sequencer:getState()
    return self.state
end

function Sequencer:clear()
    self.events = {}
    self.loop_length = 0
end

-- Add this to lib/sequencer.lua

-- Convert MIDI note number to note name
local function midi_to_note_name(midi_num)
    local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local pc = midi_num % 12
    local octave = math.floor(midi_num / 12) - 1
    return notes[pc + 1] .. octave
end

-- Serialize sequence to saveable table
function Sequencer:serialize()
    if #self.events == 0 then
        return nil  -- Don't save empty sequence
    end
    
    return {
        events = self.events,
        loop_length = self.loop_length
    }
end

-- Load sequence from saved data
function Sequencer:deserialize(data)
    if not data then 
        self:clear()
        return 
    end
    
    self.events = data.events or {}
    self.loop_length = data.loop_length or 0
    self.playback_tick = 0
    self.event_index = 1
    self.state = "STOPPED"
    
    print(string.format("Loaded sequence: %.2f beats, %d events", 
                        self.loop_length, #self.events))
end

-- Print sequencer stats
function Sequencer:printInfo(print_callback)
    print_callback = print_callback or print
    
    local separator = string.rep("-", 70)
    print_callback(separator)
    print_callback("SEQUENCER STATE: " .. self.state)
    print_callback("Loop Length: " .. string.format("%.2f", self.loop_length) .. " beats")
    print_callback("Total Events: " .. #self.events)
    print_callback(separator)
end

-- Print sequencer state and events
function Sequencer:print(print_callback)
    print_callback = print_callback or print
    
    local separator = string.rep("-", 70)
    print_callback(separator)
    print_callback("SEQUENCER STATE: " .. self.state)
    print_callback("Loop Length: " .. string.format("%.2f", self.loop_length) .. " beats")
    print_callback("Total Events: " .. #self.events)
    print_callback(separator)
    
    if #self.events == 0 then
        print_callback("No events recorded")
        print_callback(separator)
        return
    end
    
    local headerFormat = "%-5s | %-8s | %-10s | %s"
    print_callback(string.format(headerFormat, "Index", "Time", "Type", "Data"))
    print_callback(separator)
    
    for idx, event in ipairs(self.events) do
        -- Collect all data fields (everything except time and type)
        local data_parts = {}
        for k, v in pairs(event) do
            if k ~= "time" and k ~= "type" then
                table.insert(data_parts, k .. "=" .. tostring(v))
            end
        end
        local data_str = table.concat(data_parts, ", ")
        
        local formatStr = "%-5s | %-8s | %-10s | %s"
        local info = string.format(
            formatStr,
            tostring(idx),
            string.format("%.3f", event.time),
            event.type or "?",
            data_str
        )
        print_callback(info)
    end
    
    print_callback(separator)
    
    if self.state == "PLAYING" then
        local current_beat = self.playback_tick / 180
        print_callback(string.format("Playback Position: %.2f beats (Event Index: %d)", 
            current_beat, self.event_index))
        print_callback(separator)
    end
end

return {
    Sequencer = Sequencer
}