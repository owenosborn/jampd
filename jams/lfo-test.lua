
require ("lib/lfo")

function init(io)
    lfo = LFO.new(21, {rate = 20})
    lfo:print()
end

function tick(io)

    if io.on(1) then 
        io.noteout(60, 100, .1)
    end

    lfo:tick(io)
end
