local R=require("runtime")
local V=require("vector")
local S=require("state")
local P=require("predict")
local B=require("batched_prediction")
local C=require("collision")
local M=require("presentation")
local U=require("umg")
local T=require("telemetry")
local Performance=require("performance")
local W=require("world_renderer")
local O=require("outline_renderer")
local Preview={}
-- Native out tables are retained by this bridge; keep one for all screen
-- projections and return independent points for clipping/drawing.
local projection_out={}
local last_visible
function Preview.for_release(weapon,now)
    if last_visible and R.valid(weapon) and weapon:GetAddress()==last_visible.weapon
        and now>=last_visible.frame.time and now-last_visible.frame.time<=2 then
        return last_visible.frame,Preview.last==last_visible.frame and "current_frame" or "last_visible_before_animation"
    end
    return nil,"unavailable"
end
local function remember(snap)
    if snap.mode=="ready" then last_visible={weapon=snap.bow:GetAddress(),frame=Preview.last} end
end
local query_cache
local near_contact_active=false
local last_status
local function status(value)
    if value~=last_status then T.log("preview_status",{status=value});last_status=value end
end
-- A capsule is symmetric about local Z; rotate Z onto its flight direction.
local function capsule_rotation(direction,fallback)
    local d=assert(V.unit(direction) or fallback,"zero flight direction")
    if d.Z < -0.999999 then return {X=1,Y=0,Z=0,W=0} end
    local scale=math.sqrt(2*(1+d.Z))
    return {X=-d.Y/scale,Y=d.X/scale,Z=0,W=scale/2}
end
function Preview.frame(pc,config)
    -- Publish telemetry only after a complete draw for this frame. Lost
    -- possession or a missing viewport must never retain an older trajectory.
    Preview.last=nil
    C.target=nil
    local snap,reason=S.capture(pc,config)
    if not snap then if reason~="not_ready" then last_visible=nil end;near_contact_active=false;U.hide();W.hide();O.hide();Preview.last=nil;status(reason);return end
    Performance.stage("capture")
    -- Dim hypothetical paths. Never interpolate speed, positions or collision:
    -- a quick release must use this frame's live draw strength.
    if snap.mode~="ready" then
        local appearance={}
        for key,value in pairs(config) do appearance[key]=value end
        appearance.opacity=config.opacity*(snap.mode=="planning" and 0.65 or 0.45)
        config=appearance
    end
    local world=snap.pawn:GetWorld()
    local gravity=world.PersistentLevel.WorldSettings.WorldGravityZ
    assert(type(gravity)=="number" and gravity<0,"world gravity unavailable")
    local profile=snap.profile
    snap.gravity=V.new(0,0,gravity*profile.gravity_scale)
    snap.drag=P.drag_coefficient(profile.radius,profile.damping,profile.mass)
    snap.drag_interval=0.03333299979567528
    local address=snap.pawn:GetAddress()
    if not query_cache or not R.valid(query_cache.pawn) or not R.valid(query_cache.library)
        or query_cache.address~=address or query_cache.radius~=profile.radius or query_cache.length~=snap.half_length then
        local library,query=C.capsule_query(snap.pawn,profile.radius,snap.half_length)
        query_cache={pawn=snap.pawn,address=address,radius=profile.radius,length=snap.half_length,library=library,query=query}
    end
    local library,query=query_cache.library,query_cache.query
    C.stats={queries=0,raw_hits=0,returned_true=0,blocking=0,touching=0}
    local run=B.mismatch and P.run or B.run
    local launch=snap.family=="spear" and {origin=snap.origin,direction=snap.direction,half_length=snap.half_length} or nil
    Performance.stage("setup")
    local result=run(snap,config,function(a,b,velocity)
        return C.sweep(library,query,snap.pawn,a,b,capsule_rotation(velocity,snap.direction),launch)
    end,function(a,b)
        if not query_cache.broad_query then
            query_cache.broad_library,query_cache.broad_query=C.broad_query(snap.pawn,math.max(profile.radius,snap.half_length),B.padding)
        end
        return C.broad(query_cache.broad_library,query_cache.broad_query,snap.pawn,a,b)
    end,true) -- Audit one rotating group, avoiding an occasional full-arc stall.
    Performance.stage("prediction_collision")
    if B.mismatch and not Preview.broad_mismatch_reported then
        Preview.broad_mismatch_reported=true
        T.log('broadphase_mismatch',{fallback='exact_sweeps'})
    end
    local near_contact=result.hit and result.distance<450
    if config.telemetry and near_contact and not near_contact_active then
        T.log("near_contact",{family=snap.family,mode=snap.mode,distance=result.distance,
            half_length=snap.half_length,origin=snap.origin,eye=snap.camera_origin,hit=result.hit})
    end
    near_contact_active=near_contact or false
    local outlined=O.draw(snap.pawn,result.status=="hit" and C.target or nil)
    C.target=nil
    if outlined and result.hit then result.hit.bounds=nil end
    Performance.stage("outline")
    if config.world_renderer and W.draw(snap.pawn,result,snap.camera_origin,config,snap.pull) then
        Performance.stage("render")
        U.hide()
        status("world:"..snap.mode..":"..result.status)
        Preview.last={collision=C.stats,result=result,projectile=snap.projectile,family=snap.family,speed=snap.speed,pull=snap.pull,mode=snap.mode,release_valid=snap.release_valid,time=T.time(snap.pawn)}
        remember(snap)
        return
    end
    W.hide()
    local layout=R.static("/Script/UMG.Default__WidgetLayoutLibrary")
    local size=layout:GetViewportSize(snap.pawn)
    local dpi=layout:GetViewportScale(snap.pawn)
    assert(dpi>0,"invalid viewport scale")
    local camera={origin=snap.camera_origin,forward=snap.camera_forward,near=1,width=size.X/dpi,height=size.Y/dpi}
    if not U.begin(pc) then status("no_viewport");return end
    local function project(point)
        local out=projection_out
        for key in pairs(out) do out[key]=nil end
        if layout:ProjectWorldLocationToWidgetPosition(pc,point,out,false) then return {X=out.X,Y=out.Y} end
    end
    M.draw(result,camera,project,
        function(a,b,alpha,thickness,style) U.line(a,b,alpha,thickness,config.ribbon_color or config.color,style) end,config)
    if result.status=="hit" and result.hit then
        require("highlight").draw(result.hit.bounds,camera,project,
            function(a,b,alpha,thickness,style) U.line(a,b,alpha,thickness,config.highlight_color or config.color,style) end,config)
    end
    U.finish()
    Performance.stage("render")
    status("drawing:"..snap.mode..":"..result.status)
    Preview.last={collision=C.stats,result=result,projectile=snap.projectile,family=snap.family,speed=snap.speed,pull=snap.pull,mode=snap.mode,release_valid=snap.release_valid,time=T.time(snap.pawn)}
    remember(snap)
end
function Preview.safe_frame(pc,config)
    C.stats=nil
    local started=Performance.begin(config.telemetry)
    local ok,err=pcall(Preview.frame,pc,config)
    if not ok then
        U.hide();W.hide();O.hide();C.target=nil
        local text=tostring(err)
        if text~=last_status then T.log("preview_error",{error=text});last_status=text end
        Preview.last=nil;last_visible=nil
    end
    Performance.finish(started,Preview.last~=nil,C.stats and C.stats.queries or 0,Preview.last and Preview.last.family)
end
return Preview
