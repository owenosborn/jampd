

require("lib/chord")
require ("lib/lfo")

function init(io)
    chord = Chord.new("C-7")
    chord:print()
    lfo = LFO.new(21, {rate = 20})
    count = 0
end

function tick(io)
    if io.on(1/4) then
        count = count + 3
        count = count % 28
        io.noteout(chord:note(count, 4), 100, .1)
    end
    lfo:tick(io)
end

