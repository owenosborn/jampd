require("lib/utils")
require("lib/chord")
require("lib/progression")

function init(jam)
    print("🥞 Pancake Jingle Starting! 🥞")
    
    -- Upbeat progression in C major - feels happy and commercial
    verse_prog = Progression.new("C.G.A-.F.C.G.F.C.")
    
    -- Dark bridge progression - minor feel
    bridge_prog = Progression.new("A-...F...G...E-...")
    
    -- Solo progression - back to major but with movement
    solo_prog = Progression.new("C.D-.G.C.F.G.C.G.")
    
    progression = verse_prog
    
    -- Melody notes that spell out "PAN-CAKES ARE GREAT!"
    -- Using scale degrees for a catchy tune
    verse_melody = {
        -- "Pan-cakes are"
        60, 62, 64, 65,  -- C D E F
        -- "so de-li-cious"
        67, 67, 65, 64,  -- G G F E
        -- "Fluf-fy stack of"
        60, 62, 64, 65,  -- C D E F
        -- "pure de-light!"
        67, 69, 72, 72   -- G A C C
    }
    
    -- Darker, descending melody for bridge
    bridge_melody = {
        69, 67, 65, 64,  -- A G F E
        62, 60, 58, 57,  -- D C Bb A
        67, 65, 64, 62,  -- G F E D
        60, 58, 57, 55   -- C Bb A G
    }
    
    melody_pattern = verse_melody
    melody_index = 1
    bass_octave = 3
    
    -- Percussion-like hits
    kick_note = 36
    snare_note = 38
    hihat_note = 42
    
    -- Verse lyrics (bright and happy)
    verse_lyrics = {
        "Pan-", "cakes", "are", "so",
        "de-", "li-", "cious", "treat!",
        "Fluf-", "fy", "stack", "of",
        "morn-", "ing", "gold-", "en!"
    }
    
    -- Bridge lyrics (dark and ominous)
    bridge_lyrics = {
        "But", "what", "if", "we",
        "run", "out", "of", "sy-",
        "rup", "for", "our", "sweet",
        "break-", "fast", "dreams", "lost..."
    }
    
    lyrics = verse_lyrics
    lyric_index = 1
    
    -- Structure tracking
    section_count = 0  -- counts how many times we've played through
    current_section = "verse"
    beat_in_section = 0
    
    -- Solo section variables
    solo_scale = {60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79}  -- C major scale extended
    solo_note_counter = 0
end

