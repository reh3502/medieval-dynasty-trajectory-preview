local runtime=package.loaded.runtime
local globals={StaticFindObject=StaticFindObject,StaticConstructObject=StaticConstructObject,FName=FName}
package.loaded.runtime={valid=function(o) return type(o)=='table' end,read=function(o,k) return o[k] end}
local children={}
local panel={GetChildrenCount=function() return #children end,GetChildAt=function(_,i) return children[i+1] end,
    AddChildToCanvas=function(_,child) children[#children+1]=child;return {} end}
local widget={RenderOpacity=0.7,MainTargetPanel=panel,WidgetTree={},GetAddress=function() return 1 end,
    SetRenderOpacity=function(self,value) self.RenderOpacity=value end}
local pc={UI_PlayerHUDReference={UI_Interaction={UI_Crosshair=widget}},IsLocalPlayerController=function() return true end}
StaticFindObject=function() return {} end
FName=function(value) return value end
StaticConstructObject=function(_,outer,name,flags)
    assert(outer==widget.WidgetTree and flags==0x40)
    return {SetRenderOpacity=function(self,v) self.RenderOpacity=v end,SetVisibility=function(_,v) assert(v==1) end,
        GetFName=function() return {ToString=function() return name end} end,
        RemoveFromParent=function() children={} end}
end
package.loaded.crosshair=nil
local C=require('crosshair')
C.update(pc,true);assert(widget.RenderOpacity==0 and #children==1)
C.update(pc,true);assert(#children==1)
-- Simulate Ctrl+R losing all Lua state while keeping the live HUD.
package.loaded.crosshair=nil;C=require('crosshair')
C.update(pc,true);assert(#children==1)
C.update(pc,false);assert(widget.RenderOpacity==0.7 and #children==0)
-- Respect a crosshair already hidden by its original opacity.
widget.RenderOpacity=0;C.update(pc,true);C.update(pc,false);assert(widget.RenderOpacity==0)
widget.RenderOpacity=0.4;C.update(pc,true);C.update(nil,true)
assert(widget.RenderOpacity==0.4 and #children==0)
package.loaded.crosshair=nil;package.loaded.runtime=runtime
for _,key in ipairs({'StaticFindObject','StaticConstructObject','FName'}) do _G[key]=globals[key] end
print('PASS crosshair toggle, prior opacity, reload restoration and lost controller')
