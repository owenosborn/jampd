local jam = {}

function jam:init(io)
    -- A minor scale (relative to root note)
    self.scale = {0, 2, 3, 5, 7, 8, 10}  -- A, B, C, D, E, F, G
    self.root = 57  -- A3 as root note
    
    -- Bass settings
    self.bass_octave_range = {-12, 0}  -- 1-2 octaves below root
    self.bass_rate = 2  -- trigger every 2 beats
    self.bass_duration = 2  -- 2 beats long
    
    -- Melody settings  
    self.melody_octave_range = {12, 24}  -- 1-2 octaves above root
    self.melody_rate = 0.25  -- trigger every quarter beat
    self.melody_duration = 0.25  -- sixteenth note
    
    print("Scale jam initialized - A minor")
    print("Bass: long notes every " .. self.bass_rate .. " beats")
    print("Melody: short notes every " .. self.melody_rate .. " beats")
end

-- Get a random note from the scale at a given octave range
function jam:random_note(octave_min, octave_max)
    -- Pick random scale degree
    local degree = self.scale[math.random(#self.scale)]
    -- Pick random octave offset
    local octave_offset = math.random(octave_min, octave_max)
    return self.root + degree + octave_offset
end

function jam:tick(io)
    -- Play bass notes
    if io.on(self.bass_rate) then
        local note = self:random_note(self.bass_octave_range[1], self.bass_octave_range[2])
        local velocity = math.random(60, 90)  -- quieter, more consistent
        io.noteout(note, velocity, self.bass_duration)
    end
    
    -- Play melody notes
    if io.on(self.melody_rate) then
        local note = self:random_note(self.melody_octave_range[1], self.melody_octave_range[2])
        local velocity = math.random(70, 110)  -- more varied dynamics
        io.noteout(note - 12, velocity, self.melody_duration)
    end
end

return jam
