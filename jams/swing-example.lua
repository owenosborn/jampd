 
function init(jam)
    print("hi")
end

function tick(jam)
  
    -- play swing using offset
    
    -- down beat notes
    if jam.every(1) then
        jam.noteout(60, 100, .1)
    end 
    
    -- use offset for off beat notes 
    -- 1/2 would strait, .6 a little bit of swing, 2/3 for full triplet feel
    if jam.every(1, 2/3) then  
        jam.noteout(60, 75, .1)
    end 

end
