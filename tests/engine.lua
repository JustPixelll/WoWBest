-- From the repository root: lua tests/engine.lua
local A = {}
assert(loadfile("WoWBest/Profiles.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Engine.lua"))("WoWBest", A)

local function item(id, loc, strength, extra)
    local v = {id = id, loc = "INVTYPE_" .. loc, stats = {ITEM_MOD_STRENGTH_SHORT = strength}}
    for k, value in pairs(extra or {}) do v[k] = value end
    return v
end
local plain = {strength = 1, meleeDPS = 4, rangedDPS = 3, offhandScale = .5}
local function check(which, actual, expected)
    assert(expected == actual, which .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function solve(items, dual, profile)
    return A.Solve(items, {dual = dual or false}, profile or plain)
end

local two = item(1, "2HWEAPON", 15)
local one = item(2, "WEAPON", 6)
local shield = item(3, "SHIELD", 8)
local ranged = item(4, "RANGEDRIGHT", 18)
local r, score = solve({two, one, shield, ranged})
check("two-hander", r[16], two)
check("blocks even a shield", r[17], nil)
check("ranged remains separate", r[18], ranged)
check("joint score", score, 33)
two.stats.ITEM_MOD_STRENGTH_SHORT = 12
r = solve({two, one, shield})
check("pair beats two-hander", r[16], one)
check("shield", r[17], shield)
check("cannot equip an offhand by itself", solve({shield})[17], nil)
local oh = item(5, "WEAPONOFFHAND", 20)
check("specific offhand needs dual wield", solve({one, oh})[17], nil)
check("specific offhand dual wield", solve({one, oh}, true)[17], oh)
check("one-hand may be wielded twice with dual wield", solve({one}, true)[17], one)
check("ordinary one-hands cannot fill offhand without dual wield", solve({one})[17], nil)
local mh = item(6, "WEAPONMAINHAND", 25)
check("mainhand-only cannot be dual wielded", solve({mh}, true)[17], nil)
local book = item(7, "HOLDABLE", 10)
check("held offhand works without dual wield", solve({mh, book})[17], book)
check("shield profile never proposes two handers", solve({two}, false, A.Profiles.WARRIOR[3])[16], nil)
local unique = item(8, "FINGER", 5, {unique = true})
local common = item(9, "FINGER", 4)
r = solve({unique, common})
check("strong unique ring", r[11], unique)
check("unique ring not repeated", r[12], common)
r = solve({common})
check("two farmable rings", r[12], common)
local a = item(10, "TRINKET", 8, {unique = "Badge"})
local b = item(11, "TRINKET", 7, {unique = "Badge"})
local c = item(12, "TRINKET", 6, {unique = true})
r = solve({a, b, c})
check("shared-category cap", r[14], c)
a.uniqueLimit, b.uniqueLimit = 2, 2
check("higher shared-category cap", solve({a, b, c})[14], a)

local questHead = item(13, "HEAD", 10, {choice = 1})
local questChest = item(14, "CHEST", 12, {choice = 1})
local otherChest = item(15, "ROBE", 8)
r, score = solve({questChest, questHead, otherChest})
check("joint optimization, protect quest head", r[1], questHead)
check("other chest better than leaving head empty", r[5], otherChest)
check("combined cross-slot score", score, 18)
local oneQuest = item(16, "FINGER", 10, {choice = 123, maxCopies = 1, routeKey = "quest/123"})
local anotherQuest = item(16, "FINGER", 10, {choice = 456, maxCopies = 1, routeKey = "quest/456"})
check("a single quest is not repeatable", solve({oneQuest})[12], nil)
r = solve({oneQuest, anotherQuest})
assert(r[11] ~= r[12] and r[12], "two independent quests allow two copies of a non-unique item")
anotherQuest.unique, oneQuest.unique = true, true
check("unique spans distinct acquisition routes", solve({oneQuest, anotherQuest})[12], nil)
anotherQuest.uniqueLimit, oneQuest.uniqueLimit = 3, 3
check("explicit item unique cap above one", solve({oneQuest, anotherQuest})[12], anotherQuest)
local us = item(160, "FINGER", 10, {unique = "set", uniqueLimit = 2, itemLimit = 1})
check("personal cap survives shared category", solve({us})[12], nil)
local groupHead = item(17, "HEAD", 24, {unique = "group", uniqueLimit = 2})
local groupRing = item(18, "FINGER", 12, {unique = "group", uniqueLimit = 2})
r, score = solve({groupRing, groupHead, common})
check("explicit maximum across equipment slots", score, 40)
check("select alternative second ring", r[12], common)
check("unsupported cosmetic slots excluded", solve({item(100, "TABARD", 300)})[19], nil)
check("ranged and relics", solve({item(100, "RELIC", 12)})[18].id, 100)

local dps = item(19, "WEAPON", 0, {classID = 2, stats = {DPS = 10, ITEM_MOD_STRENGTH_SHORT = 2}})
check("weapon dps main", A.Score(dps, plain, 16), 42)
check("offhand scales only weapon damage", A.Score(dps, plain, 17), 22)
check("ranged uses own DPS weight", A.Score(dps, plain, 18), 32)
local healing = {stats = {ITEM_MOD_SPELL_HEALING_DONE_SHORT = 21, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 7}}
check("healing and damage do not double count", A.Score(healing, A.Profiles.PRIEST[3]), 21)
check("caster reads damage", A.Score(healing, A.Profiles.PRIEST[1]), 7)
for class, profiles in pairs(A.Profiles) do
    local seen, trees = {}, {}
    for _, profile in ipairs(profiles) do
        assert(not seen[profile.key], class .. " duplicate key " .. profile.key)
        seen[profile.key], trees[profile.tree] = true, true
    end
    assert(trees[1] and trees[2] and trees[3], class .. " missing talent tree")
end

-- Independent exhaustive search on many tiny catalogs catches pruning errors,
-- especially when a quest decision also changes the best weapon configuration.
local function brute(items, dual)
    local slots = {1, 5, 11, 12, 16, 17}
    local chosen, best, used = {}, 0, {}
    local function visit(i, total)
        if i > #slots then best = math.max(best, total); return end
        local s = slots[i]
        chosen[s] = nil
        visit(i + 1, total)
        for _, it in ipairs(items) do
            local loc = it.loc
            local can = s == 1 and loc == "INVTYPE_HEAD"
                or s == 5 and loc == "INVTYPE_CHEST"
                or (s == 11 or s == 12) and loc == "INVTYPE_FINGER"
                or s == 16 and (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_WEAPON")
                or s == 17 and chosen[16] and chosen[16].loc ~= "INVTYPE_2HWEAPON"
                    and (loc == "INVTYPE_SHIELD" or (dual and loc == "INVTYPE_WEAPON"))
            if can and (not it.choice or not used[it.choice]) and (not it.unique or not used[it.id]) then
                chosen[s] = it
                if it.choice then used[it.choice] = true end
                if it.unique then used[it.id] = true end
                visit(i + 1, total + it.stats.ITEM_MOD_STRENGTH_SHORT)
                if it.choice then used[it.choice] = nil end
                if it.unique then used[it.id] = nil end
                chosen[s] = nil
            end
        end
    end
    visit(1, 0)
    return best
end
local locs = {"HEAD", "CHEST", "FINGER", "WEAPON", "SHIELD", "2HWEAPON"}
math.randomseed(5421)
for trial = 1, 300 do
    local items = {}
    for id = 1, 9 do
        items[id] = item(id, locs[math.random(#locs)], math.random(20), {
            choice = math.random(3) < 3 and ("q" .. math.random(3)) or nil,
            unique = math.random(3) == 1 or nil,
        })
    end
    local dual = trial % 2 == 0
    local _, result = solve(items, dual)
    check("randomized catalog " .. trial, result, brute(items, dual))
end
print("Engine OK: profiles, equipment limits, per-slot score and 300 exhaustive comparisons.")
