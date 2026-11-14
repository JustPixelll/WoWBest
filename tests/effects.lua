local A = {}
for _, name in ipairs({"Profiles", "Effects", "Engine"}) do
    assert(loadfile("WoWBest/" .. name .. ".lua"))("WoWBest", A)
end

local function close(actual, expected)
    assert(math.abs(actual - expected) < .000001, tostring(actual) .. " vs " .. tostring(expected))
end
local function score(id, profile, stats)
    return A.Score({id = id, loc = "INVTYPE_TRINKET", stats = stats or {}}, profile)
end

local mage, arms, holy = A.Profiles.MAGE[1], A.Profiles.WARRIOR[1], A.Profiles.PRIEST[3]
close(score(13965, arms), (14 + 5 * 14 * 20 / 300) * arms.crit)
close(score(13965, arms, {ITEM_MOD_CRIT_RATING_SHORT = 14}), score(13965, arms))
close(score(13965, mage), 5 * 14 * 20 / 300 * mage.crit)
close(score(13968, mage), 14 * mage.crit + 7 * 10 * 20 / 300 * mage.hit)
close(score(13968, holy), 14 * holy.crit)
close(score(13968, arms), 0)
close(score(13968, arms, {ITEM_MOD_CRIT_RATING_SHORT = 14}), 0)
close(score(13965, mage, {ITEM_MOD_CRIT_RATING_SHORT = 14}), score(13965, mage))
close(score(20130, arms), 20 * 60 / 360 * arms.strength)
close(score(11819, holy), 15 * holy.healing + 3.5 * holy.mp5)
close(score(11819, holy, {ITEM_MOD_SPELL_POWER_SHORT = 5}), score(11819, holy))
close(score(11819, holy, {ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 5, ITEM_MOD_SPELL_HEALING_DONE_SHORT = 15}), score(11819, holy))
local shaman = A.Profiles.SHAMAN[3]
close(score(20503, shaman), 7.3 * shaman.mp5)
close(score(20503, shaman, {ITEM_MOD_MANA_REGENERATION_SHORT = 4}), score(20503, shaman))
local flask = {id = 20130, loc = "INVTYPE_TRINKET", stats = {}, unique = true}
local plan = A.Solve({flask}, {}, arms)
assert(plan[13] == flask and not plan[14], "effect-only trinket enters the legal loadout")
print("Effects OK: five Forever models, role sensitivity, on-use averaging, flat stat deduplication.")
