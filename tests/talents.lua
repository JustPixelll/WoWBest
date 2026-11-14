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
print("Talent detection tests passed.")
