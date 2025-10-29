


function init(io)
    print("COOL")
    print(io.tpb)
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
    if io.on(1) then
        io.msgout("onono", 1, 2)
        io.noteout(60, 0)
        io.noteout(60, 100)
        io.noteout(72, 100, .1)
        io.cltout(30,20)
    end
end

