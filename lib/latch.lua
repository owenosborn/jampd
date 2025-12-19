-- lib/latch.lua
-- Latch module for capturing and holding notes
-- When enabled: notes are latched (held) even after key release
-- When disabled: latched notes are released (note offs sent)

Latch = {}
Latch.__index = Latch

function Latch.new(callback)
    local self = setmetatable({}, Latch)
    self.enabled = false
    self.latched_notes = {}  -- {[note] = velocity} - notes that are latched/sounding
    self.held_notes = {}     -- {[note] = true} - notes physically being held down right now
    self.callback = callback or function() end
    return self
end

-- Enable latching
function Latch:enable()
    self.enabled = true
    return self
end

-- Disable latching and send note offs for all latched notes
function Latch:disable()
    if not self.enabled then return self end
    
    -- Send note offs for all latched notes
    for note, _ in pairs(self.latched_notes) do
        self.callback(note, 0)
    end
    
    self.latched_notes = {}
    self.held_notes = {}
    self.enabled = false
    return self
end

-- Toggle latch state
function Latch:toggle()
    if self.enabled then
        self:disable()
    else
        self:enable()
    end
    return self
end

-- Handle incoming note (note on/off from MIDI input)
function Latch:notein(note, velocity)
    if not self.enabled then
        -- Pass through when disabled
        self.callback(note, velocity)
        return
    end
    
    if velocity > 0 then
        -- Note on
        
        -- Check if any notes are currently being held down
        local any_held = false
        for _, _ in pairs(self.held_notes) do
            any_held = true
            break
        end
        
        -- If no notes held, flush all latched notes first
        if not any_held then
            for latched_note, _ in pairs(self.latched_notes) do
                self.callback(latched_note, 0)
            end
            self.latched_notes = {}
        end
        
        -- Add to held notes and latched notes
        self.held_notes[note] = true
        
        -- Only send note-on if not already latched (avoid duplicate note-ons)
        if not self.latched_notes[note] then
            self.callback(note, velocity)
        end
        
        self.latched_notes[note] = velocity
    else
        -- Note off - remove from held but keep in latched
        self.held_notes[note] = nil
        -- Don't send note off - note stays latched
    end
end

-- Clear all latched notes without sending note offs
-- (useful if you want to reset without sound)
function Latch:clear()
    self.latched_notes = {}
    self.held_notes = {}
    return self
end

-- Print current latch state
function Latch:print()
    print("Latch enabled:", self.enabled)
    print("Latched notes:", table.concat(self:get_notes(), ", "))
end

-- Get array of currently latched note numbers
function Latch:get_notes()
    local notes = {}
    for note, _ in pairs(self.latched_notes) do
        table.insert(notes, note)
    end
    table.sort(notes)
    return notes
end

return {
    Latch = Latch
}