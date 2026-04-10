-- one-note.lua
-- The simplest possible jam: play one note at the start.

function init(jam)
    jam.noteout(60, 100, 1)  -- C4, one beat long
end
