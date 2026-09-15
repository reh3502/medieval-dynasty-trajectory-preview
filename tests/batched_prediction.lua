local P=require('predict')
local B=require('batched_prediction')
local V=require('vector')
local opts={step=1/60,horizon=5,max_distance=20000,max_steps=512}
local function same(a,b)
 assert(a.status==b.status and #a.points==#b.points)
 assert(math.abs(a.distance-b.distance)<1e-7)
 for i,p in ipairs(a.points) do
  local q=b.points[i]
  assert(V.length(V.sub(p.position,q.position))<1e-8 and math.abs(p.time-q.time)<1e-8)
 end
end
for _,vz in ipairs({-1000,0,6000,11000}) do
 local snap={origin=V.new(0,0,0),velocity=V.new(5500,0,vz),gravity=V.new(0,0,-980),drag=.0000589,drag_interval=.03333299979567528}
 for _,wall in ipairs({50,500,5000,15000,1e9}) do
  local calls,broad=0,0
  local function exact(a,b)
   calls=calls+1
   if a.X<=wall and b.X>=wall then
    local f=(wall-a.X)/(b.X-a.X)
    return {fraction=f,position=V.lerp(a,b,f),normal=V.new(-1,0,0)}
   end
  end
  local baseline=P.run(snap,opts,exact)
  local baseline_calls=calls;calls=0
  local optimized=B.run(snap,opts,exact,function(a,b)
   broad=broad+1
   return a.X-66.2<=wall and b.X+66.2>=wall
  end)
  same(baseline,optimized)
  if wall==50 then assert(broad==0 and calls==baseline_calls) end
  if wall==1e9 then assert(calls+broad<baseline_calls/4) end
 end
end
-- Independently check each group contains every original segment endpoint.
local snap={origin=V.new(0,0,0),velocity=V.new(100,0,2000),gravity=V.new(0,0,-980),drag=0,drag_interval=.03333299979567528}
local path=P.run(snap,opts,function() end)
B.run(snap,opts,function() end,function(a,b)
 local d=V.sub(b,a);local len=V.dot(d,d)
 for _,entry in ipairs(path.points) do
  local p=entry.position
  if p.X>=a.X and p.X<=b.X then
   local t=len>0 and math.max(0,math.min(1,V.dot(V.sub(p,a),d)/len)) or 0
   assert(V.length(V.sub(p,V.add(a,V.scale(d,t))))<=B.padding+1e-7)
  end
 end
 return false
end)
-- A shadow check must preserve a hit and flag an incorrectly clear precheck.
local calls=0
B.audit_cursor=1;B.audit_offset=0
local audited=B.run(snap,opts,function(a,b)
 calls=calls+1
 if calls==6 then return {fraction=.5,position=V.lerp(a,b,.5)} end
end,function() return false end,true)
assert(audited.status=='hit' and B.mismatch==true)
B.mismatch=nil
print('PASS batched collision equivalence, near-hit fast path, curved-span bounds, query reduction and mismatch detection')
-- Every clear-span segment is eventually audited, with at most four extra
-- exact queries per frame after the first four direct launch checks.
B.audit_cursor=1;B.audit_offset=0
local seen={}
local total=#path.points-1
for frame=1,math.ceil(total/16)*4+4 do
 local n=0
 B.run(snap,opts,function(a,b)
  n=n+1
  for i=1,total do
   if path.points[i].position.X==a.X then seen[i]=true;break end
  end
 end,function() return false end,true)
 assert(n<=8,'Audit exceeded four additional exact checks')
end
for i=1,total do assert(seen[i],'Clear segment never audited: '..i) end
print('PASS rotating audit covers every segment with four extra checks per frame')
