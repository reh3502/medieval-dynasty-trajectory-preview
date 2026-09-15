-- Suppress only the local crosshair widget, without changing saved HUD settings.
local R=require('runtime')
local C={}
local current,marker
local marker_name='MDTrajectoryCrosshairOpacity'
local function restore()
    if R.valid(current) and R.valid(marker) then
        current:SetRenderOpacity(marker.RenderOpacity)
        marker:RemoveFromParent()
    end
    current=nil;marker=nil
end
function C.update(pc,enabled)
    local widget
    if R.valid(pc) and pc:IsLocalPlayerController() then
        local hud=R.read(pc,'UI_PlayerHUDReference')
        local interaction=R.valid(hud) and R.read(hud,'UI_Interaction')
        widget=R.valid(interaction) and R.read(interaction,'UI_Crosshair')
    end
    if not R.valid(widget) then restore();return end
    if not R.valid(current) or current:GetAddress()~=widget:GetAddress() then
        restore();current=widget
        -- The collapsed transient marker preserves the original opacity over
        -- Ctrl+R, so a reload cannot accidentally capture our zero as default.
        local panel=widget.MainTargetPanel
        for i=0,panel:GetChildrenCount()-1 do
            local child=panel:GetChildAt(i)
            if R.valid(child) and child:GetFName():ToString()==marker_name then marker=child;break end
        end
    end
    if not enabled then restore();return end
    if not R.valid(marker) then
        local original=widget.RenderOpacity
        assert(type(original)=='number','crosshair opacity unavailable')
        local class=StaticFindObject('/Script/UMG.Border')
        marker=StaticConstructObject(class,widget.WidgetTree,FName(marker_name),0x40)
        assert(R.valid(marker),'crosshair restore marker creation failed')
        marker:SetRenderOpacity(original)
        marker:SetVisibility(1) -- Collapsed: no drawing, layout or input.
        widget.MainTargetPanel:AddChildToCanvas(marker)
    end
    if widget.RenderOpacity~=0 then widget:SetRenderOpacity(0) end
end
return C
