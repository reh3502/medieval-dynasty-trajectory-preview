local H=require("highlight")
local find=StaticFindObject
StaticFindObject=function(path) return {path=path,IsValid=function() return true end} end
local kind,alive='animal',true
local buffers={}
local complete=true
local actor={IsValid=function() return true end,IsA=function(_,class)
    return (kind=='animal' and class.path=='/Script/Medieval_Dynasty.AnimalBase')
        or (kind=='character' and class.path=='/Script/Medieval_Dynasty.CharacterBase')
        or (kind=='dummy' and class.path:find('BP_Furniture_TrainingDummy',1,true)~=nil)
end,IsAlive=function() return alive end,GetHealth=function() return 100 end,
    GetActorBounds=function(_,colliding,center,extent,children)
        assert(colliding and children)
        buffers[center]=true;buffers[extent]=true
        assert(next(center)==nil and next(extent)==nil,'Stale native bounds output')
        center.X=10;center.Y=0;center.Z=0
        extent.X=1;extent.Y=2;if complete then extent.Z=3 end
    end}
local ok,err=pcall(function()
    local weak={Get=function() return actor end}
    local bounds=assert(H.capture(weak))
    assert(bounds.extent.Z==3)
    kind='house';assert(H.capture(weak)==nil) -- Even if a building has health.
    kind='animal';alive=false;assert(H.capture(weak)==nil)
    kind='character';assert(H.capture(weak)==nil)
    alive=true;assert(H.capture(weak))
    kind='dummy';alive=false;assert(H.capture(weak))
    kind='animal';alive=true
    assert(H.capture(nil)==nil)
    for _=1,120 do assert(H.capture(weak)) end
    local count=0;for _ in pairs(buffers) do count=count+1 end
    assert(count==2,'Native bounds buffers accumulate across frames: '..count)
    complete=false;assert(H.capture(weak)==nil,'Incomplete bounds reused a previous extent')
    assert(bounds.extent.Z==3,'Retained numeric bounds changed with native buffer')
    complete=true
    local camera={origin={X=0,Y=0,Z=0},forward={X=1,Y=0,Z=0},near=1,width=100,height=100}
    local lines=0
    local function project(p) assert(p.X>=1);return {X=50+p.Y,Y=50+p.Z} end
    local function line(a,b) lines=lines+1;assert(a.X>=0 and b.X<=100) end
    H.draw(bounds,camera,project,line,{opacity=1,thickness=2})
    assert(lines==12,"Whole entity box must contain 12 edges")
    lines=0;bounds.center.X=-10
    H.draw(bounds,camera,project,line,{opacity=1,thickness=2})
    assert(lines==0,"Behind-camera box was drawn")
    bounds.center.X=1
    H.draw(bounds,camera,project,line,{opacity=1,thickness=2})
    assert(lines>0 and lines<=12,"Near-plane clipping lost visible box")
end)
StaticFindObject=find
assert(ok,err)
print("PASS living-target and dummy allow-list, dead/prop exclusion and box clipping")
