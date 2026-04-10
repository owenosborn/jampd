-- passthrough.lua
-- Pass incoming notes straight to the output.
-- The simplest use of notein.

function notein(jam, note, velocity)
    jam.noteout(note, velocity)
end
