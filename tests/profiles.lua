local A = {}
for _, file in ipairs({"Profiles", "Engine"}) do
    assert(loadfile("WoWBest/" .. file .. ".lua"))("WoWBest", A)
end

local function get(class, key, level)
    for _, profile in ipairs(A.Profiles[class]) do
        if profile.key == key then return A.ProfileForLevel(profile, {class = class, level = level}) end
    end
    error(class .. "/" .. key)
end
local function close(a, b)
    assert(math.abs(a - b) < .000001, ("%s vs %s"):format(a, b))
end
local function stat(name, n, p)
    return A.Score({loc = "INVTYPE_HEAD", stats = {["ITEM_MOD_" .. name .. "_SHORT"] = n}}, p, 1)
end

local count = 0
for class, set in pairs(A.Profiles) do
    for _, base in ipairs(set) do
        count = count + 1
        assert(base == get(class, base.key, 60))
        for level = 1, 60 do
            local p = A.ProfileForLevel(base, level)
            assert(p == A.ProfileForLevel(base, {level = level}))
            assert(p.key == base.key and p.level == level)
            close(p.meleeCritShare + p.rangedCritShare + p.spellCritShare, 1)
            for key, value in pairs(p) do
                if type(value) == "number" then assert(value >= 0 and value < math.huge, key) end
            end
        end
    end
end
assert(count == 29)
local arms, fury, prot = get("WARRIOR", "arms", 19), get("WARRIOR", "fury", 19), get("WARRIOR", "protection", 19)
local cap = get("WARRIOR", "arms", 60)
assert(A.ProfileForLevel(arms, 60) == cap and arms ~= cap)
local custom = {strength = 12}
assert(A.ProfileForLevel(custom, 19) == custom and A.ProfileForLevel(nil, 19) == nil)

-- Same canonical AP/crit inputs, different return per primary stat at 19/60.
close(stat("STRENGTH", 5, arms), stat("ATTACK_POWER", 10, arms))
close(stat("AGILITY", 7.4, arms), stat("CRIT_RATING", 14, arms) + stat("ARMOR", 14.8, arms))
close(stat("AGILITY", 20, cap), stat("CRIT_RATING", 14, cap) + stat("ARMOR", 40, cap))
assert(arms.spirit > cap.spirit and fury.spirit > 0)
assert(stat("INTELLECT", 5, arms) == 0 and stat("SPELL_POWER", 5, arms) == 0)
assert(prot.blockValue > 0 and prot.defenseSkill == prot.defense and prot.shield)
close(stat("DEFENSE_SKILL_RATING", 5, prot), A.Score({stats = {DEFENSE_SKILL = 5}}, prot))
close(prot.defenseSkill, .04 * (24 * prot.dodge + 15 * prot.parry + 5 * prot.block))
assert(prot.armor > arms.armor and prot.stamina > arms.stamina)
assert(arms.mainHandDamage > fury.mainHandDamage and fury.offhandScale > arms.offhandScale)

local slow = {loc="INVTYPE_2HWEAPON", classID=2, minDamage=40, maxDamage=40, weaponSpeed=4, stats={DPS=10}}
local fast = {loc="INVTYPE_2HWEAPON", classID=2, minDamage=20, maxDamage=20, weaponSpeed=2, stats={DPS=10}}
assert(A.Score(slow, arms, 16) > A.Score(fast, arms, 16))
local cat, bear = get("DRUID", "cat", 30), get("DRUID", "bear", 30)
for _, p in ipairs({cat, bear}) do
    close(A.Score(slow, p, 16), A.Score(fast, p, 16))
    assert(A.Score(fast, p, 16) > 0)
end
assert(not bear.shield and bear.block == 0 and bear.parry == 0)
local cat19, cat20 = get("DRUID", "cat", 19), get("DRUID", "cat", 20)
close(cat19.agility, 14 * cat19.crit / 7.8 + 2 * cat19.armor)
close(cat20.agility, cat20.attack + 14 * cat20.crit / 8.8 + 2 * cat20.armor)

