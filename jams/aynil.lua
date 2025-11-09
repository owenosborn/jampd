
require("lib/chord")
require("lib/progression")
    
 
function init(jam)
    print("hi")
    progression = Progression.new()
    progression:parse("Fmaj7...F+7...Bbmaj7.Bo7.A-7.Abo7.G-7.C7.A-7b5.D7.G-7.C7.F6...")
    progression:print()
    count = 0
end

function tick(jam)
    
    chord = progression:tick(jam)
   
    if jam.on(1/1) then
        jam.noteout(chord:note(1, 3), 100, 1)
        count = 0
    end

    if jam.on(1/6) then 
        note = chord:note(count % #chord.tones + 1, count // #chord.tones)
    end

end
