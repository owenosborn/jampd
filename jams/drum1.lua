require ("lib/utils")
require ("lib/chord")
require("lib/progression")

function init(jam)
end

function ctlin(jam, n, v) 
    if n == 33 then 
        jam.noteout(v//1, 60, .1)
    end
end

function tick(jam)

    if jam.every(1, -.05) then jam.noteout(40, 90, 1/4) end
    if jam.every(choose({1, 1/2, 1/4})) and p(.5)  then jam.noteout(54, 90, 1/4) end
    if jam.every(1/4) and p(.9)  then jam.noteout(70, choose({30, 80}), 1/8) end

end

