local R=require("runtime")
local V=require("vector")
local C={}
-- This UE4SS build retains registry references to reflected out tables.
-- Reuse separate buffers and clear before every call, so a no-hit query cannot
-- see old hits and the bridge cannot retain an ever-growing set of results.
local aim_out,sweep_out,broad_out={},{},{}
local function reset(out)
    for key in pairs(out) do out[key]=nil end
    return out
end
-- Pure ordering/filtering seam shared by the engine adapter and its tests.
function C.first(hits, accept)
    local best
    for _, hit in ipairs(hits) do
        if type(hit.fraction)=="number" and hit.fraction>=0 and hit.fraction<=1
            and V.finite(hit.position) and accept(hit)
            and (not best or hit.fraction<best.fraction) then best=hit end
    end
    return best
end
function C.aim(pawn,start_point,end_point)
    local system=R.static("/Script/Engine.Default__KismetSystemLibrary")
    assert(R.valid(system),"KismetSystemLibrary unavailable")
    local out=reset(aim_out)
    local hit=system:LineTraceSingle(pawn,start_point,end_point,0,false,{pawn},0,out,true,
        {R=0,G=0,B=0,A=0},{R=0,G=0,B=0,A=0},0)
    return hit and R.vec(out.ImpactPoint) or end_point
end
-- Rotated capsule queries use the same native query library as the game.
-- Argument marshalling and actor filtering must pass runtime verification before
-- connecting this adapter to the visible preview.
function C.capsule_query(pawn,radius,half_length)
    local library=R.static("/Script/NeatCollision.Default__NeatCollisionFunctionLibrary")
    assert(R.valid(library),"NeatCollision unavailable")
    local native=require("neat_structs")
    native.register()
    local shape=library:MakeCapsuleCollisionShape(radius,half_length)
    local query=library:MakeCollisionQueryDataFromTraceType(3,true,true,false,{pawn},{},shape)
    native.validate(query)
    return library,query
end
-- Ignore only an initial rear overlap while a spear leaves its launch space.
-- Contacts ahead and later contacts keep the ordinary first-hit behavior.
function C.rear_launch_overlap(hit,a,b,launch)
    if not launch or not hit.initial_overlap or hit.fraction~=0 then return false end
    local movement=V.sub(b,a)
    if V.dot(movement,launch.direction)<=0 then return false end
    if V.dot(V.sub(a,launch.origin),launch.direction)>launch.half_length*2 then return false end
    return V.dot(V.sub(hit.position,launch.origin),launch.direction)<0
end
function C.sweep(library,query,pawn,a,b,rotation,launch)
    local out=reset(sweep_out)
    local returned=library:SweepMulti(pawn,query,a,b,rotation,out,-1)
    if C.stats then
        C.stats.queries=C.stats.queries+1
        C.stats.raw_hits=C.stats.raw_hits+#out
        if returned then C.stats.returned_true=C.stats.returned_true+1 end
    end
    if #out==0 then return end
    local hits={}
    for _,wrapped in ipairs(out) do
        -- UE4SS converts array out-parameters to tables of parameter wrappers.
        local hit=wrapped:get()
        if C.stats then
            if hit.bBlockingHit==true then C.stats.blocking=C.stats.blocking+1 else C.stats.touching=C.stats.touching+1 end
            if not C.stats.first then C.stats.first={time=hit.Time,blocking=hit.bBlockingHit,position=R.vec(hit.ImpactPoint)} end
        end
        if hit.bBlockingHit then
            hits[#hits+1]={weak_actor=R.read(hit,"Actor"),weak_component=R.read(hit,"Component"),initial_overlap=hit.bStartPenetrating==true,fraction=hit.Time,position=R.vec(hit.ImpactPoint),normal=R.vec(hit.ImpactNormal),blocking=true}
        end
    end
    local first=C.first(hits,function(hit)
        local rear=C.rear_launch_overlap(hit,a,b,launch)
        if rear and C.stats then C.stats.rear_overlaps=(C.stats.rear_overlaps or 0)+1 end
        return hit.blocking==true and not rear
    end)
    if first then
        first.actor=R.weak_name(first.weak_actor)
        first.component=R.weak_name(first.weak_component)
        first.weak_component=nil
        first.bounds=require("highlight").capture(first.weak_actor)
        -- Used only during this prediction frame, never included in telemetry.
        if first.bounds then C.target=first.weak_actor:Get() end
        first.weak_actor=nil -- Keep only numeric bounds in prediction/telemetry.
    end
    return first
end
function C.broad_query(pawn,half_length,padding)
    -- A capsule with equal radius and half-height is a sphere. Its radius
    -- encloses the arrow capsule plus the permitted centreline deviation.
    local radius=half_length+padding+1
    local library,query=C.capsule_query(pawn,radius,radius)
    -- Verified build layout: FCollisionQueryParams begins at +8 and its
    -- bFindInitialOverlaps bool is at +17. A broad check must include starts
    -- already touching geometry; otherwise it cannot conservatively reject.
    query.MDTrajectoryByte025=1
    return library,query
end
function C.broad(library,query,pawn,a,b)
    local out=reset(broad_out)
    local hit=library:SweepMulti(pawn,query,a,b,{X=0,Y=0,Z=0,W=1},out,-1)
    if C.stats then
        C.stats.queries=C.stats.queries+1
        C.stats.broad_queries=(C.stats.broad_queries or 0)+1
    end
    -- Any returned contact is a candidate, including overlaps/touches.
    return hit or #out>0
end
return C
