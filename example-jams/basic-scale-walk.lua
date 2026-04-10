-- scale-walk.lua
-- Walk up a minor scale in eighth notes, looping.

function init(jam)
    scale = {0, 2, 3, 5, 7, 8, 10}
    step = 1
end

function tick(jam)
    if jam.every(1/2) then
        jam.noteout(60 + scale[step], 90, 1/4)
        step = (step % #scale) + 1
    end
end
