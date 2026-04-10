-- accelerando.lua
-- A note that accelerates from once per beat to a buzz over 16 beats.
-- Demonstrates tick-level timing control outside of jam.every(),
-- using an exponential curve for a natural speed-up feel.

require("lib/chord")

function init(jam)
    div = jam.tpb
end

function tick(jam)
    local beat = jam.tc / jam.tpb
    local duration = 16

    -- Progress from 0 to 1 over the duration
    local progress = math.min(beat / duration, 1)
    -- Exponential curve: starts slow, speeds up naturally
    local rate = 1 * math.pow(1/8, progress)

    div = div - 1
    if div <= 0 then
        div = (jam.tpb * rate) // 1
        jam.noteout(60, 100, 0.1)
    end
end
