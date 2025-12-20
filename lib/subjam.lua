-- lib/subjam.lua
-- Load jams within jams with namespace isolation and output redirection
local SubJam = {}

function SubJam.load(filepath, jam, output_callback)
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
    
    -- Create jam wrapper with custom output routing
    local jam_wrapper = {}
    setmetatable(jam_wrapper, {__index = jam})
    
    -- Override output functions to route through callback
    jam_wrapper.noteout = function(note, velocity, duration)
        if output_callback then
            output_callback("note", note, velocity, duration)
        else
            jam.noteout(note, velocity, duration)
        end
    end
    
    jam_wrapper.ctlout = function(controller, value)
        if output_callback then
            output_callback("ctl", controller, value)
        else
            jam.ctlout(controller, value)
        end
    end
    
    jam_wrapper.msgout = function(...)
        if output_callback then
            output_callback("msg", ...)
        else
            jam.msgout(...)
        end
    end
    
    -- Initialize with wrapper
    if instance.init then
        instance.init(jam_wrapper)
    end
    
    -- Wrap all handlers to use jam_wrapper
    return {
        tick = function() 
            if instance.tick then instance.tick(jam_wrapper) end
        end,
        notein = instance.notein and function(n, v) 
            instance.notein(jam_wrapper, n, v) 
        end or nil,
        ctlin = instance.ctlin and function(n, v) 
            instance.ctlin(jam_wrapper, n, v) 
        end or nil,
        jam = jam_wrapper,  -- expose wrapper if needed
    }
end

return SubJam