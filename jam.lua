require ("lib/utils")


function init(jam)
    local Progression = require("lib/progression").Progression
    
    progression = Progression.new()
    --progression:parse("Fmaj7...F+7...Bbmaj7.Bo7.A-7.Abo7.G-7.C7.A-7b5.D7.G-7.C7.F6...")
    progression:parse("G.....E-.....")
    progression:print()    
    print("Country jam loaded")
end

function ctlin(jam, n, v) 
    if n == 33 then 
        jam.noteout(chord:filter(v), 60, .1)
    end
end

function tick(jam)
    chord = progression:tick(jam)
    
    if jam.on(1) then
        local bass_note = chord:note(1, 4)
        jam.noteout(bass_note, 90, 0.9)
    end

    -- Chord hits on strong beats, play it a little early
    if jam.on(3, 0) then  -- every 2 beats
        chord:play(jam)
    end
    
    -- swing stuff
    if (jam.on(1) or jam.on(1, 2/3)) and p(.7) then 
        local note = chord:filter(randi(50,80))
        jam.noteout(note, randi(60, 85), 0.4)
    end

end

