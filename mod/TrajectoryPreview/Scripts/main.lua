local R = require("runtime")
local T = require("telemetry")
local Preview = require("preview")
local UMG = require("umg")
local Profiles = require("profiles")
local probe_attempted=false
local Settings = require("settings")
local config_source=assert(package.searchpath("config",package.path), "local config path missing")
local preferences_path=config_source:gsub("config%.lua$", "preferences.ini")
local config=Settings.load(preferences_path)
T.enabled=config.telemetry
-- Each frame creates short-lived path tables and reflected Unreal wrappers.
-- Generational collection reclaims these without repeatedly walking the whole
-- mod heap. Configure once before callbacks; never force a full GC in a frame.
local gc_ok,gc_previous=pcall(collectgarbage,"generational",20,100)
T.log("memory_policy",{mode=gc_ok and "generational" or "unchanged",previous=gc_ok and gc_previous or nil,
    error=not gc_ok and tostring(gc_previous) or nil})
RegisterKeyBind(Key.F6, {ModifierKey.CONTROL, ModifierKey.SHIFT}, function()
    config.enabled=not config.enabled
    local saved,err=Settings.save(preferences_path,config)
    print("[TrajectoryPreview] preview "..(config.enabled and "enabled" or "disabled").."\n")
    if not saved then print("[TrajectoryPreview] preferences_write_error "..tostring(err).."\n") end
end)
local hooked = {}
local described = {}
local last_state = ""
local pc, pawn, bow
local function observe(path, callback)
    if hooked[path] ~= nil then return end
    local fn = StaticFindObject(path)
    if not R.valid(fn) then return end
    local ok, pre, post = pcall(RegisterHook, path, function(...)
        local success, err = pcall(callback, ...)
        if not success then T.log("observer_error", {path=path, error=tostring(err)}) end
        -- No return value: vanilla function results and parameters stay unchanged.
    end)
    if ok then hooked[path] = {pre, post}; T.log("hook", {path=path})
    else hooked[path] = false; T.log("hook_unavailable", {path=path, error=tostring(pre)}) end
end
local function tick()
    pc, pawn = R.local_player()
    local crosshair_ok,crosshair_error=pcall(require("crosshair").update,pc,config.enabled)
    if not crosshair_ok then T.log("crosshair_error",{error=tostring(crosshair_error)}) end
    if pc and not probe_attempted and UMG.root(pc) then
        probe_attempted=true
        local ok,err=pcall(function() UMG.cleanup(pc);require("world_renderer").cleanup() end)
        if not ok then T.log("umg_probe_error", {error=tostring(err)}) end
    end
    -- Preview/controller refresh and HUD recovery are needed without telemetry.
    -- Weapon snapshots and hooks below are diagnostics only.
    if not config.telemetry then return end
    local family
    if pawn then bow,family=R.owned_weapon(pawn) else bow=nil end
    if not bow then
        if last_state ~= "inactive" then T.log("state", {status="no_local_supported_weapon"}); last_state="inactive" end
        return
    end
    local snap = T.snapshot(bow, pawn, pc)
    local state = table.concat({tostring(snap.Aiming), tostring(snap.IsArrow), tostring(snap.IsBolt), tostring(snap.WasThrown), tostring(snap.isReloading), tostring(snap.Speed or snap.ThrowStrength), tostring(snap.Alpha)}, ":")
    if state ~= last_state then T.log("state", snap); last_state=state end
    local identity = R.name(bow)
    if config.telemetry and not described[identity] then
        described[identity] = true
        T.describe(bow, "bow")
        T.describe(pc.MyHUD, "hud")
        T.log("local_player", {controller=R.name(pc), pawn=R.name(pawn)})
    end
    local function observe_release(context, speed, max_speed, pull, transform)
        local weapon = context:get()
        local owner = R.read(weapon, "PlayerCharacterReference")
        if not R.valid(owner) or not owner:IsLocallyControlled() then return end
        local quantized=transform:get()
        local rotation=quantized.Rotation
        local now=T.time(owner)
        local preview,basis=Preview.for_release(weapon,now)
        T.log("vanilla_release", {time=now,preview_basis=basis,speed=speed:get(), max_speed=max_speed:get(), pull=pull:get(),
            weapon=R.name(weapon),owner_velocity=R.vec(owner:GetVelocity()),
            origin=R.vec(quantized.Translation),scale=R.vec(quantized.Scale3D),
            rotation={Pitch=rotation.Pitch,Yaw=rotation.Yaw,Roll=rotation.Roll},
            snapshot=T.snapshot(weapon,owner,pc),preview=preview})
    end
    -- Unequipped weapon classes may not be loaded. Repeated failed global
    -- lookups are costly; observe only the equipped family's release function.
    observe(Profiles.families[family].release, observe_release)
    observe("/Game/Blueprints/Projectiles/Base/BP_MasterProjectile.BP_MasterProjectile_C:TryHit", function(context, hit, velocity, spawn_item, spawned, has_hit)
        local projectile=context:get()
        local owner=projectile:GetOwner()
        if not R.valid(owner) or not owner:IsLocallyControlled() or not has_hit:get() then return end
        local contact=hit:get()
        T.log("vanilla_contact", {time=T.time(projectile),projectile=R.name(projectile),
            actor=R.weak_name(R.read(contact,"Actor")),component=R.weak_name(R.read(contact,"Component")),
            position=R.vec(contact.ImpactPoint),normal=R.vec(contact.ImpactNormal),velocity=R.vec(velocity:get())})
    end)
