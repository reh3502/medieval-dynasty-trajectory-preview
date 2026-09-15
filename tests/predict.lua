local P=require("predict")
local V=require("vector")
local M=require("presentation")
local count=0
local function check(ok,msg) assert(ok,msg); count=count+1 end
local function near(a,b,t) check(math.abs(a-b)<(t or 1e-7), tostring(a).." != "..tostring(b)) end
local options={step=0.02,horizon=1,max_steps=256,max_distance=100000}
local s={origin=V.new(0,0,0),velocity=V.new(100,0,100),gravity=V.new(0,0,-10),drag=0,drag_interval=0.033}
local clear=function() end
local result=P.run(s,options,clear)
local last=result.points[#result.points]
near(last.time,1); near(last.position.X,100); near(last.position.Z,95)
check(result.status=="horizon" and not result.hit,"horizon is not impact")
s.gravity=V.new(0,0,0)
result=P.run(s,options,clear); last=result.points[#result.points]
near(last.position.X,100); near(last.position.Z,100)
local inherited=P.launch_velocity(V.new(1,0,0),100,V.new(20,999,0))
near(inherited.X,120); near(inherited.Y,0)
near(P.launch_velocity(V.new(1,0,0),100,V.new(-20,0,0)).X,80)
near(P.drag(V.new(100,0,0),100,1).X,0)
near(V.length(P.drag(V.new(0,0,0),1,1)),0)
check(P.drag(V.new(100,0,0),0.001,0.033).X<100,"drag loses speed")
-- Independent plane intersection at x=25; must end here, not at horizon.
local calls=0
result=P.run(s,options,function(a,b)
    calls=calls+1
    if a.X<=25 and b.X>=25 then
        local f=(25-a.X)/(b.X-a.X)
        return {fraction=f,position=V.new(25,0,25),normal=V.new(-1,0,0)}
    end
end)
check(result.status=="hit","plane hit missing"); near(result.hit.position.X,25)
near(result.points[#result.points].time,0.25)
check(calls<100,"sweeps continued after hit")
options.max_distance=10
result=P.run(s,options,clear); near(result.distance,10)
check(result.status=="range" and not result.hit,"range is not impact")
options.max_steps=1; options.max_distance=100000
result=P.run(s,options,clear)
check(result.status=="budget" and #result.points==2,"unbounded work")
local state={enabled=true,local_owner=true,supported=true,aiming=true,loaded=true,reloading=false,ui_blocked=false,alive=true,release_valid=true}
check(M.visible(state),"valid shot hidden")
for _,key in ipairs({"enabled","local_owner","supported","aiming","loaded","alive","release_valid"}) do
    state[key]=false; check(not M.visible(state),key.." didn't hide"); state[key]=true
end
for _,key in ipairs({"reloading","ui_blocked"}) do
    state[key]=true; check(not M.visible(state),key.." didn't hide"); state[key]=false
end
local a,b=M.clip({X=-10,Y=50},{X=110,Y=50},100,100)
near(a.X,0); near(b.X,100)
check(M.clip({X=-5,Y=0},{X=-5,Y=100},100,100)==nil,"outside line visible")
local draw_count=0
local cam={origin=V.new(0,0,0),forward=V.new(1,0,0),near=1,width=100,height=100}
M.draw({status="horizon",points={{position=V.new(-5,0,0)},{position=V.new(-1,0,0)}}},cam,function() error('behind camera projected') end,function() draw_count=draw_count+1 end,{})
near(draw_count,0)
print("PASS "..count.." predictor/presentation assertions")
-- Regression: UE4SS struct/container wrappers can be valid without being UObjects.
local R=require("runtime")
check(R.name({IsValid=function() return true end})=="<non-object>","valid struct broke diagnostic naming")
check(R.valid({IsValid=function() return {} end})==false,"non-boolean validity accepted")
print("PASS diagnostic wrapper regression checks")
local C=require("collision")
local hit=C.first({
    {fraction=0.9,position=V.new(9,0,0),blocking=true},
    {fraction=0.1,position=V.new(1,0,0),blocking=false},
    {fraction=0.3,position=V.new(3,0,0),blocking=true},
},function(h) return h.blocking end)
near(hit.fraction,0.3)
check(C.first({},function() return true end)==nil,"empty collision invented hit")
print("PASS unordered collision/filter checks")
