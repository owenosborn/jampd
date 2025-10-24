-- lib/arpeggio.lua
-- Arpeggio utility for generating note sequences from chords
-- Supports up, down, updown, downup, and random patterns
-- Can span multiple octaves and control note timing
-- Example: arp = Arpeggio.new(chord, "updown", 2); arp:tick(io)

local Arpeggio = {}
Arpeggio.__index = Arpeggio

-- Create new arpeggio from chord
function Arpeggio.new(chord, pattern, octaves, octave_base)
    local self = setmetatable({}, Arpeggio)
    
    self.chord = chord or require("lib/chord").Chord.new():parse("Cmaj7")
    self.pattern = pattern or "up"  -- up, down, updown, downup, random
    self.octaves = octaves or 1     -- how many octaves to span
    self.octave_base = octave_base or 5  -- starting octave
    
    self.notes = {}                 -- generated note sequence
    self.index = 1                  -- current position in sequence
    self.active = false             -- whether arpeggio is playing
    self.note_duration = 90         -- default note duration in ticks
    self.velocity = 80              -- default velocity
    self.step_interval = 45         -- ticks between notes
    self.start_tick = 0             -- global tick when arpeggio started
    
    self:_generate_sequence()
    return self
end

-- Generate note sequence based on pattern and octaves
function Arpeggio:_generate_sequence()
    self.notes = {}
    local chord_size = #self.chord.pitches
    
    if self.pattern == "up" then
        -- Ascending through octaves
        for oct = 0, self.octaves - 1 do
            for i = 1, chord_size do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        
    elseif self.pattern == "down" then
        -- Descending from highest octave
        for oct = self.octaves - 1, 0, -1 do
            for i = chord_size, 1, -1 do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        
    elseif self.pattern == "updown" then
        -- Up then down
        for oct = 0, self.octaves - 1 do
            for i = 1, chord_size do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        -- Skip the top note to avoid duplication, then go down
        for oct = self.octaves - 1, 0, -1 do
            for i = chord_size - 1, 1, -1 do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        
    elseif self.pattern == "downup" then
        -- Down then up
        for oct = self.octaves - 1, 0, -1 do
            for i = chord_size, 1, -1 do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        -- Skip the bottom note to avoid duplication, then go up
        for oct = 0, self.octaves - 1 do
            for i = 2, chord_size do
                table.insert(self.notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        
    elseif self.pattern == "random" then
        -- Random order within octave range
        local all_notes = {}
        for oct = 0, self.octaves - 1 do
            for i = 1, chord_size do
                table.insert(all_notes, self.chord:note(i, self.octave_base + oct))
            end
        end
        -- Shuffle the notes
        for i = #all_notes, 2, -1 do
            local j = math.random(i)
            all_notes[i], all_notes[j] = all_notes[j], all_notes[i]
        end
        self.notes = all_notes
    end
end

-- Start playing the arpeggio
function Arpeggio:play(velocity, note_duration, step_interval, io)
    self.velocity = velocity or self.velocity
    self.note_duration = note_duration or self.note_duration
    self.step_interval = step_interval or self.step_interval
    
    self.active = true
    self.index = 1
    self.start_tick = io.tc  -- Sync to global tick count
    return self
end

-- Stop the arpeggio
function Arpeggio:stop()
    self.active = false
    return self
end

-- Set arpeggio timing parameters
function Arpeggio:setTiming(step_interval, note_duration)
    self.step_interval = step_interval or self.step_interval
    self.note_duration = note_duration or self.note_duration
    return self
end

-- Change pattern and regenerate sequence
function Arpeggio:setPattern(pattern, octaves)
    self.pattern = pattern or self.pattern
    self.octaves = octaves or self.octaves
    self:_generate_sequence()
    if self.active then
        self.index = 1  -- Reset to start if currently playing
    end
    return self
end

-- Set the chord and regenerate sequence
function Arpeggio:setChord(chord)
    self.chord = chord
    self:_generate_sequence()
    if self.active then
        self.index = 1  -- Reset to start if currently playing
    end
    return self
end

-- Call every tick to handle arpeggio playback
function Arpeggio:tick(io)
    if not self.active or #self.notes == 0 then
        return
    end
    
    -- Calculate which note should be playing based on global tick count
    local ticks_since_start = io.tc - self.start_tick
    local note_position = math.floor(ticks_since_start / self.step_interval)
    local expected_index = (note_position % #self.notes) + 1
    
    -- Check if we should play a note on this exact tick
    if ticks_since_start % self.step_interval == 0 and ticks_since_start >= 0 then
        local note = self.notes[expected_index]
        io.playNote(note, self.velocity, self.note_duration)
    end
    
    -- Update current index for reference
    self.index = expected_index
end

-- Get current note without playing
function Arpeggio:currentNote()
    if #self.notes == 0 then return nil end
    return self.notes[self.index]
end

-- Get the full note sequence
function Arpeggio:getSequence()
    return self.notes
end

-- Print arpeggio information
function Arpeggio:print(print_callback)
    print_callback = print_callback or print
    print_callback("Arpeggio:")
    local separator = string.rep("-", 50)
    print_callback(separator)
    print_callback(string.format("Chord: %s", self.chord.name or "Unknown"))
    print_callback(string.format("Pattern: %s", self.pattern))
    print_callback(string.format("Octaves: %d (base: %d)", self.octaves, self.octave_base))
    print_callback(string.format("Notes in sequence: %d", #self.notes))
    print_callback(string.format("Active: %s, Index: %d", tostring(self.active), self.index))
    print_callback("Sequence: " .. table.concat(self.notes, ", "))
    print_callback(separator)
end

return {
    Arpeggio = Arpeggio
}