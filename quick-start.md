# Jam Cheat Sheet

## Overview

Jam is a Pure Data external that embeds a Lua interpreter for creating algorithmic music and MIDI processing. It provides a minimal but powerful API focused on tick-based timing and MIDI I/O.

### Core Concept

Jam scripts follow a simple lifecycle:
- **`init(jam)`** - Called once when the script loads
- **`tick(jam)`** - Called on every timing tick
- **Input handlers** - Called when MIDI or other messages arrive

The `jam` object provides timing information and functions to generate musical output.

---

## The `jam` Object

### Timing Properties
```lua
jam.tpb     -- Ticks per beat (default: 180)
jam.bpm     -- Beats per minute (default: 100)
jam.tc      -- Global tick counter (starts at 0)
jam.ch      -- MIDI output channel (default: 1)
```

### Core Methods

#### `jam.every(interval, offset)`
Returns true when current tick aligns with rhythmic interval
```lua
jam.every(1)        -- Every beat
jam.every(1/2)      -- Every half beat (eighth notes)
jam.every(1/4)      -- Every quarter beat (sixteenth notes)
jam.every(2)        -- Every 2 beats
jam.every(1, 1/2)   -- Every beat, offset by half beat
```

#### `jam.once(beat)`
Returns true exactly once at specified beat number
```lua
jam.once(4)      -- True only at beat 4
jam.once(2.5)    -- True only at beat 2.5
```

#### `jam.noteout(note, velocity, duration)`
Send MIDI note
```lua
jam.noteout(60, 100, 1)    -- C4, vel 100, 1 beat duration
jam.noteout(60, 100)       -- C4, vel 100, no duration
```
- **note**: MIDI note number (0-127)
- **velocity**: Note velocity (0-127)
- **duration**: (optional) Duration in beats

#### `jam.ctlout(controller, value)`
Send MIDI CC message
```lua
jam.ctlout(7, 64)    -- Volume to 64
jam.ctlout(1, 127)   -- Mod wheel to max
```

#### `jam.msgout(...)`
Send arbitrary list message to left outlet
```lua
jam.msgout("bang")
jam.msgout("tempo", 120)
jam.msgout(1, 2, 3, "go")
```

---

## Script Lifecycle

### `init(jam)`
Called once when script loads
```lua
function init(jam)
    -- Initialize variables, objects, etc.
end
```

### `tick(jam)`
Called every tick (main loop)
```lua
function tick(jam)
    -- Generate music here
end
```

---

## Input Handlers

### `notein(jam, note, velocity, channel)`
Called when MIDI note arrives
```lua
function notein(jam, note, velocity, channel)
    -- Process incoming note
end
```

### `ctlin(jam, controller, value, channel)`
Called when MIDI CC arrives
```lua
function ctlin(jam, controller, value, channel)
    -- Process incoming CC
end
```

### Custom handlers via list messages
Any function can be called via PD's `list` messages
```lua
function myhandler(jam, arg1, arg2)
    -- Custom message handler
end
```
Then in PD: `[list myhandler 42 hello(` → calls `myhandler(jam, 42, "hello")`

---

## Utility Functions (`lib/utils`)

All utilities are available globally after requiring:
```lua
require("lib/utils")
```

### Probability & Random
```lua
prob(p)                      -- Return true p% of time (0-1)
p(p)                         -- Alias for prob()
randi()                      -- Random 0 or 1
randi(n)                     -- Random 0 to n
randi(min, max)              -- Random min to max
randf()                      -- Random 0.0 to 1.0
randf(n)                     -- Random 0.0 to n
randf(min, max)              -- Random min to max
choose(array)                -- Pick random element
weighted_choose(weights)     -- Weighted random selection (returns index)
```

### Math Utilities
```lua
clamp(value, min, max)       -- Constrain value to range
lerp(a, b, t)                -- Linear interpolation (t: 0-1)
map(val, in_min, in_max, out_min, out_max)  -- Remap value from one range to another
wrap(value, min, max)        -- Wrap value to range [min, max)
```

