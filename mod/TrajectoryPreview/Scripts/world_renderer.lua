-- Local transient visual components only. No projectile actors or collision bodies.
local R=require('runtime')
local T=require('telemetry')
local G=require('world_geometry')
local A=require('trajectory_animation')
local animation={}
local visible=false
local parameter_values={}
local W={}
local component,owner,materials,two_sided,failed,cleaned
local section_sizes={}
local section_indices={}
local name='MDTrajectoryWorldRibbon'
local identity={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
function W.hide()
    animation={}
    if not cleaned then pcall(W.cleanup) end
    if visible and R.valid(component) then pcall(function() component:SetVisibility(false,false) end) end
    visible=false
end
function W.cleanup()
    -- Exact mod-owned name only; also removes previous Lua session's component.
    for _,item in ipairs(FindAllOf('ProceduralMeshComponent') or {}) do
        if R.valid(item) and item:GetFName():ToString()==name then
            item:SetVisibility(false,false)
            item:K2_DestroyComponent(item:GetOwner())
        end
    end
    component=nil;owner=nil;materials=nil;section_sizes={};section_indices={};animation={};parameter_values={};visible=false;cleaned=true
end
local function ensure(pawn,options)
    if not cleaned then W.cleanup() end
    if R.valid(component) and R.valid(owner) and owner:GetAddress()==pawn:GetAddress() then return end
    W.cleanup()
    assert(pawn:IsLocallyControlled(),'world renderer requires local pawn')
    local path='/Game/MDTrajectory/M_TrajectoryThread.M_TrajectoryThread'
    local material=StaticFindObject(path)
    if not R.valid(material) then
        local assets=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        material=assets:GetAsset({ObjectPath=FName(path)})
    end
    assert(R.valid(material),'world material unavailable')
    -- Never change a shared material or attempt to recompile its cooked shader.
    assert(material.bDisableDepthTest==false,'world material must use depth testing')
    two_sided=material.TwoSided==true
    local class=StaticFindObject('/Script/ProceduralMeshComponent.ProceduralMeshComponent')
    assert(R.valid(class),'procedural mesh class unavailable')
    component=StaticConstructObject(class,pawn,FName(name),0x40) -- RF_Transient
    assert(R.valid(component),'world component creation failed')
    owner=pawn
    component:SetVisibility(false,false)
    component:SetCollisionEnabled(0) -- NoCollision, before registration
    component:SetGenerateOverlapEvents(false)
    component:SetCastShadow(false)
    component:SetIsReplicated(false)
    -- Manual attachment leaves the identity transform fixed in world space.
    pawn:FinishAddComponent(component,true,identity)
    component:SetHiddenInGame(false,false)
    materials={}
    materials[1]=component:CreateDynamicMaterialInstance(0,material,FName('MDTrajectoryThread'))
    assert(R.valid(materials[1]),'trajectory material instance creation failed')
    materials[1]:SetScalarParameterValue(FName('Reveal'),0)
    local box_path='/Engine/EngineMaterials/Widget3DPassThrough.Widget3DPassThrough'
    local box_material=StaticFindObject(box_path)
    if not R.valid(box_material) then LoadAsset(box_path);box_material=StaticFindObject(box_path) end
    assert(R.valid(box_material) and box_material.bDisableDepthTest==false,'box material unavailable')
    local source=assert(package.searchpath('config',package.path))
    local rendering=StaticFindObject('/Script/Engine.Default__KismetRenderingLibrary')
    -- gsub returns both the path and replacement count. Do not forward both
    -- results into the reflected engine call.
    local texture_path=source:gsub('config%.lua$','../Textures/world-box.png')
    local texture=rendering:ImportFileAsTexture2D(pawn,texture_path)
    assert(R.valid(texture),'box texture unavailable')
    materials[2]=component:CreateDynamicMaterialInstance(1,box_material,FName('MDTrajectoryBox'))
    assert(R.valid(materials[2]),'box material instance creation failed')
    materials[2]:SetTextureParameterValue(FName('SlateUI'),texture)
    materials[2]:SetVectorParameterValue(FName('TintColorAndOpacity'),{R=1,G=1,B=1,A=1})
    materials[2]:SetVectorParameterValue(FName('BackColor'),{R=0,G=0,B=0,A=0})
    materials[2]:SetScalarParameterValue(FName('OpacityFromTexture'),1)
    T.log('world_renderer_ready',{material=path,component=R.name(component),depth_test=true,responsive_aa=material.bEnableResponsiveAA,shading_model=material.ShadingModel,two_sided=two_sided,owner_hidden=R.read(pawn,'bHidden')})
end
function W.draw(pawn,result,eye,options,pull)
    if failed then return false end
    local ok,err=pcall(function()
        ensure(pawn,options)
        local values=A.frame(animation,T.time(pawn),pull,result.status=='hit')
        values.Opacity=options.opacity
        for key,value in pairs(values) do
            if parameter_values[key]~=value then
                materials[1]:SetScalarParameterValue(FName(key),value)
                parameter_values[key]=value
            end
        end
        for i,mesh in ipairs(G.build(result,eye,options,two_sided)) do
            if #mesh.triangles==0 then
                if section_sizes[i] then component:ClearMeshSection(i-1);section_sizes[i]=nil end
            elseif section_sizes[i]==#mesh.vertices and section_indices[i]==#mesh.triangles then
                component:UpdateMeshSection_LinearColor(i-1,mesh.vertices,mesh.normals,mesh.uv,{},{},{},mesh.colors,{})
            else
                component:CreateMeshSection_LinearColor(i-1,mesh.vertices,mesh.triangles,mesh.normals,mesh.uv,{},{},{},mesh.colors,{},false)
                section_sizes[i]=#mesh.vertices
                section_indices[i]=#mesh.triangles
            end
        end
        if not visible then component:SetVisibility(true,false);visible=true end
    end)
    if ok then return true end
    W.hide();failed=true
    T.log('world_renderer_error',{error=tostring(err),fallback='umg'})
    return false
end
return W
