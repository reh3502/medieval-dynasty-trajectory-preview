-- Validate the cooked Windows material before connecting it to the camera.
local R=require('runtime')
local A={path='/Game/MDTrajectory/M_PredictedOutline.M_PredictedOutline'}
function A.probe(pawn)
    assert(R.valid(pawn),'load a single-player save before checking the outline asset')
    local material=StaticFindObject(A.path)
    if not R.valid(material) then
        -- Like UE4SS's BPModLoader, load by object path: a mod pak is not
        -- listed in the base game's asset registry used by LoadAsset.
        local assets=StaticFindObject('/Script/AssetRegistry.Default__AssetRegistryHelpers')
        assert(R.valid(assets),'asset registry helpers unavailable')
        material=assets:GetAsset({ObjectPath=FName(A.path)})
    end
    assert(R.valid(material),'outline material failed to load; check the game log for package or asset errors')
    local library=StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
    assert(R.valid(library),'material library unavailable')
    local mid=library:CreateDynamicMaterialInstance(pawn,material,FName('MDTrajectoryOutlineProbe'),1)
    assert(R.valid(mid),'outline material instance creation failed')
    local defaults={}
    for _,entry in ipairs({{'StencilId',254},{'Width',2},{'Strength',1}}) do
        local value=mid:K2_GetScalarParameterValue(FName(entry[1]))
        assert(value==entry[2],'unexpected outline parameter '..entry[1]..': '..tostring(value))
        defaults[entry[1]]=value
    end
    mid:SetScalarParameterValue(FName('StencilId'),253)
    assert(mid:K2_GetScalarParameterValue(FName('StencilId'))==253,'outline parameter update failed')
    return {asset=R.name(material),domain=material.MaterialDomain,defaults=defaults,parameter_update=true}
end
return A
