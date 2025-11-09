
require("lib/chord")
require("lib/progression")
 
function init(jam)
    print("hi")
    progression = Progression.new()
    --progression:parse("Fmaj7...F+7...Bbmaj7.Bo7.A-7.Abo7.G-7.C7.A-7b5.D7.G-7.C7.F6...")
    progression:parse("C-7...Dbmaj7...")
    --progression:parse("Ebo7...D-7...F#-7b5.B7,b9.D-7...")
    progression:print()
    chord = progression:chord()
    c = 0
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
        jam.noteout(chord:note(1, 3 + c % 2), 100, 1/3)
    end

    if jam.on(1/2) and math.random() > .1 then
        jam.noteout(chord:filter(math.random(40,90)), 100, .4)
    end 

    if jam.on(1/2, .6/2) and math.random() > .33 then
        jam.noteout(chord:filter(math.random(40,90)), 100, .4)
    end 

end
