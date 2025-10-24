-- lib/chord_player.lua

-- ChordPlayer utility for playing chords with different articulations
-- Supports block, roll, strum, random, and pattern playing styles
-- Call tick() every tick and play() to trigger chord with current style
-- Example: player:setStyle("roll", {delay = 5}) then player:play()

local ChordPlayer = {}
ChordPlayer.__index = ChordPlayer

function ChordPlayer.new(chord, octave)
    local self = setmetatable({}, ChordPlayer)
    
    -- Create default C major chord if none provided
    if chord == nil then
        local default_chord = require("lib/chord").Chord.new()
        default_chord:parse("Cmaj7")
        self.chord = default_chord
    else
        self.chord = chord
    end
    
    self.octave = octave or 5
    self.style = "block"  -- default style
    self.config = {}
    self.pending_notes = {}  -- {tick_offset, note, velocity, duration}
    self.trigger_tick = -1   -- when play() was called
    return self
end

-- Set playing style and configuration
function ChordPlayer:setStyle(style, config)
    self.style = style
    self.config = config or {}
    return self
end

-- Trigger chord to be played with current style
function ChordPlayer:play(velocity, duration)
    velocity = velocity or 80
    duration = duration or 180
    
    self.pending_notes = {}
    self.trigger_tick = 0  -- relative to current tick
    
    if self.style == "block" then
        -- All notes at once
        for i = 1, #self.chord.pitches do
            table.insert(self.pending_notes, {0, self.chord:note(i, self.octave), velocity, duration})
        end
        
    elseif self.style == "roll" then
        -- Sequential with delay
        local delay = self.config.delay or 3
        for i = 1, #self.chord.pitches do
            local offset = (i - 1) * delay
            table.insert(self.pending_notes, {offset, self.chord:note(i, self.octave), velocity, duration})
        end
        
    elseif self.style == "strum" then
        -- Like roll but reverse order option
        local delay = self.config.delay or 2
        local reverse = self.config.reverse or false
        local indices = {}
        for i = 1, #self.chord.pitches do
            indices[i] = reverse and (#self.chord.pitches - i + 1) or i
        end
        for i, idx in ipairs(indices) do
            local offset = (i - 1) * delay
            table.insert(self.pending_notes, {offset, self.chord:note(idx, self.octave), velocity, duration})
        end
        
    elseif self.style == "random" then
        -- Random timing within window
        local window = self.config.window or 10
        for i = 1, #self.chord.pitches do
            local offset = math.random(0, window)
            table.insert(self.pending_notes, {offset, self.chord:note(i, self.octave), velocity, duration})
        end
        
    elseif self.style == "pattern" then
        -- Custom pattern from config
        local pattern = self.config.pattern or {0, 3, 6, 9}
        for i = 1, math.min(#self.chord.pitches, #pattern) do
            table.insert(self.pending_notes, {pattern[i], self.chord:note(i, self.octave), velocity, duration})
        end
    end
end

-- Call every tick to handle scheduled notes
function ChordPlayer:tick(io)
    if self.trigger_tick >= 0 then
        -- Check for notes to play this tick
        local current_offset = self.trigger_tick
        
        for i = #self.pending_notes, 1, -1 do
            local note_data = self.pending_notes[i]
            if note_data[1] == current_offset then
                io.playNote(note_data[2], note_data[3], note_data[4])
                table.remove(self.pending_notes, i)
            end
        end
        
        self.trigger_tick = self.trigger_tick + 1
        
        -- Clean up when all notes played
        if #self.pending_notes == 0 then
            self.trigger_tick = -1
        end
    end
end

return ChordPlayer
