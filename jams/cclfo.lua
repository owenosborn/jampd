
function init(io)
    -- LFO rates in beats per cycle
    rate1 = 160    -- CC 21: 160 beats per cycle
    rate2 = 140    -- CC 22: 140 beats per cycle
    rate3 = 120    -- CC 23: 120 beats per cycle
    
    print("LFO jam initialized")
    print("CC 21: " .. rate1 .. " beats/cycle")
    print("CC 22: " .. rate2 .. " beats/cycle")
    print("CC 23: " .. rate3 .. " beats/cycle")
end

function tick(io)
    -- Calculate current position in beats
    local beats = jam.tc / jam.tpb
    
    -- Calculate LFO values using sine wave (oscillating 0-127)
    -- sin gives -1 to 1, so we scale to 0-127
    local lfo1 = math.floor((math.sin(2 * math.pi * beats / rate1) + 1) / 2 * 127)
    local lfo2 = math.floor((math.sin(2 * math.pi * beats / rate2) + 1) / 2 * 127)
    local lfo3 = math.floor((math.sin(2 * math.pi * beats / rate3) + 1) / 2 * 127)
    
    -- Send out CC messages x times per beat to avoid overwhelming MIDI
    if jam.on(.1) then
        jam.cltout(21, lfo1)
        jam.cltout(22, lfo2)
        jam.cltout(23, lfo3)
    end
end

