-- polyrhythm.lua
-- Four voices of a chord, each on a different prime-ratio interval.
-- The voices cycle in and out of alignment, creating a shifting
-- polyrhythmic texture from a single chord.

require("lib/chord")

function init(jam)
    chord = Chord.new("C-7")
    chord:print()
end

function tick(jam)
    if jam.every(1/4) then jam.noteout(chord:note(1, 5), 100, .2) end
    if jam.every(3/4) then jam.noteout(chord:note(2, 5), 100, .2) end
    if jam.every(5/4) then jam.noteout(chord:note(3, 5), 100, .2) end
    if jam.every(7/4) then jam.noteout(chord:note(4, 5), 100, .2) end
end
