-- lib/chord.lua
-- Unified chord module combining Chord class and parsing functionality
-- Converts chord symbols like "C-7", "F#maj7", "Bb7b5" into pitch arrays
-- Supports major/minor/dim/aug qualities and extensions (6, 7, 9, 11, 13)
-- Example: chord:parse("A-7") sets pitches to [0, 3, 7, 10]

-- Utility function to split a string by a separator
function string:split(sep)
    local fields = {}
    self:gsub("([^"..sep.."]*)",
        function(c) fields[#fields+1] = c end)
    return fields 
end

-- Convert note name to pitch class (0-11)
local function note_to_pitch_class(note)
    local pitch_classes = {
        ["C"] = 0, ["C#"] = 1, ["Db"] = 1, ["D"] = 2, ["D#"] = 3, ["Eb"] = 3, ["E"] = 4,
        ["F"] = 5, ["F#"] = 6, ["Gb"] = 6, ["G"] = 7, ["G#"] = 8, ["Ab"] = 8, ["A"] = 9,
        ["A#"] = 10, ["Bb"] = 10, ["B"] = 11,
    }
    if pitch_classes[note] then
        return pitch_classes[note]
    else
        error("Invalid note "..note)
    end
end

-- Parse chord text into components
local function parse_chord_text(chord_text)
    local root
    local quality
    local extension = ""
    local bass

    -- Extract the root note
    local root_character = chord_text:sub(1, 1)
    local next_character = chord_text:sub(2, 2)

    if next_character == '#' or next_character == 'b' then
        root = root_character .. next_character
        chord_text = chord_text:sub(3)
    else
        root = root_character
        chord_text = chord_text:sub(2)
    end

    -- Check the quality
    local quality_marker = chord_text:sub(1, 1)
    if quality_marker == '-' then
        quality = 'min'
        chord_text = chord_text:sub(2)
    elseif quality_marker == '+' then
        quality = 'aug'
        chord_text = chord_text:sub(2)
    elseif quality_marker == 'o' then
        quality = 'dim'
        chord_text = chord_text:sub(2)
    else
        quality = 'maj'
    end

    -- Extract extension and bass note if they exist
    local split_by_bass = chord_text:split('/')
    if #split_by_bass > 1 then
        bass = split_by_bass[2]
        extension = split_by_bass[1]
    else
        extension = split_by_bass[1]
    end

    return {
        root = root,
        quality = quality,
        extension = extension,
        bass = bass,
    }
end

-- Define chord quality calculator (returns pitch class intervals)
local quality = {
    maj = function() return {0, 4, 7} end,
    min = function() return {0, 3, 7} end,
    dim = function() return {0, 3, 6} end,
    aug = function() return {0, 4, 8} end,
}

-- Define how to process each extension (adds pitch class intervals with proper octaves)
local extension = {
    ["6"] = function(pitches, chord) table.insert(pitches, 9) end,     -- 6th in same octave
    ["maj7"] = function(pitches, chord) table.insert(pitches, 11) end, -- maj7 in same octave
    ["7"] = function(pitches, chord) 
                if chord.quality == "dim" then
                    table.insert(pitches, 9)  -- dim7 (actually bb7)
                else
                    table.insert(pitches, 10) -- dom7
                end
            end,
    ["9"] = function(pitches, chord) table.insert(pitches, 14) end,    -- 9th = 2nd + octave
    ["b9"] = function(pitches, chord) table.insert(pitches, 13) end,   -- b9 = b2nd + octave
    ["11"] = function(pitches, chord) table.insert(pitches, 17) end,   -- 11th = 4th + octave
    ["#11"] = function(pitches, chord) table.insert(pitches, 18) end,  -- #11 = #4th + octave
    ["13"] = function(pitches, chord) table.insert(pitches, 21) end,   -- 13th = 6th + octave
    ["7b5"] = function(pitches, chord) 
                table.insert(pitches, 10) -- add dom7
                pitches[3] = 6 -- flatten the 5th
              end,
    ["sus4"] = function(pitches, chord) 
                pitches[2] = 5 -- flatten the 5th
              end,

}

-- Construct chord from parsed components
local function construct_chord(chord_data)
    -- Get base triad as pitch classes
    local pitches = quality[chord_data.quality]()

    -- Apply extensions (keeping proper octaves)
    if chord_data.extension and chord_data.extension ~= "" then
        local exts = chord_data.extension:split(',')
        for _, ext in ipairs(exts) do
            local ext_func = extension[ext]
            if ext_func then
                ext_func(pitches, chord_data)
            else
                print("Warning: Unrecognized extension ".. ext .. ". Skipping.")
            end
        end
    end

    -- Don't normalize to 0-11 anymore - keep octave information
    -- Users can mod 12 if they want true pitch classes

    return pitches
end

-- Chord class definition
Chord = {}
Chord.__index = Chord

function Chord.new()
    local self = setmetatable({}, Chord)
    self.pitches = {}      -- array of pitches, starting from 0, can be more than one octave for extensions
    self.root = 0         -- root note pitch class, 0-11
    self.bass = 0          -- bass note for slash chords, pitch class 0-11
    self.name = ""         -- chord symbol e.g. "A-7"
    return self
end

-- Parse chord symbol and set chord properties
function Chord:parse(chord_string)
    -- Parse the chord string
    local parsed = parse_chord_text(chord_string)

    -- Construct the chord pitches
    local chord_pitches = construct_chord(parsed)

    -- Set the chord object's properties
    self.pitches = chord_pitches
    self.root = note_to_pitch_class(parsed.root)
    self.bass = parsed.bass and note_to_pitch_class(parsed.bass) or self.root
    self.name = chord_string

    return self
end

-- Get specific note from chord at given index and octave
function Chord:note(index, octave)
    octave = octave or 5  -- default to octave 5 (60 = C5)
    index = ((index - 1) % #self.pitches) + 1
    return self.pitches[index] + self.root + (octave * 12)
end

-- Print chord information
function Chord:print(print_callback)
    print_callback = print_callback or print
    print_callback("Chord:")
    local formatStr = "%-20s | %-6s | %-6s | %-9s"
    local headerFormat = "%-20s | %-6s | %-6s | %-9s"
    local separator = string.rep("-", 50)
    print_callback(separator)
    print_callback(string.format(headerFormat, "Pitches", "Root", "Bass", "Name"))
    print_callback(separator)
    local pitches_str = table.concat(self.pitches, ", ")
    local info = string.format(
        formatStr,
        "[" .. pitches_str .. "]",
        tostring(self.root),
        tostring(self.bass),
        self.name
    )
    print_callback(info)
    print_callback(separator)
end

return {
    Chord = Chord
}
