# Jam User's Guide

## What is Jam?

Jam lets you sketch musical patterns and processes using simple Lua scripts. Instead of patching together boxes, you write code that describes *when* and *what* to play. Your scripts run inside Pure Data, so you get Pd's audio engine and MIDI I/O.

## Your First Jam


```lua
function tick(jam)
    if jam.every(1) then
        jam.noteout(60, 100, 0.5)  -- C4, velocity 100, half beat
    end
end
```

This plays middle C on every beat. That's it.

## Thinking in Beats

Everything in Jam is measured in **beats**, not ticks or milliseconds.

```lua
jam.every(1)      -- every beat (quarter notes)
jam.every(1/2)    -- every half beat (eighth notes)
jam.every(1/4)    -- every quarter beat (sixteenth notes)
jam.every(2)      -- every 2 beats (half notes)
jam.every(4)      -- every 4 beats (whole notes)
```

Note durations work the same way:

```lua
jam.noteout(60, 100, 1)      -- whole beat duration
jam.noteout(60, 100, 1/2)    -- half beat
jam.noteout(60, 100, 1/4)    -- quarter beat
```

## Building Rhythms

Combine multiple `jam.every()` calls to build patterns:

```lua
function tick(jam)
    -- kick on beats 1 and 3
    if jam.every(2) then
        jam.noteout(36, 100, 0.1)
    end

    -- snare on beats 2 and 4
    if jam.every(2, 1) then  -- offset by 1 beat
        jam.noteout(38, 100, 0.1)
    end

    -- hi-hat on every eighth note
    if jam.every(1/2) then
        jam.noteout(42, 60, 0.1)
    end
end
```

## Swing and Offsets

The second argument to `jam.every()` is an **offset** in beats:

```lua
-- straight eighths
if jam.every(1/2) then ... end

-- swung eighths (triplet feel)
if jam.every(1) then ... end           -- downbeats
if jam.every(1, 2/3) then ... end      -- upbeats delayed to triplet position

-- subtle swing
if jam.every(1) then ... end
if jam.every(1, 0.55) then ... end     -- just a touch late
```

## Adding Randomness

Use the utility functions for variation:

```lua
require("lib/utils")

function tick(jam)
    if jam.every(1/4) then
        -- 70% chance to play
        if p(0.7) then
            jam.noteout(60, randi(60, 100), 0.1)  -- random velocity
        end
    end
end
```

### Probability Functions

```lua
p(0.5)              -- 50% chance of true
prob(0.3)           -- 30% chance (same as p)
randi(1, 5)         -- random integer 1-5
randf(0.5, 1.0)     -- random float 0.5-1.0
choose({60, 62, 64}) -- pick random element from list
```

## Responding to MIDI Input

Your script can respond to incoming notes:

```lua
function init(jam)
    held_notes = {}
end

function notein(jam, note, velocity)
    if velocity > 0 then
        held_notes[note] = true
    else
        held_notes[note] = nil
    end
end

function tick(jam)
    -- do something with held_notes
end
```

## Building an Arpeggiator

Here's a complete arpeggiator:

```lua
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
    -- build sorted list of held notes
    local notes = {}
    for note, _ in pairs(held_notes) do
        table.insert(notes, note)
    end
    table.sort(notes)

    -- arpeggiate
    if #notes > 0 and jam.every(1/4) then
        arp_index = ((arp_index - 1) % #notes) + 1
        jam.noteout(notes[arp_index], 80, 0.2)
        arp_index = arp_index + 1
    end
end
```

## Script Lifecycle

```lua
function init(jam)
    -- Called once when script loads
    -- Set up variables, state, etc.
end

function tick(jam)
    -- Called on every tick (many times per beat)
    -- Generate notes here
end

function notein(jam, note, velocity)
    -- Called when MIDI note arrives
end

function msgin(jam, ...)
    -- Called for arbitrary messages from Pd
end
```

## The jam Object

Inside your functions, `jam` gives you:

| Property | Description |
|----------|-------------|
| `jam.tc` | Current tick count (starts at 0) |
| `jam.tpb` | Ticks per beat (default: 180) |
| `jam.bpm` | Beats per minute |
| `jam.ch` | MIDI output channel (default: 1) |

| Function | Description |
|----------|-------------|
| `jam.every(interval, offset)` | True when tick aligns with interval |
| `jam.once(beat)` | True only at specific beat number |
| `jam.noteout(note, vel, dur)` | Send MIDI note (note accepts floats for microtones) |
| `jam.msgout(...)` | Send arbitrary message to Pd |

## Tips

**Start simple.** Get one thing working before adding complexity.

**Use print() for debugging.** Output appears in Pd's console.

```lua
print("current beat:", jam.tc / jam.tpb)
```

**Hot reload.** Edit your script, save, send `load` message again. No need to restart Pd.

**Think in musical terms.** Use fractions for rhythms: `1/4` for sixteenths, `1/3` for triplets, `2/3` for swing.

## Pure Data Setup

Create a `[jam]` object:
```
[jam 180 120]
     |     \
     |      \
[route note makenote]  [number]
     |                    |
   (to your synth)     (tick count)
```

- First argument: ticks per beat (180 = high resolution)
- Second argument: BPM
- Left outlet: note messages
- Right outlet: tick counter

Drive it with a metro based on your tpb and bpm:
```
[metro 1000/(180*120/60)]  -- for 180 tpb at 120 bpm
     |
   [jam]
```

Send `load path/to/script.lua` to load your jam.
