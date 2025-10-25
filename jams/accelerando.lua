

require("lib/chord")

function init(io)
    div = io.tpb
end

function tick(io)
    local beat = io.tc / io.tpb
    local duration = 16
    
    local progress = math.min(beat / duration, 1)
    -- Exponential curve feels more natural
    local rate = 1 * math.pow(1/8, progress) 

    div = div - 1 
    if div <= 0  then
        div = (io.tpb * rate)//1
        io.noteout(60, 100, 0.1)
    end

end
