-- Run from the repository root with Lua 5.1. Exercise the shipped rows directly.
local A = {}
assert(loadfile("WoWBest/Catalog.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Gates.lua"))("WoWBest", A)
local rows = {}
for _, r in ipairs(A.Catalog) do rows[r.id] = r end
local engineering, fishing, hasFish, onQuest, completed = 0, 1, false, false, false
C_SkillInfo = {GetSkillLineInfoByID = function(skill)
    return {rank = skill == 202 and engineering or skill == 356 and fishing or 0}
end}
C_QuestLog = {
    IsQuestFlaggedCompleted = function() return completed end,
    IsOnQuest = function(id) return id == 8221 and onQuest end,
}
C_Item = {GetItemCount = function(id) return id == 19805 and hasFish and 1 or 0 end}
local function warrior(side, level)
    return {level = level or 19, classID = 1, raceID = side == "Alliance" and 1 or 2, faction = side}
end
local green, flying, shadow = rows[4385], rows[4368], rows[4373]
assert(green.itemLevel == 30 and green.minLevel == 1 and green.wearProfessionRank == 150)
assert(green.trainerRecipe and green.craftSpellID == 3956 and not green.requiresKnownCraft)
assert(green.source:find("Lilliam Sparkspindle", 1, true) and green.source:find("Nogg", 1, true))
assert(green.source:find("2 Moss Agate", 1, true) and green.statSummary:find("+8 Stamina", 1, true))
assert(flying.craftProfessionRank == 100 and flying.statSummary:find("+4 Stamina", 1, true))
assert(shadow.craftSpellID == 3940 and not shadow.trainerRecipe and shadow.source:find("#4410", 1, true))
for _, side in ipairs({"Alliance", "Horde"}) do
    for _, rank in ipairs({0, 99, 100, 119, 120, 149, 150}) do
        engineering = rank
        assert(A.RouteAvailable(green, warrior(side)) == (rank >= 150))
        assert(A.RouteAvailable(shadow, warrior(side)) == (rank >= 120))
        assert(A.RouteAvailable(flying, warrior(side)) == (rank >= 100))
    end
end
local band = rows[279391]
assert(band.minLevel == 18 and band.questID == 98093 and band.choice == band.questID)
assert(A.RouteAvailable(band, warrior("Horde", 18)) and not A.RouteAvailable(band, warrior("Horde", 17)))
assert(not A.RouteAvailable(band, warrior("Alliance")))
completed = true
assert(not A.RouteAvailable(band, warrior("Horde")))
completed = false
local hat, boots = rows[19972], rows[19969]
assert(hat.eventName and hat.questID == 8221 and hat.requiresItemID == 19805 and hat.requiresQuestInLog)
assert(boots.questID == 8225 and boots.requiresItemID == 19803 and boots.requiresQuestInLog)
assert(not A.RouteAvailable(hat, warrior("Alliance")))
hasFish = true
assert(not A.RouteAvailable(hat, warrior("Horde")))
onQuest = true
assert(A.RouteAvailable(hat, warrior("Alliance")) and A.RouteAvailable(hat, warrior("Horde")))
fishing = 0
assert(not A.RouteAvailable(hat, warrior("Horde")))
-- Appearance-only pieces cannot occupy a BiS slot, including the similarly named Barrens Headband.
assert(not rows[274021] and not rows[49715])
-- Tradeable weapon does not make the player's own profession a prerequisite for buying it.
local axe = rows[2845]
-- There may also be shop/drop routes for the same ID.
for _, r in ipairs(A.Catalog) do
    if r.id == 2845 and r.kind == "Crafted" then axe = r end
end
assert(axe.craftProfessionID == 164 and not axe.professionID and not axe.requiresKnownCraft)
print("Level-19 Warrior headgear routes passed")
