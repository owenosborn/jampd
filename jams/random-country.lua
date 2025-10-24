local jam = {}

function jam:init(io)
    local Progression = require("lib/progression").Progression
    
    self.progression = Progression.new()
    self.progression:parse("G...E-...A7...B7.D7.")
    
    -- Country/bluegrass scale
    self.scale = {0, 2, 4, 7, 9}  -- G major pentatonic: G, A, B, D, E
    self.root = 55  -- G3
    
    print("Country jam loaded - G major")
end

-- Get a random note from the pentatonic scale
function jam:random_melody_note()
    local degree = self.scale[math.random(#self.scale)]
    local octave_offset = math.random(0, 12)  -- within an octave
    return self.root + degree + octave_offset + 12  -- up an octave for melody
end

function jam:tick(io)
    local current_chord = self.progression:tick(io)
    -- Alternating bass pattern (classic country style)
    -- Root on odd beats, fifth on even beats
    if io.on(2) then
        local bass_note = current_chord:note(1, 3)
        io.noteout(bass_note, 90, 0.9)
    end

    if io.on(2,1) then
        local bass_note = current_chord:note(3, 3)
        io.noteout(bass_note - 12, 90, 0.9)
    end

    -- Chord hits on strong beats
    if io.on(2, 1.05) then  -- every 2 beats
        io.noteout(current_chord:note(1, 4), 70, 0.4)
        io.noteout(current_chord:note(2, 4), 70, 0.4)
        io.noteout(current_chord:note(3, 4), 70, 0.4)
    end
    
    -- Simple melody fills on off-beats
    if io.on(0.5, 0.25) then  -- syncopated eighth notes
        if math.random() < 0.3 then  -- sparse, not every time
            local note = self:random_melody_note()
            io.noteout(note, math.random(60, 85), 0.4)
        end
    end
end

return jam
