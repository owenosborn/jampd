


function init(io)
    print("COOL")
end

function ctlin(io, ...)
    print("received CC")
end

function msgin(io, ...)
    print("received message")
end

function notein(io, ...)
    print("received NOTE")
end

function tick(io)
    if jam.on(1) then
        jam.msgout("onono", 1, 2)
        jam.noteout(60, 0)
        jam.noteout(60, 100)
        jam.noteout(72, 100, .1)
        jam.cltout(30,20)
    end
end

