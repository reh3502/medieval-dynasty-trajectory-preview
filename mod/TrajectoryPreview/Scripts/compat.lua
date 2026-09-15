-- Reject unverified executable layouts before registering private struct fields.
local M={}
function M.check()
    local path=assert(package.searchpath("config",package.path))
    path=path:gsub("config%.lua$","../../../../Medieval_Dynasty-Win64-Shipping.exe")
    local f=assert(io.open(path,"rb"),"Cannot verify game build")
    f:seek("set",73321956)
    local signature=f:read(24)
    f:close()
    assert(signature=="\x52\x53\x44\x53\x1d\xe2\x9a\x87\x14\xa0\xd0\x48\xa7\x07\x80\xd2\x49\xd7\x13\x88\x01\x00\x00\x00","Unsupported game PDB identity; collision layout disabled")
end
return M
