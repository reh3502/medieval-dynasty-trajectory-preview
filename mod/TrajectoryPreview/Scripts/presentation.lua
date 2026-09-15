-- Stateless drawing commands. Discard prior output on every invalid snapshot.
local V=require("vector")
local M={}
function M.visible(state)
    local preview=state.mode=="planning" or state.mode=="drawing"
        or (state.aiming==true and state.release_valid==true)
    return preview and state.enabled==true and state.local_owner==true and state.supported==true
        and state.loaded==true and state.reloading==false
        and state.ui_blocked==false and state.alive==true
end
-- Clip projected lines to the viewport (Liang-Barsky).
function M.clip(a,b,width,height)
    local dx,dy=b.X-a.X,b.Y-a.Y
    local lo,hi=0,1
    local p={-dx,dx,-dy,dy}; local q={a.X,width-a.X,a.Y,height-a.Y}
    for i=1,4 do
        if p[i]==0 then if q[i]<0 then return nil end
        else
            local t=q[i]/p[i]
            if p[i]<0 then lo=math.max(lo,t) else hi=math.min(hi,t) end
            if lo>hi then return nil end
        end
    end
    return {X=a.X+lo*dx,Y=a.Y+lo*dy},{X=a.X+hi*dx,Y=a.Y+hi*dy}
end
function M.draw(result, camera, project, line, options)
    if not result or not result.points or #result.points<2 then return end
    for i=2,#result.points do
        local a,b=result.points[i-1].position,result.points[i].position
        local da=V.dot(V.sub(a,camera.origin),camera.forward)
        local db=V.dot(V.sub(b,camera.origin),camera.forward)
        if da>=camera.near or db>=camera.near then
            if da<camera.near then a=V.lerp(a,b,(camera.near-da)/(db-da))
            elseif db<camera.near then b=V.lerp(a,b,(camera.near-da)/(db-da)) end
            local pa,pb=project(a),project(b)
            if pa and pb then
                local ca,cb=M.clip(pa,pb,camera.width,camera.height)
                if ca then
                    local fade=1
                    if result.status~="hit" then fade=math.min(1,(#result.points-i)/8) end
                    local progress=(i-2)/math.max(1,#result.points-2)
                    -- Width changes only the presentation, never the simulated path.
                    local width=options.thickness*(6.5-2.5*progress)
                    line(ca,cb,options.opacity*fade*(0.9-0.2*progress),width,"ribbon")
                end
            end
        end
    end
    if result.status=="hit" and result.hit then
        local point=result.hit.position
        if V.dot(V.sub(point,camera.origin),camera.forward)<camera.near then return end
        local p=project(point)
        if not p then return end
        local radius=options.marker_radius*1.35
        -- Screen-space ring, no actor or gameplay component.
        for i=0,15 do
            local a,b=i*math.pi/8,(i+1)*math.pi/8
            local ca,cb=M.clip({X=p.X+radius*math.cos(a),Y=p.Y+radius*math.sin(a)},
                {X=p.X+radius*math.cos(b),Y=p.Y+radius*math.sin(b)},camera.width,camera.height)
            if ca then line(ca,cb,options.opacity*0.85,options.thickness*2.5,"ribbon") end
        end
    end
end
return M
