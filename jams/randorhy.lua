function init(io)
    print("hi")
    divs = {1/2, 1/4, 1/8, 1}
    divi = 1
end

function tick(io)

    if io.on(1) then 
        divi = math.random(1, #divs)
    end

    if io.on (divs[divi]) then
        io.noteout(60, 100, 1/4)
    end

end
