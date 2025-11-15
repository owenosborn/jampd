
require("lib/utils")
require("lib/chord")
require("lib/progression")

function init(jam)
  print("hi")
  print(jam.tc)
  print(jam.bpm)
  print(jam.tpb)
  count = Counter.new(40)
  prog = Progression.new("A-9.......B-7b5...E7b9...")
  chord = prog:chord()
  prog:print()
end

function tick(jam)
   
    chord = prog:tick(jam)
    if prog:isnew() then
        chord:print()
    end
    if jam.every(1) and p(.9) then chord:voice():playv(jam, 80, 1.1) end
    --if jam.every(1, 2/3) and p(.1) then chord:voice():playv(jam, 80, 1.1) end

    if jam.every(1/4) and p(.7)  then 
        note = chord:note(randi(1, #chord.tones), 4)
        jam.noteout(note, 80, 1/4) 
        note = chord:filter(count:tick() + 50)
        jam.noteout(note, 80, 1/4) 
    end
    --if jam.every(choose({1/4, 1/8, 1/16}), .54 / 4) and p(.9)  then jam.noteout(randi(60, 80), 80, 1/4) end

end

