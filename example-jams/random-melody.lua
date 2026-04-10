-- random-melody.lua
-- Random notes from A minor scale with a slow bass and fast melody.
-- Demonstrates using jam.every() at different rates to create layers,
-- math.random for variation, and building a scale from intervals.

function init(jam)
    scale = {0, 2, 3, 5, 7, 8, 10}  -- natural minor intervals
    root = 57  -- A3
end

-- Pick a random note from the scale within an octave range
function random_note(octave_min, octave_max)
    local degree = scale[math.random(#scale)]
    local octave_offset = math.random(octave_min, octave_max)
    return root + degree + octave_offset
end

function tick(jam)
    -- Bass: long notes every 2 beats
    if jam.every(2) then
        local note = random_note(-12, 0)
        jam.noteout(note, math.random(60, 90), 2)
    end

    -- Melody: short notes every sixteenth
    if jam.every(1/4) then
        local note = random_note(0, 12)
        jam.noteout(note, math.random(70, 110), 1/4)
    end
end
