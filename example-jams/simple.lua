-- simple.lua
-- The simplest possible jam: a counter that plays notes every sixteenth.
-- Demonstrates jam.every() and jam.noteout() with basic state.

function init(jam)
    count = 0
end

function tick(jam)
    if jam.every(1/4) then
        count = count + 3
        count = count % 28
        jam.noteout(60 + count, 100, .1)
    end
end
