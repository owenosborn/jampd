
local jam = {}


function jam:init(io)
    self.count = 0
end


function jam:tick(io)
    if io.on(1/4) then
        self.count = self.count + 3
        self.count = self.count % 28
        io.noteout(60 + self.count, 100, .1)
    end
end

return jam
