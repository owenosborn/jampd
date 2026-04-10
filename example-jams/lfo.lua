-- lfo.lua
-- Three sine-wave LFOs sent as MIDI CC messages.
-- Demonstrates jam.msgout() for non-note output — controlling
-- synth parameters, effects, etc. Each LFO runs at a different
-- rate so they slowly drift in and out of alignment.

function init(jam)
    -- LFO rates in beats per cycle
    rate1 = 160  -- CC 21
    rate2 = 140  -- CC 22
    rate3 = 120  -- CC 23
end

function tick(jam)
    local beats = jam.tc / jam.tpb

    -- Sine LFOs scaled to 0-127
    local lfo1 = math.floor((math.sin(2 * math.pi * beats / rate1) + 1) / 2 * 127)
    local lfo2 = math.floor((math.sin(2 * math.pi * beats / rate2) + 1) / 2 * 127)
    local lfo3 = math.floor((math.sin(2 * math.pi * beats / rate3) + 1) / 2 * 127)

    -- Send CC messages a few times per beat
    if jam.every(1/10) then
        jam.msgout("cc", 21, lfo1)
        jam.msgout("cc", 22, lfo2)
        jam.msgout("cc", 23, lfo3)
    end
end
