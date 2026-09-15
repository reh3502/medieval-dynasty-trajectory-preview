-- Data-only preferences stored beside the mod scripts, never in a game save.
local defaults=require("config")
local S={}
local limits={opacity={0,1},thickness={0.5,8},marker_radius={2,24},
    horizon={0.1,5},max_distance={100,20000},step={1/240,0.1},max_steps={1,512},
    red={0,1},green={0,1},blue={0,1}}
local function finite(n) return type(n)=="number" and n==n and math.abs(n)<math.huge end
function S.normalize(input)
    local result={}
    for key,range in pairs(limits) do
        local fallback=defaults[key]
        if key=="red" then fallback=defaults.color.R elseif key=="green" then fallback=defaults.color.G elseif key=="blue" then fallback=defaults.color.B end
        local value=input[key]
        if not finite(value) then value=fallback end
        result[key]=math.max(range[1],math.min(range[2],value))
    end
    result.max_steps=math.floor(result.max_steps)
    result.enabled=defaults.enabled
    if type(input.enabled)=="boolean" then result.enabled=input.enabled end
    result.world_renderer=defaults.world_renderer
    result.telemetry=defaults.telemetry
    result.color={R=result.red,G=result.green,B=result.blue}
    result.ribbon_color=defaults.ribbon_color
    result.highlight_color=defaults.highlight_color
    return result
end
function S.parse(text)
    local values={}
    for line in text:gmatch("[^\r\n]+") do
        local key,value=line:match("^%s*([%a_]+)%s*=%s*([^#;]+)")
        if key then
            value=value:match("^%s*(.-)%s*$")
            if key=="enabled" and (value=="true" or value=="false") then values.enabled=value=="true"
            elseif limits[key] then values[key]=tonumber(value) end
        end
    end
    return S.normalize(values)
end
function S.serialize(values)
    local config=S.normalize(values)
    local keys={"enabled","opacity","thickness","marker_radius","horizon","max_distance","step","max_steps","red","green","blue"}
    local lines={"# TrajectoryPreview local preferences. Ctrl+R reloads edits."}
    for _,key in ipairs(keys) do
        local value=config[key]
        local text=type(value)=="number" and string.format("%.17g",value) or tostring(value)
        lines[#lines+1]=key.."="..text
    end
    return table.concat(lines,"\n").."\n"
end
function S.load(path)
    local file=io.open(path,"r")
    if not file then return S.normalize({}) end
    local content=file:read(65536) or ""
    file:close()
    return S.parse(content)
end
function S.save(path,values)
    local file,err=io.open(path,"w")
    if not file then return nil,err end
    local ok,write_error=file:write(S.serialize(values))
    local closed,close_error=file:close()
    if not ok or not closed then return nil,write_error or close_error end
    return true
end
return S
