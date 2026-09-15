-- Independent numeric state only. The caller supplies measured flight settings
-- and a read-only sweep; this module never accesses or mutates Unreal objects.
local V=require("vector")
local P={}
local function number(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function P.launch_velocity(direction, speed, owner_velocity)
    local forward=V.unit(direction)
    assert(forward and number(speed) and V.finite(owner_velocity), "invalid launch inputs")
    return V.scale(forward,speed+V.dot(forward,owner_velocity))
end
function P.drag_coefficient(radius,damping,mass)
    assert(number(radius) and radius>=0 and number(damping) and number(mass), "invalid drag inputs")
    return math.max(math.pi*radius*radius*damping*0.0015,0)/math.max(mass,0.01)
end
function P.drag(velocity,k,dt)
    local speed=V.length(velocity)
    if speed==0 then return V.new(0,0,0) end
    -- Blueprint VInterpTo_Constant toward zero; clamp at target, never reverse.
    return V.scale(velocity,math.max(0,1-speed*k*dt))
end
function P.run(snapshot, options, sweep)
    assert(V.finite(snapshot.origin) and V.finite(snapshot.velocity) and V.finite(snapshot.gravity), "missing flight inputs")
    assert(number(snapshot.drag) and snapshot.drag>=0, "missing drag coefficient")
    assert(number(options.step) and options.step>0 and options.step<=0.1, "invalid integration step")
    assert(number(options.horizon) and options.horizon>0 and options.horizon<=5, "invalid horizon")
    assert(number(options.max_distance) and options.max_distance>0, "invalid range")
    assert(number(options.max_steps) and options.max_steps>=1 and options.max_steps<=512 and options.max_steps%1==0, "invalid work limit")
    assert(type(sweep)=="function", "collision provider required")
    local interval=snapshot.drag_interval
    assert(number(interval) and interval>0, "missing actor drag interval")
    local position=V.new(snapshot.origin.X,snapshot.origin.Y,snapshot.origin.Z)
    local velocity=V.new(snapshot.velocity.X,snapshot.velocity.Y,snapshot.velocity.Z)
    local result={points={{position=position,time=0}},status="horizon",distance=0}
    local elapsed, since_drag=0,0
    for _=1,options.max_steps do
        local dt=math.min(options.step,options.horizon-elapsed,interval-since_drag)
        if dt<1e-9 then break end
        -- Constant-acceleration movement component step; actor drag is a separate
        -- discrete update. Runtime telemetry must establish phase/order parity.
        local half_dt_squared=0.5*dt*dt
        local gravity=snapshot.gravity
        local next_position={X=position.X+(velocity.X*dt+gravity.X*half_dt_squared),
            Y=position.Y+(velocity.Y*dt+gravity.Y*half_dt_squared),
            Z=position.Z+(velocity.Z*dt+gravity.Z*half_dt_squared)}
        local next_velocity={X=velocity.X+gravity.X*dt,Y=velocity.Y+gravity.Y*dt,Z=velocity.Z+gravity.Z*dt}
        local dx,dy,dz=next_position.X-position.X,next_position.Y-position.Y,next_position.Z-position.Z
        local length=math.sqrt(dx*dx+dy*dy+dz*dz)
        local fraction=1
        if result.distance+length>options.max_distance then
            fraction=(options.max_distance-result.distance)/length
            next_position=V.lerp(position,next_position,fraction)
        end
        local hit=sweep(position,next_position,velocity,next_velocity)
        if hit then
            assert(number(hit.fraction) and hit.fraction>=0 and hit.fraction<=1 and V.finite(hit.position), "invalid collision result")
            result.points[#result.points+1]={position=hit.position,time=elapsed+dt*fraction*hit.fraction}
            result.status="hit"; result.hit=hit
            result.distance=result.distance+length*fraction*hit.fraction
            return result
        end
        elapsed=elapsed+dt*fraction
        result.distance=result.distance+length*fraction
        position=next_position; velocity=next_velocity
        result.points[#result.points+1]={position=position,time=elapsed}
        if fraction<1 then result.status="range"; return result end
        since_drag=since_drag+dt
        if since_drag>=interval-1e-9 then
            velocity=P.drag(velocity,snapshot.drag,since_drag)
            since_drag=0
        end
        if elapsed>=options.horizon-1e-9 then return result end
    end
    result.status="budget"
    return result
end
return P
