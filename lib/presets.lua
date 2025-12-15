-- lib/presets.lua
-- Preset management for saving/loading settings

local Presets = {}
Presets.__index = Presets

function Presets.new(base_path)
    local self = setmetatable({}, Presets)
    self.base_path = base_path or "presets"
    self.current_index = 0  -- 0 means no preset loaded yet
    self.preset_list = {}   -- Array of preset filenames
    
    -- Create presets folder if it doesn't exist
    os.execute("mkdir -p " .. self.base_path)
    
    -- Scan for existing presets
    self:scan()
    
    return self
end

-- Scan presets folder and populate preset_list
function Presets:scan()
    self.preset_list = {}
    
    -- List files matching pattern, sorted
    local handle = io.popen("ls -1 " .. self.base_path .. "/*-settings.lua 2>/dev/null | sort")
    if handle then
        for line in handle:lines() do
            -- Extract filename from path
            local filename = line:match("([^/]+)$")
            if filename then
                table.insert(self.preset_list, filename)
            end
        end
        handle:close()
    end
end

-- Get total number of presets
function Presets:count()
    return #self.preset_list
end

-- Load preset by index (with wrap-around)
function Presets:load(index)
    if #self.preset_list == 0 then
        print("No presets")
        return nil
    end
    
    -- Wrap around
    if index < 1 then
        index = #self.preset_list
    elseif index > #self.preset_list then
        index = 1
    end
    
    local filename = self.preset_list[index]
    local filepath = self.base_path .. "/" .. filename
    
    local settings = dofile(filepath)
    if settings then
        self.current_index = index
        print("Loaded preset: " .. filename)
        return settings
    end
    
    return nil
end

-- Load previous preset (first time loads preset 1)
function Presets:prev()
    if self.current_index == 0 then
        return self:load(1)
    else
        return self:load(self.current_index - 1)
    end
end

-- Load next preset (first time loads preset 1)
function Presets:next()
    if self.current_index == 0 then
        return self:load(1)
    else
        return self:load(self.current_index + 1)
    end
end

-- Helper function to serialize a value (handles nested tables)
local function serialize_value(v, indent)
    indent = indent or ""
    local t = type(v)
    
    if t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "table" then
        local lines = {"{\n"}
        local next_indent = indent .. "    "
        for k, val in pairs(v) do
            local key_str
            if type(k) == "number" then
                key_str = ""
            else
                key_str = k .. " = "
            end
            table.insert(lines, next_indent .. key_str .. serialize_value(val, next_indent) .. ",\n")
        end
        table.insert(lines, indent .. "}")
        return table.concat(lines)
    else
        return "nil"
    end
end

-- Save current settings as new preset
function Presets:save(settings)
    -- Find next available number
    local next_num = 1
    for _, filename in ipairs(self.preset_list) do
        local num = tonumber(filename:match("^(%d+)"))
        if num and num >= next_num then
            next_num = num + 1
        end
    end
    
    -- Format as 4-digit padded number: 0001-settings.lua
    local filename = string.format("%04d-settings.lua", next_num)
    local filepath = self.base_path .. "/" .. filename
    
    -- Write settings file
    local file = io.open(filepath, "w")
    if file then
        file:write("return {\n")
        for k, v in pairs(settings) do
            file:write("    " .. k .. " = " .. serialize_value(v, "    ") .. ",\n")
        end
        file:write("}\n")
        file:close()
        
        -- Add to list instead of rescanning
        table.insert(self.preset_list, filename)
        
        -- Set current to newly saved preset
        self.current_index = #self.preset_list
        
        print("Saved preset: " .. filename)
        return true
    end
    
    return false
end

-- Get current preset name for display
function Presets:getCurrentName()
    if self.current_index == 0 or self.current_index > #self.preset_list then
        return "None"
    end
    -- Remove the "-settings.lua" suffix for cleaner display
    return self.preset_list[self.current_index]:gsub("-settings%.lua$", "")
end

return {
    Presets = Presets
}