end
RegisterKeyBind(Key.F8, function()
    if not config.telemetry then return end
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            tick()
            T.describe(pawn, "pawn")
            T.describe(bow, "bow_manual")
            T.describe(pc and pc.MyHUD, "hud_manual")
            for _, projectile in ipairs(FindAllOf("BP_Projectile_CopperArrow_C") or {}) do
                T.describe(projectile, "projectile")
                T.describe(projectile.ProjectileMovement, "movement")
            end
            for _, path in ipairs({
                "/Script/NeatCollision.NeatCollisionFunctionLibrary:MakeCapsuleCollisionShape",
                "/Script/NeatCollision.NeatCollisionFunctionLibrary:MakeCollisionQueryDataFromTraceType",
                "/Script/NeatCollision.NeatCollisionFunctionLibrary:SweepMulti",
                "/Script/Engine.KismetSystemLibrary:LineTraceSingle",
                "/Script/Engine.Canvas:K2_Project"
            }) do T.function_info(path) end
            DumpAllObjects()
        end)
        if not ok then T.log("diagnostic_error", {error=tostring(err)}) end
    end)
end)
RegisterKeyBind(Key.F7, function()
    if not config.telemetry then return end
    ExecuteInGameThread(function()
        local local_pc=R.local_player()
        local ok,err=pcall(UMG.probe,local_pc)
        if not ok then T.log("umg_probe_error", {error=tostring(err)}) end
    end)
end)
RegisterKeyBind(Key.F6, {ModifierKey.CONTROL}, function()
    ExecuteInGameThread(function()
        local _,local_pawn=R.local_player()
        local ok,result=pcall(require('outline_asset').probe,local_pawn)
        if ok then
            T.log('outline_asset_probe',result)
            print('[TrajectoryPreview] outline asset loaded; material parameters passed.\n')
        else
            T.log('outline_asset_probe_error',{error=tostring(result)})
            print('[TrajectoryPreview] outline asset check failed: '..tostring(result)..'\n')
        end
    end)
end)
local function observe_projectile(projectile)
    if not config.telemetry then return end
    ExecuteInGameThreadAfterFrames(1, function()
        if not R.valid(projectile) then return end
        local owner=projectile:GetOwner()
        if not R.valid(owner) or not owner:IsLocallyControlled() then return end
        T.describe(projectile, "projectile")
        T.describe(projectile.ProjectileMovement, "movement")
        local samples=0
        local sample_loop
        sample_loop=LoopInGameThreadWithDelay(16, function()
            samples=samples+1
            if not R.valid(projectile) or samples>360 then CancelDelayedAction(sample_loop); return end
            local movement=projectile.ProjectileMovement
            if not R.valid(movement) then CancelDelayedAction(sample_loop); return end
            if R.read(projectile,"IsActive")==false then
                T.log("flight_ended", {time=T.time(projectile),projectile=R.name(projectile),samples=samples-1})
                CancelDelayedAction(sample_loop)
                return
            end
            T.log("flight", {time=T.time(projectile), sample=samples, projectile=R.name(projectile), position=R.vec(movement.UpdatedComponent:K2_GetComponentLocation()), velocity=R.vec(movement.Velocity), gravity_scale=movement.ProjectileGravityScale, active=R.read(projectile,"IsActive")})
        end)
    end)
end
if config.telemetry then
    for projectile_class in pairs(Profiles.projectiles) do
        NotifyOnNewObject(projectile_class,observe_projectile)
    end
end
LoopInGameThreadAfterFrames(1,function()
    Preview.safe_frame(pc,config)
end)
local loop = LoopInGameThreadWithDelay(250, function()
    local ok, err = pcall(tick)
    if not ok and last_state ~= tostring(err) then
        T.log("adapter_error", {error=tostring(err)})
        last_state=tostring(err)
    end
end)
T.log("started", {version="0.6.12", phase="runtime_adapter", key="F8 diagnostic snapshot", engine_tick=EngineTickAvailable})
