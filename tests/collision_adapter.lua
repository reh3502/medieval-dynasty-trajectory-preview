local C=require("collision")
local observed={Time=0.25,ImpactPoint={X=1,Y=2,Z=3},ImpactNormal={X=0,Y=0,Z=1},bBlockingHit=true}
observed.Actor={Get=function() return {IsValid=function() return true end,
    GetFullName=function() return "Landscape Test" end} end}
local library={SweepMulti=function(self,pawn,query,a,b,rotation,out,debug)
    assert(debug==-1)
    out[1]={get=function() return observed end}
    return true
end}
local hit=C.sweep(library,{},nil,{},{},{})
assert(hit and hit.fraction==0.25 and hit.position.Z==3 and hit.normal.Z==1,
    'Out-array parameter wrapper was not decoded')
assert(hit.actor=="Landscape Test" and hit.component=="<invalid>","Weak contact actor was not decoded")
print('PASS collision out-array wrapper regression')
-- Model the bridge retaining out tables. A long sequence must retain only one
-- table per query kind, and an empty response must never reuse a previous hit.
local buffers={}
local contacts=true
local pooled={SweepMulti=function(_,pawn,query,a,b,rotation,out)
    buffers[out]=true
    assert(next(out)==nil,'A query received stale output')
    if contacts then out[1]={get=function() return observed end};return true end
    return false
end}
for i=1,120 do
    contacts=i%2==1
    assert((C.sweep(pooled,{},nil,{},{},{})~=nil)==contacts)
    assert(C.broad(pooled,{},nil,{},{})==contacts)
end
local count=0;for _ in pairs(buffers) do count=count+1 end
assert(count==2,'Collision output tables accumulate across frames')
print('PASS bounded collision output buffers and no stale contacts')
