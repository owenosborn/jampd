# Jam

Jam is an environment for sketching musical ideas in Lua.

Jam doesn't make any sound itself, it only makes messages. Think of it as operating at the control rate: it specifies *what* to play, but doesn't create sound. Like MIDI, Jam describes notes and events, and it's up to whatever you connect it to (a synth, a sampler, a DAW) to make those notes audible.

Jam was inspired by creative coding platforms like Processing, and openFrameworks, which all model behavior based on the same pattern: something that happens once at the beginning (setup) and something that happens again and again (draw). Where these systems operate in the graphical domain, Jam lets us do something similar with music. After initialization, Jam calls a function once per tick, where a tick is a tiny subdivision of the musical beat. Inside this function we can generate notes and other messages, similar to drawing shapes on a screen. 

Currently Jam is implemented as a Pure Data external, allowing you to load and run Jam scripts right in Pd.

See Jam in action inside the Critter & Guitari (PLAY patches)[https://patchstorage.com/play-patches-2/] for the Organelle, documented [here](https://critterandguitari.github.io/cg-docs/Organelle/organelle_programming/#22-the-faust-lua-jam-patch).

## The Jam Script

Die Kunst der Jam.

A jam script specifies musical behavior with up to four functions (all optional):

- **`init(jam)`** — called once at the beginning, sets initial conditions
- **`tick(jam)`** — called once per tick, this is where you generate music
- **`notein(jam, note, velocity)`** — called when a note arrives into the jam system
- **`msgin(jam, ...)`** — called when any other a message arrives into the jam system

```lua
function init(jam)
    -- set initial conditions
end

function tick(jam)
    -- generate music here
end

function notein(jam, note, velocity)
    -- respond to incoming notes
end

function msgin(jam, ...)
    -- respond to incoming messages
end
```

## The jam Object

All four functions receive the `jam` object, which provides the context in which your script is running: where you are in musical time, and how to send information out.

### Timing Properties

| Property   | Description                                          | Default |
|------------|------------------------------------------------------|---------|
| `jam.tc`   | Global tick counter — number of ticks since init     | 0       |
| `jam.tpb`  | Ticks per beat (usually constant for the whole jam)  | 180     |
| `jam.bpm`  | Current beats per minute                             | 100     |
| `jam.ch`   | MIDI output channel (appended to outgoing notes)     | 1       |

### jam.every(interval, offset)

Evaluates to true at the given beat period. This is how you build rhythmic patterns.

```lua
jam.every(1)       -- once per beat
jam.every(1/2)     -- every half beat (eighth notes)
jam.every(1/4)     -- every quarter beat (sixteenth notes)
jam.every(2)       -- every two beats (half notes)
jam.every(1, 1/2)  -- every beat, offset by half a beat
```

- **interval** — number of beats between triggers (default: 1)
- **offset** — beat offset for rhythmic displacement (default: 0). Delays triggers by this many beats. Does not wrap — an offset of 2.5 delays by exactly 2.5 beats. Returns false until the offset time has elapsed. Useful for swing (small values like `1/6`) or staggering pattern starts.

### jam.once(beat)

Evaluates to true exactly once at the specified beat number.

```lua
jam.once(0)      -- first tick, right after init
jam.once(4)      -- at beat 4
jam.once(2.5)    -- at beat 2.5
```

### jam.noteout(note, velocity, duration)

Sends a note out. If you specify a duration (in beats), Jam automatically schedules a note-off after that many beats.

```lua
jam.noteout(60, 100, 1)      -- C4, velocity 100, 1 beat long
jam.noteout(60.5, 100, 1)    -- microtone between C4 and C#4
jam.noteout(60, 100)          -- no automatic note-off
```

- **note** — MIDI note number. Supports floats for microtonal pitches (e.g. `60.5`)
- **velocity** — 0–127
- **duration** — (optional) length in beats, schedules automatic note-off

The current value of `jam.ch` is appended to every outgoing note. Set it before calling `noteout` to route notes to different channels — for example, drums on one channel and bass on another:

```lua
function tick(jam)
    if jam.every(1) then
        jam.ch = 1
        jam.noteout(36, 100, 1/4)  -- kick drum on channel 1

        jam.ch = 2
        jam.noteout(36, 90, 1)     -- bass note on channel 2
    end
end
```

### jam.msgout(...)

Sends an arbitrary message out. Use this for anything that isn't a note: synth parameters, continuous controllers, OSC-style messages, Pd-style lists. It's up to whatever you have Jam connected to to interpret the data.

```lua
jam.msgout("cc", 21, 64)           -- send a CC message
jam.msgout("osc", "/filter", 0.5)  -- send an OSC-style message
```

### jam.flushnotes()

Sends note-off for all currently sounding notes and cancels all pending note-offs. Panic button.

## Examples

### Play one note at the start

```lua
function init(jam)
    jam.noteout(60, 100, 1)  -- C4, one beat long
end
```

### Play a note every beat

```lua
function tick(jam)
    if jam.every(1) then
        jam.noteout(60, 100, 1/2)
    end
end
```

### Pass input notes to output

```lua
function notein(jam, note, velocity)
    jam.noteout(note, velocity)
end
```

### Simple arpeggiator

```lua
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
```

### Walk up a minor scale

```lua
function init(jam)
    scale = {0, 2, 3, 5, 7, 8, 10}
    step = 1
end

function tick(jam)
    if jam.every(1/2) then
        jam.noteout(60 + scale[step], 90, 1/4)
        step = (step % #scale) + 1
    end
end
```

### A simple melody

```lua
function init(jam)
    melody = {60, 62, 64, 65, 67, 65, 64, 62}
    idx = 1
end

function tick(jam)
    if jam.every(1) then
        jam.noteout(melody[idx], 100, 3/4)
        idx = (idx % #melody) + 1
    end
end
```

### Send an LFO message

```lua
function tick(jam)
    local beats = jam.tc / jam.tpb
    local lfo = math.floor((math.sin(2 * math.pi * beats / 8) + 1) / 2 * 127)

    if jam.every(1/8) then
        jam.msgout("cc", 21, lfo)
    end
end
```

More examples in the [example-jams](example-jams/) folder.

## The Jam Library

The Jam library is a collection of Lua modules designed to play nicely with the Jam system. Documentation is in a separate file (see [lib/JAM-LIBRARY.md](lib/JAM-LIBRARY.md)).

Modules include:

- **chord** — chord construction and note filtering
- **progression** — chord progressions from string notation
- **sequencer** — step sequencing
- **subjam** — run jams inside other jams
- **utils** — general-purpose helpers

## Jam in Pure Data

Currently, Jam is implemented as a Pure Data external. Pd is a natural fit because it provides MIDI I/O, sound synthesis, and a metronome — everything Jam needs to turn its messages into music.

### Creating the object

```
[jam 180 100]
```

First argument is ticks per beat (default 180), second is BPM (default 100). To run your jam, just bang the object at the tick rate. The Lua interpreter is lightweight, so running many jam objects (tens or even hundreds) in a single patch is no problem.

### Messages

| Message | What it does |
|---------|-------------|
| `load <filename>` | Load a Lua jam script |
| `bang` | Advance one tick (typically driven by `[metro]`) |
| `reset` | Reset tick counter to 0, flush all sounding notes |
| `flushnotes` | Note-off for all sounding notes, cancel pending note-offs |
| `bpm <number>` | Set tempo |
| `tpb <number>` | Set ticks per beat resolution |
| `note <note> <vel> <ch>` | Route to `notein` handler |
| `msg <args...>` | Route to `msgin` handler |
| `linkphase <0-1>` | Sync to Ableton Link beat phase (see below) |
| `list <function> <args...>` | Call any Lua function by name (see below) |

### Outlets

- **Left** — musical messages (`note`, `msg`, `loaded`, `reset`)
- **Right** — tick counter (outputs `tc` before each tick)

### Ableton Link

Instead of driving Jam with `[metro]` + `bang`, you can sync to Ableton Link by sending `linkphase` every DSP block with the current beat phase (0 = beat start, 1 = beat end). Jam fires as many ticks as needed to stay aligned with Link, handling beat boundary wraparound.

### Calling Lua functions from Pd

A handy consequence of running inside Pd: any list message whose first element is a symbol calls the Lua function with that name, passing `jam` as the first argument followed by the remaining values. This is a convenient shortcut for dispatching messages — instead of routing through `msgin` and checking the name there, you can define a function directly in your script.

```
[list setscale 0 2 4 5 7 9 11]
```

calls:

```lua
function setscale(jam, ...)
    local args = {...}  -- 0, 2, 4, 5, 7, 9, 11
end
```

If the function doesn't exist, the message is silently ignored.

See the Pd help patch for more details.
