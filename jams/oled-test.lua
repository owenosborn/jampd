local oled = require("lib/oled")

function init(jam)
    -- Simple text on patch screen (legacy, immediate update)
    oled.simpleText(jam, 
        "Jam Session", 
        "BPM: 120", 
        "Key: C minor", 
        "", 
        "Ready!")
end

function tick(jam)
    -- Graphics mode (requires flip)
    if jam.every(1) then
        local beat = math.floor(jam.tc / jam.tpb)
        
        oled.clear(jam)
        oled.text(jam, 10, 10, "Beat: " .. beat, oled.SIZE_16)
        oled.circle(jam, 64, 32, 20)
        oled.flip(jam)
    end
end

