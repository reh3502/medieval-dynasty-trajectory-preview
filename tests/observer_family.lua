-- Run the real startup/tick wiring with the unequipped family unloaded.
local family='spear'
local weapon,pawn,pc={},{},{}
local lookups,callbacks={},{}
local noop=function() end
local modules={
    runtime={valid=function(o) return o~=nil end,local_player=function() return pc,pawn end,
        owned_weapon=function() return weapon,family end,name=function() return 'test' end},
    telemetry={log=noop,describe=noop,snapshot=function() return {} end},
    preview={safe_frame=noop},umg={root=function() return false end},
    settings={load=function() return {telemetry=true,enabled=true} end},
    profiles=require('profiles'),crosshair={update=noop}
}
local env=setmetatable({require=function(name) return assert(modules[name],name) end,
    Key={F6=6,F7=7,F8=8},ModifierKey={CONTROL=1,SHIFT=2},
    RegisterKeyBind=noop,NotifyOnNewObject=noop,LoopInGameThreadAfterFrames=noop,
    LoopInGameThreadWithDelay=function(delay,callback) callbacks[delay]=callback end,
    StaticFindObject=function(path)
        lookups[path]=(lookups[path] or 0)+1
        if family=='spear' and path:find('/Range/',1,true) then return nil end
        return {}
    end,
    RegisterHook=function() return 1,2 end,
    collectgarbage=function() return 'incremental' end
},{__index=_G})
local path=assert(package.searchpath('main',package.path))
assert(loadfile(path,'t',env))()
for _=1,100 do callbacks[250]() end
local spear='/Game/Blueprints/HoldableItems/Melee/BP_HoldableItem_WoodenPike.BP_HoldableItem_WoodenPike_C:SpawnProjectile_Server'
local bow='/Game/Blueprints/HoldableItems/Range/Base/BP_MasterRangeHoldableItem.BP_MasterRangeHoldableItem_C:SpawnProjectile_Server'
assert(lookups[spear]==1,'Spear observer was not registered once')
assert(lookups[bow]==nil,'Spear repeatedly searches for an unloaded bow function')
family='bow'
callbacks[250]()
assert(lookups[bow]==1,'Switching to bow failed to install its observer')
family='crossbow'
callbacks[250]()
assert(lookups[bow]==1 and lookups[spear]==1,'Existing observers were registered twice')
print('PASS equipped-family observers avoid unloaded lookups and survive weapon switching')
