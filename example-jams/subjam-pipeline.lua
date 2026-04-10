-- subjam-pipeline.lua
-- Chaining sub-jams together: a chord generator feeds into an arpeggiator.
-- Demonstrates routing one jam's note output into another jam's notein,
-- creating a processing pipeline.

local SubJam = require("lib/subjam")

function init(jam)
    local info = debug.getinfo(1, "S")
    local my_dir = info.source:match("^@(.*/)")

    -- Load arp first (its output goes to the real jam.noteout)
    arp = SubJam.load(my_dir .. "arp.lua", jam)

    -- Load chord generator with output routed into arp's notein
    chord_gen = SubJam.load(
        my_dir .. "chord-gen.lua",
        jam,
        function(type, ...)
            if type == "note" then
                local note, velocity, duration = ...
                if arp.notein then
                    arp.notein(note, velocity)
                end
            end
        end
    )
end

function tick(jam)
    -- Tick chord generator first (produces notes)
    chord_gen.tick()
    -- Then tick arp (arpeggiates the held notes)
    arp.tick()
end
