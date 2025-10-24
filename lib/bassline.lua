-- lib/bassline.lua
local Bassline = {}
Bassline.__index = Bassline

-- helpers
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function vhuman(base, spread) return clamp(math.floor(base + (math.random() * 2 - 1) * spread), 1, 127) end
local function dhuman(ticks, pct) return math.max(1, math.floor(ticks * (1 - (math.random() * 2 - 1) * pct))) end

-- Resolve a chord's root at a given octave (default 3)
local function chord_root_midi(ch, oct)
    oct = oct or 3
    return ch:note(1, oct)
end

-- Fifth above root (stays in same octave unless force_up)
local function chord_fifth_midi(ch, oct, force_up)
    local r = chord_root_midi(ch, oct)
    local fifth = r + 7
    if not force_up and fifth - r > 7 then fifth = fifth - 12 end
    return fifth
end

-- Simple chromatic approach to target (one semitone away, from above or below)
local function approach(target, prefer_below)
    if prefer_below then return target - 1 else return target + 1 end
end

function Bassline.new(opts)
    opts = opts or {}
    local self = setmetatable({}, Bassline)
    self.style      = "pulse"
    self.octave     = opts.octave or 3
    self.channel    = opts.channel or 1
    self.vel        = opts.velocity or 80
    self.vel_jitter = opts.vel_jitter or 8
    self.gate       = opts.gate or 0.8         -- fraction of note length
    self.humanize   = opts.humanize or 0.05    -- timing variation on duration
    self.rate       = opts.rate or 1           -- beats between notes (1 = quarter notes)
    self.sync_prob  = opts.sync_prob or 0.5    -- used by sync pattern
    self.walk_prob  = opts.walk_prob or 0.6    -- used by walk pattern
    self.current_chord = nil
    self.next_root_fn  = nil -- optional function returning MIDI root of next chord (same octave as current)
    return self
end

function Bassline:setStyle(style, cfg)
    self.style = style or self.style
    if cfg then
        for k,v in pairs(cfg) do self[k] = v end
    end
    return self
end

-- Called by the Jam when progression advances
function Bassline:update_chord(ch)
    self.current_chord = ch
end

-- Optional: give the bassline a way to peek the next chord root (closure)
function Bassline:setNextRootFn(fn)
    self.next_root_fn = fn
end

-- Decide the next bass note based on style
function Bassline:choose_note(io, pos_in_bar)
    local ch = self.current_chord
    if not ch then return nil end

    local root = chord_root_midi(ch, self.octave)

    if self.style == "pulse" then
        -- Root every beat; jump an octave on 1 & 3 to add motion
        if pos_in_bar % 2 == 1 then
            return root + 12
        else
            return root
        end

    elseif self.style == "octave" then
        -- Alternate root and octave every note
        if (pos_in_bar % 2) == 0 then return root else return root + 12 end

    elseif self.style == "sync" then
        -- Root on 1, syncopate with fifths/approaches on the off-beats
        if pos_in_bar == 0 then
            return root
        elseif math.random() < self.sync_prob then
            if math.random() < 0.5 then
                return chord_fifth_midi(ch, self.octave, true)
            else
                local tgt = (self.next_root_fn and self.next_root_fn()) or root
                return approach(tgt, math.random() < 0.5)
            end
        else
            return nil -- rest
        end

    elseif self.style == "walk" then
        -- Basic walking idea: hit root on 1, then move by chord tones or half-steps toward next root
        if pos_in_bar == 0 then
            return root
        else
            if math.random() < self.walk_prob then
                -- chord tone movement: root -> fifth -> third -> root (wrap)
                local cycle = { root, chord_fifth_midi(ch, self.octave), ch:note(2, self.octave), root }
                return cycle[(pos_in_bar % #cycle) + 1]
            else
                -- chromatic toward next
                local next_root = (self.next_root_fn and self.next_root_fn()) or root
                if next_root > root then
                    return root + (pos_in_bar % 4) -- step up
                else
                    return root - (pos_in_bar % 4) -- step down
                end
            end
        end
    end

    -- Fallback
    return root
end

-- Call every tick
function Bassline:tick(io)
    if not self.current_chord then return end

    -- Fire on the grid based on self.rate (beats between notes)
    if io.on(self.rate) then
        -- position within a 4-beat bar (just for pattern logic)
        local pos_in_bar = (io.beat_count % 4)
        local note = self:choose_note(io, pos_in_bar)
        if note then
            local base_ticks = io.dur(self.rate)
            local dur_ticks  = dhuman(math.floor(base_ticks * self.gate), self.humanize)
            local vel        = vhuman(self.vel, self.vel_jitter)
            io.playNote(note, vel, dur_ticks, self.channel)
        end
    end
end

return Bassline
