local S=require('state')
local R=require('runtime')
local C=require('collision')
local Profiles=require('profiles')
local saved=C.aim
local saved_name=FName
local name_type={}
FName=function(value) return setmetatable({value=value},name_type) end
local function valid() return true end
local function vec(x,y,z) return {X=x,Y=y,Z=z} end
local length=80
local mesh={IsValid=valid,K2_GetComponentLocation=function() return vec(5,6,30) end,
 GetLocalBounds=function(_,lo,hi) hi.X=length end}
local camera={IsValid=valid,K2_GetComponentLocation=function() return vec(0,0,100) end,
 GetForwardVector=function() return vec(1,0,0) end}
local camera_distance=300
local third_camera={IsValid=valid,K2_GetComponentLocation=function() return vec(10,-camera_distance,200) end,
 GetForwardVector=function() return vec(0,1,0) end}
local arm={IsValid=valid,K2_GetComponentLocation=function() return vec(10,0,200) end}
local pawn=setmetatable({IsValid=valid,IsLocallyControlled=valid,GetAddress=function() return 10 end,
 ViewMode=1,FP_Camera=camera,TP_Camera=third_camera,TP_SpringArm=arm,
 GetHealth=function() return 100 end,GetVelocity=function() return vec(0,0,0) end,
 Mesh={GetSocketLocation=function(_,name)
  assert(getmetatable(name)==name_type and name.value=='head','Socket lookup requires an Unreal FName')
  return vec(10,20,100)
 end},
 GetActorRightVector=function() return vec(0,1,0) end,
 BP_CharacterStatsComponent={Sex=0,Stamina=100}}, {__index=function() return false end})
local pc={IsValid=valid,IsLocalPlayerController=valid,Pawn=pawn,
 IsGameMenuActive=false,IsMainMenuActive=false,DialogueChangeToHeirUIOpen=false}
local ammo_path
local ammo={ProjectileClass_12_0B95F94245C55429626C82B945BFD43C={GetObjectID=function()
 return {GetAssetPathName=function() return {ToString=function() return ammo_path end} end} end}}
local range,trace_start,trace_end
C.aim=function(_,start,finish) range=finish.X;trace_start=start;trace_end=finish;return finish end
local count=0
local ok,err=pcall(function()
 for class,family in pairs(Profiles.weapons) do
  local weapon={IsValid=valid,GetClass=function() return {IsValid=valid,GetFullName=function() return class end} end,
   PlayerCharacterReference=pawn,Aiming=true,LeftKeyDown=true,IsArrow=true,IsBolt=true,isReloading=false,
   Arrow=mesh,Bolt=mesh,Mesh=mesh,CurrentArrow=ammo,CurrentSpear=ammo,
   Speed=5500,MaxSpeed=11000,MinSpeed=2000,ThrowStrength=1500,MaxStrength=3000,MinStrength=750,
   Alpha=.5,WasThrown=false,StaminaCost=4}
  pawn.HeldItem=weapon
  for path,profile in pairs(Profiles.projectiles) do
   ammo_path=path
   if profile.family==family then
    local snap=assert(S.capture(pc,{enabled=true}))
    assert(snap.family==family and snap.projectile==path and snap.profile==profile and snap.half_length==80)
    assert(snap.speed==(family=='spear' and 1500 or 5500))
    assert(snap.pull==(family=='crossbow' and 1 or .5))
    assert(range==(family=='spear' and 3000 or 5000))
    pawn.ViewMode=0
    for _,distance in ipairs({300,40,0}) do
     camera_distance=distance
     local third=assert(S.capture(pc,{enabled=true}),'Third-person preview rejected')
     assert(third.camera_origin.X==10 and third.camera_origin.Y==-distance and third.camera_origin.Z==200)
     assert(third.camera_forward.X==0 and third.camera_forward.Y==1)
     assert(trace_start.X==10 and trace_start.Y==100 and trace_start.Z==200)
     assert(trace_end.X==10 and trace_end.Y==(family=='spear' and 3000 or 5000) and trace_end.Z==200)
     assert(third.origin.X==snap.origin.X and third.origin.Y==snap.origin.Y and third.origin.Z==snap.origin.Z)
     assert(third.speed==snap.speed and third.pull==snap.pull)
    end
    pawn.TP_SpringArm=nil;assert(S.capture(pc,{enabled=true})==nil);pawn.TP_SpringArm=arm
    pawn.TP_Camera=nil;assert(S.capture(pc,{enabled=true})==nil);pawn.TP_Camera=third_camera
    pawn.ViewMode=2;assert(S.capture(pc,{enabled=true})==nil,'Unknown view mode accepted')
    pawn.ViewMode=1
    if family=='spear' then
     assert(snap.origin.X==10 and snap.origin.Y==32 and snap.origin.Z==30)
     pawn.BP_CharacterStatsComponent.Sex=1
     assert(S.capture(pc,{enabled=true}).origin.Y==44)
     pawn.BP_CharacterStatsComponent.Sex=0
     pawn.BP_CharacterStatsComponent.Stamina=2.5
     local low=assert(S.capture(pc,{enabled=true}))
     assert(low.speed==750 and not low.release_valid,'Low stamina not applied at strict threshold')
     pawn.BP_CharacterStatsComponent.Stamina=100
     weapon.WasThrown=true;assert(S.capture(pc,{enabled=true})==nil);weapon.WasThrown=false
    else
     weapon.isReloading=true;assert(S.capture(pc,{enabled=true})==nil);weapon.isReloading=false
     if family=='crossbow' then weapon.IsBolt=false;weapon.IsArrow=true
     else weapon.IsArrow=false end
     assert(S.capture(pc,{enabled=true})==nil,'Unloaded weapon retained guide')
     weapon.IsArrow=true;weapon.IsBolt=true
    end
    weapon.Aiming=false
    assert(S.capture(pc,{enabled=true}).mode=='planning')
    assert(S.capture(pc,{enabled=true}).speed==(family=='spear' and 3000 or 11000))
    weapon.Aiming=true
    count=count+1
   else assert(S.capture(pc,{enabled=true})==nil,'Wrong-family ammunition accepted') end
  end
  local owner=weapon.PlayerCharacterReference
  weapon.PlayerCharacterReference={IsValid=valid,GetAddress=function() return 99 end}
  assert(R.owned_weapon(pawn)==nil,'Another player weapon selected')
  weapon.PlayerCharacterReference=owner
 end
end)
C.aim=saved
FName=saved_name
assert(ok,err)
assert(count==88,'Weapon/ammo coverage changed: '..count)
print('PASS all 88 bow/crossbow/spear combinations in both views, camera obstruction/zoom, ownership, reload, charge, stamina and launch geometry')
