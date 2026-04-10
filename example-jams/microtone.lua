-- microtone.lua
-- Microtonal pitch gliding between notes.
-- Demonstrates using fractional MIDI note numbers to smoothly
-- bend between pitches, creating slides and quarter-tone melodies.

function init(jam)
    base = 60
    target = 60
    current = 60
    step = 0
    steps = 32  -- ticks to glide over

    destinations = {60, 62, 63.5, 65, 67, 68.5, 70, 72}
    dest_idx = 1
end

function tick(jam)
    -- Glide current pitch toward target
    if step < steps then
        current = base + (target - base) * (step / steps)
        step = step + 1
    else
        current = target
    end

    -- Play the current (possibly fractional) pitch every sixteenth
    if jam.every(1/4) then
        jam.noteout(current, 80, 1/4)
    end

    -- Move to next destination every 2 beats
    if jam.every(2) then
        base = target
        dest_idx = (dest_idx % #destinations) + 1
        target = destinations[dest_idx]
        step = 0
    end
end
