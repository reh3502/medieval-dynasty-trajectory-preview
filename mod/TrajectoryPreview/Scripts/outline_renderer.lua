-- Local post-process component and recoverable stencil ownership.
local R=require('runtime')
local S=require('outline_stencil')
local T=require('telemetry')
local O={}
local name='MDTrajectoryOutlinePostProcess'
local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
local component,owner,target,marker,cleaned,failed
local function system() return StaticFindObject('/Script/Engine.Default__KismetSystemLibrary') end
local function clear_target()
    if R.valid(marker) then S.restore(marker) end
    marker=nil;target=nil
end
local function release(item)
    if not R.valid(item) then return end
    item.bEnabled=false
    local previous
    item.ComponentTags:ForEach(function(_,tag)
        previous=previous or tonumber(tag:get():ToString():match('^MDDepth|(%d+)$'))
    end)
    if previous and system():GetConsoleVariableIntValue('r.CustomDepth')==3 then
        system():ExecuteConsoleCommand(item:GetOwner(),'r.CustomDepth '..previous,nil)
    end
    item:K2_DestroyComponent(item:GetOwner())
end
function O.cleanup()
    if cleaned then
        clear_target()
        release(component)
    else
        -- Global recovery is needed once per Lua session, not each aim cycle.
        S.cleanup()
        for _,item in ipairs(FindAllOf('PostProcessComponent') or {}) do
            if R.valid(item) and item:GetFName():ToString()==name then release(item) end
        end
    end
    component=nil;owner=nil;marker=nil;target=nil;cleaned=true
end
function O.hide()
    local ok,err=pcall(function()
        if not cleaned or R.valid(component) then O.cleanup() else clear_target() end
    end)
    if not ok then T.log('outline_cleanup_error',{error=tostring(err)}) end
end
local function ensure(pawn)
    if not cleaned then O.cleanup() end
    if R.valid(component) and R.valid(owner) and owner:GetAddress()==pawn:GetAddress() then return end
    O.cleanup()
    assert(pawn:IsLocallyControlled(),'outline requires local pawn')
    local assets=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
    local material=assets:GetAsset({ObjectPath=FName(require('outline_asset').path)})
    assert(R.valid(material),'outline material unavailable')
    local library=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
    local mid=library:CreateDynamicMaterialInstance(pawn,material,FName('MDTrajectoryOutlineLive'),1)
    assert(R.valid(mid),'outline material instance unavailable')
    mid:SetScalarParameterValue(FName('StencilId'),254)
    mid:SetScalarParameterValue(FName('Width'),2)
    mid:SetScalarParameterValue(FName('Strength'),1)
    component=StaticConstructObject(StaticFindObject('/Script/Engine.PostProcessComponent'),pawn,FName(name),0x40)
    assert(R.valid(component),'outline component creation failed')
    owner=pawn
    component.bEnabled=false
    component.bUnbound=true
    component.BlendWeight=1
    component.Priority=100
    component:SetIsReplicated(false)
    component:SetComponentTickEnabled(false)
    pawn:FinishAddComponent(component,true,identity)
    component.Settings.WeightedBlendables.Array:Empty()
    component.Settings.WeightedBlendables.Array={{Weight=1,Object=mid}}
    local previous=system():GetConsoleVariableIntValue('r.CustomDepth')
    assert(type(previous)=='number' and previous>=0 and previous<=3,'custom depth mode unavailable')
    component.ComponentTags:Empty()
    component.ComponentTags={FName(string.format('MDDepth|%d',previous))}
    system():ExecuteConsoleCommand(pawn,'r.CustomDepth 3',nil)
    assert(system():GetConsoleVariableIntValue('r.CustomDepth')==3,'custom depth stencil mode could not be enabled')
    T.log('outline_renderer_ready',{component=R.name(component),previous_depth=previous})
end
function O.draw(pawn,actor)
    if failed then return false end
    local ok,active=pcall(function()
        if not cleaned then O.cleanup() end
        if not R.valid(actor) or not require('highlight').eligible(actor) then
            clear_target()
            if R.valid(component) then component.bEnabled=false end
            return false
        end
        ensure(pawn)
        if not R.valid(target) or target:GetAddress()~=actor:GetAddress() then
            clear_target()
            marker=S.apply(actor,254)
            if not R.valid(marker) then return false end
            target=actor
            T.log('outline_target',{actor=R.name(actor)})
        end
        component.bEnabled=true
        return true
    end)
    if ok then return active end
    -- A failed setter may have written restoration metadata before apply returned.
    local recovered,recovery_error=pcall(S.cleanup)
    if not recovered then T.log('outline_cleanup_error',{error=tostring(recovery_error)}) end
    O.hide();failed=true
    T.log('outline_renderer_error',{error=tostring(active),fallback='box'})
    return false
end
return O
