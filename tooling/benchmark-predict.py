#!/usr/bin/env python3
"""Compare pure predictor cost/equivalence with a Git revision; excludes Unreal calls."""
from pathlib import Path
import argparse, subprocess
from lupa.lua54 import LuaRuntime
p=argparse.ArgumentParser();p.add_argument('baseline');args=p.parse_args()
root=Path(__file__).resolve().parents[1]
path='mod/TrajectoryPreview/Scripts/predict.lua'
old=subprocess.check_output(['git','show',f'{args.baseline}:{path}'],cwd=root,text=True)
new=(root/path).read_text()
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path=str(root/'mod/TrajectoryPreview/Scripts/?.lua')+';'+lua.globals().package.path
run=lua.eval('''function(old_source,new_source)
local old=assert(load(old_source))()
local new=assert(load(new_source))()
local options={step=1/60,horizon=5,max_distance=20000,max_steps=512}
local snap={origin={X=0,Y=0,Z=0},velocity={X=7000,Y=120,Z=3000},gravity={X=0,Y=0,Z=-980},drag=.0000589,drag_interval=.03333299979567528}
local function miss() end
for _,speed in ipairs({2100,5500,11000}) do
 snap.velocity.X=speed
 local a,b=old.run(snap,options,miss),new.run(snap,options,miss)
 assert(a.status==b.status and #a.points==#b.points and a.distance==b.distance)
 for i,p in ipairs(a.points) do
  local q=b.points[i]
  assert(p.time==q.time and p.position.X==q.position.X and p.position.Y==q.position.Y and p.position.Z==q.position.Z)
 end
end
local function measure(module)
 collectgarbage('collect')
 local t=os.clock()
 for i=1,1000 do module.run(snap,options,miss) end
 local ms=(os.clock()-t)*1000
 collectgarbage('collect');collectgarbage('stop')
 local before=collectgarbage('count')
 for i=1,100 do module.run(snap,options,miss) end
 local allocated=collectgarbage('count')-before
 collectgarbage('restart');collectgarbage('collect')
 return ms,allocated
end
local a,b=measure(old)
local c,d=measure(new)
return a,c,b,d
end''')
a,b,c,d=run(old,new)
print('PASS exact predictor path/status/time equivalence at three launch speeds')
print(f'1000 predictions: baseline {a:.1f} ms; current {b:.1f} ms ({(1-b/a)*100:.1f}% less CPU time)')
print(f'100 predictions without GC: baseline {c:.1f} KiB; current {d:.1f} KiB ({(1-d/c)*100:.1f}% less allocation)')
print('Synthetic Lua measurement only; engine collision/rendering and GPU cost are excluded.')
