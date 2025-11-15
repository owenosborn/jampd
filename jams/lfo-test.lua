
require ("lib/lfo")

function init(jam)
    lfo = LFO.new(21, {rate = 20})
    lfo:print()
end

function tick(jam)

    if jam.every(1) then 
        jam.noteout(60, 100, .1)
    end

    lfo:tick(jam)
end
