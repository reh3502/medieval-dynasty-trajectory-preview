local R = require("runtime")
local Profiles = require("profiles")
local T = {}
local escapes={['"']='\\"', ['\\']='\\\\', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
local function quote(value)
    return '"'..value:gsub('[%z\1-\31\\"]',function(c)
        return escapes[c] or string.format("\\u%04x",string.byte(c))
    end)..'"'
end
local function encode(v)
    local kind=type(v)
    if kind=="nil" then return "null" end
    if kind=="number" then
        if v~=v or math.abs(v)==math.huge then return "null" end
        return string.format("%.17g",v)
    end
    if kind=="boolean" then return tostring(v) end
    if kind=="table" then
        local parts={}
        for k,item in pairs(v) do parts[#parts+1]=quote(tostring(k))..":"..encode(item) end
        table.sort(parts)
        return "{"..table.concat(parts,",").."}"
    end
    return quote(tostring(v))
end
T.encode=encode
function T.time(actor)
    local library=R.static("/Script/Engine.Default__GameplayStatics")
    if R.valid(library) then return library:GetTimeSeconds(actor) end
end

function T.log(event, values)
    if T.enabled==false and not event:find("error") and event~="started" then return end
    print("[TrajectoryPreview] " .. event .. " " .. encode(values or {}) .. "\n")
end
function T.snapshot(bow, pawn, pc)
    local result = {weapon=R.name(bow), pawn=R.name(pawn), hud=R.name(R.read(pc, "MyHUD"))}
    local family=Profiles.weapons[R.name(bow:GetClass())]
    local fields=Profiles.families[family or "bow"]
    for _,key in ipairs(fields.telemetry) do
        local value=R.read(bow,key)
        if type(value)=="boolean" or type(value)=="number" then result[key]=value end
    end
    local ok,ammo=pcall(function()
        local data=bow[fields.ammo]
        return data[Profiles.projectile_field]:GetObjectID():GetAssetPathName():ToString()
    end)
    if ok then result.ammo=ammo end
    result.view = R.read(pawn, "ViewMode")
    if R.valid(pawn) then result.owner_velocity = R.vec(pawn:GetVelocity()) end
    local arrow=R.read(bow,fields.mesh)
    if R.valid(arrow) then result.origin = R.vec(arrow:K2_GetComponentLocation()) end
    return result
end
function T.describe(object, label)
    if not R.valid(object) then T.log(label, {status="invalid"}); return end
    T.log(label, {object=R.name(object)})
    local class = object:GetClass()
    local depth = 0
    while R.valid(class) and depth < 12 do
        class:ForEachProperty(function(property)
            local key = property:GetFName():ToString()
            local value = R.read(object, key)
            if type(value) ~= "number" and type(value) ~= "boolean" and type(value) ~= "string" then
                value = R.valid(value) and R.name(value) or tostring(value)
            end
            T.log(label .. ".property", {name=key, value=value})
        end)
        class = class:GetSuperStruct()
        depth = depth + 1
    end
end
function T.function_info(path)
    local fn=StaticFindObject(path)
    if not R.valid(fn) then T.log("function_missing", {path=path}); return end
    fn:ForEachProperty(function(property)
        T.log("function_parameter", {path=path, property=property:GetFullName()})
    end)
end
return T
