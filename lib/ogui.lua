-- lib/oled.lua
-- Organelle UI control (OLED screen and LED) via OSC
-- Sends OSC messages through a callback function

local OGUI = {}
OGUI.__index = OGUI

-- Constants
OGUI.SCREEN_WIDTH = 128
OGUI.SCREEN_HEIGHT = 64
OGUI.COLOR_BLACK = 0
OGUI.COLOR_WHITE = 1

-- Text sizes for gCharacter
OGUI.SIZE_8 = 8
OGUI.SIZE_16 = 16
OGUI.SIZE_24 = 24
OGUI.SIZE_32 = 32

-- LED colors
OGUI.LED_OFF = 0
OGUI.LED_RED = 1
OGUI.LED_ORANGE = 2
OGUI.LED_GREEN = 3
OGUI.LED_CYAN = 4
OGUI.LED_BLUE = 5
OGUI.LED_PURPLE = 6
OGUI.LED_WHITE = 7

function OGUI.new(msgout_callback)
    local self = setmetatable({}, OGUI)
    self.msgout = msgout_callback or function() end
    self.default_screen = 0
    return self
end

------------------------------------------------------------------------------
-- LED Control
------------------------------------------------------------------------------

-- Set LED color (0-7)
function OGUI:led(color)
    self.msgout("oled", "/led", color)
end

------------------------------------------------------------------------------
-- Graphics Functions (require flip to update display)
------------------------------------------------------------------------------

-- Show/hide the info bar (VU meters)
function OGUI:showInfoBar(show, screen)
    screen = screen or self.default_screen
    self.msgout("oled", "/oled/gShowInfoBar", screen, show and 1 or 0)
end

-- Clear the screen
function OGUI:clear(screen)
    screen = screen or self.default_screen
    self.msgout("oled", "/oled/gClear", screen, 1)
end

-- Set a single pixel
function OGUI:setPixel(x, y, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gSetPixel", screen, x, y, color)
end

-- Fill an area
function OGUI:fillArea(x, y, width, height, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gFillArea", screen, x, y, width, height, color)
end

-- Draw a circle outline
function OGUI:circle(x, y, radius, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gCircle", screen, x, y, radius, color)
end

-- Draw a filled circle
function OGUI:filledCircle(x, y, radius, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gFilledCircle", screen, x, y, radius, color)
end

-- Draw a line
function OGUI:line(x0, y0, x1, y1, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gLine", screen, x0, y0, x1, y1, color)
end

-- Draw a box outline
function OGUI:box(x, y, width, height, color, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gBox", screen, x, y, width, height, color)
end

-- Invert entire screen
function OGUI:invert(invert, screen)
    screen = screen or self.default_screen
    self.msgout("oled", "/oled/gInvert", screen, invert and 1 or 0)
end

-- Invert a rectangular area
function OGUI:invertArea(x, y, width, height, screen)
    screen = screen or self.default_screen
    self.msgout("oled", "/oled/gInvertArea", screen, x, y, width, height)
end

-- Draw a character
function OGUI:character(char, x, y, color, size, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    size = size or OGUI.SIZE_8
    self.msgout("oled", "/oled/gCharacter", screen, char, y, x, color, size)
end

-- Print text (variable arguments)
function OGUI:println(x, y, height, color, text, screen)
    screen = screen or self.default_screen
    color = color or OGUI.COLOR_WHITE
    self.msgout("oled", "/oled/gPrintln", screen, x, y, height, color, text)
end

-- REQUIRED: Update the display after graphics operations
function OGUI:flip(screen)
    screen = screen or self.default_screen
    self.msgout("oled", "/oled/gFlip", screen)
end

------------------------------------------------------------------------------
-- Legacy Text Functions (update immediately, for patch screen)
------------------------------------------------------------------------------

-- Set line text (lines 1-5)
function OGUI:setLine(line_num, text)
    if line_num < 1 or line_num > 5 then
        error("Line number must be 1-5")
    end
    self.msgout("oled", "/oled/line/" .. line_num, text)
end

-- Invert a line on patch screen (lines 0-4)
function OGUI:invertLine(line_num)
    if line_num < 0 or line_num > 4 then
        error("Line number must be 0-4 for invertLine")
    end
    self.msgout("oled", "/oled/invertline", line_num)
end

------------------------------------------------------------------------------
-- Convenience/Helper Functions
------------------------------------------------------------------------------

-- Clear and flip in one call
function OGUI:reset(screen)
    self:clear(screen)
    self:flip(screen)
end

-- Draw text at position with automatic flip
function OGUI:text(x, y, text, size, color, screen)
    size = size or OGUI.SIZE_8
    color = color or OGUI.COLOR_WHITE
    self:println(x, y, size, color, text, screen)
    self:flip(screen)
end

-- Draw a filled rectangle (alias for fillArea)
function OGUI:rect(x, y, width, height, color, screen)
    self:fillArea(x, y, width, height, color, screen)
end

-- Simple text interface for 5-line display
function OGUI:simpleText(line1, line2, line3, line4, line5)
    if line1 then self:setLine(1, line1) end
    if line2 then self:setLine(2, line2) end
    if line3 then self:setLine(3, line3) end
    if line4 then self:setLine(4, line4) end
    if line5 then self:setLine(5, line5) end
end

return {
    OGUI = OGUI
}