local R=require("runtime")
local V=require("vector")
local M=require("presentation")
local P=require("predict")
local C=require("collision")
local Profiles=require("profiles")
local S={}
local bounds_min,bounds_max={},{}
local function finite(n)
    return type(n)=="number" and n==n and math.abs(n)<math.huge
end
S.copper="/Game/Blueprints/Projectiles/BP_Projectile_CopperArrow.BP_Projectile_CopperArrow_C"
function S.capture(pc,config)
    if not config.enabled then return nil,"disabled" end
    if not R.valid(pc) or not pc:IsLocalPlayerController() then return nil,"not_local" end
    local pawn=pc.Pawn
    if not R.valid(pawn) or not pawn:IsLocallyControlled() then return nil,"no_pawn" end
    local bow,family=R.owned_weapon(pawn)
    if not bow then return nil,"unsupported_weapon" end
    local fields=Profiles.families[family]
    local ammo_data=bow[fields.ammo]
    local ammo=ammo_data[Profiles.projectile_field]:GetObjectID():GetAssetPathName():ToString()
    local profile=Profiles.projectiles[ammo]
    if not profile or profile.family~=family then return nil,"unsupported_ammo" end
    local view=pawn.ViewMode
    if view~=0 and view~=1 then return nil,"unsupported_view_mode" end
    local blocked=false
    for _,key in ipairs({"Inventory Open","GameMenuOpen","BuildingMenuOpen","CraftingMenuOpen","ChoiceMenuOpen","InputDisabled","QuickslotMenuOpen","SleepMenuOpen","WindowMenuOpen"}) do
        local value=R.read(pawn,key)
        if type(value)~="boolean" then return nil,"unknown_ui_state:"..key end
        blocked=blocked or value
    end
    blocked=blocked or pc.IsGameMenuActive or pc.IsMainMenuActive or pc.DialogueChangeToHeirUIOpen
    local dialogue=pc.UI_Dialogue
    if R.valid(dialogue) and dialogue:IsInViewport() and dialogue:IsVisible() then blocked=true end
    if type(bow.Aiming)~="boolean" then return nil,"unknown_draw_state" end
    local drawing=bow.Aiming
    local maximum,minimum=bow[fields.maximum],bow[fields.minimum]
    local speed,pull=bow[fields.speed],family=="crossbow" and 1 or bow.Alpha
    local loaded,reloading
    if family=="spear" then
        loaded=bow.WasThrown==false
        reloading=false
    else
        loaded=bow[fields.loaded]
        reloading=bow.isReloading
        if family=="bow" then
            if type(bow.LeftKeyDown)~="boolean" then return nil,"unknown_draw_state" end
            drawing=drawing and bow.LeftKeyDown
        end
    end
    if not finite(maximum) or maximum<=0 then return nil,"invalid_max_speed" end
    if not drawing then speed,pull=maximum,1 end
    if not finite(speed) or speed<0 or not finite(pull) or pull<0 or pull>1
        or not finite(minimum) or minimum<0 then return nil,"invalid_draw_state" end
    if family=="spear" then
        local stats=bow.PlayerCharacterReference.BP_CharacterStatsComponent
        local stamina=R.read(stats,"Stamina")
        local cost=R.read(bow,"StaminaCost")
        if not finite(stamina) or not finite(cost) or cost<0 then return nil,"unknown_stamina" end
        local required=cost*2.5*pull
        if required>0 then speed=speed*math.max(0,math.min(1,stamina/required)) end
    end
    local release_valid=drawing and speed>minimum
    local mode=not drawing and "planning" or (release_valid and "ready" or "drawing")
    local state={mode=mode,enabled=config.enabled,local_owner=true,supported=true,aiming=bow.Aiming,
        loaded=loaded,reloading=reloading,ui_blocked=blocked,
        alive=pawn:GetHealth()>0,release_valid=release_valid}
    if not M.visible(state) then return nil,"not_ready" end
    local camera
    if view==0 then camera=pawn.TP_Camera else camera=pawn.FP_Camera end
    local mesh=bow[fields.mesh]
    if not R.valid(camera) or not R.valid(mesh) then return nil,"missing_component" end
    local origin=R.vec(mesh:K2_GetComponentLocation())
    if family=="spear" then
        local sex=R.read(pawn.BP_CharacterStatsComponent,"Sex")
        if sex~=0 and sex~=1 then return nil,"unknown_character_sex" end
        local head=R.vec(pawn.Mesh:GetSocketLocation(FName("head")))
        local right=R.vec(pawn:GetActorRightVector())
        if not V.finite(head) or not V.finite(right) then return nil,"missing_head_transform" end
        local offset=V.add(head,V.scale(right,sex==0 and 12 or 24))
        origin={X=offset.X,Y=offset.Y,Z=origin.Z}
    end
    for key in pairs(bounds_min) do bounds_min[key]=nil end
    for key in pairs(bounds_max) do bounds_max[key]=nil end
    mesh:GetLocalBounds(bounds_min,bounds_max)
    local half_length=bounds_max.X
    if not finite(half_length) or half_length<=0 then return nil,"missing_projectile_bounds" end
    local eye=R.vec(camera:K2_GetComponentLocation())
    local forward=R.vec(camera:GetForwardVector())
    if not V.finite(eye) or not V.finite(forward) then return nil,"missing_camera_transform" end
    local camera_distance=0
    if view==0 then
        -- Vanilla InteractionRange advances both ray ends by the actual
        -- camera-to-arm distance, including camera obstruction/zoom changes.
        local arm=pawn.TP_SpringArm
        if not R.valid(arm) then return nil,"missing_camera_arm" end
        local arm_origin=R.vec(arm:K2_GetComponentLocation())
        if not V.finite(arm_origin) then return nil,"missing_camera_transform" end
        camera_distance=V.length(V.sub(eye,arm_origin))
    end
    local start_point=V.add(eye,V.scale(forward,100+camera_distance))
    local end_point=V.add(eye,V.scale(forward,(family=="spear" and maximum or 5000)+camera_distance))
    local target=C.aim(pawn,start_point,end_point)
    local direction=V.unit(V.sub(target,origin))
    if not direction then return nil,"degenerate_aim" end
    return {pawn=pawn,bow=bow,origin=origin,direction=direction,
        velocity=P.launch_velocity(direction,speed,R.vec(pawn:GetVelocity())),
        speed=speed,pull=pull,mode=mode,release_valid=release_valid,
        projectile=ammo,family=family,profile=profile,half_length=half_length,
        camera_origin=eye,camera_forward=forward},mode
end
return S
