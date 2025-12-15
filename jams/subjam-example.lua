-- jam.lua (or whatever your mother jam is)
local SubJam = require("lib/subjam")

function init(jam)
    -- Figure out where we are
    local info = debug.getinfo(1, "S")
    local my_dir = info.source:match("^@(.*/)")
    
    -- Load sub-jams with full paths
    drums = SubJam.load(my_dir .. "jams/drum1.lua", jam)
    bass = SubJam.load(my_dir .. "jams/swing-example.lua", jam)
    
    print("Mother jam loaded with sub-jams!")
end

function tick(jam)
    drums.tick(jam)
    bass.tick(jam)
end
