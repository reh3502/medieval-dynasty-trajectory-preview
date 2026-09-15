local P=require("performance")
local T=require("telemetry")
local log=T.log
local find=StaticFindObject
local reports={}
T.log=function(kind,data) reports[#reports+1]={kind=kind,data=data} end
local ok,err=pcall(function()
    assert(P.begin(false)==nil,"Disabled profiling accessed engine clock")
    StaticFindObject=function()
        return {GetAccurateRealTime=function(_,first,second)
            assert(first==second,"Clock must share numeric out-parameter storage")
            first.Seconds=100;first.PartialSeconds=0.25
        end}
    end
    assert(P.begin(true)==100.25,"Clock failed to combine named numeric outputs")
    for i=120,1,-1 do P.record(i,true,2);P.record(0.1,false,0) end
    assert(#reports==2,"Active and hidden batches were not separated")
    local active,hidden=reports[1].data,reports[2].data
    assert(active.state=="active" and active.p50_ms==60 and active.p95_ms==114
        and active.worst_ms==120 and active.total_sweeps==240 and active.max_sweeps==2)
    assert(hidden.state=="hidden" and hidden.total_sweeps==0 and hidden.p95_ms==0.1)
    P.record(0/0,true,0);P.record(-1,true,0);P.record(math.huge,true,0)
    for _=1,119 do P.record(1,true,0) end
    assert(#reports==2,"Invalid timing samples entered a batch")
    P.record(1,true,0)
    assert(#reports==3 and reports[3].data.worst_ms==1,"Batch retained old samples")
    local time=0
    local outputs={}
    StaticFindObject=function()
        return {GetAccurateRealTime=function(_,out)
            outputs[out]=true
            assert(out.Seconds==nil and out.PartialSeconds==nil,'Clock output was not reset')
            time=time+.001;out.Seconds=0;out.PartialSeconds=time
        end}
    end
    for _=1,120 do
        local start=P.begin(true)
        P.stage('capture');P.stage('prediction_collision')
        P.finish(start,true,5,'spear')
    end
    local stages=reports[#reports]
    assert(stages.kind=='performance_stages' and stages.data.family=='spear')
    assert(stages.data.samples==120 and math.abs(stages.data.capture.p50_ms-1)<1e-8)
    assert(math.abs(stages.data.prediction_collision.p95_ms-1)<1e-8)
    assert(stages.data.worst_frame.queries==5)
    assert(stages.data.worst_frame.heap_kb>0)
    assert(type(stages.data.worst_frame.heap_change_kb.capture)=='number')
    assert(math.abs(stages.data.worst_frame.stages_ms.capture-1)<1e-8)
    assert(math.abs(stages.data.frame_interval_ms.p50_ms-4)<1e-8)
    local count=0;for _ in pairs(outputs) do count=count+1 end
    assert(count==1,'Profiler output tables accumulate across frames')
end)
T.log=log
StaticFindObject=find
assert(ok,err)
print("PASS bounded performance batches, percentiles and hidden sweep counts")
