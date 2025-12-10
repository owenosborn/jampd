-- lib/subjam.lua
local SubJam = {}

function SubJam.load(filepath, jam)
    local env = {}
    setmetatable(env, {__index = _G})
    
    local chunk, err = loadfile(filepath, "t", env)
    if not chunk then
        error("Failed to load " .. filepath .. ": " .. err)
    end
    
    chunk() -- Execute to define init/tick in env
    
    local instance = {
        init = env.init,
        tick = env.tick,
        notein = env.notein,
        ctlin = env.ctlin,
    }
    
    if instance.init then
        instance.init(jam)
    end
    
    return instance
end

return SubJam
