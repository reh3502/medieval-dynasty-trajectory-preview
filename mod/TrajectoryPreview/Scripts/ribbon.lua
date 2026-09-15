-- A local UI texture supplies feathered edges and a shaded gray cross-section.
local R=require("runtime")
local T=require("telemetry")
local B={}
local texture,brush,failed
function B.brush(context)
    if failed then return end
    if R.valid(texture) then return brush end
    local ok,value=pcall(function()
        local config=assert(package.searchpath("config",package.path))
        local path=config:gsub("config%.lua$","../Textures/trajectory.png")
        local rendering=StaticFindObject("/Script/Engine.Default__KismetRenderingLibrary")
        texture=rendering:ImportFileAsTexture2D(context,path)
        assert(R.valid(texture),"Trajectory texture import failed")
        local widgets=StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        return widgets:MakeBrushFromTexture(texture,64,64)
    end)
    if ok then brush=value;T.log("ribbon_texture",{loaded=true});return brush end
    failed=true;T.log("ribbon_error",{error=tostring(value)})
end
function B.texture(context)
    B.brush(context)
    return texture
end
return B
