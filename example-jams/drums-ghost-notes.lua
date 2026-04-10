-- drums-ghost-notes.lua
-- A drum pattern with ghost notes on kick and snare.
-- Demonstrates using elseif chains so only one hit per instrument
-- per tick, and mixing steady patterns with probabilistic fills.

require("lib/utils")

function tick(jam)
    -- Hi-hats on sixteenths with accents on downbeats
    if jam.every(1/4) then
        local vel = jam.every(1) and 90 or 50
        jam.noteout(70, vel, 1/8)
    end

    -- Snare on 2 and 4, with ghost notes
    -- elseif ensures only one snare voice per tick
    if jam.every(2, 1) then
        jam.noteout(54, 85, 1/4)
    elseif jam.every(1/3) and p(.1) then
        jam.noteout(54, 50, 1/4)
    elseif jam.every(1/4) and p(.1) then
        jam.noteout(54, 50, 1/4)
    end

    -- Kick on 1 and 3, with ghost notes
    if jam.every(2) then
        jam.noteout(40, 90, 1/4)
    elseif jam.every(1/3) and p(.1) then
        jam.noteout(40, 50, 1/4)
    elseif jam.every(1/4) and p(.6) then
        jam.noteout(40, 50, 1/4)
    end
end
