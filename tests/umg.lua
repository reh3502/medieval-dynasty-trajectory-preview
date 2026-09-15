local U=require("umg")
local original_root=U.root
local construct,find,fname=StaticConstructObject,StaticFindObject,FName
local counts={visibility=0,color=0,position=0}
local function object()
    return setmetatable({IsValid=function() return true end,
        GetAddress=function() return 1 end,GetChildrenCount=function() return 0 end,
        SetVisibility=function() counts.visibility=counts.visibility+1 end,
        SetBrushColor=function() counts.color=counts.color+1 end,
        SetPosition=function() counts.position=counts.position+1 end,
        AddChildToCanvas=function(self) return self end},
        {__index=function() return function() end end})
end
local root=object()
U.root=function() return root,root end
StaticConstructObject=function() return object() end
StaticFindObject=function() return object() end
FName=function(name) return name end
local ok,err=pcall(function()
    local color={R=0,G=1,B=0}
    local function frame(alpha)
        assert(U.begin({}))
        U.line({X=0,Y=0},{X=20,Y=10},alpha,2,color)
        U.finish()
    end
    frame(1)
    local visibility,brushes=counts.visibility,counts.color
    frame(1)
    assert(counts.visibility==visibility and counts.color==brushes,
        "Unchanged appearance caused repeated engine writes")
    assert(counts.position==2,"Live geometry stopped updating")
    color.R=1;frame(0.5)
    assert(counts.color==brushes+1,"Changed appearance failed to update")
    U.begin({});U.finish()
    local hidden=counts.visibility
    U.begin({});U.finish()
    assert(counts.visibility==hidden,"Unused line was repeatedly hidden")
    frame(0.5)
    assert(counts.visibility==hidden+1,"Reused line did not become visible")
    U.hide();local before=counts.visibility;U.hide()
    assert(counts.visibility==before,"Hidden overlay repeatedly wrote visibility")
    frame(0.5)
    assert(counts.visibility==before+1,"Overlay did not resume after hiding")
end)
U.cleanup({})
U.root=original_root;StaticConstructObject=construct;StaticFindObject=find;FName=fname
assert(ok,err)
print("PASS UMG appearance reuse, live geometry and hide/show transitions")
