-- lib/sequencer.lua
local Sequencer = {}
Sequencer.__index = Sequencer

function Sequencer.new(config)
    local self = setmetatable({}, Sequencer)
    
    config = config or {}
    self.tpb = config.tpb or 180
    self.max_events = config.max_events or 1000
    self.output = config.output or function() end
    
    self.state = "STOPPED"
    self.events = {}
    self.recording_start_tick = 0
    self.playback_tick = 0
    self.loop_length = 0
    self.event_index = 1
    self.recording_held_notes = {}
    self.playback_held_notes = {}
    self.internal_tick = 0  -- Our own counter
    self.sync_pending = false  -- Waiting for beat boundary
    
    return self
end

-- State transitions
function Sequencer:arm()
    self:clear()
    self.state = "ARMED"
    return true
end

function Sequencer:startRecording()
    print("Recording started")
    self.state = "RECORDING"
    self.recording_start_tick = self.internal_tick
    self.events = {}
    self.recording_held_notes = {}
end

function Sequencer:endRecording()
    if self.state ~= "RECORDING" then return end
    
    local current_beat = (self.internal_tick - self.recording_start_tick) / self.tpb
    
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
    self.loop_length = math.floor(current_beat + 0.5)  -- Round to nearest integer beat
    if self.loop_length == 0 then self.loop_length = 1 end
    self:stop()
    self:printInfo()
end

function Sequencer:play()
    if #self.events == 0 then return false end
    self.state = "PLAYING"
    self.playback_tick = 0
    self.event_index = 1
    self.playback_held_notes = {}
    self.sync_pending = false
    return true
end

function Sequencer:playSync()
    if #self.events == 0 then return false end
    -- Mark that we're waiting for the next beat
    self.sync_pending = true
    return true
end

function Sequencer:stop()
    -- Send note-offs for any held notes
    for note, _ in pairs(self.playback_held_notes) do
        self.output("note", note, 0)
    end
    self.playback_held_notes = {}
    self.state = "STOPPED"
    self.sync_pending = false
end

function Sequencer:toggle()
    if self.state == "PLAYING" then
        self:stop()
    elseif self.state == "STOPPED" and #self.events > 0 then
        self:play()
    end
end

-- Core event recording with max check
function Sequencer:recordEvent(event)
    if self.state == "RECORDING" then
        -- Check limit before recording
        if #self.events >= self.max_events then
            print("Sequence reached (" .. self.max_events .. " events), not recording")
            return false
        end
        
        -- Add timestamp
        event.time = (self.internal_tick - self.recording_start_tick) / self.tpb
        table.insert(self.events, event)
        return true
    end
    
    return false
end

-- Record note
function Sequencer:recordNote(note, velocity, duration)
    local recorded = self:recordEvent({
        type = "note",
        note = note,
        velocity = velocity,
        duration = duration
    })
    
    if recorded and self.state == "RECORDING" then
        if velocity > 0 then
            self.recording_held_notes[note] = true
        else
            self.recording_held_notes[note] = nil
        end
    end
end

-- Record knob
function Sequencer:recordKnob(knob_num, value)
    self:recordEvent({
        type = "knob" .. knob_num,
        value = value
    })
end

-- Check if we're on a beat boundary
local function is_beat_boundary(tick, tpb)
    return tick % tpb == 0
end

-- Playback (call every tick)
function Sequencer:tick()
    -- Always increment internal tick
    self.internal_tick = self.internal_tick + 1
    
    -- If we're waiting to sync, check for beat boundary
    if self.sync_pending then
        if is_beat_boundary(self.internal_tick, self.tpb) then
            -- Start playing now!
            self.state = "PLAYING"
            self.playback_tick = 0
            self.event_index = 1
            self.playback_held_notes = {}
            self.sync_pending = false
        end
        return  -- Don't play anything yet
    end
    
    if self.state ~= "PLAYING" then return end
    
    local current_beat = self.playback_tick / self.tpb
    
    -- Play events at current beat
    while self.event_index <= #self.events do
        local event = self.events[self.event_index]
        
        if event.time <= current_beat then
            if event.type == "note" then
                self.output("note", event.note, event.velocity, event.duration)
                
                if event.velocity > 0 then
                    self.playback_held_notes[event.note] = true
                else
                    self.playback_held_notes[event.note] = nil
                end
            elseif event.type:match("^knob%d$") then
                self.output(event.type, event.type, event.value)
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

function Sequencer:isSyncing()
    return self.sync_pending
end

function Sequencer:hasEvents()
    return #self.events > 0
end

function Sequencer:getState()
    if self.sync_pending then
        return "SYNCING"
    end
    return self.state
end

function Sequencer:clear()
    self.events = {}
    self.loop_length = 0
end

-- Serialize sequence to saveable table
function Sequencer:serialize()
    if #self.events == 0 then
        return nil
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
    self.sync_pending = false
    
    print(string.format("Loaded sequence: %.2f beats, %d events", 
                        self.loop_length, #self.events))
end

-- Print sequencer stats
function Sequencer:printInfo(print_callback)
    print_callback = print_callback or print
    
    local separator = string.rep("-", 70)
    print_callback(separator)
    print_callback("SEQUENCER STATE: " .. self:getState())
    print_callback("Loop Length: " .. string.format("%.2f", self.loop_length) .. " beats")
    print_callback("Total Events: " .. #self.events)
    print_callback(separator)
end

-- Print sequencer state and events
function Sequencer:print(print_callback)
    print_callback = print_callback or print
    
    local separator = string.rep("-", 70)
    print_callback(separator)
    print_callback("SEQUENCER STATE: " .. self:getState())
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
        local current_beat = self.playback_tick / self.tpb
        print_callback(string.format("Playback Position: %.2f beats (Event Index: %d)", 
            current_beat, self.event_index))
        print_callback(separator)
    end
end

return {
    Sequencer = Sequencer
}