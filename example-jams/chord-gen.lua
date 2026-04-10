-- chord-gen.lua
-- Generates chord tones from a progression, one chord per beat.
-- Used by subjam-pipeline.lua as a note source — its output gets
-- routed into an arpeggiator or other processor.

require("lib/chord")
require("lib/progression")

function init(jam)
    progression = Progression.new("C.F.G.C.")
    previous_notes = {}
end

function tick(jam)
    local chord = progression:tick(jam)

    if jam.every(1) then
        -- Note-offs for previous chord
        for _, note in ipairs(previous_notes) do
            jam.noteout(note, 0)
        end

        -- Build and play new chord
        local new_notes = {}
        for i = 1, #chord.tones do
            local note = chord:note(i, 4)
            table.insert(new_notes, note)
            jam.noteout(note, 100)
        end

        previous_notes = new_notes
    end
end
