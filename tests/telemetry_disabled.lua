-- Disabling diagnostics must remove their native work, not just silence logs.
local callbacks={}
local snapshots,hooks,notifications,crosshairs,frames=0,0,0,0,0
local noop=function() end
local pc,pawn,weapon={},{},{}
local config={enabled=true,telemetry=false}
local modules={
    runtime={valid=function(o) return o~=nil end,local_player=function() return pc,pawn end,
        owned_weapon=function() return weapon,'bow' end,name=function() return 'test' end},
    telemetry={log=noop,describe=noop,snapshot=function() snapshots=snapshots+1;return {} end},
    preview={safe_frame=function(controller) assert(controller==pc);frames=frames+1 end},
    umg={root=function() return false end},settings={load=function() return config end},
    profiles=require('profiles'),crosshair={update=function() crosshairs=crosshairs+1 end},
}
local env=setmetatable({require=function(name) return assert(modules[name],name) end,
    Key={F6=6,F7=7,F8=8},ModifierKey={CONTROL=1,SHIFT=2},RegisterKeyBind=noop,
    NotifyOnNewObject=function() notifications=notifications+1 end,
    LoopInGameThreadAfterFrames=function(_,callback) callbacks.frame=callback end,
    LoopInGameThreadWithDelay=function(_,callback) callbacks.tick=callback end,
    StaticFindObject=function() return {} end,
    RegisterHook=function() hooks=hooks+1;return 1,2 end,
    collectgarbage=function() return 'incremental' end,
},{__index=_G})
assert(loadfile(assert(package.searchpath('main',package.path)),'t',env))()
for _=1,120 do callbacks.tick();callbacks.frame() end
assert(snapshots==0,'Disabled telemetry still captures weapon snapshots: '..snapshots)
assert(hooks==0 and notifications==0,'Disabled telemetry still registers observers')
assert(crosshairs==120 and frames==120,'Disabling diagnostics stopped ordinary preview work')
print('PASS disabled telemetry performs no snapshot/hook/notification work and preserves preview updates')
