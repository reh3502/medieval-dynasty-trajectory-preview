local saved={}
for _,key in ipairs({'runtime','telemetry','ribbon','world_renderer'}) do saved[key]=package.loaded[key];package.loaded[key]=nil end
local globals={StaticFindObject=StaticFindObject,StaticConstructObject=StaticConstructObject,FName=FName,FindAllOf=FindAllOf,LoadAsset=LoadAsset}
local calls,events={},{}
local parameters={}
local parameter_calls=0
local now=10
local material={bDisableDepthTest=false,TwoSided=false,bEnableResponsiveAA=true}
local pawn={IsLocallyControlled=function() return true end,GetAddress=function() return 1 end}
local object={}
local destroyed=false
local function record(name,...) calls[#calls+1]={name,...} end
function object:SetVisibility(value) record('visible',value) end
function object:SetCollisionEnabled(value) record('collision',value) end
function object:SetGenerateOverlapEvents(value) record('overlap',value) end
function object:SetCastShadow(value) record('shadow',value) end
function object:SetIsReplicated(value) record('replicated',value) end
function object:SetHiddenInGame(value) record('hidden',value) end
function object:GetFName() return {ToString=function() return 'MDTrajectoryWorldRibbon' end} end
function object:GetOwner() return pawn end
function object:K2_DestroyComponent(owner) assert(owner==pawn);destroyed=true end
function object:CreateDynamicMaterialInstance()
    return {SetTextureParameterValue=function() end,SetVectorParameterValue=function() end,SetScalarParameterValue=function(_,key,value) parameters[key]=value;parameter_calls=parameter_calls+1 end}
end
function object:CreateMeshSection_LinearColor(index,verts,triangles,normals,uv,u1,u2,u3,colors,tangents,collision)
    assert(collision==false);record('create',index)
end
function object:UpdateMeshSection_LinearColor(index) record('update',index) end
function object:ClearMeshSection(index) record('clear',index) end
function pawn:FinishAddComponent(component,manual,transform)
    assert(component==object and manual and transform.Scale3D.X==1)
    assert(calls[2][1]=='collision' and calls[2][2]==0)
    assert(calls[3][1]=='overlap' and calls[3][2]==false)
    assert(calls[5][1]=='replicated' and calls[5][2]==false)
    record('register')
end
package.loaded.runtime={valid=function(o) return type(o)=='table' end,name=function() return 'test' end,read=function(o,key) return o[key] end}
package.loaded.telemetry={log=function(name,data) events[#events+1]={name,data} end,time=function() return now end}
package.loaded.ribbon={texture=function() return {} end}
StaticFindObject=function(path)
    if path:find('Widget3DPassThrough') or path:find('M_TrajectoryThread') then return material end
    if path:find('KismetRendering') then return {ImportFileAsTexture2D=function(_,context,path,...)
        assert(select('#',...)==0,'texture import received an extra Lua return value')
        assert(context==pawn and path:match('/Textures/world%-box.png$'))
        return {}
    end} end
    return {}
end
StaticConstructObject=function(class,outer,name,flags) assert(outer==pawn and flags==0x40);return object end
FName=function(name) return name end
FindAllOf=function() return {} end
local W=require('world_renderer')
local result={status='range',points={{position={X=0,Y=0,Z=0}},{position={X=900,Y=0,Z=0}}}}
local opts={thickness=2,marker_radius=7,color={R=1,G=1,B=1},opacity=.85}
assert(W.draw(pawn,result,{X=0,Y=1,Z=0},opts))
assert(events[1][1]=='world_renderer_ready' and parameters.Reveal==0)
now=10.12
assert(W.draw(pawn,result,{X=0,Y=2,Z=0},opts))
assert(calls[#calls][1]=='update' and math.abs(parameters.Reveal-1)<1e-8)
local before=parameter_calls
assert(W.draw(pawn,result,{X=0,Y=2,Z=0},opts))
assert(parameter_calls==before,'unchanged parameters must not be sent again')
W.hide();assert(calls[#calls][1]=='visible' and calls[#calls][2]==false)
assert(W.draw(pawn,result,{X=0,Y=2,Z=0},opts))
assert(parameters.Reveal==0,'reacquiring aim must restart appearance')
FindAllOf=function() return {object} end
W.cleanup();assert(destroyed)
-- A depth-disabled material must fail before any new component construction.
material.bDisableDepthTest=true
StaticConstructObject=function() error('must not construct') end
assert(not W.draw(pawn,result,{X=0,Y=1,Z=0},opts))
assert(events[#events][1]=='world_renderer_error')
for _,key in ipairs({'runtime','telemetry','ribbon','world_renderer'}) do package.loaded[key]=saved[key] end
for _,key in ipairs({'StaticFindObject','StaticConstructObject','FName','FindAllOf','LoadAsset'}) do _G[key]=globals[key] end
print('PASS world adapter collision/replication disabled before registration, mesh reuse, cleanup and depth-test guard')
