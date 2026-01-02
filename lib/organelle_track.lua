-- lib/organelle_track.lua
-- note flow: notein -> latch -> subjam arp -> sequencer -> output
local Sequencer = require("lib/sequencer").Sequencer
local Latch = require("lib/latch").Latch
local Presets = require("lib/presets").Presets
local SubJam = require("lib/subjam")

local Track = {}
Track.__index = Track

function Track.new(jam, track_id, output_callback)
    local self = setmetatable({}, Track)
    
    self.jam = jam
    self.track_id = track_id
    self.output = output_callback or function() end
    self.transpose = 0
    self.knob_values = {0, 0, 0, 0}
    self.pattern_files = {}
    self.current_pattern_index = 0
    
    -- Sequencer outputs through our callback
    self.seq = Sequencer.new({
        tpb = jam.tpb,
        max_events = 1000,
        output = function(type, ...)
            self.output(type, ...)
        end
    })
    
    -- Latch routes to pattern
    self.latch = Latch.new(function(note, velocity)
        if self.pattern and self.pattern.notein then
            self.pattern.notein(note, velocity)
        end
        -- always pass note offs thru to output 
        if velocity == 0 then self.output("note", note, velocity) end
    end)
    
    -- Track-specific preset storage
    self.presets = Presets.new("presets/track" .. track_id)
    
    self.pattern = nil
    
    -- Scan patterns
    self:scanPatterns()
    
    return self
end

function Track:tick()
    self.seq:tick()
    if self.pattern and self.pattern.tick then
        self.pattern.tick()
    end
end

function Track:notein(note, velocity)
    local transposed = note + self.transpose
    
    -- Route to latch (which routes to pattern)
    self.latch:notein(transposed, velocity)
end

function Track:setKnob(knob_num, value)
    self.knob_values[knob_num] = value
    
    -- Output knob change
    self.output("knob" .. knob_num, "knob" .. knob_num, value)
    
    -- Start recording if armed
    if self.seq:isArmed() then
        self.seq:startRecording()
    end
    
    -- Record to sequencer
    self.seq:recordKnob(knob_num, value)
end

function Track:getKnob(knob_num)
    return self.knob_values[knob_num]
end

function Track:transposeUp()
    self.transpose = math.min(24, self.transpose + 12)
    return self.transpose / 12  -- return octaves
end

function Track:transposeDown()
    self.transpose = math.max(-24, self.transpose - 12)
    return self.transpose / 12  -- return octaves
end

function Track:getTranspose()
    return self.transpose / 12  -- return octaves
end

function Track:toggleLatch()
    self.latch:toggle()
    return self.latch.enabled
end

function Track:isLatchEnabled()
    return self.latch.enabled
end

-- Sequencer controls
function Track:togglePlayback()
    if self.seq:isPlaying() then
        self.seq:stop()
        return "stopped"
    elseif self.seq:isStopped() then
        if self.seq:hasEvents() then
            self.seq:playSync()
            return "playing"
        else
            return "empty"
        end
    elseif self.seq:isArmed() then
        self.seq:stop()
        return "stopped"
    end
end

function Track:startPlayback()
    self.seq:stop()
    if self.seq:hasEvents() then
        self.seq:playSync()
        return "playing"
    else
        return "empty"
    end
end

function Track:stopPlayback()
    self.seq:stop()
    return "stopped"
end

function Track:toggleArm()
    if self.seq:isStopped() or self.seq:isPlaying() then
        self.seq:stop()
        self.seq:arm()
        return "armed"
    elseif self.seq:isArmed() then
        self.seq:stop()
        return "stopped"
    end
end

function Track:endRecording()
    if self.seq:isRecording() then
        self.seq:endRecording()
        self.seq:playSync()
        return "playing"
    end
end

function Track:getSeqState()
    return self.seq:getState()
end

function Track:hasEvents()
    return self.seq:hasEvents()
end

-- Pattern management
function Track:scanPatterns()
    self.pattern_files = {}
    local handle = io.popen("ls -1 patterns/*.lua 2>/dev/null | sort")
    if handle then
        for line in handle:lines() do
            table.insert(self.pattern_files, line)
        end
        handle:close()
    end
end

function Track:loadPattern(index)
    if index < 1 or index > #self.pattern_files then
        return nil
    end
    
    local filepath = self.pattern_files[index]
    
    -- Load pattern as SubJam with output routed through our callback
    self.pattern = SubJam.load(filepath, self.jam, function(type, ...)
        if type == "note" then
            local note, velocity, duration = ...
            -- Start recording if armed
            if self.seq:isArmed() and velocity > 0 then
                self.seq:startRecording()
            end
            -- Record to sequencer
            self.seq:recordNote(note, velocity, duration)
            -- Output
            self.output("note", note, velocity, duration)
        end
    end)
    
    self.current_pattern_index = index
    
    -- Extract filename for display
    return filepath:match("([^/]+)%.lua$") or tostring(index)
end

function Track:getPatternCount()
    return #self.pattern_files
end

-- Preset management
function Track:savePreset()
    local settings = {
        knob1 = self.knob_values[1],
        knob2 = self.knob_values[2],
        knob3 = self.knob_values[3],
        knob4 = self.knob_values[4],
        sequence = self.seq:hasEvents() and self.seq:serialize() or nil
    }
    
    return self.presets:save(settings)
end

function Track:loadPreset(settings)
    if self.seq:isPlaying() then
        self.seq:stop()
    end
    
    for i = 1, 4 do
        self.knob_values[i] = settings["knob" .. i] or 0
        self.output("knob" .. i, "knob" .. i, self.knob_values[i])
    end
    
    if settings.sequence then
        self.seq:deserialize(settings.sequence)
    end
end

function Track:nextPreset()
    local settings = self.presets:next()
    if settings then
        self:loadPreset(settings)
        return self.presets:getDisplayString()
    end
    return nil
end

function Track:prevPreset()
    local settings = self.presets:prev()
    if settings then
        self:loadPreset(settings)
        return self.presets:getDisplayString()
    end
    return nil
end

function Track:deletePreset()
    return self.presets:delete()
end

function Track:getPresetDisplay()
    return self.presets:getDisplayString()
end

function Track:getPresetCount()
    return self.presets:count()
end

function Track:getCurrentPresetIndex()
    return self.presets.current_index
end

return { Track = Track }