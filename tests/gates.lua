-- From the repository root: lua tests/gates.lua
local A = {}
assert(loadfile("WoWBest/Gates.lua"))("WoWBest", A)

local function player()
    return { faction = "Alliance", raceID = 95, classID = 2, level = 25 }
end
local function allowed(row, p)
    return A.RouteAvailable(row, p or player())
end

assert(allowed({minLevel = 25, maxLevel = 25, faction = "Alliance", classMask = 2, raceMask = 2^32}))
assert(not allowed({minLevel = 26}))
assert(not allowed({maxLevel = 24}))
assert(not allowed({classMask = 4}))
assert(not allowed({raceMask = 2^33}))
assert(not allowed({faction = "Horde"}))
local troll = player()
troll.raceID = 8
assert(allowed({raceMask = 2^7}, troll))
assert(not allowed({raceMask = 2^32}, troll))
assert(allowed({raceMask = 0, classMask = 0}))
assert(not allowed({raceMask = 2^9}, {}))

assert(not allowed({questID = 42}))
assert(not allowed({professionID = 202, professionRank = 50}))
assert(not allowed({repFactionID = 509, minStanding = 6}))
assert(not allowed({minPvPRank = 5}))
assert(allowed({kind = "Owned", questID = 42, professionID = 202, minLevel = 50}))

local questCalls = 0
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) questCalls = questCalls + 1; return id == 42 end,
    IsQuestDisabledForSession = function(id) return id == 44 end,
}
local p = player()
assert(not allowed({questID = 42}, p))
assert(not allowed({questID = 42}, p))
assert(questCalls == 1)
assert(allowed({questID = 43}, p)) -- a quest may still be picked up
assert(not allowed({questID = 44}, p))
assert(not allowed({questID = 44, once = false}, p))
assert(allowed({questID = 42, once = false}))
assert(allowed({kind = "World drop"}, p)) -- a different source remains open

C_SkillInfo = {GetSkillLineInfoByID = function(id)
    if id == 202 then return {rank = 50} end
end}
assert(allowed({professionID = 202, professionRank = 50}))
assert(not allowed({professionID = 202, professionRank = 51}))
assert(not allowed({professionID = 164}))
C_Reputation = {GetFactionDataByID = function(id)
    if id == 509 then return {reaction = 6} end
end}
assert(allowed({repFactionID = 509, minStanding = 6}))
assert(not allowed({repFactionID = 509, minStanding = 7}))
assert(not allowed({minStanding = 5}))
C_MajorFactions = {GetMajorFactionProgressionInfo = function(id)
    assert(id == 2800)
    return {renownLevel = 4}
end}
assert(allowed({minPvPRank = 4}))
assert(not allowed({minPvPRank = 5}))

print("Acquisition gates passed")
