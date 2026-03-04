# Jam - Lua-Powered Music Processor for Pure Data

## Overview
Jam is a Pure Data external that embeds a Lua interpreter for creating algorithmic music and MIDI processing. It provides a minimal but powerful API focused on tick-based timing and MIDI I/O, allowing you to build any musical process using Lua scripts.

## Core Concept

Jam scripts follow a simple lifecycle:
- **`init(jam)`** - Called once when the script loads
- **`tick(jam)`** - Called on every timing tick
- **Input handlers** - Called when MIDI or other messages arrive

The `jam` object provides timing information and functions to generate musical output.

## The jam Object

### Timing Properties
- **`jam.tpb`** - Ticks per beat (default: 180, configurable)
- **`jam.bpm`** - Beats per minute (default: 100)
- **`jam.tc`** - Global tick counter (starts at 0, increments each tick)
- **`jam.ch`** - MIDI output channel (default: 1)

### Core Functions

#### `jam.every(interval, offset)`
Returns true when the current tick aligns with a rhythmic interval.

```lua
jam.every(1)       -- Every beat
jam.every(1/4)     -- Every quarter beat (sixteenth notes)
jam.every(2)       -- Every 2 beats
jam.every(1, 1/2)  -- Every beat, offset by half a beat
```

- **`interval`** - Number of beats between triggers (default: 1)
- **`offset`** - Beat offset for rhythmic displacement (default: 0). Delays triggers by this many beats. Does not wrap - an offset of 2.5 delays by exactly 2.5 beats. Returns false until the offset time has elapsed. Useful for swing (small values like `1/6`) or staggered pattern starts (larger values).

#### `jam.once(beat)`
Returns true exactly once at the specified beat number.
```lua
jam.once(4)      -- True only at beat 4
jam.once(2.5)    -- True only at beat 2.5
```

#### `jam.noteout(note, velocity, duration)`
Send a note to Pure Data's left outlet.
If duration is provided (in beats), a note-off (velocity 0) is automatically scheduled after that many beats. The timing is tick-based, so it tracks tempo changes.

```lua
jam.noteout(60, 100, 1)      -- C4, velocity 100, note-off after 1 beat
jam.noteout(60.5, 100, 1)    -- microtone between C4 and C#4
jam.noteout(60, 100)          -- C4, velocity 100, no automatic note-off
```

- **`note`** - MIDI note number, supports floats for microtonal pitches (e.g. `60.5`)
- **`velocity`** - Note velocity (0-127), supports floats
- **`duration`** - (optional) Duration in beats, schedules automatic note-off

Output format: `note [note] [velocity] [channel]`

#### `jam.flushnotes()`
Send note-off (velocity 0) for all currently sounding notes and cancel all pending scheduled note-offs. Useful for panic/cleanup.

```lua
jam.flushnotes()
```

## Input Handlers

Jam scripts can respond to incoming messages by implementing handler functions:

### `notein(jam, note, velocity)`
Called when a note message arrives.

```lua
function notein(jam, note, velocity)
    -- Process incoming note
end
```

### `msgin(jam, ...)`
Called when a msg message arrives. Receives arbitrary arguments.

```lua
function msgin(jam, ...)
    local args = {...}
    -- Process incoming message
end
```

## Basic Jam Structure

```lua

function init(jam)
    -- Initialize your musical process
end

function tick(jam)
    -- Called every tick - generate music here
end

-- Optional: respond to incoming messages
function notein(jam, note, velocity)
    -- Process incoming MIDI
end

```

## Pure Data Setup

### Creating the Object
```
[jam 180 100]
```
- First argument: ticks per beat (optional, default 180)
- Second argument: BPM (optional, default 100)

### Messages
- **`load [filename]`** - Load a Lua jam script
- **`bang`** - Advance one tick (typically driven by `[metro]`)
- **`linkphase [0-1]`** - Sync to Ableton Link beat phase. Call every DSP block with the current beat phase (0=beat start, 1=beat end). Fires as many ticks as needed to keep `tc` aligned with Link. Handles beat boundary wraparound. When using Link, omit the `[metro]` and drive jam with `linkphase` instead.
- **`float`** - Set tick counter (does not execute tick)
- **`reset`** - Reset tick counter to 0, flush all sounding notes
- **`flushnotes`** - Send note-off for all sounding notes, cancel pending note-offs
- **`bpm [number]`** - Set tempo
- **`tpb [number]`** - Set ticks per beat resolution
- **`note [note] [velocity] [channel]`** - Route to `notein` handler
- **`msg [args...]`** - Route to `msgin` handler
- **`list [function] [args...]`** - Call any Lua function by name (see below)

#### Calling Lua functions from Pd

Any list message whose first element is a symbol will call the Lua function with that name, passing `jam` as the first argument followed by the remaining atoms. This lets you extend jam with custom functions without modifying the C code.

For example, sending `list setscale 0 2 4 5 7 9 11` to the jam object will call:
```lua
function setscale(jam, ...)
    -- args: 0, 2, 4, 5, 7, 9, 11
end
```

If the function doesn't exist in Lua, the message is silently ignored.

### Outlets
- **Left outlet** - Musical messages (`note`, `loaded`, `reset`)
- **Right outlet** - Tick counter (outputs tc before each tick)

## Design Philosophy

Jam provides a **minimal timing and I/O foundation** upon which any musical process can be built:

- **Tick-based timing** - Precise rhythmic control via `jam.every()`
- **Bidirectional MIDI** - Generate notes via `jam.noteout()`, respond via `notein()`
- **Lua flexibility** - Full programming language for algorithms, state, randomness
- **Hot-reloadable** - Edit scripts and reload without restarting Pure Data

The simplicity is intentional: rather than providing high-level musical abstractions, Jam gives you the tools to create your own.
