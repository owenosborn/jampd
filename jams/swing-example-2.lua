require ("lib/utils")
require ("lib/chord")
require("lib/progression")

function init(jam)
    progression = Progression.new("D9.......E-7.......C.D.F.A.")
    progression:print()    
    print("Country jam loaded")
    count = Counter.new(2)
end

function ctlin(jam, n, v) 
    if n == 33 then 
        jam.noteout(chord:filter(v), 60, .1)
    end
end

function tick(jam)

    chord = progression:tick(jam)
    
    if jam.every(1) then
        local bass_note = chord:note(1, count:tick() + 3 )
        jam.noteout(bass_note, 90, 0.9)
    end

    if jam.every(2, .98) then  
        chord:voice():playv(jam)
    end
 
    if jam.every(2, 1 + 2/3) and p(.5) then 
        chord:voice():playv(jam, 20, .1)
    end
       
    if (jam.every(1) or jam.every(1, 2/3)) and p(.7) then 
        local note = chord:filter(randi(50,80))
        jam.noteout(note, randi(60, 85), choose({1,1/8,1/6,1/4,1/2}))
    end

end

