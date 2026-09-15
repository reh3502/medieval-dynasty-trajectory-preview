-- Per-projectile physical inputs from installed build 23681518.
-- Bounds come from the equipped projectile mesh, as in vanilla initialization.
local Profiles={}
-- Engine field names live here so capture, diagnostics and observers agree.
-- Family behavior (draw gates, stamina and launch placement) stays in state.lua.
Profiles.projectile_field="ProjectileClass_12_0B95F94245C55429626C82B945BFD43C"
local range_release="/Game/Blueprints/HoldableItems/Range/Base/BP_MasterRangeHoldableItem.BP_MasterRangeHoldableItem_C:SpawnProjectile_Server"
Profiles.families={
    bow={
        ammo="CurrentArrow",mesh="Arrow",speed="Speed",maximum="MaxSpeed",minimum="MinSpeed",
        loaded="IsArrow",release=range_release,
        telemetry={"Aiming","IsArrow","isReloading","Speed","MinSpeed","MaxSpeed","Alpha","LeftKeyDown","RightKeyDown"},
    },
    crossbow={
        ammo="CurrentArrow",mesh="Bolt",speed="Speed",maximum="MaxSpeed",minimum="MinSpeed",
        loaded="IsBolt",release=range_release,
        telemetry={"Aiming","IsBolt","isReloading","Speed","MinSpeed","MaxSpeed"},
    },
    spear={
        ammo="CurrentSpear",mesh="Mesh",speed="ThrowStrength",maximum="MaxStrength",minimum="MinStrength",
        release="/Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_WoodenPike.BP_HoldableItem_WoodenPike_C:SpawnProjectile_Server",
        telemetry={"Aiming","WasThrown","ThrowStrength","MaxStrength","MinStrength","Alpha"},
    },
}
Profiles.projectiles={
    ["/Game/Blueprints/Projectiles/BP_Projectile_StoneArrow.BP_Projectile_StoneArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_CopperArrow.BP_Projectile_CopperArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_BronzeArrow.BP_Projectile_BronzeArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_IronArrow.BP_Projectile_IronArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedStoneArrow.BP_Projectile_PoisonedStoneArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedCopperArrow.BP_Projectile_PoisonedCopperArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedBronzeArrow.BP_Projectile_PoisonedBronzeArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedIronArrow.BP_Projectile_PoisonedIronArrow_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_WoodenBolt.BP_Projectile_WoodenBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_CopperBolt.BP_Projectile_CopperBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_BronzeBolt.BP_Projectile_BronzeBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_IronBolt.BP_Projectile_IronBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedWoodenBolt.BP_Projectile_PoisonedWoodenBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedCopperBolt.BP_Projectile_PoisonedCopperBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedBronzeBolt.BP_Projectile_PoisonedBronzeBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_PoisonedIronBolt.BP_Projectile_PoisonedIronBolt_C"]={family="crossbow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_WoodenPike.BP_Projectile_WoodenPike_C"]={family="spear",radius=1.5,mass=10.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_StonePike.BP_Projectile_StonePike_C"]={family="spear",radius=1.5,mass=13.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_CopperPike.BP_Projectile_CopperPike_C"]={family="spear",radius=1.5,mass=13.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_BronzePike.BP_Projectile_BronzePike_C"]={family="spear",radius=1.5,mass=13.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_IronPike.BP_Projectile_IronPike_C"]={family="spear",radius=1.5,mass=13.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_FishingSpear.BP_Projectile_FishingSpear_C"]={family="spear",radius=4,mass=10.0,damping=0.05000000074505806,gravity_scale=1},
    ["/Game/Blueprints/Projectiles/BP_Projectile_ArrowOfRandomness.BP_Projectile_ArrowOfRandomness_C"]={family="bow",radius=0.5,mass=1.0,damping=0.05000000074505806,gravity_scale=1},
}
Profiles.weapons={}
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_Bow.BP_HoldableItem_Bow_C"]="bow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_Longbow.BP_HoldableItem_Longbow_C"]="bow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_RecurveBow.BP_HoldableItem_RecurveBow_C"]="bow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_TheSilencingWind.BP_HoldableItem_TheSilencingWind_C"]="bow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_Crossbow.BP_HoldableItem_Crossbow_C"]="crossbow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Range/BP_HoldableItem_Wooden_Crossbow.BP_HoldableItem_Wooden_Crossbow_C"]="crossbow"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_WoodenPike.BP_HoldableItem_WoodenPike_C"]="spear"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_StonePike.BP_HoldableItem_StonePike_C"]="spear"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_CopperPike.BP_HoldableItem_CopperPike_C"]="spear"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_BronzePike.BP_HoldableItem_BronzePike_C"]="spear"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_IronPike.BP_HoldableItem_IronPike_C"]="spear"
Profiles.weapons["BlueprintGeneratedClass /Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_FishingSpear.BP_HoldableItem_FishingSpear_C"]="spear"
return Profiles
