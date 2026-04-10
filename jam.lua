-- jam.lua
-- Test jam: plays a note every beat, prints incoming notes and messages.

function init(jam)
    print("hello")
end

function tick(jam)
    if jam.every(1) then
        jam.noteout(60, 100, 1/2)
    end
end

function notein(jam, note, velocity)
    print("note: " .. note .. " vel: " .. velocity)
end

function msgin(jam, ...)
    local args = {...}
    print("msg: " .. table.concat(args, " "))
end