### Counter Class
```lua
local Counter = require("lib/utils").Counter

counter = Counter.new(max)   -- Count 0 to max-1
counter:tick()               -- Increment and return current count
counter:reset()              -- Reset to 0

-- Properties
counter.count                -- Current count value
counter.max                  -- Maximum count value
```

---

## Chord Class (`lib/chord`)

```lua
local Chord = require("lib/chord").Chord
```

### Constructor & Parsing
```lua
chord = Chord.new()              -- Empty chord
chord = Chord.new("A-7")         -- Create from string
chord:parse("F#maj7")            -- Parse new chord symbol
```

### Chord Symbols
- **Qualities**: `-` (minor), `+` (aug), `o` (dim), or nothing (major)
- **Extensions**: `6`, `7`, `maj7`, `9`, `b9`, `7b9`, `7#9`, `11`, `#11`, `13`, `7b5`, `sus4`
- **Slash chords**: `C/E` (C major with E in bass)

Examples: `C`, `A-7`, `F#maj7`, `Bb7b9`, `G7sus4`, `D-7/C`

### Methods
```lua
chord:note(index, octave)        -- Get specific note from chord
chord:filter(note_in)            -- Quantize MIDI note to nearest chord tone
chord:play(jam, vel, dur, oct)   -- Play all chord tones
chord:voice(center)              -- Generate voicing around center note
chord:playv(jam, vel, dur)       -- Play generated voicing
chord:print()                    -- Print chord information
```

### Properties
```lua
chord.tones      -- Array of intervals from root (can span > octave)
chord.root       -- Root pitch class (0-11)
chord.bass       -- Bass note pitch class (0-11)
chord.name       -- Chord symbol string
chord.voicing    -- Generated voicing array (after :voice())
```

---

## Progression Class (`lib/progression`)

```lua
local Progression = require("lib/progression").Progression
```

### Constructor & Parsing
```lua
prog = Progression.new()                    -- Empty progression
prog = Progression.new("G-7.A7.D-9.Db7.")  -- Parse from string
prog:parse("C.F.G.C.")                     -- Parse new string
```

### Parsing Format
- Chord symbols separated by dots
- Each dot = 1 beat duration
- Examples:
  - `"C."` = C major for 2 beats
  - `"G..."` = G major for 4 beats
  - `"A-7.D7.G."` = A-7 (2 beats), D7 (2 beats), G (2 beats)

### Methods
```lua
prog:add(chord, beats)      -- Add chord manually with duration
prog:tick(jam)              -- Advance playhead, returns current chord
prog:chord()                -- Get current chord without advancing
prog:isnew()                -- Returns true if chord just changed
prog:reset()                -- Reset playhead to beginning
prog:scale(factor)          -- Time-stretch entire progression
prog:print()                -- Print progression information
```

### Properties
```lua
prog.chords          -- Array of Chord objects
prog.length_beats    -- Total length in beats
prog.playhead        -- Current position in ticks
prog.index           -- Current chord index (1-based)
prog.chord_changed   -- Flag indicating new chord
```

---

## Pure Data Setup

### Creating the Object
```
[jam 180 100]
```
- First argument: ticks per beat (optional, default 180)
- Second argument: BPM (optional, default 100)

### Messages
- `load [filename]` - Load a Lua jam script
- `bang` - Advance one tick
- `reset` - Reset tick counter to 0
- `bpm [number]` - Set tempo
- `tpb [number]` - Set ticks per beat resolution
- `list note [args]` - Route to `notein` handler
- `list ctl [args]` - Route to `ctlin` handler

### Outlets
- **Left outlet** - Musical messages (`note`, `ctl`, `makenote` lists)
- **Right outlet** - Info and debug messages (prints from Lua)
