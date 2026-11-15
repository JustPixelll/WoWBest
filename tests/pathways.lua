-- Run from the repository root with Lua 5.1. Use the shipped catalog so a
-- missing real route or a changed restriction breaks the test.
local A = {}
for _, file in ipairs({"Catalog", "Character", "Gates"}) do
    assert(loadfile("WoWBest/" .. file .. ".lua"))("WoWBest", A)
end
local function record(id)
    for _, row in ipairs(A.Catalog) do if row.id == id then return row end end
    error("missing catalog item " .. id)
end
local function warrior(level, faction)
    return {level = level or 14, class = "WARRIOR", classID = 1,
        raceID = faction == "Horde" and 2 or 1, faction = faction or "Alliance"}
end
local function option(row, p)
    local o = A.ProfessionTarget(row, p)
    if o then assert(not A.RouteAvailable(row, p), "an unavailable item entered both lists") end
    return o
end
local skills, spells, bags, quests, active, recipes = {}, {}, {}, {}, {}, {}
C_SkillInfo = {GetSkillLineInfoByID = function(id)
    if skills[id] then return {rank = skills[id]} end
end}
IsPlayerSpell = function(id) return spells[id] == true end
C_QuestLog = {
    IsQuestFlaggedCompleted = function(id) return quests[id] == true end,
    IsOnQuest = function(id) return active[id] == true end,
}
C_TradeSkillUI = {GetRecipeInfo = function(id) return {learned = recipes[id] == true} end}
C_Item = {GetItemCount = function(id) return bags[id] or 0 end}
local tiger, shadow, green, bright = record(4368), record(4373), record(4385), record(10499)
for _, row in ipairs({tiger, shadow, green}) do
    assert(not option(row, warrior(9)))
    local o = assert(option(row, warrior(10)))
    assert(o.slot == 1 and o.skillRank == 0 and o.statSummary == row.statSummary)
end
assert(not option(bright, warrior(19)))
assert(option(bright, warrior(20)))
skills[202] = 119
assert(A.RouteAvailable(tiger, warrior()))
assert(not option(tiger, warrior()))
assert(option(shadow, warrior()).skillRank == 119)
skills[202], skills[186], skills[164] = nil, 1, 1
assert(option(green, warrior()).requirement:find("Both primary slots", 1, true))
bags[4385] = 1
assert(option(green, warrior()).source == "Already owned")
bags[4385] = nil

local fish = record(19972)
skills[356] = 1
assert(option(fish, warrior()).eventName)
bags[19805] = 1
assert(option(fish, warrior()))
active[8221] = true
assert(A.RouteAvailable(fish, warrior()))
assert(not option(fish, warrior()))
active[8221], quests[8221] = nil, true
assert(not option(fish, warrior()))

-- A level-appropriate fishing-trunk route can be pursued after training Journeyman.
local trunk = {id = 999, invType = 1, classID = 4, subclassID = 1, professionID = 356, professionRank = 130}
assert(not option(trunk, warrior(9)))
assert(option(trunk, warrior(10)).requirement:find("Fishing 130", 1, true))
assert(not A.RouteAvailable(trunk, warrior(19)))
-- Confirm real level/faction-gated head alternatives with no profession.
assert(not A.RouteAvailable(record(279391), warrior(17, "Horde")))
assert(A.RouteAvailable(record(279391), warrior(18, "Horde")))
assert(not A.RouteAvailable(record(279391), warrior(18)))
assert(A.RouteAvailable(record(6971), warrior(20)))
-- A recipe-limited BoP craft cannot be bought from someone else.
local craft = {id = 1, invType = 1, classID = 4, subclassID = 3, professionID = 164,
    professionRank = 149, requiresKnownCraft = true, craftSpellID = 555, craftSpecSpellID = 556}
assert(not option(craft, warrior(30)))
spells[556] = true
assert(not option(craft, warrior(30)))
craft.trainerRecipe = true
assert(not option(craft, warrior(30))) -- no trained mail in fixture
spells[8737] = true
assert(option(craft, warrior(30)))
skills[164] = 150
assert(option(craft, warrior(30)).requirement:find("Learn the recipe", 1, true))
recipes[555] = true
assert(A.RouteAvailable(craft, warrior(30)))
assert(not option(craft, warrior(30)))

-- If a live tooltip is cached, only the actual profession's red line is exempt.
C_Item.IsItemDataCachedByID = function() return true end
C_Item.GetItemInfo = function() return "Goggles", "item:4385", 2, 30, 1, nil, nil, nil, "INVTYPE_HEAD", nil, nil, 4, 1 end
C_TradeSkillUI.GetTradeSkillDisplayName = function() return "Ingenieurskunst" end
local tooltip = {{leftText = "Brille"}, {leftText = "Benötigt Ingenieurskunst (150)", leftColor = {r = 1, g = 0, b = 0}}}
C_TooltipInfo = {GetHyperlink = function() return {lines = tooltip} end}
assert(option(green, warrior()))
tooltip[3] = {leftText = "Benötigt Stufe 20", leftColor = {r = 1, g = 0, b = 0}}
assert(not option(green, warrior()))
print("Profession and event pathways passed")
