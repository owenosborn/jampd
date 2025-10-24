#include "m_pd.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>

static t_class *jam_class;

typedef struct _jam {
    t_object x_obj;
    lua_State *L;
    t_outlet *msg_out;     // left outlet: musical messages
    t_outlet *info_out;    // right outlet: info/debug
    t_float tpb;           // ticks per beat
    t_float bpm;           // beats per minute
    long tc;               // tick counter
} t_jam;

// Lua C function to implement io.noteout()
static int l_noteout(lua_State *L) {
    // Get the jam object from registry
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    
    // Get arguments: note, velocity, duration (optional, in beats)
    int note = luaL_checkinteger(L, 1);
    int velocity = luaL_checkinteger(L, 2);
    double duration_beats = luaL_optnumber(L, 3, 0.0);
    
    // Get channel from io.ch
    lua_getglobal(L, "io");
    lua_getfield(L, -1, "ch");
    int channel = (int)lua_tonumber(L, -1);
    lua_pop(L, 2);  // pop channel and io table
    
    if (duration_beats > 0) {
        // Calculate duration in milliseconds from beats
        // duration_ms = (duration_beats / bpm) * 60000
        int duration_ms = (int)((duration_beats / x->bpm) * 60000.0);
        
        // Output as makenote format: [makenote 60 100 500 1(
        t_atom argv[5];
        SETSYMBOL(&argv[0], gensym("makenote"));
        SETFLOAT(&argv[1], (t_float)note);
        SETFLOAT(&argv[2], (t_float)velocity);
        SETFLOAT(&argv[3], (t_float)duration_ms);
        SETFLOAT(&argv[4], (t_float)channel);
        outlet_list(x->msg_out, &s_list, 5, argv);
    } else {
        // Output as raw note (no duration): [note 60 100 1(
        t_atom argv[4];
        SETSYMBOL(&argv[0], gensym("note"));
        SETFLOAT(&argv[1], (t_float)note);
        SETFLOAT(&argv[2], (t_float)velocity);
        SETFLOAT(&argv[3], (t_float)channel);
        outlet_list(x->msg_out, &s_list, 4, argv);
    }
    
    return 0;
}

// Lua C function to implement io.cltout()
static int l_cltout(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "pd_jam_obj");
    t_jam *x = (t_jam *)lua_touserdata(L, -1);
    lua_pop(L, 1);
    
    int controller = luaL_checkinteger(L, 1);
    int value = luaL_checkinteger(L, 2);
    
    // Get channel from io.ch
    lua_getglobal(L, "io");
    lua_getfield(L, -1, "ch");
    int channel = (int)lua_tonumber(L, -1);
    lua_pop(L, 2);
    
    // Create and send PD message: [ctl 7 64 1(
    t_atom argv[4];
    SETSYMBOL(&argv[0], gensym("ctl"));
    SETFLOAT(&argv[1], (t_float)controller);
    SETFLOAT(&argv[2], (t_float)value);
    SETFLOAT(&argv[3], (t_float)channel);
    outlet_list(x->msg_out, &s_list, 4, argv);
    
    return 0;
}

// Lua C function to implement io.msgout()
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

// Lua C function to implement io.on()
static int l_on(lua_State *L) {
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
    
    double ticks_per_interval = x->tpb * interval;
    long intervals_passed = (long)(tc / ticks_per_interval);
    long interval_start_tick = (long)(ticks_per_interval * intervals_passed) + 1;
    lua_pushboolean(L, tc == interval_start_tick);

    return 1;
}

// Initialize the io table in Lua
static void init_io(t_jam *x) {
    lua_State *L = x->L;
    
    // Create io table
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
    
    lua_pushcfunction(L, l_cltout);
    lua_setfield(L, -2, "cltout");
 
    lua_pushcfunction(L, l_msgout);
    lua_setfield(L, -2, "msgout");

    lua_pushcfunction(L, l_on);
    lua_setfield(L, -2, "on");
    
    // Store io as global
    lua_setglobal(L, "io");
    
    // Override global print to use our outlet
    lua_pushcfunction(L, l_print);
    lua_setglobal(L, "print");
}

// Update io values before each tick
static void update_io(t_jam *x) {
    lua_State *L = x->L;
    
    lua_getglobal(L, "io");
    if (lua_istable(L, -1)) {
        lua_pushinteger(L, x->tc);
        lua_setfield(L, -2, "tc");
    }
    lua_pop(L, 1);
}

// Load and initialize a jam file
static int load_jam(t_jam *x, t_symbol *s) {
    lua_State *L = x->L;
   
    // Find path of script and update package path
    const char *filepath = s->s_name;
    char dirpath[MAXPDSTRING];
    strncpy(dirpath, filepath, MAXPDSTRING);
    char *last_slash = strrchr(dirpath, '/');
    if (last_slash) {
        *last_slash = '\0';  // Truncate to directory
        
        // Update package.path to include the script's directory
        lua_getglobal(L, "package");
        lua_getfield(L, -1, "path");
        const char *current_path = lua_tostring(L, -1);
        
        char new_path[MAXPDSTRING * 3];
        snprintf(new_path, sizeof(new_path), 
                 "%s/?.lua;%s/lib/?.lua;%s", 
                 dirpath, dirpath, current_path);
        
        lua_pop(L, 1);  // pop old path
        lua_pushstring(L, new_path);
        lua_setfield(L, -2, "path");
        lua_pop(L, 1);  // pop package table
    }

    // Load the jam file
    if (luaL_dofile(L, s->s_name) != LUA_OK) {
        pd_error(x, "jam: error loading %s: %s", 
                 s->s_name, lua_tostring(L, -1));
        lua_pop(L, 1);
        return -1;
    }
    
    // The jam should return a table
    if (!lua_istable(L, -1)) {
        pd_error(x, "jam: %s did not return a table", s->s_name);
        lua_pop(L, 1);
        return -1;
    }
    
    // Store the jam table as global "jam"
    lua_setglobal(L, "jam");
    
    // Initialize the io table (this also overrides print)
    init_io(x);
    
    // Call jam:init(io)
    lua_getglobal(L, "jam");
    lua_getfield(L, -1, "init");
    lua_pushvalue(L, -2);  // push jam table as self
    lua_getglobal(L, "io");
    
    if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in init(): %s", lua_tostring(L, -1));
        lua_pop(L, 1);
        return -1;
    }
    
    lua_pop(L, 1);  // pop jam table
    
    // Send load confirmation to info outlet
    outlet_symbol(x->info_out, gensym("loaded"));
    post("jam: loaded %s", s->s_name);
    return 0;
}

