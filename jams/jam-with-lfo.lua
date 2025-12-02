require("lib/utils")
require("lib/chord")
require("lib/progression")

function init(jam)
    -- Minor progression for atmospheric background
    progression = Progression.new("A-7...D-7...E-7...D-7...")
    
    -- Bass pattern state
    bass_octave = 2  -- Start low
    bass_counter = 0
    
    -- Descending riff state
    riff_active = false
    riff_notes = {}
    riff_index = 1
    
    print("Analog Filter Synth Demo loaded")
    print("- Slow minor chord pads")
    print("- Octave alternating bass")
    print("- Descending high riffs")
end

function tick(jam)
    local chord = progression:tick(jam)
    
    -- Slow atmospheric chord pads - every 2 beats
    if jam.every(2) then
        -- Play chord with slight randomization in velocity for analog feel
        for i = 1, #chord.tones do
            local vel = randi(65, 75)
            jam.noteout(chord:note(i, 5), vel, 1.8)
        end
    end
    
    -- Octave alternating bass line - every quarter note
    if jam.every(1/4) then
        local root = chord:note(1, bass_octave)
        local vel = randi(90, 100)
        jam.noteout(root, vel, 0.2)
        
        -- Alternate between low and high octave
        bass_counter = bass_counter + 1
        if bass_counter % 2 == 0 then
            bass_octave = 3  -- Higher octave
        else
            bass_octave = 2  -- Lower octave
        end
    end
    
    -- Trigger descending riff occasionally
    if jam.every(4) and prob(0.3) then
        -- Generate new descending riff from current chord
        riff_notes = {}
        local start_octave = 6
        
        -- Build descending pattern using chord tones
        for i = #chord.tones, 1, -1 do
            table.insert(riff_notes, chord:note(i, start_octave))
        end
        -- Add some passing tones descending
        for i = #chord.tones, 1, -1 do
            table.insert(riff_notes, chord:note(i, start_octave - 1))
        end
        
        riff_active = true
        riff_index = 1
    end
    
    -- Play descending riff - fast 16th notes
    if riff_active and jam.every(1/8) then
        if riff_index <= #riff_notes then
            local vel = randi(95, 110)
            jam.noteout(riff_notes[riff_index], vel, 0.15)
            riff_index = riff_index + 1
        else
            riff_active = false
        end
    end
    
    -- Add filter sweep on CC (can map to filter cutoff)
    -- Slow LFO-style movement
    if jam.every(1/16) then
        local cutoff = math.floor(66 + 60 * math.sin(jam.tc / jam.tpb))
        jam.ctlout(1, cutoff)  -- CC74 for filter cutoff
    end
    
    -- Send resonance CC for analog character
    if jam.every(1) then
        local resonance = randi(60, 80)
        jam.ctlout(2, resonance)  -- CC71 for resonance
    end
end
