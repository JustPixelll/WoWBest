local A = {}
assert(loadfile("WoWBest/Profiles.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Talents.lua"))("WoWBest", A)
local spent = {2, 4, 1}
C_ClassTalents = {GetActiveConfigID = function() return 32 end}
C_Traits = {
    GetConfigInfo = function() return {treeIDs = {100}} end,
    GetGroupDisplayInfoByTreeID = function() return {
        {orderIndex = 2, groupID = 101}, {orderIndex = 0, groupID = 10}, {orderIndex = 1, groupID = 99},
    } end,
    GetGroupCurrencyInfo = function() return {
        {traitNodeGroupID = 99, currencyInfos = {{spent = spent[2]}}},
        {traitNodeGroupID = 101, currencyInfos = {{spent = spent[3]}}},
        {traitNodeGroupID = 10, currencyInfos = {{spent = spent[1]}}},
    } end,
}
local who = {class = "WARRIOR", level = 50}
assert(A.DetectProfile(who) == "fury")
spent = {7, 4, 7}
assert(A.DetectProfile(who) == nil)
spent = {0, 0, 0}
assert(A.DetectProfile(who) == nil)
who.class, spent = "DRUID", {1, 3, 1}
assert(A.DetectProfile(who) == nil)
who.level, spent = 6, {0, 0, 9}
assert(A.DetectProfile(who) == nil)
C_Traits = nil
who.level = 60
assert(A.DetectProfile(who) == nil)

-- Live ranks can differ between active configurations. At rest a zero rank
-- is a positive observation; missing nodes and uncommitted changes are not.
local nodes = {
    [104958] = {spell=17003, rank=4},
    [104920] = {spell=17106, rank=2},
    [104918] = {spell=1328621, rank=1},
    [104911] = {spell=1309631, rank=0},
}
local config, staged, combat = 32, false, false
local reads = 0
C_ClassTalents.GetActiveConfigID = function() return config end
InCombatLockdown = function() return combat end
C_Traits = {
    ConfigHasStagedChanges = function(id) assert(id == config); return staged end,
    GetNodeInfo = function(id, node)
        assert(id == config)
        reads = reads + 1
        local data = nodes[node]
        if not data then return end
        local rank = config == 32 and data.rank or 0
        return {ID=node, entryIDs={node + 500}, activeRank=rank,
            activeEntry=rank > 0 and {entryID=node + 500, rank=rank} or nil}
    end,
    GetEntryInfo = function(id, entry)
        assert(id == config)
        return {definitionID=entry + 500}
    end,
    GetDefinitionInfo = function(def)
        return {spellID=nodes[def - 1000].spell}
    end,
}
local ranks = assert(A.GetRestoDruidTalents())
assert(ranks.reflection == 2 and ranks.livingSpirit == 0 and ranks.bloom == 1 and ranks.heartOfTheWild == 4)
nodes[104920].rank = 3
assert(A.GetRestoDruidTalents().reflection == 3, "same-config respec must not reuse stale ranks")
config = 44
local empty = assert(A.GetRestoDruidTalents())
assert(empty.reflection == 0 and empty.heartOfTheWild == 0 and empty.bloom == 0 and empty.livingSpirit == 0)
config, staged = 32, true
assert(A.GetRestoDruidTalents() == nil, "previewed points are not committed")
staged, combat = false, true
local previous = reads
assert(A.GetRestoDruidTalents() == nil and reads == previous)
combat = false
nodes[104918].spell = 1288559 -- A different spell called Bloom.
assert(A.GetRestoDruidTalents() == nil)
nodes[104918].spell = 1328621
nodes[104918].rank = 2
assert(A.GetRestoDruidTalents() == nil)
nodes[104918] = nil
assert(A.GetRestoDruidTalents() == nil)
C_Traits.GetNodeInfo = function() error("data unavailable") end
assert(A.GetRestoDruidTalents() == nil)
print("Talent detection and committed Restoration Druid rank checks passed.")
