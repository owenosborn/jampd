-- arp.lua
-- Arpeggiator: receives notes via notein, arpeggiates them

function init(jam)
    held_notes = {}  -- notes currently being held
    arp_index = 1    -- current position in arp
    print("Arpeggiator loaded")
end

function notein(jam, note, velocity)
    if velocity > 0 then
        -- Note on: add to held notes
        if not held_notes[note] then
            held_notes[note] = true
            print("Arp received note: " .. note)
        end
    else
        -- Note off: remove from held notes
        held_notes[note] = nil
    end
end

function tick(jam)
    -- Build sorted array of currently held notes
    local notes = {}
    for note, _ in pairs(held_notes) do
        table.insert(notes, note)
    end
    table.sort(notes)
    
    -- Arpeggiate if we have notes
    if #notes > 0 then
        if jam.every(1/4) then  -- 16th note arp
            -- Get current note
            arp_index = ((arp_index - 1) % #notes) + 1
            local note = notes[arp_index]
            
            -- Output arpeggiated note
            jam.noteout(note, 80, 0.2)
            
            arp_index = arp_index + 1
        end
    end
end