local shadow, holy = get("PRIEST", "shadow", 19), get("PRIEST", "holy", 19)
assert(shadow.rangedDPS > get("PRIEST", "shadow", 60).rangedDPS)
assert(stat("SPELL_HEALING_DONE", 8, holy) > 0 and stat("SPELL_DAMAGE_DONE", 8, holy) == 0)
assert(stat("SPELL_HEALING_DONE", 8, shadow) == 0 and stat("SPELL_DAMAGE_DONE", 8, shadow) > 0)
close(holy.intellect, 15 * holy.mana + holy.crit * 14 / 15.9)
assert(holy.spellHitShare == 0 and holy.spellCritShare == 1)

-- A level-31 Restoration Druid gets 15 mana and 1/29.1 percentage points
-- of spell crit per Intellect. MP5 works inside the five-second rule as well.
local resto = get("DRUID", "restoration", 31)
local function druid(pace, talents)
    return A.ProfileForLevel(resto, {level = 31, healingPace = pace, restoTalents = talents})
end
assert(resto == druid(nil, nil) and resto.healingPace == "dungeon" and resto.restoTalents == nil)
local plain = druid("dungeon", {})
assert(plain ~= resto and plain.restoTalents.reflection == 0 and plain.restoTalents.bloom == 0)
assert(plain == druid("invalid", {bloom = 0}))
close(plain.mp5, 90 / 5 * plain.mana)
close(plain.spirit, .625 * .25 * plain.mp5)
close(plain.intellect, 15 * plain.mana + stat("CRIT_RATING", 14, plain) / 29.1)
close(stat("SPELL_HEALING_DONE", 10, plain), 10)
close(stat("SPELL_POWER", 10, plain), 10)
close(stat("SPELL_DAMAGE_DONE", 10, plain), 0)
close(stat("NATURE_SPELL_DAMAGE", 10, plain), 0)
local talents = {reflection = 3, bloom = 1, livingSpirit = 2, heartOfTheWild = 5}
local talented = druid("dungeon", talents)
close(talented.spirit, 1.10 * ((.25 + .75 * .50) * .625 * plain.mp5 + .41))
close(talented.intellect, 1.10 * plain.intellect)
close(talented.mp5, plain.mp5)
close(talented.mana, plain.mana)
for rank, fraction in ipairs({.17, .33, .50}) do
    close(druid("dungeon", {reflection = rank}).spirit, (.25 + .75 * fraction) * .625 * plain.mp5)
end
local short, sustained = druid("short", talents), druid("sustained", talents)
close(short.mp5, 6 * plain.mana)
close(sustained.mp5, 36 * plain.mana)
assert(short.mp5 < short.intellect and sustained.mp5 > sustained.intellect)
assert(short.spirit < talented.spirit and talented.spirit < sustained.spirit)
-- At fixed talent ranks, 5 MP5 over three minutes overtakes 8 Intellect.
-- A short window favors the larger initial reserve.
assert(stat("MANA_REGENERATION", 5, short) < stat("INTELLECT", 8, short))
assert(stat("MANA_REGENERATION", 5, sustained) > stat("INTELLECT", 8, sustained))
assert(stat("SPIRIT", 10, plain) < stat("SPELL_HEALING_DONE", 7, plain))
assert(stat("SPIRIT", 10, talented) > stat("SPELL_HEALING_DONE", 7, talented))
assert(druid("short", nil).restoTalents == nil)
talents.reflection = 0
assert(talented.restoTalents.reflection == 3 and druid("dungeon", talents) ~= talented)
close(get("SHAMAN", "restoration", 31).mp5, 2.12)
local enhancement = get("SHAMAN", "enhancement", 19)
assert(enhancement.spellCritShare > 0 and enhancement.physicalCritShare > 0)
local marks, survival = get("HUNTER", "marksmanship", 19), get("HUNTER", "survival", 19)
assert(marks.rangedDPS > marks.meleeDPS and survival.meleeDPS > survival.rangedDPS)
local destruction = get("WARLOCK", "destruction", 60)
assert(destruction.fire > destruction.shadow and destruction.spell > destruction.fire)
print("All 29 profiles across 60 levels and class/role scoring checks passed.")
