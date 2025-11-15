
require("lib/chord")
require("lib/progression")

 
function init(jam)
    print("hi")
    progression = Progression.new()
    --progression:parse("G.A.D.D7.")
    progression:parse("Bb...F7...Bbmaj7...Bb6.F7.D-7...G9...C-7...F7...G-7...C9...C-7...C#o7...D-7...G7...")
    progression:print()
    chord = progression:chord()
    count = 0
end

function ctlin(jam, n, v) 
    if n == 33 then 
        jam.noteout(chord:filter(v), 60, .1)
    end
end

function tick(jam)
    
    chord = progression:tick(jam)
    
    if progression:isnew() then
        chord:print()
    end
    
    if jam.every(1/1) then
        jam.noteout(chord:note(1, 3), 100, 1)
        count = 0
    end

    if jam.every(1/6) then 
        note = chord:note(count % #chord.tones + 1, count // #chord.tones)
        count = count + 1
        max = 4 * #chord.tones 
        if count > max then count = 0 end
        --jam.noteout(note + 60, 50, .1)
    end

    if jam.every(1/8) and math.random() > .2 then
        rando = chord:filter(math.random(20,100)) 
        jam.noteout(rando, 60, .1)
    end 

end
