
require("lib/chord")
require("lib/progression")
    
 
function init(io)
    print("hi")
    progression = Progression.new()
    progression:parse("G.A.D.D7.")
    progression:print()
    count = 0
end

function tick(io)
    
    chord = progression:tick(io)
   
    if jam.on(1/1) then
        jam.noteout(chord:note(1, 3), 100, 1)
        count = 0
    end

    if jam.on(1/6) then 
        note = chord:note(count % #chord.tones + 1, count // #chord.tones)
        count = count + 1
        max = 4 * #chord.tones 
        if count > max then count = 0 end
        jam.noteout(note + 60, 50, .1)
    end

end
