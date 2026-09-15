local A=require('outline_asset')
local old_find,old_load,old_name=StaticFindObject,LoadAsset,FName
local loaded=false
local material={IsValid=function() return true end,GetFullName=function() return A.path end,MaterialDomain=4}
local pawn={IsValid=function() return true end}
local values={StencilId=254,Width=2,Strength=1}
local mid={IsValid=function() return true end,
    K2_GetScalarParameterValue=function(_,name) return values[name] end,
    SetScalarParameterValue=function(_,name,value) values[name]=value end}
local library={IsValid=function() return true end,
    CreateDynamicMaterialInstance=function(_,context,parent,name,flags)
        assert(context==pawn and parent==material and name=='MDTrajectoryOutlineProbe' and flags==1)
        return mid
    end}
FName=function(value) return value end
local assets={IsValid=function() return true end,
    GetAsset=function(_,data)
        assert(data.ObjectPath==A.path)
        loaded=true
        return material
    end}
StaticFindObject=function(path)
    if path==A.path then return loaded and material or nil end
    if path=='/Script/AssetRegistry.Default__AssetRegistryHelpers' then return assets end
    assert(path=='/Script/Engine.Default__KismetMaterialLibrary');return library
end
LoadAsset=function() error('mod asset must not depend on the base asset registry') end
local result=A.probe(pawn)
assert(result.parameter_update and result.defaults.StencilId==254 and values.StencilId==253)
assert(result.domain==4)
values.Width=9
local ok,err=pcall(A.probe,pawn)
assert(not ok and tostring(err):find('unexpected outline parameter',1,true))
loaded=false;assets.GetAsset=function() return nil end
ok,err=pcall(A.probe,pawn)
assert(not ok and tostring(err):find('failed to load',1,true))
assert(not pcall(A.probe,nil))
StaticFindObject,LoadAsset,FName=old_find,old_load,old_name
print('PASS outline asset load, parameter update, and missing/invalid asset handling')