// Handle tick/bang messages
static void jam_bang(t_jam *x) {
    lua_State *L = x->L;
    
    // Update io values
    update_io(x);
    
    // Call jam:tick(io)
    lua_getglobal(L, "jam");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }
    
    lua_getfield(L, -1, "tick");
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 2);
        return;
    }
    
    lua_pushvalue(L, -2);  // push jam table as self
    lua_getglobal(L, "io");
    
    if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in tick(): %s", lua_tostring(L, -1));
        // Also send error to info outlet
        t_atom argv[2];
        SETSYMBOL(&argv[0], gensym("error"));
        SETSYMBOL(&argv[1], gensym(lua_tostring(L, -1)));
        outlet_list(x->info_out, &s_list, 2, argv);
        lua_pop(L, 1);
    }
    
    lua_pop(L, 1);  // pop jam table
    
    // Increment counters
    x->tc++;
}

// Handle list messages - route to specific handlers or fallback
static void jam_list(t_jam *x, t_symbol *s, int argc, t_atom *argv) {
    lua_State *L = x->L;
    
    if (argc < 1) return;
    
    // Update io values first
    update_io(x);
    
    // Get jam table
    lua_getglobal(L, "jam");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }
    
    // Get the command (first argument should be a symbol)
    const char *cmd = NULL;
    if (argv[0].a_type == A_SYMBOL) {
        cmd = atom_getsymbol(&argv[0])->s_name;
    } else {
        lua_pop(L, 1);
        return;  // First arg must be a symbol
    }
    
    // Try to find specific handler (notein, ctlin, etc.)
    char handler_name[64];
    snprintf(handler_name, sizeof(handler_name), "%sin", cmd);
    
    lua_getfield(L, -1, handler_name);
    
    // If no specific handler, try generic on_message
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, -1, "msgin");
        
        // If still no handler, just return
        if (!lua_isfunction(L, -1)) {
            lua_pop(L, 2);
            return;
        }
    }
    
    // Push self (jam table)
    lua_pushvalue(L, -2);
    
    // Push io table
    lua_getglobal(L, "io");
    
    // Push remaining arguments (skip the command name for specific handlers)
    for (int i = 1; i < argc; i++) {
        if (argv[i].a_type == A_FLOAT) {
            lua_pushnumber(L, atom_getfloat(&argv[i]));
        } else if (argv[i].a_type == A_SYMBOL) {
            lua_pushstring(L, atom_getsymbol(&argv[i])->s_name);
        }
    }
    
    // Call jam:on_XXX(io, ...) or jam:on_message(io, ...)
    if (lua_pcall(L, argc + 1, 0, 0) != LUA_OK) {
        pd_error(x, "jam: error in %s: %s", handler_name, lua_tostring(L, -1));
        lua_pop(L, 1);
    }
    
    lua_pop(L, 1);  // pop jam table
}

// Reset tick counter
static void jam_reset(t_jam *x) {
    x->tc = 0;
    outlet_symbol(x->info_out, gensym("reset"));
    post("jam: reset counters");
}

// Set BPM
static void jam_bpm(t_jam *x, t_floatarg f) {
    if (f > 0) {
        x->bpm = f;
        
        // Update io.bpm in Lua
        lua_State *L = x->L;
        lua_getglobal(L, "io");
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
        
        // Update io.tpb in Lua
        lua_State *L = x->L;
        lua_getglobal(L, "io");
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
    x->bpm = 100.0;
    x->tc = 0;
    
    // Parse arguments (optional: tpb, bpm)
    if (argc > 0 && argv[0].a_type == A_FLOAT)
        x->tpb = atom_getfloat(&argv[0]);
    if (argc > 1 && argv[1].a_type == A_FLOAT)
        x->bpm = atom_getfloat(&argv[1]);
    
    // Create outlets (left to right)
    x->msg_out = outlet_new(&x->x_obj, &s_list);   // musical messages
    x->info_out = outlet_new(&x->x_obj, &s_symbol); // info/debug
    
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
    class_addlist(jam_class, jam_list);  // Handle list messages
    class_addmethod(jam_class, (t_method)load_jam, 
                    gensym("load"), A_SYMBOL, 0);
    class_addmethod(jam_class, (t_method)jam_reset, 
                    gensym("reset"), 0);
    class_addmethod(jam_class, (t_method)jam_bpm, 
                    gensym("bpm"), A_FLOAT, 0);
    class_addmethod(jam_class, (t_method)jam_tpb, 
                    gensym("tpb"), A_FLOAT, 0);
}
