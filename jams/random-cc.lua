
 
function init(jam)
    print("hi")
end

function tick(jam)
    

    if jam.on(1/8) and math.random() > 0 then
        jam.ctlout(1, math.random(0,127))
        jam.ctlout(2, math.random(0,127))
        jam.ctlout(3, math.random(0,127))
    end


end
