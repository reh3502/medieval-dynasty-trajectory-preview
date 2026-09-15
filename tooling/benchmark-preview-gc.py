#!/usr/bin/env python3
"""Compare Lua collector pauses on the real numeric/ribbon workload.

Run with the same lupa.lua54 Python runtime as test-mod.py. The retained tables
model a larger VM heap; native Unreal wrappers/uploads require live profiling.
No wall-time thresholds: print distributions for repeated local comparison.
"""
from pathlib import Path
from lupa.lua54 import LuaRuntime

root = Path(__file__).resolve().parents[1]
for mode in ("default", "incremental", "generational"):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().package.path = str(root / "mod/TrajectoryPreview/Scripts/?.lua") + ";" + lua.globals().package.path
    lua.globals().mode = mode
    lua.execute('''
local B=require('batched_prediction');local G=require('world_geometry')
local snapshot={origin={X=0,Y=0,Z=100},velocity={X=3000,Y=0,Z=1000},
    gravity={X=0,Y=0,Z=-980},drag=.000053,drag_interval=.03333299979567528}
local options={step=1/60,horizon=5,max_steps=512,max_distance=20000,thickness=2,marker_radius=7}
local retained={}
for i=1,50000 do retained[i]={X=i,Y=i,Z=i} end
collectgarbage('collect')
if mode=='incremental' then collectgarbage('incremental',110,200,10)
elseif mode=='generational' then collectgarbage('generational',20,100)
else collectgarbage('incremental',200,100,13) end
local durations,peak={},0
local previous
for i=1,2000 do
    local started=os.clock()
    local result=B.run(snapshot,options,function() end,function() return false end,true)
    previous=G.build(result,{X=0,Y=0,Z=170},options,true)
    durations[i]=(os.clock()-started)*1000
    peak=math.max(peak,collectgarbage('count'))
end
assert(#retained==50000 and #previous[1].vertices>0)
table.sort(durations)
print(string.format('%s: median %.3f ms, p99 %.3f ms, max %.3f ms, peak %.0f KB',
    mode,durations[1000],durations[1980],durations[2000],peak))
''')
