-- Development-only wall-clock samples; fixed batches bound memory and log volume.
local T=require("telemetry")
local R=require("runtime")
local P={}
local buckets={}
local unavailable=false
local stages,last_mark
local heap,last_heap,previous_start,frame_interval
local stage_batches={}
local clock_out={}
local function clock()
    local library=R.static("/Script/Engine.Default__GameplayStatics")
    -- UE4SS retains the first scalar-out table on its argument stack. Share
    -- one table so both named output fields are available regardless.
    local out=clock_out
    out.Seconds=nil;out.PartialSeconds=nil
    library:GetAccurateRealTime(out,out)
    assert(type(out.Seconds)=="number" and type(out.PartialSeconds)=="number",
        "Accurate real-time output unavailable")
    return out.Seconds+out.PartialSeconds
end
function P.record(milliseconds,active,queries)
    if type(milliseconds)~="number" or milliseconds~=milliseconds or milliseconds<0 or milliseconds==math.huge then return end
    local key=active and "active" or "hidden"
    local bucket=buckets[key] or {values={},queries=0,max_queries=0}
    buckets[key]=bucket
    bucket.values[#bucket.values+1]=milliseconds
    bucket.queries=bucket.queries+queries
    bucket.max_queries=math.max(bucket.max_queries,queries)
    if #bucket.values<120 then return end
    table.sort(bucket.values)
    T.log("performance",{state=key,samples=120,clock="GameplayStatics.GetAccurateRealTime",
        p50_ms=bucket.values[60],p95_ms=bucket.values[114],worst_ms=bucket.values[120],
        total_sweeps=bucket.queries,max_sweeps=bucket.max_queries})
    buckets[key]=nil
end
local function failure(error)
    unavailable=true
    T.log("performance_error",{error=tostring(error)})
end
function P.begin(enabled)
    stages=nil;last_mark=nil
    if not enabled or unavailable then previous_start=nil;return end
    local ok,value=pcall(clock)
    if ok then
        stages={};heap={};last_mark=value;last_heap=collectgarbage('count')
        frame_interval=previous_start and (value-previous_start)*1000 or nil
        previous_start=value
        return value
    end
    failure(value)
end
function P.stage(name)
    if not stages then return end
    local ok,now=pcall(clock)
    if not ok then stages=nil;failure(now);return end
    stages[name]=(stages[name] or 0)+(now-last_mark)*1000
    local memory=collectgarbage('count')
    heap[name]=(heap[name] or 0)+memory-last_heap
    last_heap=memory
    last_mark=now
end
function P.finish(started,active,queries,family)
    if not started then return end
    local ok,value=pcall(clock)
    if ok then
        P.record((value-started)*1000,active,queries)
        if active and stages then
            local key=family or "unknown"
            local batch=stage_batches[key] or {count=0,values={},intervals={}}
            batch.count=batch.count+1
            if frame_interval and frame_interval>=0 then batch.intervals[#batch.intervals+1]=frame_interval end
            local duration=(value-started)*1000
            if not batch.worst or duration>batch.worst.preview_ms then
                batch.worst={preview_ms=duration,stages_ms=stages,heap_change_kb=heap,
                    heap_kb=last_heap,queries=queries,frame_interval_ms=frame_interval}
            end
            for name,ms in pairs(stages) do
                local values=batch.values[name] or {};values[#values+1]=ms;batch.values[name]=values
            end
            stage_batches[key]=batch
            if batch.count==120 then
                local summary={family=key,samples=120,worst_frame=batch.worst}
                if #batch.intervals>0 then
                    table.sort(batch.intervals)
                    summary.frame_interval_ms={p50_ms=batch.intervals[math.ceil(#batch.intervals*.5)],
                        p95_ms=batch.intervals[math.ceil(#batch.intervals*.95)],max_ms=batch.intervals[#batch.intervals]}
                end
                for name,values in pairs(batch.values) do
                    table.sort(values);summary[name]={p50_ms=values[math.ceil(#values*.5)],p95_ms=values[math.ceil(#values*.95)],max_ms=values[#values]}
                end
                T.log("performance_stages",summary);stage_batches[key]=nil
            end
        end
    else failure(value) end
    stages=nil;last_mark=nil
end
return P
