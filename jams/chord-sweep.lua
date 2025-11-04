
require("lib/chord")

function init(jam)
    print("hi")
    chord = Chord.new("C-7")
    chord:print()
    count = 0
end

function tick(jam)
    
    if jam.on(1/8) then 
        note = chord:note(count % #chord.tones + 1, count // #chord.tones)
        count = count + 1
        max = 8 * #chord.tones 
        if count > max then count = 0 end
        jam.noteout(note + 24, 100, .1)
    end

end
