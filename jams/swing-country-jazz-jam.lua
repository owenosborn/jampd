
function init(jam)
    local Progression = require("lib/progression").Progression
    
    progression = Progression.new()
    progression:parse("Fmaj7...F+7...Bbmaj7.Bo7.A-7.Abo7.G-7.C7.A-7b5.D7.G-7.C7.F6...")
    progression:print()    
    print("Country jam loaded - F major")
end

function tick(jam)
    local chord = progression:tick(jam)
    -- Alternating bass pattern (classic country style)
    -- Root on odd beats, fifth on even beats
    if jam.on(2) then
        local bass_note = chord:note(1, 4)
        jam.noteout(bass_note, 90, 0.9)
    end

    if jam.on(2,1) then
        local bass_note = chord:note(3, 4)
        jam.noteout(bass_note - 12, 90, 0.9)
    end

    -- Chord hits on strong beats
    if jam.on(2, .95) then  -- every 2 beats
        jam.noteout(chord:note(1, 5), 70, 0.4)
        jam.noteout(chord:note(2, 5), 70, 0.4)
        jam.noteout(chord:note(3, 5), 70, 0.4)
        jam.noteout(chord:note(4, 5), 70, 0.4)
    end
    
    -- Simple melody fills on off-beats
    --if jam.on(1, 2/3) then  -- swing 8
    if jam.on(0.5, 1/3) then 
        if math.random() > 0.3 then  -- sparse, not every time
            local note = chord:filter(math.random(50,80))
            jam.noteout(note, math.random(60, 85), 0.4)
        end
    end

    if jam.on(1/3, .04) and math.random() > .6 then
        local note = chord:filter(math.random(80,100))
        jam.noteout(note, math.random(60, 80), 0.5)
    end
end

