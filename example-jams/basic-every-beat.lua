-- every-beat.lua
-- Play a note every beat. The most basic use of jam.every().

function tick(jam)
    if jam.every(1) then
        jam.noteout(60, 100, 1/2)
    end
end
