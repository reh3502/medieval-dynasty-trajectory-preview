local M=require("presentation")
local result={status="horizon",points={
    {position={X=5,Y=0,Z=0}}, {position={X=10,Y=5,Z=0}},
    {position={X=15,Y=10,Z=0}}, {position={X=20,Y=15,Z=0}}}}
local camera={origin={X=0,Y=0,Z=0},forward={X=1,Y=0,Z=0},near=1,width=100,height=100}
local widths={}
M.draw(result,camera,function(p) return {X=p.X,Y=p.Y} end,
    function(a,b,opacity,width,style)
        assert(style=="ribbon" and opacity>=0 and opacity<=0.8)
        widths[#widths+1]=width
    end,{opacity=0.8,thickness=2})
assert(#widths==3 and widths[1]>widths[2] and widths[2]>widths[3])
assert(result.points[4].position.X==20 and result.points[4].position.Y==15,
    "Presentation changed predicted geometry")
print("PASS ribbon taper, opacity bounds and unchanged trajectory geometry")
