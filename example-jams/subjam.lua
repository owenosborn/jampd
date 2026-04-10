-- subjam.lua
-- Running multiple jams together using SubJam.
-- Loads two jam scripts and ticks them both from a parent jam,
-- combining their output. The Lua interpreter is lightweight
-- so you can layer many sub-jams without trouble.

local SubJam = require("lib/subjam")

function init(jam)
    local info = debug.getinfo(1, "S")
    local my_dir = info.source:match("^@(.*/)")

    drums = SubJam.load(my_dir .. "drums-basic.lua", jam)
    melody = SubJam.load(my_dir .. "simple.lua", jam)
end

function tick(jam)
    drums.tick(jam)
    melody.tick(jam)
end
