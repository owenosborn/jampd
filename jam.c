#include "m_pd.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <math.h>

static t_class *jam_class;

#define MAX_PENDING 256

typedef struct _pending_noteoff {
    struct _pending_noteoff *next;
    long target_tick;
    t_float pitch;
    int channel;
} t_pending_noteoff;

typedef struct _active_note {
    struct _active_note *next;
    t_float pitch;
    int channel;
} t_active_note;

typedef struct _jam {
    t_object x_obj;
    lua_State *L;
    t_outlet *msg_out;     // left outlet: musical messages
    t_outlet *tc_out;      // right outlet: tick counter
    t_float tpb;           // ticks per beat
    t_float bpm;           // beats per minute
    long tc;               // tick counter
    long tc_wrap;          // largest beat-aligned value safe for t_float output
    t_float link_phase_prev; // previous Link beat phase for wraparound detection
    t_pending_noteoff *noteoffs;  // linked list of pending note-offs
    int noteoff_count;            // current count of pending note-offs
    t_active_note *active_notes;  // linked list of sounding notes
    int active_count;             // current count of active notes
} t_jam;

// Remove first matching note from active list
static void jam_remove_active(t_jam *x, t_float pitch, int channel) {
    t_active_note **pp = &x->active_notes;
    while (*pp) {
        t_active_note *a = *pp;
        if (a->pitch == pitch && a->channel == channel) {
            *pp = a->next;
            freebytes(a, sizeof(*a));
            x->active_count--;
            return;
        }
        pp = &a->next;
    }
}

// Output a note message on the left outlet and track active notes
static void jam_output_note(t_jam *x, t_float pitch, t_float velocity, int channel) {
    if (velocity > 0) {
        // Track note-on in active list
        if (x->active_count < MAX_PENDING) {
            t_active_note *a = (t_active_note *)getbytes(sizeof(*a));
            a->pitch = pitch;
            a->channel = channel;
            a->next = x->active_notes;
            x->active_notes = a;
            x->active_count++;
        }
    } else {
        // Remove from active list on note-off
        jam_remove_active(x, pitch, channel);
    }
    t_atom argv[4];
    SETSYMBOL(&argv[0], gensym("note"));
    SETFLOAT(&argv[1], pitch);
    SETFLOAT(&argv[2], velocity);
    SETFLOAT(&argv[3], (t_float)channel);
    outlet_list(x->msg_out, &s_list, 4, argv);
}

// Process pending note-offs: send note-off for any that have reached their target tick
static void jam_process_noteoffs(t_jam *x) {
    t_pending_noteoff **pp = &x->noteoffs;
    while (*pp) {
        t_pending_noteoff *p = *pp;
        if (x->tc >= p->target_tick) {
            jam_output_note(x, p->pitch, 0, p->channel);
            *pp = p->next;
            freebytes(p, sizeof(*p));
            x->noteoff_count--;
        } else {
            pp = &p->next;
        }
    }
}

// Flush all sounding notes: send note-offs for all active notes and clear pending list
static void jam_flushnotes(t_jam *x) {
    // Send note-offs for all active notes
    while (x->active_notes) {
        t_active_note *a = x->active_notes;
        x->active_notes = a->next;
        x->active_count--;
        // Output note-off directly (don't go through jam_output_note to avoid list manipulation)
        t_atom argv[4];
        SETSYMBOL(&argv[0], gensym("note"));
        SETFLOAT(&argv[1], a->pitch);
        SETFLOAT(&argv[2], 0);
        SETFLOAT(&argv[3], (t_float)a->channel);
        outlet_list(x->msg_out, &s_list, 4, argv);
        freebytes(a, sizeof(*a));
    }
    // Clear pending note-offs (their active entries were already flushed above)
    t_pending_noteoff *p;
    while ((p = x->noteoffs)) {
        x->noteoffs = p->next;
        freebytes(p, sizeof(*p));
    }
    x->noteoff_count = 0;
}

