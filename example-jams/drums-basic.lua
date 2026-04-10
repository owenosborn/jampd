-- drums-basic.lua
-- A simple drum pattern using probability for variation.
-- Demonstrates jam.every() for different rhythmic layers and the
-- p() utility for probabilistic note triggering.

require("lib/utils")

function tick(jam)
    -- Kick on every beat, slightly early for a pushed feel
    if jam.every(1, -.05) then
        jam.noteout(40, 90, 1/4)
    end

    -- Snare: randomly picks between quarter, eighth, or sixteenth grid
    if jam.every(choose({1, 1/2, 1/4})) and p(.5) then
        jam.noteout(54, 90, 1/4)
    end

    -- Hi-hat on sixteenths, mostly hits
    if jam.every(1/4) and p(.9) then
        jam.noteout(70, choose({30, 80}), 1/8)
    end
end
