-- A transient, non-rendering marker keeps original mesh settings across Ctrl+R.
-- Used by the cooked outline material renderer.
local R=require('runtime')
local S={marker_name='MDTrajectoryOutlineRestore'}
local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
local function unwrap(value)
    local ok,result=pcall(function() return value:get() end)
    return ok and result or value
end
local function values(array)
    local out={}
    if type(array)=='table' then
        for _,value in ipairs(array) do out[#out+1]=unwrap(value) end
    else
        array:ForEach(function(_,value) out[#out+1]=unwrap(value) end)
    end
    return out
end
local function name(object) return object:GetFName():ToString() end
local function components(actor,class)
    return values(actor:K2_GetComponentsByClass(StaticFindObject(class)))
end
local function integer(value,maximum)
    return type(value)=='number' and value==math.floor(value) and value>=0 and value<=maximum
end
function S.restore(marker)
    if not R.valid(marker) then return end
    local actor=marker:GetOwner()
    if not R.valid(actor) then return end
    local meshes={}
    for _,mesh in ipairs(components(actor,'/Script/Engine.MeshComponent')) do
        if R.valid(mesh) then meshes[name(mesh)]=mesh end
    end
    for _,tag in ipairs(values(marker.ComponentTags)) do
        local assigned,depth,stencil,mask,mesh_name=tag:ToString():match('^MDT1|(%d+)|([01])|(%d+)|(%d+)|(.+)$')
        assert(assigned,'invalid outline restore record')
        assigned,depth,stencil,mask=tonumber(assigned),tonumber(depth),tonumber(stencil),tonumber(mask)
        assert(integer(assigned,255) and assigned>0 and integer(stencil,255) and integer(mask,8),'invalid stencil values')
        local mesh=meshes[mesh_name]
        -- A later game effect may have taken ownership of these fields. Do not
        -- overwrite a newer stencil value or a field it changed independently.
        if mesh and mesh.CustomDepthStencilValue==assigned then
            if mesh.bRenderCustomDepth==true then mesh:SetRenderCustomDepth(depth==1) end
            if mesh.CustomDepthStencilWriteMask==0 then mesh:SetCustomDepthStencilWriteMask(mask) end
            mesh:SetCustomDepthStencilValue(stencil)
        end
    end
    marker.ComponentTags:Empty()
end
function S.apply(actor,assigned)
    assert(R.valid(actor) and integer(assigned,255) and assigned>0,'invalid outline target')
    local marker
    for _,component in ipairs(components(actor,'/Script/Engine.SceneComponent')) do
        if R.valid(component) and name(component)==S.marker_name then marker=component;break end
    end
    if marker then S.restore(marker) end
    local selected,records={},{}
    for _,mesh in ipairs(components(actor,'/Script/Engine.MeshComponent')) do
        if R.valid(mesh) and mesh:IsVisible() and not mesh.bHiddenInGame and mesh.bRenderInMainPass then
            local depth,stencil,mask=mesh.bRenderCustomDepth,mesh.CustomDepthStencilValue,mesh.CustomDepthStencilWriteMask
            assert(type(depth)=='boolean' and integer(stencil,255) and integer(mask,8),'mesh stencil state unavailable')
            assert(stencil~=assigned,'outline stencil already belongs to target')
            records[#records+1]=FName(string.format('MDT1|%d|%d|%d|%d|%s',assigned,depth and 1 or 0,stencil,mask,name(mesh)))
            selected[#selected+1]=mesh
        end
    end
    if #selected==0 then return nil end
    if not marker then
        marker=StaticConstructObject(StaticFindObject('/Script/Engine.SceneComponent'),actor,FName(S.marker_name),0x40)
        assert(R.valid(marker),'outline restore marker creation failed')
        marker:SetIsReplicated(false)
        marker:SetComponentTickEnabled(false)
        actor:FinishAddComponent(marker,true,identity)
    end
    -- Empty first: UE4SS's Lua-table array setter constructs a new allocation.
    marker.ComponentTags:Empty()
    marker.ComponentTags=records
    -- Persist every original value before changing any mesh. If a setter fails,
    -- the caller can still restore partial changes using the marker.
    for _,mesh in ipairs(selected) do
        mesh:SetCustomDepthStencilValue(assigned)
        mesh:SetCustomDepthStencilWriteMask(0) -- ERSRM_Default: all bits.
        mesh:SetRenderCustomDepth(true)
    end
    return marker
end
function S.cleanup()
    for _,component in ipairs(FindAllOf('SceneComponent') or {}) do
        if R.valid(component) and name(component)==S.marker_name then S.restore(component) end
    end
end
return S
