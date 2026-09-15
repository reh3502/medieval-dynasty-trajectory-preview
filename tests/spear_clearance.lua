local C=require('collision')
local function v(x,y,z) return {X=x,Y=y or 0,Z=z or 0} end
local launch={origin=v(0),direction=v(1),half_length=108}
local rear={initial_overlap=true,fraction=0,position=v(-70)}
assert(C.rear_launch_overlap(rear,v(0),v(50),launch))
assert(not C.rear_launch_overlap(rear,v(0),v(50),nil),'Bow overlap changed')
assert(not C.rear_launch_overlap(rear,v(250),v(300),launch),'Escape extended beyond launch')
assert(not C.rear_launch_overlap(rear,v(0),v(-50),launch),'Throw toward rear wall ignored')
local ahead={initial_overlap=true,fraction=0,position=v(70)}
assert(not C.rear_launch_overlap(ahead,v(0),v(50),launch),'Forward wall ignored')
local entry={initial_overlap=false,fraction=.5,position=v(-10)}
assert(not C.rear_launch_overlap(entry,v(0),v(50),launch),'Ordinary hit ignored')
-- Exercise the real adapter: the rear overlap must not hide another hit ahead.
local function native(x,time,overlap)
 return {get=function() return {Time=time,bStartPenetrating=overlap,bBlockingHit=true,
 ImpactPoint=v(x),ImpactNormal=v(-1)} end}
end
local library={SweepMulti=function(_,_,_,_,_,_,out)
 out[1]=native(-70,0,true);out[2]=native(30,.6,false);return true
end}
local hit=C.sweep(library,{},nil,v(0),v(50),{},launch)
assert(hit and hit.position.X==30 and hit.fraction==.6)
print('PASS spear rear launch clearance preserves forward walls, later hits and bow collisions')
