
require("lib/chord")
require("lib/progression")
 
function init(jam)
    print("hi")
    progression = Progression.new()
    progression:parse("G-7.A7.D-9.Db7.")
    progression:print()
    chord = progression:chord()
    c = 0
    div = 1/4
end

function ctlin(jam, n, v) 
    if n == 33 then 
        sweep = chord:filter(v)
        jam.noteout(sweep, 60, .1)
    end
end

function tick(jam)
    
    chord = progression:tick(jam)
 
    if jam.on(1/2) then
        c = c + 1
        jam.noteout(chord:note(1, 3 + c % 2), 100, .1)
    end

    if jam.on(div) and math.random() > .33 then
        if math.random() > .5 then div = 1/8 else div = 1/4 end
        jam.noteout(chord:filter(math.random(40,90)), 100, .1)
    end 
end