function tick(jam)
    chord = progression:tick(jam)
    
    -- Track beats to know when to switch sections
    if jam.every(1) then
        beat_in_section = beat_in_section + 1
        
        -- After 16 beats (one full progression loop)
        if beat_in_section >= 16 then
            beat_in_section = 0
            section_count = section_count + 1
            
            -- Switch to bridge after 2 verses
            if section_count == 2 and current_section == "verse" then
                current_section = "bridge"
                progression = bridge_prog
                progression:reset()
                melody_pattern = bridge_melody
                lyrics = bridge_lyrics
                melody_index = 1
                lyric_index = 1
                print("\n🌑 BRIDGE SECTION 🌑\n")
            -- Switch to solo after bridge
            elseif section_count == 3 and current_section == "bridge" then
                current_section = "solo"
                progression = solo_prog
                progression:reset()
                solo_note_counter = 0
                print("\n🎸 SYNTH SOLO TIME! 🎸\n")
            -- Return to verse after solo
            elseif section_count == 4 and current_section == "solo" then
                current_section = "verse"
                progression = verse_prog
                progression:reset()
                melody_pattern = verse_melody
                lyrics = verse_lyrics
                melody_index = 1
                lyric_index = 1
                section_count = 0
                print("\n🥞 BACK TO THE PANCAKES! 🥞\n")
            end
        end
    end
    
    -- Bass line - simple root notes on beats
    if jam.every(1) then
        local bass_vel = current_section == "bridge" and 110 or 90
        jam.noteout(chord:note(1, bass_octave), bass_vel, 0.9)
    end
    
    -- Chord stabs - different patterns for verse vs bridge vs solo
    if current_section == "verse" then
        -- Bouncy offbeat chords for verse
        if jam.every(1/2, 1/4) then
            jam.noteout(chord:note(1, 5), 60, 0.4)
            jam.noteout(chord:note(2, 5), 60, 0.4)
            jam.noteout(chord:note(3, 5), 60, 0.4)
        end
    elseif current_section == "bridge" then
        -- Darker, sustained chords for bridge
        if jam.every(2) then
            jam.noteout(chord:note(1, 4), 70, 1.8)
            jam.noteout(chord:note(2, 4), 70, 1.8)
            jam.noteout(chord:note(3, 4), 70, 1.8)
            if #chord.tones >= 4 then
                jam.noteout(chord:note(4, 4), 70, 1.8)
            end
        end
    elseif current_section == "solo" then
        -- Rhythmic stabs for solo backing
        if jam.every(1) then
            jam.noteout(chord:note(1, 4), 70, 0.3)
            jam.noteout(chord:note(2, 4), 70, 0.3)
            jam.noteout(chord:note(3, 4), 70, 0.3)
        end
    end
    
    -- Main melody - eighth notes (verse and bridge only)
    if (current_section == "verse" or current_section == "bridge") and jam.every(1/2) then
        local note = melody_pattern[melody_index]
        jam.noteout(note, 100, 0.45)
        
        -- Print the lyric for this note
        print(lyrics[lyric_index])
        
        -- Add line break after each phrase (every 8 syllables)
        if lyric_index % 8 == 0 then
            print("") -- blank line for readability
        end
        
        melody_index = (melody_index % #melody_pattern) + 1
        lyric_index = (lyric_index % #lyrics) + 1
    end
    
    -- SYNTH SOLO SECTION
    if current_section == "solo" then
        -- Fast running notes (16th notes)
        if jam.every(1/8) and prob(0.85) then
            -- Filter random scale notes to current chord
            local scale_note = choose(solo_scale)
            local filtered = chord:filter(scale_note)
            jam.noteout(filtered, randi(80, 110), 0.2)
            solo_note_counter = solo_note_counter + 1
        end
        
        -- Occasional higher accent notes
        if jam.every(1/4) and prob(0.6) then
            local high_note = choose(solo_scale) + 12
            jam.noteout(high_note, 100, 0.8)
        end
        
        -- Crazy run every 4 beats
        if jam.every(4, 3.5) then
            -- Ascending chromatic run
            for i = 0, 5 do
                jam.noteout(67 + i, 90, 0.1)
            end
        end
    end
    
    -- Percussion feel - varies by section
    if current_section == "verse" then
        -- Kick on beats 1 and 3
        if jam.every(2) or jam.every(2, 1) then
            jam.noteout(kick_note, 100, 0.2)
        end
        
        -- Snare on beats 2 and 4
        if jam.every(2, 0.5) or jam.every(2, 1.5) then
            jam.noteout(snare_note, 90, 0.2)
        end
        
        -- Hi-hat on every eighth note
        if jam.every(1/2) and prob(0.8) then
            jam.noteout(hihat_note, 50, 0.1)
        end
    elseif current_section == "bridge" then
        -- Bridge: Heavier, slower feel
        -- Kick on every beat (march-like)
        if jam.every(1) then
            jam.noteout(kick_note, 120, 0.3)
        end
        
        -- Occasional dark cymbal crashes
        if jam.every(4) then
            jam.noteout(49, 80, 1.0)  -- Crash cymbal
        end
    elseif current_section == "solo" then
        -- Solo: Driving rock beat
        -- Kick on 1 and 3
        if jam.every(2) or jam.every(2, 1) then
            jam.noteout(kick_note, 110, 0.2)
        end
        
        -- Snare on 2 and 4
        if jam.every(2, 0.5) or jam.every(2, 1.5) then
            jam.noteout(snare_note, 100, 0.2)
        end
        
        -- Constant hi-hat for energy
        if jam.every(1/4) then
            jam.noteout(hihat_note, 60, 0.1)
        end
        
        -- Crash at phrase starts
        if jam.every(8) then
            jam.noteout(49, 90, 0.5)
        end
    end
    
    -- Special sparkle at the end of phrases (verse only)
    if current_section == "verse" and jam.every(16, 15.5) then
        -- Ascending sparkle
        for i = 0, 2 do
            jam.noteout(72 + i*2, 80, 0.2)
        end
    end
end
