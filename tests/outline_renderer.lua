local saved={}
for _,key in ipairs({'outline_renderer','outline_stencil','highlight','telemetry'}) do saved[key]=package.loaded[key] end
local globals={StaticFindObject=StaticFindObject,StaticConstructObject=StaticConstructObject,FindAllOf=FindAllOf,FName=FName}
local depth=0
local components={}
local scans=0
local applied,restored=0,0
local function valid(o) o.IsValid=function(self) return not self.destroyed end;return o end
local function array(items)
    items=items or {}
    items.Empty=function(self) for i=#self,1,-1 do self[i]=nil end end
    items.ForEach=function(self,fn) for i,v in ipairs(self) do fn(i,{get=function() return v end}) end end
    return items
end
FName=function(value) return {ToString=function() return value end} end
local pawn=valid({GetAddress=function() return 1 end,IsLocallyControlled=function() return true end})
pawn.FinishAddComponent=function(_,c) assert(c.bEnabled==false and c.replicated==false) end
local function actor(id) return valid({GetAddress=function() return id end,GetFullName=function() return 'target'..id end}) end
local a,b=actor(2),actor(3)
local marker
package.loaded.outline_stencil={
    apply=function(target) applied=applied+1;marker=valid({target=target});return marker end,
    restore=function(m) restored=restored+1;m.destroyed=true end,
    cleanup=function() if marker and not marker.destroyed then restored=restored+1;marker.destroyed=true end end}
package.loaded.highlight={eligible=function(o) return not o.dead end}
package.loaded.telemetry={log=function() end}
local material=valid({})
local mid=valid({SetScalarParameterValue=function() end})
local sys={GetConsoleVariableIntValue=function() return depth end,
    ExecuteConsoleCommand=function(_,context,command) assert(context==pawn);depth=assert(tonumber(command:match('r.CustomDepth (%d+)'))) end}
StaticFindObject=function(path)
    if path:find('KismetSystemLibrary',1,true) then return sys end
    if path:find('AssetRegistryHelpers',1,true) then return {GetAsset=function() return material end} end
    if path:find('KismetMaterialLibrary',1,true) then return {CreateDynamicMaterialInstance=function() return mid end} end
    return {}
end
StaticConstructObject=function(_,owner,name)
    local c=valid({Settings={WeightedBlendables={Array=array()}},_tags=array(),
        GetFName=function() return name end,GetFullName=function() return 'postprocess' end,
        GetOwner=function() return owner end,SetIsReplicated=function(self,v) self.replicated=v end,
        SetComponentTickEnabled=function() end,K2_DestroyComponent=function(self) self.destroyed=true end})
    setmetatable(c,{__index=function(self,key) if key=='ComponentTags' then return self._tags end end,
        __newindex=function(self,key,value) if key=='ComponentTags' then self._tags=array(value) else rawset(self,key,value) end end})
    components[#components+1]=c;return c
end
FindAllOf=function() scans=scans+1;return components end
package.loaded.outline_renderer=nil
local O=require('outline_renderer')
local ok,err=pcall(function()
    assert(O.draw(pawn,a) and depth==3 and applied==1)
    assert(components[1].bEnabled and components[1].Settings.WeightedBlendables.Array[1].Object==mid)
    assert(O.draw(pawn,a) and applied==1,'same target should reuse stencil state')
    assert(O.draw(pawn,b) and applied==2 and restored==1,'target switch must restore previous mesh')
    b.dead=true
    assert(not O.draw(pawn,b) and restored==2 and not components[1].bEnabled)
    assert(O.draw(pawn,a))
    assert(scans==1,'ordinary target changes must not scan all post-process components')
    package.loaded.outline_renderer=nil
    O=require('outline_renderer');O.hide()
    assert(depth==0 and components[1].destroyed and restored==3,'reload must restore depth and meshes')
    assert(O.draw(pawn,a))
    depth=2 -- Another effect takes ownership of the renderer setting.
    O.hide();assert(depth==2,'cleanup must preserve an external depth change')
    assert(O.draw(pawn,a))
    package.loaded.outline_stencil.apply=function() error('injected stencil failure') end
    b.dead=false
    assert(not O.draw(pawn,b) and depth==2 and components[#components].destroyed)
end)
-- Restore globals that were nil before this test, too.
for _,key in ipairs({'StaticFindObject','StaticConstructObject','FindAllOf','FName'}) do _G[key]=globals[key] end
for _,key in ipairs({'outline_renderer','outline_stencil','highlight','telemetry'}) do package.loaded[key]=saved[key] end
assert(ok,err)
print('PASS outline target transitions, material attachment, reload restoration and failure cleanup')
