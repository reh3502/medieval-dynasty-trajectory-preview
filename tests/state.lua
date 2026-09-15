-- Exercise the actual capture adapter against controlled game-facing inputs.
local S=require("state")
local R=require("runtime")
local C=require("collision")
local owned,aim=R.owned_weapon,C.aim
local function valid() return true end
local origin={X=0,Y=0,Z=0}
local camera={GetLocalBounds=function(_,lo,hi) hi.X=41.18936538696289 end,IsValid=valid,K2_GetComponentLocation=function() return origin end,
    GetForwardVector=function() return {X=1,Y=0,Z=0} end}
local path={ToString=function() return S.copper end}
local asset={GetAssetPathName=function() return path end}
local soft={GetObjectID=function() return asset end}
local bow={Aiming=true,IsArrow=true,isReloading=false,LeftKeyDown=true,
    Speed=2000,MinSpeed=2000,MaxSpeed=11000,Alpha=2000/11000,Arrow=camera,
    CurrentArrow={ProjectileClass_12_0B95F94245C55429626C82B945BFD43C=soft}}
local pawn=setmetatable({IsValid=valid,IsLocallyControlled=valid,ViewMode=1,
    FP_Camera=camera,GetHealth=function() return 100 end,
    GetVelocity=function() return origin end},{__index=function() return false end})
local pc={IsValid=valid,IsLocalPlayerController=valid,Pawn=pawn,
    IsGameMenuActive=false,IsMainMenuActive=false,DialogueChangeToHeirUIOpen=false}
local queries=0
R.owned_weapon=function() return bow,"bow" end
C.aim=function(_,_,endpoint) queries=queries+1;return endpoint end
local ok,err=pcall(function()
    -- Idle and cancelled draw use the live maximum, even with stale draw fields.
    for _,aiming in ipairs({false,true}) do
        bow.Aiming=aiming;bow.LeftKeyDown=false;bow.Speed=5500;bow.Alpha=.5
        local snap=assert(S.capture(pc,{enabled=true}))
        assert(snap.mode=="planning" and snap.speed==11000 and snap.pull==1)
        assert(snap.velocity.X==11000 and snap.release_valid==false)
    end
    bow.Aiming=false;bow.LeftKeyDown=true
    assert(S.capture(pc,{enabled=true}).mode=="planning","Cancelled aim retained draw")
    bow.MaxSpeed=12345
    assert(S.capture(pc,{enabled=true}).speed==12345,"Maximum was hardcoded")
    bow.MaxSpeed=11000;bow.Aiming=true
    -- Track the whole charge, including the non-fireable early portion.
    for _,speed in ipairs({0,1999.9,2000,2000.1,5500,11000,5500}) do
        bow.Speed=speed;bow.Alpha=speed/11000
        local snap=assert(S.capture(pc,{enabled=true}))
        assert(snap.speed==speed and snap.velocity.X==speed and snap.pull==bow.Alpha,
            "Preview did not preserve current draw strength")
        assert(snap.release_valid==(speed>2000),"Incorrect release boundary")
        assert(snap.mode==(speed>2000 and "ready" or "drawing"))
    end
    bow.LeftKeyDown=false
    assert(S.capture(pc,{enabled=true}).speed==11000,"Cancel did not restore full-power guide")
    bow.LeftKeyDown=true
    local before=queries
    for _,entry in ipairs({{"IsArrow",false},{"isReloading",true},
        {"Aiming","unknown"},{"LeftKeyDown","unknown"},{"Speed",0/0},
        {"MaxSpeed",math.huge},{"MaxSpeed",0},{"Alpha",0/0}}) do
        local previous=bow[entry[1]];bow[entry[1]]=entry[2]
        assert(S.capture(pc,{enabled=true})==nil,"Invalid state retained preview: "..entry[1])
        bow[entry[1]]=previous
    end
    -- All suppression gates also apply to the new idle guide.
    bow.LeftKeyDown=false;bow.Aiming=false
    for _,entry in ipairs({{"IsArrow",false},{"isReloading",true}}) do
        local previous=bow[entry[1]];bow[entry[1]]=entry[2]
        assert(S.capture(pc,{enabled=true})==nil)
        bow[entry[1]]=previous
    end
    assert(S.capture(pc,{enabled=false})==nil)
    pawn.ViewMode=2;assert(S.capture(pc,{enabled=true})==nil);pawn.ViewMode=1
    pawn.GetHealth=function() return 0 end
    assert(S.capture(pc,{enabled=true})==nil)
    pawn.GetHealth=function() return 100 end
    pawn["Inventory Open"]=true
    assert(S.capture(pc,{enabled=true})==nil,"Inventory did not suppress preview")
    pawn["Inventory Open"]=false
    path.ToString=function() return "unsupported" end
    assert(S.capture(pc,{enabled=true})==nil,"Unsupported ammo retained preview")
    assert(queries==before,"Invalidated state performed aiming queries")
end)
R.owned_weapon=owned;C.aim=aim
assert(ok,err)
print("PASS idle full-power guide, complete charge tracking, cancel and invalidation")
