-- arp.lua
-- Simple arpeggiator: hold notes, hear them arpeggiated as sixteenths.
-- Demonstrates notein for MIDI input, and sorting held notes into
-- a playback list only when they change (not every tick).

function init(jam)
    held = {}
    sorted = {}
    idx = 1
end

function notein(jam, note, velocity)
    if velocity > 0 then
        held[note] = true
    else
        held[note] = nil
    end
    -- rebuild sorted list when notes change
    sorted = {}
    for n, _ in pairs(held) do
        table.insert(sorted, n)
    end
    table.sort(sorted)
end

function tick(jam)
    if #sorted > 0 and jam.every(1/4) then
        idx = ((idx - 1) % #sorted) + 1
        jam.noteout(sorted[idx], 80, 1/5)
        idx = idx + 1
    end
end
