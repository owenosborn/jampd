-- lfo.lua
-- Send a sine-wave LFO as a message.
-- Demonstrates jam.msgout() for non-note output.

function tick(jam)
    local beats = jam.tc / jam.tpb
    local lfo = math.floor((math.sin(2 * math.pi * beats / 8) + 1) / 2 * 127)

    if jam.every(1/8) then
        jam.msgout("cc", 21, lfo)
    end
end
