-- Conservative prechecks only reject empty space. Candidate spans still use
-- every original rotated-capsule sweep, in the original order.
local P=require('predict')
local V=require('vector')
local B={padding=24,batch_size=16}
local function distance_to_segment(p,a,b)
    local dx,dy,dz=b.X-a.X,b.Y-a.Y,b.Z-a.Z
    local squared=dx*dx+dy*dy+dz*dz
    local t=squared>0 and math.max(0,math.min(1,((p.X-a.X)*dx+(p.Y-a.Y)*dy+(p.Z-a.Z)*dz)/squared)) or 0
    local x,y,z=p.X-a.X-t*dx,p.Y-a.Y-t*dy,p.Z-a.Z-t*dz
    return math.sqrt(x*x+y*y+z*z)
end
function B.run(snapshot,options,exact,broad,audit)
    local segments={}
    local result=P.run(snapshot,options,function(a,b,velocity,next_velocity)
        segments[#segments+1]={a=a,b=b,velocity=velocity,next_velocity=next_velocity}
        -- Nearby hits are common. Resolve them without generating the long tail.
        if #segments<=4 then return exact(a,b,velocity,next_velocity) end
    end)
    if result.hit then return result end
    local i,distance=math.min(4,#segments)+1,0
    local group,check_group=0,B.audit_cursor or 1
    local audit_offset=B.audit_offset or 0
    local function advance_audit()
        if audit and group>0 then
            B.audit_cursor=check_group%group+1
            if B.audit_cursor==1 then B.audit_offset=(audit_offset+1)%4 end
        end
    end
    for j=1,i-1 do distance=distance+V.length(V.sub(segments[j].b,segments[j].a)) end
    while i<=#segments do
        group=group+1
        local last=math.min(#segments,i+B.batch_size-1)
        -- The convex swept sphere must contain every polyline centre, plus
        -- the entire capsule at every orientation. Split curves that bend too far.
        while last>i do
            local contained=true
            for j=i,last do
                if distance_to_segment(segments[j].a,segments[i].a,segments[last].b)>B.padding then contained=false;break end
            end
            if contained then break end
            last=math.floor((i+last)/2)
        end
        local candidate=last==i or broad(segments[i].a,segments[last].b)
        for j=i,last do
            local s=segments[j]
            -- Check four rotating segments, rather than sixteen extra native
            -- sweeps in one frame. Candidate groups still check every segment.
            local audit_start=i+(audit_offset*4)%(last-i+1)
            local checked=audit and group==check_group and j>=audit_start and j<audit_start+4
            local hit=(candidate or checked) and exact(s.a,s.b,s.velocity,s.next_velocity) or nil
            local length=V.length(V.sub(s.b,s.a))
            if hit then
                if not candidate then B.mismatch=true end
                assert(type(hit.fraction)=='number' and hit.fraction>=0 and hit.fraction<=1 and V.finite(hit.position),'invalid collision result')
                local start,finish=result.points[j].time,result.points[j+1].time
                result.points[j+1]={position=hit.position,time=start+(finish-start)*hit.fraction}
                for k=#result.points,j+2,-1 do result.points[k]=nil end
                result.status='hit';result.hit=hit;result.distance=distance+length*hit.fraction
                advance_audit()
                return result
            end
            distance=distance+length
        end
        i=last+1
    end
    advance_audit()
    return result
end
return B
