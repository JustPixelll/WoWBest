local _, A = ...

-- Relative stat values for the selected playstyle. These are editable heuristics,
-- in points per stat, not a rotation simulation or a list of endgame BIS items.
local melee = {
    strength = 1, agility = .60, stamina = .28, armor = .008, attack = .50,
    hit = .85, crit = .70, haste = .60, expertise = .75, meleeDPS = 6,
    offhandScale = .50,
}
local hunter = {
    agility = 1, strength = .10, stamina = .28, intellect = .28, spirit = .08,
    armor = .008, attack = .44, rangedAttack = .44, hit = .85, crit = .75,
    haste = .55, meleeDPS = .12, rangedDPS = 6, mp5 = .34, offhandScale = .50,
}
local caster = {
    intellect = .85, spirit = .45, stamina = .24, armor = .004, spell = 1,
    hit = .95, crit = .60, haste = .67, mp5 = .70,
    rangedDPS = .35, -- wands are a useful source of damage while leveling
}
local healer = {
    intellect = .88, spirit = .82, stamina = .20, armor = .004, healing = 1,
    spell = 1, crit = .58, haste = .45, mp5 = 2.1, rangedDPS = .08,
}
local tank = {
    stamina = 1.4, armor = .065, defense = 1.2, dodge = .85, parry = .75,
    block = .65, blockValue = .55, agility = .63, strength = .48, attack = .20,
    hit = .58, expertise = .52, crit = .25, meleeDPS = 1.8, shield = true,
}

local function profile(key, name, tree, base, overrides)
    local p = {key = key, name = name, tree = tree}
    for k, v in pairs(base) do p[k] = v end
    for k, v in pairs(overrides or {}) do p[k] = v end
    return p
end

-- First entry is the leveling default. 'tree' is the in-game talent tree index.
A.Profiles = {
    WARRIOR = {
        profile("arms", "Arms", 1, melee, {meleeDPS = 7.1}),
        profile("fury", "Fury", 2, melee, {hit = 1.05, crit = .90, offhandScale = .62}),
        profile("protection", "Protection", 3, tank),
    },
    PALADIN = {
        profile("retribution", "Retribution", 3, melee, {holy = .45, spell = .45, intellect = .23, mp5 = .34}),
        profile("holy", "Holy", 1, healer, {intellect = 1.1, crit = .83, spirit = .52}),
        profile("protection", "Protection", 2, tank, {spell = .65, holy = .65, intellect = .50, mp5 = .86}),
    },
    HUNTER = {
        profile("beastmastery", "Beast Mastery", 1, hunter, {stamina = .36, agility = 1.1}),
        profile("marksmanship", "Marksmanship", 2, hunter, {rangedDPS = 7.2, crit = .9}),
        profile("survival", "Survival", 3, hunter, {strength = .55, meleeDPS = 2.7, rangedDPS = 3.5}),
    },
    ROGUE = {
        profile("combat", "Combat", 2, melee, {agility = 1.2, strength = .52, hit = 1.12, offhandScale = .64}),
        profile("assassination", "Assassination", 1, melee, {agility = 1.15, strength = .5, crit = .90, hit = 1.04}),
        profile("subtlety", "Subtlety", 3, melee, {agility = 1.3, strength = .52, crit = .85}),
        profile("mutilate", "Assassination (Mutilate daggers)", 1, melee, {agility = 1.15, strength = .5, daggers = true, hit = 1.04}),
    },
    PRIEST = {
        profile("shadow", "Shadow", 3, caster, {shadow = 1, spirit = .67, crit = .44}),
        profile("discipline", "Discipline (healing)", 1, healer, {intellect = 1, spirit = .92}),
        profile("holy", "Holy", 2, healer, {spirit = 1}),
    },
    SHAMAN = {
        profile("enhancement", "Enhancement", 2, melee, {agility = .80, intellect = .38, spell = .50, nature = .35, fire = .15, mp5 = .48}),
        profile("elemental", "Elemental", 1, caster, {nature = .80, fire = .20, crit = .85, mp5 = 1.0}),
        profile("restoration", "Restoration", 3, healer, {mp5 = 2.25, spirit = .52}),
    },
    MAGE = {
        profile("frost", "Frost", 3, caster, {frost = 1}),
        profile("arcane", "Arcane", 1, caster, {arcane = 1, intellect = 1.05, mp5 = .95}),
        profile("fire", "Fire", 2, caster, {fire = 1, crit = .86}),
    },
    WARLOCK = {
        profile("affliction", "Affliction", 1, caster, {shadow = .9, fire = .10, stamina = .65, spirit = .22}),
        profile("demonology", "Demonology", 2, caster, {shadow = .8, fire = .20, stamina = .86, spirit = .22}),
        profile("destruction", "Destruction", 3, caster, {shadow = .55, fire = .45, crit = .88, stamina = .58}),
    },
    DRUID = {
        profile("cat", "Feral (Cat)", 2, melee, {agility = 1.18, crit = .86, feralAttack = .50, meleeDPS = 4}),
        profile("bear", "Feral (Bear)", 2, tank, {shield = false, block = 0, blockValue = 0, parry = 0, dodge = 1.05, agility = 1.02, feralAttack = .20}),
        profile("balance", "Balance", 1, caster, {arcane = .45, nature = .55, mp5 = 1}),
        profile("restoration", "Restoration", 3, healer, {spirit = 1.05}),
    },
}
