-- lib/lfo.lua
-- Simple LFO (Low Frequency Oscillator) for sending MIDI CC messages
-- Supports sine, triangle, square, saw, and random waveforms
-- Example: lfo = LFO.new(21, {rate = 16, wave = "sine"}); lfo:tick(jam)

LFO = {}
LFO.__index = LFO

-- Waveform functions (all return -1 to 1)
local waveforms = {
    sine = function(phase)
        return math.sin(2 * math.pi * phase)
    end,
    
    triangle = function(phase)
        -- Triangle wave: rise from -1 to 1, then fall back to -1
        if phase < 0.5 then
            return -1 + (phase * 4)  -- Rising
        else
            return 3 - (phase * 4)   -- Falling
        end
    end,
    
    square = function(phase)
        return phase < 0.5 and 1 or -1
    end,
    
    saw = function(phase)
        -- Sawtooth: rise from -1 to 1, then jump back
        return -1 + (phase * 2)
    end,
    
    rsaw = function(phase)
        -- Reverse sawtooth: fall from 1 to -1, then jump back
        return 1 - (phase * 2)
    end,
    
    random = function(phase, last_value)
        -- Sample-and-hold random (changes at phase = 0)
        if not last_value or phase < 0.01 then
            return (math.random() * 2) - 1
        else
            return last_value
        end
    end
}

-- Create new LFO
function LFO.new(cc_number, config)
    local self = setmetatable({}, LFO)
    
    config = config or {}
    
    self.cc = cc_number or 1           -- MIDI CC number
    self.min = config.min or 0         -- Minimum CC value
    self.max = config.max or 127       -- Maximum CC value
    self.rate = config.rate or 16      -- Beats per cycle
    self.wave = config.wave or "sine"  -- Waveform type
    self.phase = config.phase or 0     -- Initial phase (0-1)
    self.channel = config.channel      -- MIDI channel (nil = use jam.ch)
    self.update_rate = config.update_rate or 0.1  -- Send CC every N beats (default 0.1)
    
    self.last_value = nil              -- For random waveform
    self.last_cc_value = nil           -- Track last sent value to avoid redundant sends
    
    -- Validate waveform
    if not waveforms[self.wave] then
        error("LFO: unknown waveform '" .. self.wave .. "'. Use: sine, triangle, square, saw, rsaw, random")
    end
    
    return self
end

-- Set waveform type
function LFO:setWave(wave)
    if not waveforms[wave] then
        error("LFO: unknown waveform '" .. wave .. "'. Use: sine, triangle, square, saw, rsaw, random")
    end
    self.wave = wave
    return self
end

-- Set rate in beats per cycle
function LFO:setRate(rate)
    self.rate = rate
    return self
end

-- Set min/max range
function LFO:setRange(min, max)
    self.min = min
    self.max = max
    return self
end

-- Set phase offset (0-1)
function LFO:setPhase(phase)
    self.phase = phase % 1
    return self
end

-- Get current LFO value (0-1 normalized)
function LFO:getValue(jam)
    local beats = jam.tc / jam.tpb
    local phase = ((beats / self.rate) + self.phase) % 1
    
    -- Get raw waveform value (-1 to 1)
    local wave_func = waveforms[self.wave]
    local raw_value = wave_func(phase, self.last_value)
    
    -- Store for random waveform
    if self.wave == "random" then
        self.last_value = raw_value
    end
    
    -- Normalize to 0-1
    return (raw_value + 1) / 2
end

-- Get current LFO value scaled to min/max range
function LFO:getScaled(jam)
    local normalized = self:getValue(jam)
    return self.min + (normalized * (self.max - self.min))
end

-- Call every tick to send CC messages
function LFO:tick(jam)
    -- Only send at update_rate intervals to avoid MIDI spam
    if jam.every(self.update_rate) then
        local value = math.floor(self:getScaled(jam) + 0.5)  -- Round to nearest int
        
        -- Only send if value changed
        if value ~= self.last_cc_value then
            if self.channel then
                -- Use specified channel (need to temporarily override jam.ch)
                local old_ch = jam.ch
                jam.ch = self.channel
                jam.cltout(self.cc, value)
                jam.ch = old_ch
            else
                -- Use current jam.ch
                jam.cltout(self.cc, value)
            end
            
            self.last_cc_value = value
        end
    end
end

-- Print LFO information
function LFO:print(print_callback)
    print_callback = print_callback or print
    print_callback("LFO:")
    print_callback(string.format("  CC: %d", self.cc))
    print_callback(string.format("  Range: %d - %d", self.min, self.max))
    print_callback(string.format("  Rate: %.2f beats/cycle", self.rate))
    print_callback(string.format("  Wave: %s", self.wave))
    print_callback(string.format("  Phase: %.2f", self.phase))
    print_callback(string.format("  Update Rate: %.2f beats", self.update_rate))
end

return {
    LFO = LFO
}
