

require("lib/chord")

function init(jam)
    chord = Chord.new("C-7")
    chord:print()
    count = 0
end

function tick(jam)
    if jam.on(1/4) then
        count = count + 3
        count = count % 28
        jam.noteout(chord:note(count, 4), 100, .1)
    end
end

