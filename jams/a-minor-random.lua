
function init(jam)
    -- A minor scale (relative to root note)
    scale = {0, 2, 3, 5, 7, 8, 10}  -- A, B, C, D, E, F, G
    root = 57  -- A3 as root note
    
    -- Bass settings
    bass_octave_range = {-12, 0}  -- 1-2 octaves below root
    bass_rate = 2  -- trigger every 2 beats
    bass_duration = 2  -- 2 beats long
    
    -- Melody settings  
    melody_octave_range = {12, 24}  -- 1-2 octaves above root
    melody_rate = 0.25  -- trigger every quarter beat
    melody_duration = 0.25  -- sixteenth note
    
    print("Scale jam initialized - A minor")
    print("Bass: long notes every " .. bass_rate .. " beats")
    print("Melody: short notes every " .. melody_rate .. " beats")
end

-- Get a random note from the scale at a given octave range
function random_note(octave_min, octave_max)
    -- Pick random scale degree
    local degree = scale[math.random(#scale)]
    -- Pick random octave offset
    local octave_offset = math.random(octave_min, octave_max)
    return root + degree + octave_offset
end

function tick(jam)
    -- Play bass notes
    if jam.every(bass_rate) then
        local note = random_note(bass_octave_range[1], bass_octave_range[2])
        local velocity = math.random(60, 90)  -- quieter, more consistent
        jam.noteout(note, velocity, bass_duration)
    end
    
    -- Play melody notes
    if jam.every(melody_rate) then
        local note = random_note(melody_octave_range[1], melody_octave_range[2])
        local velocity = math.random(70, 110)  -- more varied dynamics
        jam.noteout(note - 12, velocity, melody_duration)
    end
end

