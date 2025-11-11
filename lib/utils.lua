-- lib/utils.lua
-- Common utility functions for jam scripts

-- Probability test: returns true with given probability (0-1)
-- prob(0.5) -> 50% chance of true
-- prob(0.3) -> 30% chance of true
function prob(p)
    return math.random() < p
end

-- Alias for prob() if you prefer shorter syntax
p = prob

-- Random integer in range [min, max] inclusive
-- randi() -> 0 or 1
-- randi(n) -> 0 to n
-- randi(min, max) -> min to max
function randi(min, max)
    if min == nil then
        return math.random(0, 1)
    elseif max == nil then
        return math.random(0, min)
    else
        return math.random(min, max)
    end
end

-- Random float in range [min, max]
-- randf() -> 0.0 to 1.0
-- randf(n) -> 0.0 to n
-- randf(min, max) -> min to max
function randf(min, max)
    if min == nil then
        return math.random()
    elseif max == nil then
        return math.random() * min
    else
        return min + math.random() * (max - min)
    end
end

-- Clamp value between min and max
function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Linear interpolation between a and b by amount t (0-1)
function lerp(a, b, t)
    return a + (b - a) * t
end

-- Map value from one range to another
function map(value, in_min, in_max, out_min, out_max)
    return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min)
end

-- Wrap value to range [min, max)
function wrap(value, min, max)
    local range = max - min
    return min + ((value - min) % range)
end

-- Choose random element from array
function choose(t)
    return t[math.random(1, #t)]
end

-- Weighted random choice
-- weights should be array of numbers, returns corresponding index
function weighted_choose(weights)
    local total = 0
    for _, w in ipairs(weights) do
        total = total + w
    end
    
    local r = math.random() * total
    local sum = 0
    for i, w in ipairs(weights) do
        sum = sum + w
        if r <= sum then
            return i
        end
    end
    return #weights
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
    return self.count
end

function Counter:reset()
    self.count = 0
end

return {
    prob = prob,
    p = p,
    randi = randi,
    randf = randf,
    clamp = clamp,
    lerp = lerp,
    map = map,
    wrap = wrap,
    choose = choose,
    weighted_choose = weighted_choose,
    Counter = Counter
}
