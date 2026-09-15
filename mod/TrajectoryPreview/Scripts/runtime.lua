-- Unreal access is confined to callbacks on the game thread.
local R = {}
local objects={}
local finder
-- Cache only explicitly requested static classes/default objects. Never use
-- this for a level actor. Invalid objects are reacquired after reload/travel.
function R.static(path)
    if finder~=StaticFindObject then objects={};finder=StaticFindObject end
    local object=objects[path]
    if not R.valid(object) then object=StaticFindObject(path);objects[path]=object end
    return object
end
function R.valid(o)
    if o == nil then return false end
    local ok, valid = pcall(function() return o:IsValid() end)
    return ok and valid == true
end
function R.read(o, key)
    if o == nil then return nil end
    local ok, value = pcall(function() return o[key] end)
    if ok then return value end
end
function R.name(o)
    if not R.valid(o) then return "<invalid>" end
    local ok, name = pcall(function() return o:GetFullName() end)
    return ok and name or "<non-object>"
end
function R.weak_name(o)
    if o==nil then return "<invalid>" end
    local ok,object=pcall(function() return o:Get() end)
    return ok and R.name(object) or "<unreadable weak reference>"
end
function R.vec(v)
    if v == nil then return nil end
    local ok, result = pcall(function() return {X=v.X, Y=v.Y, Z=v.Z} end)
    if ok then return result end
end
local local_controller
function R.local_player()
    -- UEHelpers.GetPlayerController also accepts non-local controllers; do not use it.
    if R.valid(local_controller) and local_controller:IsLocalPlayerController() then
        local pawn=local_controller.Pawn
        if R.valid(pawn) and pawn:IsLocallyControlled() then return local_controller,pawn end
    end
    local_controller=nil
    for _, pc in ipairs(FindAllOf("PlayerController") or {}) do
        if R.valid(pc) and pc:IsLocalPlayerController() then
            local pawn = pc.Pawn
            if R.valid(pawn) and pawn:IsLocallyControlled() then local_controller=pc;return pc, pawn end
        end
    end
end
function R.owned_weapon(pawn)
    local weapon=R.read(pawn,"HeldItem")
    if not R.valid(weapon) then return end
    local family=require("profiles").weapons[R.name(weapon:GetClass())]
    if family and R.valid(weapon.PlayerCharacterReference)
        and weapon.PlayerCharacterReference:GetAddress()==pawn:GetAddress() then return weapon,family end
end
return R
