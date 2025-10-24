local jam = {}

function jam:init(io)
    -- LFO rates in beats per cycle
    self.rate1 = 16    -- CC 21: 16 beats per cycle
    self.rate2 = 14    -- CC 22: 14 beats per cycle
    self.rate3 = 12    -- CC 23: 12 beats per cycle
    
    print("LFO jam initialized")
    print("CC 21: " .. self.rate1 .. " beats/cycle")
    print("CC 22: " .. self.rate2 .. " beats/cycle")
    print("CC 23: " .. self.rate3 .. " beats/cycle")
end

function jam:tick(io)
    -- Calculate current position in beats
    local beats = io.tc / io.tpb
    
    -- Calculate LFO values using sine wave (oscillating 0-127)
    -- sin gives -1 to 1, so we scale to 0-127
    local lfo1 = math.floor((math.sin(2 * math.pi * beats / self.rate1) + 1) / 2 * 127)
    local lfo2 = math.floor((math.sin(2 * math.pi * beats / self.rate2) + 1) / 2 * 127)
    local lfo3 = math.floor((math.sin(2 * math.pi * beats / self.rate3) + 1) / 2 * 127)
    
    -- Send out CC messages 10 times per beat to avoid overwhelming MIDI
    if io.on(.05) then
        io.cltout(21, lfo1)
        io.cltout(22, lfo2)
        io.cltout(23, lfo3)
    end
end

return jam
