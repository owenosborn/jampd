
-- basic musical unit
Note = {}
Note.__index = Note

function Note.new(params)
    local self = setmetatable({}, Note)
    params = params or {}
    self.number = params.num or 60        -- MIDI note number
    self.velocity = params.vel or 100   -- MIDI velocity
    self.time = params.time or 0             -- time at which the note plays in ticks
    self.duration = params.dur or 180   -- note duration in ticks
    return self
end

-- collection of notes in time
Pattern = {}
Pattern.__index = Pattern
function Pattern.new()
    local self = setmetatable({}, Pattern)
    self.notes = {}               -- array of Note objects
    self.length = 0               -- total length in ticks
    self.playhead = 0             -- current position in ticks
    return self
end

Counter = {}
Counter.__index = Counter
function Counter.new(max)
    local self = setmetatable({}, Counter)
    self.max = max or 1
    self.count = 0
    return self
end

function Counter:tick()
    self.count = (self.count + 1) % self.max
    return self.count == 0  -- returns true on rollover
end


----------- a few useful methods


function Note:print()
    local formatStr = "%-11s | %-9s | %-6s | %-9s"
    local info = string.format(
        formatStr,
        tostring(self.number),
        tostring(self.velocity),
        tostring(self.time),
        tostring(self.duration)
    )
    print(info)
end

function Note:print_row(index)
    local formatStr = "%-7s | %-11s | %-9s | %-6s | %-9s"
    local info = string.format(
        formatStr,
        tostring(index),
        tostring(self.number),
        tostring(self.velocity),
        tostring(self.time),
        tostring(self.duration)
    )
    print(info)
end

function Note:play(io, c)
    local ch = c or self.channel or io.ch
    io.playNote(self.number, self.velocity, self.duration, ch)
end

return {
    Note = Note,
    Pattern = Pattern,
    Progression = Progression,
    Counter = Counter
}
