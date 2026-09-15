local V = {}
function V.new(x,y,z) return {X=x,Y=y,Z=z} end
function V.add(a,b) return V.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function V.sub(a,b) return V.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function V.scale(a,s) return V.new(a.X*s,a.Y*s,a.Z*s) end
function V.dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
function V.length(a) return math.sqrt(V.dot(a,a)) end
function V.unit(a)
    local n=V.length(a)
    if n < 1e-9 then return nil end
    return V.scale(a,1/n)
end
function V.finite(v)
    if type(v) ~= "table" then return false end
    for _, key in ipairs({"X","Y","Z"}) do
        local n=v[key]
        if type(n) ~= "number" or n ~= n or math.abs(n)==math.huge then return false end
    end
    return true
end
function V.lerp(a,b,t) return V.add(a,V.scale(V.sub(b,a),t)) end
return V
