


function init(jam)
    print("COOL")
end

function ctlin(jam, ...)
    print("received CC")
end

function msgin(jam, ...)
    print("received message")
end

function notein(jam, ...)
    print("received NOTE")
end

function tick(jam)
    if jam.every(1) then
        jam.msgout("onono", 1, 2)
        jam.noteout(60, 0)
        jam.noteout(60, 100)
        jam.noteout(72, 100, .1)
        jam.cltout(30,20)
    end
end

