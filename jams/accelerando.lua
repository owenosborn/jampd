

require("lib/chord")

function init(jam)
    div = jam.tpb
end

function tick(jam)
    local beat = jam.tc / jam.tpb
    local duration = 16
    
    local progress = math.min(beat / duration, 1)
    -- Exponential curve feels more natural
    local rate = 1 * math.pow(1/8, progress) 

    div = div - 1 
    if div <= 0  then
        div = (jam.tpb * rate)//1
        jam.noteout(60, 100, 0.1)
    end

end
