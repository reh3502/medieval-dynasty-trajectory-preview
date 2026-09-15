-- Appearance only: never holds or interpolates trajectory positions.
local A={}
function A.frame(state,now,pull,hit)
    assert(type(now)=='number' and now==now and math.abs(now)<math.huge,'trajectory clock unavailable')
    if not state.started or now<state.started then state.started=now;state.contact=nil end
    if hit and not state.had_hit then state.contact=now end
    state.had_hit=hit
    local t=math.max(0,math.min(1,(now-state.started)/0.12))
    return {Reveal=t*t*(3-2*t),DrawStrength=math.max(0,math.min(1,pull or 0)),
        ContactPulse=hit and state.contact and math.exp(-math.max(0,now-state.contact)/0.18) or 0}
end
return A
