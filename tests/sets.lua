local A = {}
for _, module in ipairs({"Profiles", "Effects", "SetData", "SetBonuses", "Engine"}) do
    assert(loadfile("WoWBest/" .. module .. ".lua"))("WoWBest", A)
end

local countSets, countEffects, countScored, members = 0, 0, 0, 0
for sid, rows in pairs(A.SetThresholds) do
    countSets = countSets + 1
    assert(A.SetNames[sid] and #rows > 0)
    local previous = 0
    for _, row in ipairs(rows) do
        assert(row.pieces >= previous and #row.description > 0)
        previous = row.pieces
        countEffects = countEffects + 1
        if row.stats then countScored = countScored + 1 end
    end
end
for _, sid in pairs(A.ItemSetIDs) do
    assert(A.SetThresholds[sid])
    members = members + 1
end
assert(countSets == 274 and countEffects == 780 and countScored == 389 and members == 1577)

local rogue = {attack = .5, agility = 1, targetType = "Humanoid"}
local caster = {intellect = 1, spell = 1}
local generic = {attack = .5, agility = 1}
assert(A.SetBonusScore(161, 2, rogue) == 0)
assert(A.SetBonusScore(161, 3, rogue) == 7.5 and A.SetBonusScore(161, 3, generic) == 0)
assert(A.SetBonusScore(161, 4, rogue) == 7.5) -- bleed requires positional proc assumptions
assert(A.SetBonusScore(162, 2, caster) == 10)
assert(A.SetBonusScore(162, 3, generic) == 5)
assert(A.SetBonusScore(520, 5, caster) == 23)
assert(A.SetBonusScore(2135, 2, {armor = .5}) == 50)
assert(A.SetBonusScore(1, 3, generic) == 10)
assert(A.SetBonusScore(124, 2, {defense = 1}) == 3)
assert(A.SetBonusScore(2131, 2, {strength = 1}) == 22) -- threshold contains two independent spells

local ids = {10399, 10400, 10401, 10402}
local gear = {[5] = {id = ids[1]}, [7] = {id = ids[2]}, [10] = {id = ids[3]}, [8] = {id = ids[4]}}
local results = A.ActiveSetBonuses(gear, rogue)
assert(#results == 3 and results[2].threshold == 3 and results[2].modeled and results[2].score == 7.5)
assert(not results[3].modeled and results[3].spellID == 1292028)
assert(not A.ActiveSetBonuses(gear, generic)[2].modeled)
C_Spell = {GetSpellDescription = function(id) return id == 1292028 and "Positionsabhängige Blutung" or nil end}
assert(A.ActiveSetBonuses(gear, rogue)[3].description == "Positionsabhängige Blutung")
gear[8] = {id = ids[3]}
assert(#A.ActiveSetBonuses(gear, rogue) == 2) -- copies of one set-piece ID aren't additional pieces
-- Bloodvine Garb has a Tailoring 300 set-bonus gate independent of equipability.
gear = {[5] = {id = 19682}, [7] = {id = 19683}, [8] = {id = 19684}}
C_SkillInfo = {GetSkillLineInfoByID = function(id) assert(id == 197); return {rank = 299} end}
assert(#A.ActiveSetBonuses(gear, caster) == 0)
C_SkillInfo.GetSkillLineInfoByID = function() return {rank = 300} end
assert(#A.ActiveSetBonuses(gear, caster) == 1)
print(("Set metadata passed: %d sets, %d effects, %d scored."):format(countSets, countEffects, countScored))
