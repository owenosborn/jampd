# Detect Lua installation
LUA_CFLAGS = $(shell pkg-config --cflags lua5.4 2>/dev/null || \
              pkg-config --cflags lua 2>/dev/null || \
              echo "-I/opt/homebrew/include/lua5.4")
LUA_LIBS = $(shell pkg-config --libs lua5.4 2>/dev/null || \
            pkg-config --libs lua 2>/dev/null || \
            echo "-L/opt/homebrew/lib -llua5.4")

# PD include path (adjust to your PD installation)
PD_CFLAGS = -I/Applications/Pd-0.56-1.app/Contents/Resources/src

jam.pd_darwin: jam.c
	gcc -bundle -undefined dynamic_lookup -o jam.pd_darwin jam.c \
	    $(LUA_CFLAGS) $(LUA_LIBS) $(PD_CFLAGS)

clean:
	rm -f jam.pd_darwin
