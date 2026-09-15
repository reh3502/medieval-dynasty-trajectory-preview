local R=require("runtime")
local V=require("vector")
local M=require("presentation")
local H={}
-- The native bridge retains output tables. Reuse these across frames, then
-- copy numeric values so published bounds never alias the next native call.
local center_out,extent_out={},{}
-- Positive allow-list: a prop with health is still not a living target.
function H.eligible(actor)
    if not R.valid(actor) then return false end
    local dummy=R.static('/Game/Blueprints/Furnishings/Special/BP_Furniture_TrainingDummy.BP_Furniture_TrainingDummy_C')
    if R.valid(dummy) and actor:IsA(dummy) then return true end
    local character=false
    for _,path in ipairs({'/Script/Medieval_Dynasty.AnimalBase','/Script/Medieval_Dynasty.CharacterBase'}) do
        local class=R.static(path)
        if R.valid(class) and actor:IsA(class) then character=true;break end
    end
    if not character then return false end
    local ok,alive=pcall(function() return actor:IsAlive() end)
    if ok and type(alive)=='boolean' then return alive end
    -- GetHealth is already used by the local-player readiness adapter. Some
    -- interface implementations expose only this getter through reflection.
    local health_ok,health=pcall(function() return actor:GetHealth() end)
    return health_ok and type(health)=='number' and health==health and health>0 and health<math.huge
end
function H.capture(weak)
    local ok,bounds=pcall(function()
        local actor=weak:Get()
        if not H.eligible(actor) then return end
        for key in pairs(center_out) do center_out[key]=nil end
        for key in pairs(extent_out) do extent_out[key]=nil end
        actor:GetActorBounds(true,center_out,extent_out,true)
        local center,extent=R.vec(center_out),R.vec(extent_out)
        if not V.finite(center) or not V.finite(extent)
            or extent.X<=0 or extent.Y<=0 or extent.Z<=0 then return end
        return {center=center,extent=extent}
    end)
    return ok and bounds or nil
end
function H.draw(bounds,camera,project,line,options)
    if not bounds then return end
    local corners={}
    for i=0,7 do
        corners[i]={X=bounds.center.X+((i&1)==0 and -1 or 1)*bounds.extent.X,
            Y=bounds.center.Y+((i&2)==0 and -1 or 1)*bounds.extent.Y,
            Z=bounds.center.Z+((i&4)==0 and -1 or 1)*bounds.extent.Z}
    end
    for i=0,7 do
        for _,bit in ipairs({1,2,4}) do
            if (i&bit)==0 then
                local a,b=corners[i],corners[i|bit]
                local da=V.dot(V.sub(a,camera.origin),camera.forward)
                local db=V.dot(V.sub(b,camera.origin),camera.forward)
                if da>=camera.near or db>=camera.near then
                    if da<camera.near then a=V.lerp(a,b,(camera.near-da)/(db-da))
                    elseif db<camera.near then b=V.lerp(a,b,(camera.near-da)/(db-da)) end
                    local pa,pb=project(a),project(b)
                    if pa and pb then
                        local ca,cb=M.clip(pa,pb,camera.width,camera.height)
                        if ca then line(ca,cb,options.opacity*0.8,options.thickness*2.8,"ribbon") end
                    end
                end
            end
        end
    end
end
return H
