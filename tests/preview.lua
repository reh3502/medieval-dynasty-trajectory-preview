local Preview=require("preview")
local S=require("state")
local U=require("umg")
local T=require("telemetry")
local capture,hide,log=S.capture,U.hide,T.log
local hidden=0
U.hide=function() hidden=hidden+1 end
T.log=function() end
local ok,err=pcall(function()
    for _,reason in ipairs({"no_pawn","unsupported_weapon","disabled"}) do
        Preview.last={result={status="hit"}}
        S.capture=function() return nil,reason end
        Preview.safe_frame(nil,{})
        assert(Preview.last==nil,"Rejected frame retained an old trajectory")
    end
    Preview.last={result={status="hit"}}
    S.capture=function() error("Destroyed component") end
    Preview.safe_frame(nil,{})
    assert(Preview.last==nil,"Failed frame retained an old trajectory")
    assert(hidden==4,"Invalid frames did not hide the overlay")
end)
S.capture=capture;U.hide=hide;T.log=log
assert(ok,err)
print("PASS preview invalidation on lost state and capture failure")
