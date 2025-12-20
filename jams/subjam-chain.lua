-- pipeline-example.lua
-- Pipeline: chord-gen → arp → MIDI output

local SubJam = require("lib/subjam")

function init(jam)
    local info = debug.getinfo(1, "S")
    local my_dir = info.source:match("^@(.*/)")
    
    -- Load arp first (outputs to real jam.noteout)
    arp = SubJam.load(my_dir .. "jams/arp.lua", jam)
    
    -- Load chord-gen with output routed to arp's notein
    chord_gen = SubJam.load(
        my_dir .. "jams/chord-gen.lua",
        jam,
        function(type, ...)
            if type == "note" then
                local note, velocity, duration = ...
                -- Route chord notes into arp as note events
                if arp.notein then
                    arp.notein(note, velocity)
                    --jam.noteout(note, velocity, duration)
                end
            end
        end
    )
    
    print("Pipeline loaded: chord-gen → arp → output")
    print("chord-gen generates chords")
    print("arp arpeggiates them")
    print("output goes to MIDI")
end

function tick(jam)
    -- Tick chord generator first (generates notes)
    chord_gen.tick()
    
    -- Then tick arp (arpeggiates the held notes)
    arp.tick()
end
