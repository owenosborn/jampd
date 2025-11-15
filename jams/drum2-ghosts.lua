require ("lib/utils")
require ("lib/chord")
require("lib/progression")

function init(jam)
    cflag = false
    cval = 0
end

function ctlin(jam, n, v)
    if n == 33 then
        cval = v//1
        cflag = true
    end
end

function tick(jam)
    -- Hi-hats on sixteenths with accents
    if jam.every(1/4) then 
        local vel = jam.every(1) and 90 or 50  -- accent on downbeats
        jam.noteout(70, vel, 1/8)
    end
    
    if cflag and jam.every(1/8) then
        cflag = false
        jam.noteout(cval, 80, 1/8)
    end

    -- Simple backbeat - snare on 2 and 4 with ghost notes 
    -- use elseif so we don't play more than one note the same tick
    if jam.every(2, 1)  then jam.noteout(54, 85, 1/4) 
    
    -- ghost notes
    elseif jam.every(1/3)  and p(.1)  then jam.noteout(54, 50, 1/4) 
    elseif jam.every(1/4)  and p(.1)  then jam.noteout(54, 50, 1/4) end
    
    -- Kick on 1 and 3
    if jam.every(2) then jam.noteout(40, 90, 1/4)
    
    -- ghost notes
    elseif  jam.every(1/3)  and p(.1)  then jam.noteout(40, 50, 1/4) 
    elseif  jam.every(1/4)  and p(.6)  then jam.noteout(40, 50, 1/4) end
end
