-- phase-arp.lua
-- Steve Reich-style phasing arpeggiator.
-- Two voices arpeggiate the same held notes, but voice 2 runs
-- at a slightly faster rate, causing the voices to slowly drift
-- out of phase with each other over time.
-- Demonstrates notein, jam.ch for channel routing, and using
-- slightly different interval values to create phasing effects.

function init(jam)
    held_notes = {}
    idx1 = 1
    idx2 = 1
end

function notein(jam, note, velocity)
    if velocity > 0 then
        held_notes[note] = true
    else
        held_notes[note] = nil
    end
end

function tick(jam)
    local notes = {}
    for note, _ in pairs(held_notes) do
        table.insert(notes, note)
    end
    table.sort(notes)

    if #notes == 0 then return end

    -- Voice 1: steady sixteenths
    if jam.every(1/4) then
        idx1 = ((idx1 - 1) % #notes) + 1
        jam.ch = 1
        jam.noteout(notes[idx1], 80, 1/4)
        idx1 = idx1 + 1
    end

    -- Voice 2: slightly faster — drifts ahead over time
    if jam.every(1/4 - 1/512) then
        idx2 = ((idx2 - 1) % #notes) + 1
        jam.ch = 2
        jam.noteout(notes[idx2], 70, 1/4)
        idx2 = idx2 + 1
    end
end
