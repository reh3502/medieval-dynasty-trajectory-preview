local S=require("settings")
local c=S.parse("enabled=false\nmax_steps=9999999\nhorizon=-10\nstep=0\nred=2\nopacity=nan\nunknown=7\n")
assert(c.enabled==false and c.max_steps==512 and c.horizon==0.1 and c.step==1/240 and c.red==1)
assert(c.opacity==0.85 and c.unknown==nil)
local roundtrip=S.parse(S.serialize(c))
for _,key in ipairs({"enabled","max_steps","horizon","step","red","opacity"}) do
    assert(roundtrip[key]==c[key],key.." preference did not round-trip")
end
local restored=S.load("this-preferences-file-does-not-exist")
assert(restored.enabled==true and restored.horizon==5)
local hostile=S.parse("enabled=os.execute('anything')\nmax_steps=1e999\n")
assert(hostile.enabled==true and hostile.max_steps==512)
print("PASS data-only settings validation and round-trip")
