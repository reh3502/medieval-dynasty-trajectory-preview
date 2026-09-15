local T=require('telemetry')
local function valid() return true end
local cases={
    {name='Bow',folder='Range',mesh='Arrow',ammo='CurrentArrow',
        values={Aiming=true,IsArrow=true,isReloading=false,Speed=5500,MinSpeed=2000,MaxSpeed=11000,Alpha=.5,LeftKeyDown=true,RightKeyDown=true}},
    {name='Crossbow',folder='Range',mesh='Bolt',ammo='CurrentArrow',
        values={Aiming=true,IsBolt=true,isReloading=false,Speed=5500,MinSpeed=2000,MaxSpeed=11000}},
    {name='WoodenPike',folder='Melee',mesh='Mesh',ammo='CurrentSpear',
        values={Aiming=true,WasThrown=false,ThrowStrength=1500,MaxStrength=3000,MinStrength=750,Alpha=.5}},
}
for _,case in ipairs(cases) do
    local class='BlueprintGeneratedClass /Game/Blueprints/HoldableItems/'..case.folder..'/BP_HoldableItem_'..case.name..'.BP_HoldableItem_'..case.name..'_C'
    local weapon={IsValid=valid,GetFullName=function() return case.name end,
        GetClass=function() return {IsValid=valid,GetFullName=function() return class end} end}
    for key,value in pairs(case.values) do weapon[key]=value end
    weapon[case.mesh]={IsValid=valid,K2_GetComponentLocation=function() return {X=1,Y=2,Z=3} end}
    weapon[case.ammo]={ProjectileClass_12_0B95F94245C55429626C82B945BFD43C={GetObjectID=function()
        return {GetAssetPathName=function() return {ToString=function() return case.name..'-projectile' end} end} end}}
    local touched={}
    setmetatable(weapon,{__index=function(_,key) touched[key]=true;return {} end})
    local a=T.snapshot(weapon,nil,nil)
    local b=T.snapshot(weapon,nil,nil)
    assert(next(touched)==nil,'Diagnostics read an absent field for '..case.name)
    assert(a.ammo==case.name..'-projectile' and a.origin.X==1)
    for key,value in pairs(case.values) do assert(a[key]==value,'Missing telemetry field '..key) end
    assert(T.encode(a)==T.encode(b),'Unchanged weapon produced changing diagnostic data')
end
print('PASS bow/crossbow/spear telemetry reads only family fields and remains stable when idle')
