-- arp.lua
-- Arpeggiator: receives notes via notein, arpeggiates them as sixteenths.
-- Demonstrates notein for MIDI input, sorting held notes, and cycling
-- through them rhythmically.

function init(jam)
    held_notes = {}
    arp_index = 1
end

function notein(jam, note, velocity)
    if velocity > 0 then
        held_notes[note] = true
    else
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

    if #notes > 0 and jam.every(1/4) then
        arp_index = ((arp_index - 1) % #notes) + 1
        jam.noteout(notes[arp_index], 80, 1/5)
        arp_index = arp_index + 1
    end
end
