-- melody.lua
-- A simple looping melody, one note per beat.

function init(jam)
    melody = {60, 62, 64, 65, 67, 65, 64, 62}
    idx = 1
end

function tick(jam)
    if jam.every(1) then
        jam.noteout(melody[idx], 100, 3/4)
        idx = (idx % #melody) + 1
    end
end
