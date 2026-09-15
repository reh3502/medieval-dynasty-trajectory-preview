-- World centimetres, with camera-facing joined strips and surface-aligned rings.
local V=require('vector')
local G={}
local function cross(a,b) return V.new(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end
local function perpendicular(direction)
    return assert(V.unit(cross(direction,math.abs(direction.Z)<0.9 and V.new(0,0,1) or V.new(0,1,0))))
end
local function mesh() return {vertices={},triangles={},uv={},normals={},colors={}} end
local function strip(out,points,eye,widths,two_sided,uvs,envelopes)
    if #points<2 then return end
    local base=#out.vertices
    local previous
    for i,p in ipairs(points) do
        local tangent=V.unit(V.sub(points[math.min(#points,i+1)],points[math.max(1,i-1)])) or V.new(0,0,1)
        local side=V.unit(cross(tangent,V.sub(eye,p))) or previous or perpendicular(tangent)
        if previous and V.dot(previous,side)<0 then side=V.scale(side,-1) end
        previous=side
        local half=V.scale(side,widths[i]/2)
        out.vertices[#out.vertices+1]=V.sub(p,half)
        out.vertices[#out.vertices+1]=V.add(p,half)
        local normal=V.unit(cross(side,tangent)) or V.new(0,0,1)
        out.normals[#out.normals+1]=normal;out.normals[#out.normals+1]=normal
        out.uv[#out.uv+1]={X=uvs and uvs[i] or 0.95,Y=0}
        out.uv[#out.uv+1]={X=uvs and uvs[i] or 0.95,Y=1}
        local color={R=envelopes and envelopes[i] or 1,G=envelopes and 0 or 1,B=envelopes and 0 or 1,A=1}
        out.colors[#out.colors+1]=color;out.colors[#out.colors+1]=color
        if i>1 then
            local a=base+(i-2)*2
            for _,v in ipairs({a,a+1,a+2,a+1,a+3,a+2}) do out.triangles[#out.triangles+1]=v end
            if not two_sided then
                for _,v in ipairs({a+2,a+1,a,a+2,a+3,a+1}) do out.triangles[#out.triangles+1]=v end
            end
        end
    end
end
function G.build(result,eye,options,two_sided)
    local arc,box=mesh(),mesh()
    local points,widths,uvs,envelopes={},{},{},{}
    assert(#result.points<=513,'trajectory geometry budget exceeded')
    local distance=0
    local function append(p,d)
        if d<450 then return end
        points[#points+1]=p
        -- Omit bow-adjacent geometry; fade over the following two metres.
        uvs[#uvs+1]=d
        widths[#widths+1]=options.thickness*0.55
    end
    for i,p in ipairs(result.points) do
        assert(V.finite(p.position),'invalid trajectory vertex')
        if i>1 then
            local prev=result.points[i-1].position
            local length=V.length(V.sub(p.position,prev))
            for _,boundary in ipairs({450,650}) do
                if distance<boundary and distance+length>boundary then
                    append(V.lerp(prev,p.position,(boundary-distance)/length),boundary)
                end
            end
            distance=distance+length
        end
        append(p.position,distance)
    end
    for i=1,#points do
        local progress=(uvs[i]-450)/math.max(1,distance-450)
        local fade=result.status=='hit' and 1 or math.max(0,math.min(1,(distance-uvs[i])/300))
        envelopes[i]=fade
        widths[i]=widths[i]*(1-0.25*progress)*fade
    end
    -- Merge adjacent display segments only. Prediction and collision samples
    -- remain untouched, and every removed point is within 0.25 cm of its chord.
    -- Keep fade transitions so their UV/color interpolation is unchanged.
    local compact,compact_widths,compact_uvs,compact_envelopes={},{},{},{}
    local i=1
    while i<=#points do
        compact[#compact+1]=points[i]
        compact_widths[#compact_widths+1]=widths[i]
        compact_uvs[#compact_uvs+1]=uvs[i]
        compact_envelopes[#compact_envelopes+1]=envelopes[i]
        local skip=false
        if i+2<=#points and not (uvs[i]<650 and uvs[i+2]>650)
            and not (uvs[i]<distance-300 and uvs[i+2]>distance-300) then
            local a,b,p=points[i],points[i+2],points[i+1]
            local x,y,z=b.X-a.X,b.Y-a.Y,b.Z-a.Z
            local length2=x*x+y*y+z*z
            if length2>0 then
                local t=math.max(0,math.min(1,((p.X-a.X)*x+(p.Y-a.Y)*y+(p.Z-a.Z)*z)/length2))
                local dx,dy,dz=p.X-a.X-t*x,p.Y-a.Y-t*y,p.Z-a.Z-t*z
                skip=dx*dx+dy*dy+dz*dz<=0.25*0.25
            end
        end
        i=i+(skip and 2 or 1)
    end
    strip(arc,compact,eye,compact_widths,two_sided,compact_uvs,compact_envelopes)
    local hit=result.status=='hit' and result.hit
    if hit and V.finite(hit.position) and V.finite(hit.normal) then
        local n=V.unit(hit.normal)
        if n then
            local u=perpendicular(n);local v=cross(n,u)
            local radius=math.max(2,math.min(5,options.marker_radius*0.6))
            local center=V.add(hit.position,V.scale(n,1.5))
            local base=#arc.vertices
            local segments=32
            for i=0,segments do
                local angle=i*2*math.pi/segments
                local radial=V.add(V.scale(u,math.cos(angle)),V.scale(v,math.sin(angle)))
                for side=0,1 do
                    arc.vertices[#arc.vertices+1]=V.add(center,V.scale(radial,radius+(side-0.5)*1.2))
                    arc.normals[#arc.normals+1]=n
                    arc.uv[#arc.uv+1]={X=i/segments,Y=side}
                    arc.colors[#arc.colors+1]={R=1,G=1,B=0,A=1}
                end
                if i>0 then
                    local a=base+(i-1)*2
                    for _,index in ipairs({a,a+1,a+2,a+1,a+3,a+2}) do arc.triangles[#arc.triangles+1]=index end
                    if not two_sided then
                        for _,index in ipairs({a+2,a+1,a,a+2,a+3,a+1}) do arc.triangles[#arc.triangles+1]=index end
                    end
                end
            end
        end
    end
    if hit and hit.bounds then
        local b=hit.bounds;local corners={}
        assert(V.finite(b.center) and V.finite(b.extent),'invalid entity bounds')
        for i=0,7 do
            corners[i]=V.new(b.center.X+((i&1)==0 and -1 or 1)*b.extent.X,
                b.center.Y+((i&2)==0 and -1 or 1)*b.extent.Y,b.center.Z+((i&4)==0 and -1 or 1)*b.extent.Z)
        end
        for i=0,7 do for _,bit in ipairs({1,2,4}) do
            if (i&bit)==0 then strip(box,{corners[i],corners[i|bit]},eye,{options.thickness*0.35,options.thickness*0.35},two_sided) end
        end end
    end
    return {arc,box}
end
return G