// Lua C function to implement jam.noteout()
static int l_noteout(lua_State *L) {
    // Get the jam object from registry
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);

    // Get arguments: note, velocity, duration (optional, in beats)
    double note = luaL_checknumber(L, 1);
    double velocity = luaL_checknumber(L, 2);
    double duration_beats = luaL_optnumber(L, 3, 0.0);

    // Get channel from jam.ch
    lua_getglobal(L, "jam");
    lua_getfield(L, -1, "ch");
    int channel = (int)lua_tonumber(L, -1);
    lua_pop(L, 2);  // pop channel and jam table

    // Fire any pending note-off for this pitch/channel before new note-on
    if (velocity > 0) {
        t_pending_noteoff **pp = &x->noteoffs;
        while (*pp) {
            t_pending_noteoff *p = *pp;
            if (p->pitch == (t_float)note && p->channel == channel) {
                jam_output_note(x, p->pitch, 0, p->channel);
                *pp = p->next;
                freebytes(p, sizeof(*p));
                x->noteoff_count--;
                break;
            }
            pp = &p->next;
        }
    }

    // Output note
    jam_output_note(x, (t_float)note, (t_float)velocity, channel);

    // Schedule note-off if duration given
    if (duration_beats > 0 && velocity > 0) {
        if (x->noteoff_count >= MAX_PENDING) {
            pd_error(x, "jam: noteoff limit (%d) reached, skipping note-off for %.0f",
                     MAX_PENDING, note);
        } else {
            t_pending_noteoff *p = (t_pending_noteoff *)getbytes(sizeof(*p));
            p->pitch = (t_float)note;
            p->channel = channel;
            p->target_tick = x->tc + (long)(duration_beats * x->tpb);
            p->next = x->noteoffs;
            x->noteoffs = p;
            x->noteoff_count++;
        }
    }

    return 0;
}

// Lua C function to implement jam.flushnotes()
static int l_flushnotes(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    jam_flushnotes(x);
    return 0;
}

// Lua C function to implement jam.msgout()
static int l_msgout(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    
    int n = lua_gettop(L);  // number of arguments
    
    if (n == 0) return 0;  // nothing to send
    
    t_atom argv[n];
    
    for (int i = 0; i < n; i++) {
        if (lua_isnumber(L, i + 1)) {
            SETFLOAT(&argv[i], (t_float)lua_tonumber(L, i + 1));
        } else if (lua_isstring(L, i + 1)) {
            SETSYMBOL(&argv[i], gensym(lua_tostring(L, i + 1)));
        } else {
            // For other types, convert to string representation
            SETSYMBOL(&argv[i], gensym("nil"));
        }
    }
    
    outlet_list(x->msg_out, &s_list, n, argv);
    
    return 0;
}

// Lua C function to redirect print() to Pd console
static int l_print(lua_State *L) {
    int n = lua_gettop(L);
    luaL_Buffer b;
    luaL_buffinit(L, &b);
    
    for (int i = 1; i <= n; i++) {
        if (i > 1) luaL_addstring(&b, "\t");
        
        const char *s = luaL_tolstring(L, i, NULL);
        luaL_addstring(&b, s);
        lua_pop(L, 1);  // pop the string created by luaL_tolstring
    }
    
    luaL_pushresult(&b);
    const char *msg = lua_tostring(L, -1);
    
    // Send to Pd console
    post("jam: %s", msg);
    
    return 0;
}

// Lua C function to implement jam.every()
static int l_every(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    
    double interval = luaL_optnumber(L, 1, 1.0);
    double offset = luaL_optnumber(L, 2, 0.0);
    
    long tc = x->tc - (long)(offset * x->tpb);
    if (tc < 0) {
        lua_pushboolean(L, 0);
        return 1;
    }
    
    // check for next tick on timeline
    double ticks_per_interval = x->tpb * interval;
    long intervals_passed = (long)(tc / ticks_per_interval);
    long interval_start_tick = (long)ceil((ticks_per_interval * intervals_passed));
    lua_pushboolean(L, tc == interval_start_tick);

    return 1;
}

// Lua C function to implement jam.once()
static int l_once(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    
    double beat = luaL_checknumber(L, 1);
    long target_tick = (long)(beat * x->tpb);
    
    lua_pushboolean(L, x->tc == target_tick);
    return 1;
}

// Initialize the jam table in Lua
static void init_jam(t_jam *x) {
    lua_State *L = x->L;
    
    // Create jam table
    lua_newtable(L);
    
    // Set properties
    lua_pushnumber(L, x->tpb);
    lua_setfield(L, -2, "tpb");
    
    lua_pushnumber(L, x->bpm);
    lua_setfield(L, -2, "bpm");
    
    lua_pushinteger(L, x->tc);
    lua_setfield(L, -2, "tc");
    
    lua_pushinteger(L, 1);
    lua_setfield(L, -2, "ch");
    
    // Register C functions
    lua_pushcfunction(L, l_noteout);
    lua_setfield(L, -2, "noteout");

    lua_pushcfunction(L, l_flushnotes);
    lua_setfield(L, -2, "flushnotes");

    lua_pushcfunction(L, l_msgout);
    lua_setfield(L, -2, "msgout");

    lua_pushcfunction(L, l_every);
    lua_setfield(L, -2, "every");
    
    lua_pushcfunction(L, l_once);
    lua_setfield(L, -2, "once");

    // Store jam as global
    lua_setglobal(L, "jam");
    
    // Override global print to use our outlet
    lua_pushcfunction(L, l_print);
    lua_setglobal(L, "print");
}

