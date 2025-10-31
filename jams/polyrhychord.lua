
require("lib/chord")

function init(io)
    print("hi")
    chord = Chord.new("C-7")
    chord:print()
    divs = {1/2, 1/4, 1/8, 1}
    divi = 1
    ci = 1
end

function tick(io)
    if io.on(1/4) then io.noteout(chord:note(1, 5), 100, .2) end
    if io.on(3/4) then io.noteout(chord:note(2, 5), 100, .2) end
    if io.on(5/4) then io.noteout(chord:note(3, 5), 100, .2) end
    if io.on(7/4) then io.noteout(chord:note(4, 5), 100, .2) end
end
