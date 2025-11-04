
require("lib/chord")

function init(jam)
    print("hi")
    chord = Chord.new("C-7")
    chord:print()
    divs = {1/2, 1/4, 1/8, 1}
    divi = 1
    ci = 1
end

function tick(jam)

    if jam.on(1) then 
        divi = math.random(1, #divs)
        ci = math.random(1, #chord.tones)
    end

    if jam.on (divs[divi]) then
        jam.noteout(chord:note(ci, 4), 100, 1/4)
    end

end
