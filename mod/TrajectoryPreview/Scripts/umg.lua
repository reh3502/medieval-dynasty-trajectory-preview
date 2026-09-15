-- Viewport-only widgets. No actors, replication or game input interception.
local R=require("runtime")
local T=require("telemetry")
local U={}
local probe_name="MDTrajectoryProbe"
function U.root(pc)
    if not R.valid(pc) or not pc:IsLocalPlayerController() then return nil end
    local hud=pc.UI_PlayerHUDReference
    if not R.valid(hud) then return nil end
    local tree=hud.WidgetTree
    if not R.valid(tree) then return nil end
    local root=tree.RootWidget
    if not R.valid(root) then return nil end
    return root,tree
end
function U.clear_probe(root)
    for i=root:GetChildrenCount()-1,0,-1 do
        local child=root:GetChildAt(i)
        if R.valid(child) and child:GetFName():ToString()==probe_name then child:RemoveFromParent() end
    end
end
function U.probe(pc)
    local root,tree=U.root(pc)
    if not root then return false end
    T.log("umg_root", {root=R.name(root),tree=R.name(tree)})
    local canvas_class=StaticFindObject("/Script/UMG.CanvasPanel")
    assert(root:IsA(canvas_class), "HUD root is not a CanvasPanel")
    U.clear_probe(root)
    local border_class=StaticFindObject("/Script/UMG.Border")
    assert(R.valid(border_class),"Border class missing")
    -- RF_Transient (0x40) prevents this presentation object from serialization.
    local border=StaticConstructObject(border_class,tree,FName(probe_name),0x40)
    assert(R.valid(border),"Cannot construct viewport probe")
    local slot=root:AddChildToCanvas(border)
    assert(R.valid(slot),"Cannot attach viewport probe")
    border:SetVisibility(3) -- HitTestInvisible
    border:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
    border:SetBrushColor({R=0.1,G=1,B=0.3,A=1})
    slot:SetAnchors({Minimum={X=0.5,Y=0.5},Maximum={X=0.5,Y=0.5}})
    slot:SetAlignment({X=0.5,Y=0.5})
    slot:SetPosition({X=0,Y=-80})
    slot:SetSize({X=160,Y=5})
    slot:SetZOrder(10000)
    T.log("umg_probe_attached", {widget=R.name(border)})
    ExecuteInGameThreadWithDelay(15000,function()
        if R.valid(border) then border:RemoveFromParent() end
    end)
    return true
end
local overlay_name="MDTrajectoryOverlay"
local overlay,owner_root,overlay_visible
local pool={}
function U.hide()
    if R.valid(overlay) and overlay_visible~=false then
        overlay:SetVisibility(1);overlay_visible=false
    end
end
function U.begin(pc)
    local root,tree=U.root(pc)
    if not root then U.hide(); return false end
    if not R.valid(overlay) or not R.valid(owner_root) or root:GetAddress()~=owner_root:GetAddress() then
        if R.valid(overlay) then overlay:RemoveFromParent() end
        for i=root:GetChildrenCount()-1,0,-1 do
            local child=root:GetChildAt(i)
            if R.valid(child) and child:GetFName():ToString()==overlay_name then child:RemoveFromParent() end
        end
        overlay=StaticConstructObject(StaticFindObject("/Script/UMG.CanvasPanel"),tree,FName(overlay_name),0x40)
        assert(R.valid(overlay),"Cannot construct trajectory canvas")
        local slot=root:AddChildToCanvas(overlay)
        slot:SetAnchors({Minimum={X=0,Y=0},Maximum={X=1,Y=1}})
        slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        slot:SetZOrder(9999)
        owner_root=root; pool={};overlay_visible=nil
    end
    if overlay_visible~=true then overlay:SetVisibility(3);overlay_visible=true end
    U.used=0
    return true
end
function U.line(a,b,opacity,thickness,color,style)
    if opacity<=0 then return end
    local dx,dy=b.X-a.X,b.Y-a.Y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.01 then return end
    U.used=U.used+1
    assert(U.used<=540,"drawing budget exceeded") -- Arc + ring + 12 entity-box edges.
    local entry=pool[U.used]
    if not entry then
        local border=StaticConstructObject(StaticFindObject("/Script/UMG.Border"),overlay,0,0x40)
        local slot=overlay:AddChildToCanvas(border)
        border:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
        border:SetRenderTransformPivot({X=0,Y=0.5})
        slot:SetAlignment({X=0,Y=0.5})
        entry={widget=border,slot=slot};pool[U.used]=entry
    end
    local textured=style=="ribbon"
    if entry.textured~=textured then
        if textured then
            local brush=require("ribbon").brush(overlay)
            if brush then entry.widget:SetBrush(brush) end
        else
            entry.widget:SetBrushFromTexture(nil)
        end
        entry.textured=textured;entry.color=nil
    end
    if entry.visible~=true then entry.widget:SetVisibility(3);entry.visible=true end
    local old=entry.color
    if not old or old.R~=color.R or old.G~=color.G or old.B~=color.B or old.A~=opacity then
        local brush={R=color.R,G=color.G,B=color.B,A=opacity}
        entry.widget:SetBrushColor(brush);entry.color=brush
    end
    entry.slot:SetPosition(a)
    entry.slot:SetSize({X=length,Y=thickness})
    entry.widget:SetRenderTransformAngle(math.deg(math.atan(dy,dx)))
end
function U.finish()
    for i=U.used+1,#pool do
        local entry=pool[i]
        if entry.visible~=false then entry.widget:SetVisibility(1);entry.visible=false end
    end
end
function U.cleanup(pc)
    local root=U.root(pc)
    if not root then return end
    for i=root:GetChildrenCount()-1,0,-1 do
        local child=root:GetChildAt(i)
        if R.valid(child) then
            local name=child:GetFName():ToString()
            if name==overlay_name or name==probe_name then child:RemoveFromParent() end
        end
    end
    overlay=nil;owner_root=nil;overlay_visible=nil;pool={}
end
return U
