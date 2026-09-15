local N=require("neat_structs")
local query={}
for i=0,175 do query[string.format('MDTrajectoryByte%03d',i)]=0 end
N.validate(query)
query.MDTrajectoryByte072=1
assert(not pcall(N.validate,query),'component heap pointer accepted')
query.MDTrajectoryByte072=0;query.MDTrajectoryByte104=1
assert(not pcall(N.validate,query),'actor heap pointer accepted')
query.MDTrajectoryByte104=0;query.MDTrajectoryByte160=nil
assert(not pcall(N.validate,query),'missing collision shape bytes accepted')
print('PASS opaque query completeness and heap-ownership guards')
