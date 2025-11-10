require ("lib/utils")
require("lib/progression")


function init(jam)
    
    progression = Progression.new()
    --progression:parse("Fmaj7...F+7...Bbmaj7.Bo7.A-7.Abo7.G-7.C7.A-7b5.D7.G-7.C7.F6...")
    progression:parse("G.....E-.....G.....Em......C.....D.....G.....D.....G.....C..D..E-.....C.....D.....B7.....E-...........C...........E-...........G.....D.....G..D..")
    progression:print()    
    chord = progression:chord()
    print("Country jam loaded")
    count = 0
end

function ctlin(jam, n, v) 
    if n == 33 then 
        jam.noteout(chord:filter(v), 60, .1)
    end
end

function tick(jam)
    chord = progression:tick(jam)
    
    if jam.on(1) then
        local bass_note = chord:note(1, randi(3,4))
        count = count+1
        jam.noteout(bass_note, 90, 0.9)
    end

    if jam.on(3, 0) then  -- every 2 beats
        chord:play(jam)
    end
    
    if (jam.on(1) or jam.on(1, 2/3)) and p(.7) then 
        local note = chord:filter(randi(50,80))
        --jam.noteout(note, randi(60, 85), 0.4)
    end

    if jam.on(1/3) then 
        
    end

end

