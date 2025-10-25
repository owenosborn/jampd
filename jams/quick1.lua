


function init(io)
    count = 0
end

function tick(io)
    if io.on(1/4) then
        count = count + 3
        count = count % 28
        io.noteout(60 + count, 100, .1)
    end
end

