local G=require('world_geometry')
local V=require('vector')
local options={thickness=2,marker_radius=7}
local result={status='hit',points={{position=V.new(0,0,0)},{position=V.new(10,0,0)},{position=V.new(20,0,-1)}},
    hit={position=V.new(20,0,-1),normal=V.new(0,0,1),bounds={center=V.new(20,0,0),extent=V.new(5,6,7)}}}
local meshes=G.build(result,V.new(0,0,0),options,false)
assert(#meshes[1].vertices==66 and #meshes[2].vertices==48)
for _,m in ipairs(meshes) do
    assert(#m.vertices==#m.uv and #m.normals==#m.vertices and #m.colors==#m.vertices)
    for _,v in ipairs(m.vertices) do assert(V.finite(v)) end
    for _,index in ipairs(m.triangles) do assert(index>=0 and index<#m.vertices and index%1==0) end
end
-- Contact ring stays in the surface plane, offset 1.5 cm, without moving the hit.
local center=V.new(20,0,0.5)
for _,vertex in ipairs(meshes[1].vertices) do
    local radius=V.length(V.sub(vertex,center))
    assert(math.abs(radius-3.6)<1e-8 or math.abs(radius-4.8)<1e-8)
    assert(math.abs(vertex.Z-0.5)<1e-8)
end
assert(result.hit.position.Z==-1)
local one=G.build(result,V.new(0,-10,0),options,true)
assert(#meshes[1].triangles==2*#one[1].triangles)
assert(#one[1].triangles==64*3)
result.status='range'
local nohit=G.build(result,V.new(0,0,0),options,false)
assert(#nohit[2].vertices==0 and #nohit[1].vertices==0)
-- Short trajectories have no ribbon near the bow.
local large={status='range',points={}}
for i=1,513 do large.points[i]={position=V.new(i,0,i*i/100)} end
assert(#G.build(large,V.new(0,0,0),options,false)[1].vertices<=1030)
large.points[514]=large.points[513]
assert(not pcall(G.build,large,V.new(0,0,0),options,false))
local fade=G.build({status='hit',points={{position=V.new(0,0,0)},{position=V.new(900,0,0)}}},V.new(0,-10,0),options,true)[1]
assert(#fade.vertices==6) -- 450 cm, 650 cm and endpoint.
assert(fade.vertices[1].X==450 and fade.uv[1].X==450)
assert(fade.uv[3].X==650 and fade.uv[5].X==900)
for _,v in ipairs(fade.vertices) do assert(v.X>=450) end
assert(V.length(V.sub(fade.vertices[1],fade.vertices[2]))<=1.11)
print('PASS world ribbon finite geometry, surface ring, index budget, no-hit taper and entity box')

-- Long spear ribbons should upload fewer vertices without moving the curve
-- perceptibly. Test the rendered centerline against every physics sample,
-- including a sharp zigzag that must not be smoothed away.
for _,shape in ipairs({'spear','vertical','zigzag'}) do
    local path={status='horizon',points={}}
    for i=0,300 do
        local t=i/60
        local p=shape=='spear' and V.new(3000*t,0,100+1000*t-490*t*t)
            or (shape=='vertical' and V.new(0,0,100+3000*t-490*t*t)
            or V.new(i*30,(i%2)*10,0))
        path.points[#path.points+1]={position=p}
    end
    local rendered=G.build(path,V.new(0,-100,170),options,true)[1]
    local centers={}
    for i=1,#rendered.vertices,2 do
        centers[#centers+1]=V.scale(V.add(rendered.vertices[i],rendered.vertices[i+1]),0.5)
    end
    if shape=='spear' then assert(#rendered.vertices<320,'long spear ribbon was not reduced') end
    assert(V.length(V.sub(centers[#centers],path.points[#path.points].position))<1e-8)
    local traveled=0
    for i,row in ipairs(path.points) do
        if i>1 then traveled=traveled+V.length(V.sub(row.position,path.points[i-1].position)) end
        if traveled>=450 then
            local best=math.huge
            for j=2,#centers do
                local a,b=centers[j-1],centers[j]
                local delta=V.sub(b,a)
                local length2=V.dot(delta,delta)
                local t=length2==0 and 0 or math.max(0,math.min(1,V.dot(V.sub(row.position,a),delta)/length2))
                best=math.min(best,V.length(V.sub(row.position,V.lerp(a,b,t))))
            end
            assert(best<=0.25000001,'display simplification moved the trajectory too far')
        end
    end
    assert(#path.points==301,'display changed physics samples')
end
print('PASS reduced spear mesh preserves curve within 0.25 cm, endpoint and sharp turns')
