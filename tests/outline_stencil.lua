local S=require('outline_stencil')
local saved={FName=FName,StaticFindObject=StaticFindObject,StaticConstructObject=StaticConstructObject,FindAllOf=FindAllOf}
local function array(items)
    items=items or {}
    items.Empty=function(self) for i=#self,1,-1 do self[i]=nil end end
    return items
end
FName=function(value) return {ToString=function() return value end} end
StaticFindObject=function(path) return {path=path,IsValid=function() return true end} end
local marker,actor,meshes
local function mesh(label,depth,stencil,mask)
    return {IsValid=function() return true end,GetFName=function() return FName(label) end,
        IsVisible=function() return true end,bHiddenInGame=false,bRenderInMainPass=true,
        bRenderCustomDepth=depth,CustomDepthStencilValue=stencil,CustomDepthStencilWriteMask=mask,
        SetRenderCustomDepth=function(self,value) self.bRenderCustomDepth=value end,
        SetCustomDepthStencilValue=function(self,value) self.CustomDepthStencilValue=value end,
        SetCustomDepthStencilWriteMask=function(self,value) self.CustomDepthStencilWriteMask=value end}
end
StaticConstructObject=function(class,owner,label,flags)
    assert(class.path=='/Script/Engine.SceneComponent' and owner==actor and flags==0x40)
    marker=setmetatable({_tags=array(),IsValid=function() return true end,
        GetFName=function() return label end,GetOwner=function() return actor end,
        SetIsReplicated=function(_,value) assert(value==false) end,
        SetComponentTickEnabled=function(_,value) assert(value==false) end},
        {__index=function(self,key) if key=='ComponentTags' then return self._tags end end,
         __newindex=function(self,key,value) if key=='ComponentTags' then self._tags=array(value) else rawset(self,key,value) end end})
    return marker
end
FindAllOf=function() return marker and {marker} or {} end
actor={IsValid=function() return true end,
    K2_GetComponentsByClass=function(_,class)
        local result={}
        for _,value in ipairs(class.path=='/Script/Engine.MeshComponent' and meshes or (marker and {marker} or {})) do
            result[#result+1]={get=function() return value end}
        end
        return result
    end,
    FinishAddComponent=function(_,component,manual,transform)
        assert(component==marker and manual and transform.Scale3D.X==1)
    end}
local ok,err=pcall(function()
    local body=mesh('Body',false,5,8)
    local clothing=mesh('Clothing',true,17,3)
    local hidden=mesh('HiddenProxy',false,0,0);hidden.bHiddenInGame=true
    meshes={body,clothing,hidden}
    local first=S.apply(actor,254)
    assert(first==marker and #marker.ComponentTags==2)
    assert(body.bRenderCustomDepth and clothing.bRenderCustomDepth)
    assert(body.CustomDepthStencilValue==254 and clothing.CustomDepthStencilWriteMask==0)
    assert(hidden.CustomDepthStencilValue==0)
    -- Simulate Ctrl+R by discarding the module and all its Lua state.
    package.loaded.outline_stencil=nil
    local reloaded=require('outline_stencil');reloaded.cleanup()
    assert(body.bRenderCustomDepth==false and body.CustomDepthStencilValue==5 and body.CustomDepthStencilWriteMask==8)
    assert(clothing.bRenderCustomDepth==true and clothing.CustomDepthStencilValue==17 and clothing.CustomDepthStencilWriteMask==3)
    assert(#marker.ComponentTags==0)
    assert(reloaded.apply(actor,254)==first,'marker should be reused')
    clothing.CustomDepthStencilValue=23 -- A different effect takes ownership.
    body.CustomDepthStencilWriteMask=4 -- A later independent field change.
    reloaded.restore(marker)
    assert(clothing.CustomDepthStencilValue==23 and clothing.bRenderCustomDepth)
    assert(body.CustomDepthStencilValue==5 and body.CustomDepthStencilWriteMask==4)
    -- An interrupted setter must still leave recoverable metadata.
    body.SetCustomDepthStencilWriteMask=function() error('injected setter failure') end
    assert(not pcall(reloaded.apply,actor,254))
    assert(#marker.ComponentTags==2 and body.CustomDepthStencilValue==254)
    reloaded.cleanup()
    assert(body.CustomDepthStencilValue==5 and body.bRenderCustomDepth==false)
    assert(#marker.ComponentTags==0)
    meshes={hidden};assert(reloaded.apply(actor,254)==nil)
end)
FName=saved.FName;StaticFindObject=saved.StaticFindObject
StaticConstructObject=saved.StaticConstructObject;FindAllOf=saved.FindAllOf
assert(ok,err)
print('PASS outline stencil restoration, hot reload, hidden meshes, ownership changes and partial failure')
