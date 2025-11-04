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

#### `jam.on(interval, offset)`
Returns true when the current tick aligns with a rhythmic interval.

```lua
jam.on(1)       -- Every beat
jam.on(1/4)     -- Every quarter beat (sixteenth notes)
jam.on(2)       -- Every 2 beats
jam.on(1, 1/2)  -- Every beat, offset by half a beat
```

- **`interval`** - Number of beats between triggers (default: 1)
- **`offset`** - Beat offset for rhythmic displacement (default: 0)

#### `jam.noteout(note, velocity, duration)`
Send a note to Pure Data's left outlet.
Duration is in beats, and is optional.  If duration is provided, the note will be output as makenote with duration converted to ms.

```lua
jam.noteout(60, 100, 1)      -- C4, velocity 100, 1 beat duration
```

- **`note`** - MIDI note number (0-127)
- **`velocity`** - Note velocity (0-127)
- **`duration`** - (optional) Duration in beats

Output format no duration: `note [note] [velocity] [channel]`
Output format with duration: `makenote [note] [velocity] [duration] [channel]`

#### `jam.ctlout(controller, value)`
Send a MIDI CC message.

```lua
jam.ctlout(7, 64)      -- Volume to 64 on output channel
```

Output format: `ctl [controller] [value] [channel]`

## Input Handlers

Jam scripts can respond to incoming messages by implementing handler functions:

### `notein(jam, note, velocity)`
Called when a note message arrives.

```lua
function notein(jam, note, velocity)
    -- Process incoming note
end
```

### `ctlin(jam, controller, value)`
Called when a CC message arrives.

```lua
function ctlin(jam, controller, value)
    -- Process incoming CC
end
```

### `msgin(jam, ...)`
Generic fallback for any unhandled list messages.

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
- **`reset`** - Reset tick counter to 0
- **`bpm [number]`** - Set tempo
- **`tpb [number]`** - Set ticks per beat resolution
- **`list note [args]`** - Route to `notein` handler
- **`list ctl [args]`** - Route to `ctlin` handler

### Outlets
- **Left outlet** - Musical messages (`note` and `ctl` lists)
- **Right outlet** - Info and debug messages (prints from Lua)

## Design Philosophy

Jam provides a **minimal timing and I/O foundation** upon which any musical process can be built:

- **Tick-based timing** - Precise rhythmic control via `jam.on()`
- **Bidirectional MIDI** - Generate notes via `jam.noteout()`, respond via `notein()`
- **Lua flexibility** - Full programming language for algorithms, state, randomness
- **Hot-reloadable** - Edit scripts and reload without restarting Pure Data

The simplicity is intentional: rather than providing high-level musical abstractions, Jam gives you the tools to create your own.
