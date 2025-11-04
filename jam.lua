
require("lib/chord")
require("lib/progression")
 
function init(jam)
    print("hi")
    progression = Progression.new()
    progression:parse("G-7.A7.D-9.Db7.")
    progression:print()
    chord = progression:chord()
    sweeplast = 0
    sweep = 0
    c = 0
    divs = {1/2, 1/4, 1/8, 1}
    divi = 1
end

function ctlin(jam, n, v) 
    if n == 33 then 
        sweep = chord:filter(v)
        jam.noteout(sweep, 60, .1)
    end
end

function tick(jam)
    
    chord = progression:tick(jam)
 
    if jam.on(1/2) then
        c = c + 1
        jam.noteout(chord:note(1, 3 + c % 2), 100, .1)
        divi = math.random(1, #divs)
    end

    -- if jam.on(divs[divi]) and math.random() > .33 then
    if jam.on(1/4) and math.random() > .33 then
        jam.noteout(chord:filter(math.random(40,90)), 100, .1)
    end 
end
