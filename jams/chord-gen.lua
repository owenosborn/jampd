-- chord-gen.lua
-- Generates chord progressions and outputs individual notes

require("lib/chord")
require("lib/progression")

function init(jam)
    progression = Progression.new("C.F.G.C.")
    progression:print()
    previous_notes = {}  -- track previous chord notes
    print("Chord generator loaded")
end

function tick(jam)
    local chord = progression:tick(jam)
    
    -- Output chord notes every beat
    if jam.every(1) then
        -- First: send note-offs for previous chord
        for _, note in ipairs(previous_notes) do
            jam.noteout(note, 0)  -- velocity 0 = note off
        end
        
        -- Build new chord notes
        local new_notes = {}
        for i = 1, #chord.tones do
            local note = chord:note(i, 4)
            table.insert(new_notes, note)
        end
        
        -- Then: send note-ons for new chord
        for _, note in ipairs(new_notes) do
            jam.noteout(note, 100)  -- velocity > 0 = note on
        end
        
        -- Remember these notes for next time
        previous_notes = new_notes
    end
end
