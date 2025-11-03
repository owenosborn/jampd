
 
function init(io)
    print("hi")
end

function tick(io)
    

    if io.on(1/8) and math.random() > 0 then
        io.ctlout(1, math.random(0,127))
        io.ctlout(2, math.random(0,127))
        io.ctlout(3, math.random(0,127))
    end


end
