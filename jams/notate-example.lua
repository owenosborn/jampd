
require("lib/chord")
require("lib/notate")

function init(jam)
    notate = Notate.new(jam, "/Users/owen/Desktop/my_song.ly")
    print("hi")
    chord = Chord.new("C-7")
    chord:print()
    divs = {1/2, 1/4, 1/8, 1}
    divi = 1
    ci = 1
end

function tick(jam)
    if jam.every(1/4) then jam.noteout(chord:note(1, 5), 100, .2) end
    if jam.every(3/4) then jam.noteout(chord:note(2, 5), 100, .2) end
    if jam.every(5/4) then jam.noteout(chord:note(3, 5), 100, .2) end
    if jam.every(7/4) then jam.noteout(chord:note(4, 5), 100, .2) end

    if jam.once(32) then
        notate:finish()  -- Write the .ly file
        notate:restore()  -- Optional: restore original noteout
    end

end
