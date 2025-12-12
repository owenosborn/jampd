-- lib/oled.lua
-- Organelle OLED screen control via OSC
-- Sends OSC messages through jam.msgout() to be routed in Pd

local OLED = {}

-- Constants
OLED.SCREEN_WIDTH = 128
OLED.SCREEN_HEIGHT = 64
OLED.COLOR_BLACK = 0
OLED.COLOR_WHITE = 1

-- Text sizes for gCharacter
OLED.SIZE_8 = 8
OLED.SIZE_16 = 16
OLED.SIZE_24 = 24
OLED.SIZE_32 = 32

-- Default screen number
local default_screen = 0

------------------------------------------------------------------------------
-- Graphics Functions (require gFlip to update display)
------------------------------------------------------------------------------

-- Show/hide the info bar (VU meters)
function OLED.showInfoBar(jam, show, screen)
    screen = screen or default_screen
    jam.msgout("oled", "/oled/gShowInfoBar", screen, show and 1 or 0)
end

-- Clear the screen
function OLED.clear(jam, screen)
    screen = screen or default_screen
    jam.msgout("oled", "/oled/gClear", screen, 1)
end

-- Set a single pixel
function OLED.setPixel(jam, x, y, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gSetPixel", screen, x, y, color)
end

-- Fill an area
function OLED.fillArea(jam, x, y, width, height, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gFillArea", screen, x, y, width, height, color)
end

-- Draw a circle outline
function OLED.circle(jam, x, y, radius, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gCircle", screen, x, y, radius, color)
end

-- Draw a filled circle
function OLED.filledCircle(jam, x, y, radius, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gFilledCircle", screen, x, y, radius, color)
end

-- Draw a line
function OLED.line(jam, x0, y0, x1, y1, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gLine", screen, x0, y0, x1, y1, color)
end

-- Draw a box outline
function OLED.box(jam, x, y, width, height, color, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gBox", screen, x, y, width, height, color)
end

-- Invert entire screen
function OLED.invert(jam, invert, screen)
    screen = screen or default_screen
    jam.msgout("oled", "/oled/gInvert", screen, invert and 1 or 0)
end

-- Invert a rectangular area
function OLED.invertArea(jam, x, y, width, height, screen)
    screen = screen or default_screen
    jam.msgout("oled", "/oled/gInvertArea", screen, x, y, width, height)
end

-- Draw a character
function OLED.character(jam, char, x, y, color, size, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    size = size or OLED.SIZE_8
    jam.msgout("oled", "/oled/gCharacter", screen, char, y, x, color, size)
end

-- Print text (variable arguments)
function OLED.println(jam, x, y, height, color, text, screen)
    screen = screen or default_screen
    color = color or OLED.COLOR_WHITE
    jam.msgout("oled", "/oled/gPrintln", screen, x, y, height, color, text)
end

-- REQUIRED: Update the display after graphics operations
function OLED.flip(jam, screen)
    screen = screen or default_screen
    jam.msgout("oled", "/oled/gFlip", screen)
end

------------------------------------------------------------------------------
-- Legacy Text Functions (update immediately, for patch screen)
------------------------------------------------------------------------------

-- Set line text (lines 1-5)
function OLED.setLine(jam, line_num, text)
    if line_num < 1 or line_num > 5 then
        error("Line number must be 1-5")
    end
    jam.msgout("oled", "/oled/line/" .. line_num, text)
end

-- Invert a line on patch screen (lines 0-4)
function OLED.invertLine(jam, line_num)
    if line_num < 0 or line_num > 4 then
        error("Line number must be 0-4 for invertLine")
    end
    jam.msgout("oled", "/oled/invertline", line_num)
end

------------------------------------------------------------------------------
-- Convenience/Helper Functions
------------------------------------------------------------------------------

-- Clear and flip in one call
function OLED.reset(jam, screen)
    OLED.clear(jam, screen)
    OLED.flip(jam, screen)
end

-- Draw text at position with automatic flip
function OLED.text(jam, x, y, text, size, color, screen)
    size = size or OLED.SIZE_8
    color = color or OLED.COLOR_WHITE
    OLED.println(jam, x, y, size, color, text, screen)
    OLED.flip(jam, screen)
end

-- Draw a filled rectangle (alias for fillArea)
function OLED.rect(jam, x, y, width, height, color, screen)
    OLED.fillArea(jam, x, y, width, height, color, screen)
end

-- Simple text interface for 5-line display
function OLED.simpleText(jam, line1, line2, line3, line4, line5)
    if line1 then OLED.setLine(jam, 1, line1) end
    if line2 then OLED.setLine(jam, 2, line2) end
    if line3 then OLED.setLine(jam, 3, line3) end
    if line4 then OLED.setLine(jam, 4, line4) end
    if line5 then OLED.setLine(jam, 5, line5) end
end

return OLED
