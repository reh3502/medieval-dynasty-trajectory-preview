local R=require('runtime')
local old_find,old_all=StaticFindObject,FindAllOf
local finds,scans=0,0
local function object() return {valid=true,IsValid=function(self) return self.valid end} end
local class=object()
StaticFindObject=function() finds=finds+1;return class end
assert(R.static('/Script/Engine.Test')==class)
assert(R.static('/Script/Engine.Test')==class and finds==1)
class.valid=false;class=object()
assert(R.static('/Script/Engine.Test')==class and finds==2)
local pawn=object();pawn.IsLocallyControlled=function() return true end
local controller=object();controller.IsLocalPlayerController=function() return true end;controller.Pawn=pawn
FindAllOf=function() scans=scans+1;return {controller} end
assert(R.local_player()==controller)
assert(R.local_player()==controller and scans==1)
controller.valid=false
assert(R.local_player()==nil and scans==2)
StaticFindObject=old_find;FindAllOf=old_all
print('PASS static-object and local-controller cache reuse and invalidation')