// Update jam values before each tick
static void update_jam(t_jam *x) {
    lua_State *L = x->L;
    
    lua_getglobal(L, "jam");
    if (lua_istable(L, -1)) {
        lua_pushinteger(L, x->tc);
        lua_setfield(L, -2, "tc");
    }
    lua_pop(L, 1);
}

// Recreate the Lua state for a clean reload
static void reset_lua_state(t_jam *x) {
    // Close old state if it exists
    if (x->L) {
        lua_close(x->L);
    }
    
    // Create fresh Lua state
    x->L = luaL_newstate();
    luaL_openlibs(x->L);
    
    // Store pointer to this object in Lua registry
    lua_pushlightuserdata(x->L, x);
    lua_setfield(x->L, LUA_REGISTRYINDEX, "pd_jam_obj");
    
    // Set Lua package path to include current directory and lib/
    lua_getglobal(x->L, "package");
    lua_pushstring(x->L, "./?.lua;./lib/?.lua");
    lua_setfield(x->L, -2, "path");
    lua_pop(x->L, 1);
}

// Load and initialize a jam file
static int load_jam(t_jam *x, t_symbol *s) {
    // Flush all sounding notes before reloading
    jam_flushnotes(x);
    // Reset Lua state for clean reload
    reset_lua_state(x);
    lua_State *L = x->L;
   
    // Find path of script and update package path
    const char *filepath = s->s_name;
    char dirpath[MAXPDSTRING];
    strncpy(dirpath, filepath, MAXPDSTRING);
    char *last_slash = strrchr(dirpath, '/');
    if (last_slash) {
        *last_slash = '\0';  // Truncate to directory
        
        // Update package.path to include:
        // 1. The script's directory
        // 2. The script's directory + /lib
        // 3. Current working directory (where the external is)
        // 4. Current working directory + /lib
        lua_getglobal(L, "package");
        lua_getfield(L, -1, "path");
        const char *current_path = lua_tostring(L, -1);
        
        char new_path[MAXPDSTRING * 4];
        snprintf(new_path, sizeof(new_path), 
                 "%s/?.lua;%s/lib/?.lua;./?.lua;./lib/?.lua;%s", 
                 dirpath, dirpath, current_path);
        
        lua_pop(L, 1);  // pop old path
        lua_pushstring(L, new_path);
        lua_setfield(L, -2, "path");
        lua_pop(L, 1);  // pop package table
    }

    // Load and execute the jam file
    if (luaL_dofile(L, s->s_name) != LUA_OK) {
        pd_error(x, "jam: error loading %s: %s", 
                 s->s_name, lua_tostring(L, -1));
        lua_pop(L, 1);
        return -1;
    }
    
    // Pop any return value from the script (we don't use it)
    lua_settop(L, 0);
    
    // Initialize the jam table (this also overrides print)
    init_jam(x);
    
    // Call global init(jam) if it exists
    lua_getglobal(L, "init");
    if (lua_isfunction(L, -1)) {
        lua_getglobal(L, "jam");
        
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            pd_error(x, "jam: error in init(): %s", lua_tostring(L, -1));
            lua_pop(L, 1);
            return -1;
        }
    } else {
        lua_pop(L, 1);  // pop non-function
    }
    
    // Send load confirmation to left outlet
    outlet_symbol(x->msg_out, gensym("loaded"));
    post("jam: loaded %s", s->s_name);
    return 0;
}

// Handle tick/bang messages
static void jam_bang(t_jam *x) {
    lua_State *L = x->L;

    // Update jam values
    update_jam(x);

    // Output tc on right outlet first
    outlet_float(x->tc_out, (t_float)(x->tc % x->tc_wrap));

    // Call global tick(jam)
    lua_getglobal(L, "tick");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        x->tc++;
        return;
    }

    lua_getglobal(L, "jam");

    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in tick(): %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    // Process pending note-offs after Lua tick (so note-ons go first)
    jam_process_noteoffs(x);

    x->tc++;
}

// Handle float messages - just set tc
static void jam_float(t_jam *x, t_floatarg f) {
    x->tc = (long)f;
    update_jam(x);
}

