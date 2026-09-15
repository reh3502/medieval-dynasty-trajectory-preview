-- Exercise the real predictor/preview path through both renderer boundaries.
local Preview=require('preview')
local S=require('state')
local C=require('collision')
local W=require('world_renderer')
local O=require('outline_renderer')
local U=require('umg')
local T=require('telemetry')
local originals={capture=S.capture,query=C.capsule_query,sweep=C.sweep,
    broad_query=C.broad_query,broad=C.broad,draw=W.draw,outline=O.draw,
    hide=U.hide,time=T.time,log=T.log,world_hide=W.hide,begin=U.begin,
    line=U.line,finish=U.finish,find=StaticFindObject}
local pawn={IsValid=function() return true end,GetAddress=function() return 101 end,GetWorld=function() return {PersistentLevel={WorldSettings={WorldGravityZ=-980}}} end}
local mode,speed='planning',11000
local half_length=41.18936538696289
S.capture=function()
    return {profile={radius=.5,mass=1,damping=.05,gravity_scale=1},half_length=half_length,bow={GetAddress=function() return 313 end},pawn=pawn,origin={X=0,Y=0,Z=0},direction={X=1,Y=0,Z=0},
        velocity={X=speed,Y=0,Z=0},camera_origin={X=-1000,Y=0,Z=0},
        camera_forward={X=1,Y=0,Z=0},speed=speed,pull=speed/11000,
        mode=mode,release_valid=mode=='ready'}
end
local queries=0
C.capsule_query=function() queries=queries+1;return {IsValid=function() return true end},{} end
C.broad_query=function() return {},{} end
C.broad=function() return false end
C.sweep=function(_,_,_,_,_,rotation)
    for _,n in pairs(rotation) do assert(n==n and math.abs(n)<math.huge) end
end
local rendered,opacity,pull
local use_world=true
W.draw=function(_,result,_,options,strength)
    rendered=result;opacity=options.opacity;pull=strength;return use_world
end
W.hide=function() end
O.draw=function() return false end
U.hide=function() end
U.begin=function() return true end
local lines=0
local projection_buffers={}
U.line=function(_,_,alpha) assert(alpha>=0 and alpha<=opacity);lines=lines+1 end
U.finish=function() end
StaticFindObject=function()
    return {IsValid=function() return true end,GetViewportSize=function() return {X=2000,Y=1000} end,
        GetViewportScale=function() return 1 end,
        ProjectWorldLocationToWidgetPosition=function(_,_,p,out)
            projection_buffers[out]=true
            assert(next(out)==nil,'Projection received stale output')
            out.X=100+p.X/100;out.Y=500+p.Z/100;return true
        end}
end
T.time=function() return 1 end
T.log=function() end
local config={enabled=true,world_renderer=true,opacity=.8,step=1/60,horizon=1,
    max_distance=20000,max_steps=512,thickness=2,marker_radius=7,telemetry=false}
local ok,err=pcall(function()
    for _,world in ipairs({true,false}) do
        use_world=world
        for _,entry in ipairs({{'planning',11000,.52},{'drawing',0,.36},
            {'drawing',2000,.36},{'ready',5500,.8},{'ready',11000,.8},
            {'ready',5500,.8},{'planning',11000,.52}}) do
            mode,speed=entry[1],entry[2]
            Preview.frame({},config)
            assert(Preview.last and Preview.last.mode==mode and Preview.last.speed==speed)
            assert(Preview.last.release_valid==(mode=='ready'))
            assert(rendered.points[2].position.X==speed/60,'Path delayed or interpolated')
            assert(math.abs(opacity-entry[3])<1e-8 and pull==speed/11000)
            assert(config.opacity==.8,'Mode permanently changed settings')
        end
    end
    assert(queries==1,"Stable shape rebuilt the native query")
    half_length=100
    Preview.frame({},config)
    assert(queries==2,'Changed projectile bounds reused old query')
    pawn.GetAddress=function() return 202 end
    Preview.frame({},config)
    assert(queries==3,'Changed pawn reused old owner filter')
    assert(lines>0,'Fallback renderer was not exercised')
    local count=0;for _ in pairs(projection_buffers) do count=count+1 end
    assert(count==1,'Projection output buffers accumulate across frames: '..count)
    mode='ready';Preview.frame({},config)
    local weapon={IsValid=function() return true end,GetAddress=function() return 313 end}
    local current,basis=Preview.for_release(weapon,1)
    assert(current==Preview.last and basis=='current_frame')
    Preview.last=nil
    local remembered,source=Preview.for_release(weapon,1.5)
    assert(remembered==current and source=='last_visible_before_animation')
    assert(Preview.for_release(weapon,4)==nil,'Old aim associated with new shot')
    assert(Preview.for_release(weapon,.5)==nil,'Previous world time associated with shot')
    weapon.GetAddress=function() return 414 end
    assert(Preview.for_release(weapon,1.5)==nil,'Wrong weapon associated with shot')
end)
S.capture=originals.capture;C.capsule_query=originals.query;C.sweep=originals.sweep
C.broad_query=originals.broad_query;C.broad=originals.broad;W.draw=originals.draw
O.draw=originals.outline;U.hide=originals.hide;T.time=originals.time;T.log=originals.log
W.hide=originals.world_hide;U.begin=originals.begin;U.line=originals.line
U.finish=originals.finish;StaticFindObject=originals.find
assert(ok,err)
print('PASS pre-draw/render transitions, zero-speed collision, live path and fallback appearance')
