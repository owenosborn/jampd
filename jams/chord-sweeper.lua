
require("lib/chord")
require("lib/progression")
 
function init(io)
    print("hi")
    progression = Progression.new()
    progression:parse("G-7.A7.D-9.Db7.")
    progression:print()
    chord = progression:chord()
    sweeplast = 0
    sweep = 0
end

function ctlin(io, n, v) 
    if n == 33 then 
        sweep = chord:filter(v)
    end
end

function tick(io)
    
    chord = progression:tick(io)
   
    if io.on(1/1) then
        io.noteout(chord:note(1, 3), 100, 1)
    end

    if io.on(1/8) and math.random() > 0 then
        if sweep ~= sweeplast then
            io.noteout(sweep, 60, .1)
            sweeplast = sweep
        end
    end 

end
