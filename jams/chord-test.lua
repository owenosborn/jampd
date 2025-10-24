
local jam = {}

require("lib/chord")

function jam:init(io)
    self.chord = Chord.new("C-7")
    self.chord:print()
    self.count = 0
end

function jam:tick(io)
    if io.on(1/4) then
        self.count = self.count + 3
        self.count = self.count % 28
        io.noteout(self.chord:note(self.count, 4), 100, .1)
    end
end

return jam
