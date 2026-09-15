local P=require('predict')
local V=require('vector')
local options=require('settings').normalize({})
assert(options.max_distance==20000 and options.horizon==5 and options.max_steps==512)
local snapshot={origin=V.new(0,0,0),velocity=V.new(2000,0,0),gravity=V.new(0,0,-980),drag=0,drag_interval=0.03333299979567528}
local count=0
local result=P.run(snapshot,options,function(a,b)
    count=count+1
    if a.X<=7500 and b.X>=7500 then
        local fraction=(7500-a.X)/(b.X-a.X)
        return {fraction=fraction,position=V.lerp(a,b,fraction)}
    end
end)
assert(result.status=='hit' and math.abs(result.hit.position.X-7500)<1e-7)
local last=result.points[#result.points]
assert(math.abs(last.time-3.75)<1e-7)
assert(math.abs(last.position.Z-(-490*3.75^2))<0.05)
assert(count<=512 and #result.points<=513)
-- Range exhaustion still does not invent an impact.
snapshot.velocity=V.new(6000,0,0)
result=P.run(snapshot,options,function() end)
assert(result.status=='range' and not result.hit and math.abs(result.distance-20000)<1e-6)
print('PASS analytic 75 m impact after 3 seconds and bounded 200 m range cutoff')
