
require("lib/chord")
require("lib/progression")

 
function init(io)
    print("hi")
    progression = Progression.new()
    --progression:parse("G.A.D.D7.")
    progression:parse("G-7.A7.D-9.Db7.")
    progression:print()
    chord = progression:current()
    count = 0
end

function ctlin(io, n, v) 
    if n == 33 then 
        io.noteout(chord:filter(v), 60, .1)
    end
end

function tick(io)
    
    chord = progression:tick(io)
   
    if io.on(1/1) then
        io.noteout(chord:note(1, 3), 100, 1)
        count = 0
    end

    if io.on(1/6) then 
        note = chord:note(count % #chord.tones + 1, count // #chord.tones)
        count = count + 1
        max = 4 * #chord.tones 
        if count > max then count = 0 end
        --io.noteout(note + 60, 50, .1)
    end

    if io.on(1/8) and math.random() > .2 then
        rando = chord:filter(math.random(20,100)) 
        io.noteout(rando, 60, .1)
    end 

end