// Handle note messages: note <note> <velocity> [channel]
static void jam_note(t_jam *x, t_symbol *s, int argc, t_atom *argv) {
    lua_State *L = x->L;
    
    if (argc < 2) {
        pd_error(x, "jam: note requires at least 2 arguments (note, velocity)");
        return;
    }
    
    // Update jam values first
    update_jam(x);
    
    // Get notein handler
    lua_getglobal(L, "notein");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        return;  // No handler, silently ignore
    }
    
    // Push jam table
    lua_getglobal(L, "jam");
    
    // Push note and velocity
    lua_pushnumber(L, atom_getfloat(&argv[0]));
    lua_pushnumber(L, atom_getfloat(&argv[1]));
    
    // Push optional channel
    if (argc >= 3) {
        lua_pushnumber(L, atom_getfloat(&argv[2]));
    }
    
    // Call notein(jam, note, velocity, [channel])
    int nargs = argc >= 3 ? 4 : 3;
    if (lua_pcall(L, nargs, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in notein: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

// Handle msg messages: msg <args>... -> msgin(jam, args...)
static void jam_msg(t_jam *x, t_symbol *s, int argc, t_atom *argv) {
    lua_State *L = x->L;

    // Update jam values first
    update_jam(x);

    // Get msgin handler
    lua_getglobal(L, "msgin");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        return;  // No handler, silently ignore
    }

    // Push jam table
    lua_getglobal(L, "jam");

    // Push all arguments
    for (int i = 0; i < argc; i++) {
        if (argv[i].a_type == A_FLOAT) {
            lua_pushnumber(L, atom_getfloat(&argv[i]));
        } else if (argv[i].a_type == A_SYMBOL) {
            lua_pushstring(L, atom_getsymbol(&argv[i])->s_name);
        }
    }

    // Call msgin(jam, ...)
    if (lua_pcall(L, argc + 1, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in msgin: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

// Handle list messages: list <function_name> <args>...
// Routes to any Lua function by name
static void jam_list(t_jam *x, t_symbol *s, int argc, t_atom *argv) {
    lua_State *L = x->L;
    
    if (argc < 1) return;
    
    // Update jam values first
    update_jam(x);
    
    // Get the function name (first argument must be a symbol)
    const char *func_name = NULL;
    if (argv[0].a_type == A_SYMBOL) {
        func_name = atom_getsymbol(&argv[0])->s_name;
    } else {
        pd_error(x, "jam: list messages require a function name (symbol) as first argument");
        return;
    }
    
    // Look up the function in Lua
    lua_getglobal(L, func_name);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        // Silently ignore if function doesn't exist
        return;
    }
    
    // Push jam table
    lua_getglobal(L, "jam");
    
    // Push remaining arguments (skip the function name)
    for (int i = 1; i < argc; i++) {
        if (argv[i].a_type == A_FLOAT) {
            lua_pushnumber(L, atom_getfloat(&argv[i]));
        } else if (argv[i].a_type == A_SYMBOL) {
            lua_pushstring(L, atom_getsymbol(&argv[i])->s_name);
        }
    }
    
    // Call function_name(jam, ...)
    if (lua_pcall(L, argc, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in %s(): %s", func_name, lua_tostring(L, -1));
        lua_pop(L, 1);
    }
}

// Handle linkphase messages: linkphase <phase 0-1>
// Advances tc to match Link beat phase, firing ticks as needed
static void jam_linkphase(t_jam *x, t_floatarg phase) {
    if (phase < 0.0) return;
    if (phase > 1.0) phase = phase - (long)phase;

    // Compute forward distance around the phase circle (0-1)
    double fwd = phase - x->link_phase_prev;
    if (fwd < 0.0) fwd += 1.0;  // wrap: e.g. 0.99 -> 0.01 = 0.02

    // If forward distance is more than half a beat, phase actually
    // stepped backward (shorter arc is backward). Skip it.
    if (fwd > 0.5) {
        // Don't update link_phase_prev: keep comparing against the
        // pre-jump value so subsequent phases stay filtered until
        // phase naturally catches back up (avoids tc/prev desync).
        return;
    }

    long target = (long)(phase * x->tpb);
    long current = x->tc % (long)x->tpb;

    long delta;
    if (fwd > 0.0 && target < current) {
        // beat boundary crossed (forward wrap)
        delta = ((long)x->tpb - current) + target;
    } else {
        delta = target - current;
    }

    for (long i = 0; i < delta && delta < (long)x->tpb; i++)
        jam_bang(x);

    x->link_phase_prev = phase;
}

// Reset tick counter
static void jam_reset(t_jam *x) {
    x->tc = 0;
    jam_flushnotes(x);
    outlet_symbol(x->msg_out, gensym("reset"));
    post("jam: reset counters");
}

// Set BPM
static void jam_bpm(t_jam *x, t_floatarg f) {
    if (f > 0) {
        x->bpm = f;
        
        // Update jam.bpm in Lua
        lua_State *L = x->L;
        lua_getglobal(L, "jam");
        if (lua_istable(L, -1)) {
            lua_pushnumber(L, x->bpm);
            lua_setfield(L, -2, "bpm");
        }
        lua_pop(L, 1);
        
        post("jam: bpm set to %.1f", x->bpm);
    }
}

// Set TPB
static void jam_tpb(t_jam *x, t_floatarg f) {
    if (f > 0) {
        x->tpb = f;
        
        // Update jam.tpb in Lua
        lua_State *L = x->L;
        lua_getglobal(L, "jam");
        if (lua_istable(L, -1)) {
            lua_pushnumber(L, x->tpb);
            lua_setfield(L, -2, "tpb");
        }
        lua_pop(L, 1);
        
        post("jam: tpb set to %.0f", x->tpb);
    }
}

// Constructor
static void *jam_new(t_symbol *s, int argc, t_atom *argv) {
    t_jam *x = (t_jam *)pd_new(jam_class);
    
    // Set defaults
    x->tpb = 180.0;
    x->bpm = 60.0;
    x->tc = 0;
    x->link_phase_prev = 0.0;
    x->noteoffs = 0;
    x->noteoff_count = 0;
    x->active_notes = 0;
    x->active_count = 0;

    // Parse arguments (optional: tpb, bpm)
    if (argc > 0 && argv[0].a_type == A_FLOAT)
        x->tpb = atom_getfloat(&argv[0]);
    if (argc > 1 && argv[1].a_type == A_FLOAT)
        x->bpm = atom_getfloat(&argv[1]);

    // Largest multiple of tpb below 2^24 (t_float precision limit)
    x->tc_wrap = (16000000L / (long)x->tpb) * (long)x->tpb;

    // Create outlets (left to right)
    x->msg_out = outlet_new(&x->x_obj, &s_list);   // musical messages
    x->tc_out = outlet_new(&x->x_obj, &s_float);   // tick counter
    
    // Initialize Lua
    x->L = luaL_newstate();
    luaL_openlibs(x->L);
    
    // Store pointer to this object in Lua registry
    lua_pushlightuserdata(x->L, x);
    lua_setfield(x->L, LUA_REGISTRYINDEX, "pd_jam_obj");
    
    // Set Lua package path to include current directory and lib/
    lua_getglobal(x->L, "package");
    lua_pushstring(x->L, "./?.lua;./lib/?.lua");
    lua_setfield(x->L, -2, "path");
    lua_pop(x->L, 1);
    
    post("jam: created with tpb=%.0f bpm=%.0f", x->tpb, x->bpm);
    
    return (void *)x;
}

// Destructor
static void jam_free(t_jam *x) {
    jam_flushnotes(x);
    if (x->L) {
        lua_close(x->L);
    }
}

// Setup function
void jam_setup(void) {
    jam_class = class_new(gensym("jam"),
        (t_newmethod)jam_new,
        (t_method)jam_free,
        sizeof(t_jam),
        CLASS_DEFAULT,
        A_GIMME, 0);
    
    class_addbang(jam_class, jam_bang);
    class_addfloat(jam_class, jam_float);
    class_addlist(jam_class, jam_list);
    class_addmethod(jam_class, (t_method)jam_note,
                    gensym("note"), A_GIMME, 0);
    class_addmethod(jam_class, (t_method)jam_msg,
                    gensym("msg"), A_GIMME, 0);
    class_addmethod(jam_class, (t_method)load_jam,
                    gensym("load"), A_SYMBOL, 0);
    class_addmethod(jam_class, (t_method)jam_reset,
                    gensym("reset"), 0);
    class_addmethod(jam_class, (t_method)jam_flushnotes,
                    gensym("flushnotes"), 0);
    class_addmethod(jam_class, (t_method)jam_bpm, 
                    gensym("bpm"), A_FLOAT, 0);
    class_addmethod(jam_class, (t_method)jam_tpb,
                    gensym("tpb"), A_FLOAT, 0);
    class_addmethod(jam_class, (t_method)jam_linkphase,
                    gensym("linkphase"), A_FLOAT, 0);
}
