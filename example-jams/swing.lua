-- swing.lua
-- Demonstrates swing feel using jam.every() with an offset.
-- The offset shifts the off-beat note later in time:
--   1/2 = straight, 2/3 = full triplet swing, values in between for taste.

function tick(jam)
    -- Downbeat notes
    if jam.every(1) then
        jam.noteout(60, 100, .1)
    end

    -- Off-beat notes, pushed late for swing
    -- Try different values: 1/2 (straight), .6 (gentle), 2/3 (triplet)
    if jam.every(1, 2/3) then
        jam.noteout(60, 75, .1)
    end
end
