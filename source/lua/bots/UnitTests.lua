
local verbose = false

------------------------------------------
--
------------------------------------------
Script.Load("lua/bots/BrainSenses.lua")
local s = BrainSenses()
s:Initialize()
s.debug = true
s:Add( "zzSum", function(db)
        local z = db:Get("z")
        local z = db:Get("z")
        return z+z
        end)
s:Add("x", function(db) return 1.0 end)
s:Add("y", function(db) return 2.0 end)
s:Add("z", function(db)
        local x = db:Get("x")
        local y = db:Get("y")
        return x*x+y*y
        end)

local foo = {}
s:OnBeginFrame(foo)
s:ResetDebugTrace()
s:Get("zzSum")
if verbose then DebugPrint("testing senses, trace: %s", s:GetDebugTrace() ) end
-- do it again
s:ResetDebugTrace()
s:Get("zzSum")
if verbose then DebugPrint("testing senses again, trace: %s", s:GetDebugTrace() ) end

------------------------------------------
--
------------------------------------------
AssertFloatEqual( 1.0, EvalLPF( 1.0, {{0,0}, {2,2}} ) )
AssertFloatEqual( 1.5, EvalLPF( 0.5, {{0,1}, {1,2}} ) )

------------------------------------------
--
------------------------------------------
Script.Load("lua/bots/ManyToOne.lua")

local m2o = ManyToOne()
m2o:Initialize()

m2o:Assign("steve", "marines")
m2o:Assign("dushan", "marines")
m2o:Assign("max", "aliens")
m2o:Assign("brian", "aliens")
assert( m2o:GetNumAssignedTo("marines") == 2 )
assert( m2o:GetNumAssignedTo("aliens") == 2 )
if verbose then m2o:DebugDump() end

m2o:Assign("steve", "aliens")
assert( m2o:GetNumAssignedTo("marines") == 1 )
assert( m2o:GetNumAssignedTo("aliens") == 3 )
if verbose then m2o:DebugDump() end

m2o:Unassign("max")
m2o:Unassign("steve")
assert( m2o:GetNumAssignedTo("aliens") == 1 )
assert( m2o:GetNumAssignedTo("marines") == 1 )
if verbose then m2o:DebugDump() end

m2o:RemoveGroup("aliens")
if verbose then m2o:DebugDump() end

Script.Load("lua/bots/HistoryArray.lua")
local arr = HistoryArray()
arr:Initialize(3)
assert(arr:GetCurrentSize() == 0)
assert(arr:GetAvg(0, 3, nil, nil) == nil)
assert(arr:GetAvg(0, 3, nil, 0) == 0)
assert(arr:GetAvg(0, 3, 0, nil) == 0)
arr:PutValue(3)
assert(arr:GetCurrentSize() == 1)
assert(arr:GetValueByIndex(0) == 3)
assert(arr:GetValueByIndex(1, nil) == nil)
assert(arr:GetValueByIndex(1, 5) == 5)
assert(arr:GetAvg(0, 3, nil, nil) == 3)
assert(arr:GetAvg(0, 3, nil, 0) == 3)
assert(arr:GetAvg(0, 3, 0, nil) == 1)
arr:PutValue(9)
assert(arr:GetCurrentSize() == 2)
assert(arr:GetValueByIndex(0) == 9)
assert(arr:GetValueByIndex(1) == 3)
assert(arr:GetValueByIndex(2) == nil)
assert(arr:GetValueByIndex(2, 33) == 33)
assert(arr:GetAvg(0, 3, nil, nil) == 6)
assert(arr:GetAvg(0, 3, nil, 0) == 6)
assert(arr:GetAvg(0, 3, 0, nil) == 4)
assert(arr:GetAvg(0, 3, 0, 0) == 4)
arr:PutValue(27)
assert(arr:GetCurrentSize() == 3)
assert(arr:GetValueByIndex(0) == 27)
assert(arr:GetValueByIndex(1) == 9)
assert(arr:GetValueByIndex(2) == 3)
assert(arr:GetAvg(0, 3, nil, nil) == 13)
assert(arr:GetAvg(0, 3, nil, 0) == 13)
assert(arr:GetAvg(0, 3, 0, nil) == 13)
assert(arr:GetAvg(0, 3, 0, 0) == 13)
arr:PutValue(9)
assert(arr:GetCurrentSize() == 3)
assert(arr:GetValueByIndex(0) == 9)
assert(arr:GetValueByIndex(1) == 27)
assert(arr:GetValueByIndex(2) == 9)
assert(arr:GetAvg(0, 3, nil, nil) == 15)
assert(arr:GetAvg(1, 2, nil, nil) == 18)

Script.Load("lua/bots/Oscillo.lua")
local osc = Oscillo()
osc:Initialize(3, 1)
assert(osc:GetCurrentSize() == 0)
assert(osc:GetAvg(0, 1, nil, nil) == nil)
assert(osc:GetAvg(0, 1, 9, nil) == 9)
assert(osc:GetAvg(0, 1, nil, 9) == 9)
osc:PutValue(3, 0)
assert(osc:GetCurrentSize() == 0)
assert(osc:GetAvg(0, 1, nil, nil) == 3)
assert(osc:GetAvg(0, 1, 9, nil) == 3)
assert(osc:GetAvg(0, 1, nil, 2) == 3)
assert(osc:GetAvg(0, 2, nil, 2) == 3)
assert(osc:GetAvg(0, 2, 9, nil) == 6)
osc:PutValue(9, 0.9)
assert(osc:GetCurrentSize() == 0)
assert(osc:GetAvg(0, 1, nil, nil) == 6)
osc:PutValue(27, 1.1)
assert(osc:GetCurrentSize() == 1)
assert(osc:GetAvg(0, 1, nil, nil) == 27)
assert(osc:GetAvg(1, 1, nil, nil) == 6)
assert(osc:GetAvg(0, 2, nil, nil) == 16.5)
assert(osc:GetAvg(0, 3, nil, nil) == 16.5)
assert(osc:GetAvg(0, 3, 3, nil) == 12)
osc:PutValue(27, 2.1)
assert(osc:GetCurrentSize() == 2)
assert(osc:GetAvg(0, 3, nil, nil) == 20)
assert(osc:GetAvg(1, 1, nil, nil) == 27)
assert(osc:GetAvg(1, 2, nil, nil) == 16.5) -- 27, 6
osc:PutValue(3, 3.1)
assert(osc:GetCurrentSize() == 3)
