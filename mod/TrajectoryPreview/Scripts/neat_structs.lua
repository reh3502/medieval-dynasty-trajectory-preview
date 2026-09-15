-- Build 23681518: private NeatCollision value layouts from the matching PDB.
-- UE4SS otherwise converts these opaque returns to {}, losing the query.
-- Preserve their bytes in Lua-owned tables. Reject heap-backed ignore arrays:
-- only bounded inline storage can be copied this way without shared ownership.
local N={}
local ready=false
local keys={}
for offset=0,175 do keys[offset]=string.format("MDTrajectoryByte%03d",offset) end
local function key(offset) return keys[offset] end
function N.register()
    if ready then return end
    require("compat").check()
    for name,size in pairs({NeatCollisionShape=16,NeatCollisionQueryData=176}) do
        for offset=0,size-1 do
            RegisterCustomProperty({Name=key(offset),Type=PropertyTypes.ByteProperty,
                BelongsToClass="/Script/NeatCollision."..name,OffsetInternal=offset})
        end
    end
    ready=true
end
function N.validate(query)
    for offset=0,175 do
        local value=query[key(offset)]
        assert(type(value)=="number" and value>=0 and value<=255,"Opaque query marshalling failed")
    end
    -- FCollisionQueryParams at +8: inline component allocation at +32,
    -- inline actor allocation at +80. Secondary heap pointers at +72/+104.
    for _,base in ipairs({72,104}) do
        for offset=base,base+7 do assert(query[key(offset)]==0,"Heap-backed collision query cannot be copied") end
    end
end
return N
