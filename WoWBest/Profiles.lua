local _, A = ...

-- Points are relative within a profile. A healing profile describes group healing,
-- Protection describes shield tanking, and the other profiles emphasize PvE damage.
-- The agility and intellect inputs below exclude crit. It is derived once per
-- profile using the Forever client's class/level conversions further down.
local melee = {
    strength = 1, stamina = .18, spirit = .02, armor = .008, attack = .50,
    hit = 1.12, crit = 1, haste = .78, expertise = .82, meleeDPS = 6.4,
    offhandScale = .42, physicalCritShare = 1, rangedCritShare = 0, spellHitShare = 0,
}
local hunter = {
    agility = .88, strength = .04, stamina = .23, intellect = .22, spirit = .06,
    armor = .006, attack = .44, rangedAttack = .43, hit = 1.12, crit = 1.16,
    haste = .66, meleeDPS = .18, rangedDPS = 6.2, mp5 = .42, offhandScale = .4,
    physicalCritShare = 1, rangedCritShare = .95, spellHitShare = 0,
}
local caster = {
    intellect = .36, spirit = .19, stamina = .14, armor = .003, spell = 1,
    hit = 1.18, crit = .80, haste = .90, mp5 = .65, rangedDPS = .08,
    physicalCritShare = 0, rangedCritShare = 0, spellHitShare = 1,
}
local healer = {
    intellect = .66, spirit = .72, stamina = .16, armor = .004,
    healing = 1, spell = 1, crit = .50, haste = .49, mp5 = 1.75, rangedDPS = .02,
    physicalCritShare = 0, rangedCritShare = 0, spellHitShare = 0,
}
local tank = {
    stamina = 1.4, armor = .06, dodge = 1.05, parry = .87,
    block = .73, blockValue = .63, agility = .36, strength = .48, attack = .22,
    hit = .72, expertise = .68, crit = .31, meleeDPS = 2.9, shield = true,
    physicalCritShare = 1, rangedCritShare = 0, spellHitShare = 0,
}

local function profile(key, name, tree, base, overrides)
    local p = {key = key, name = name, tree = tree}
    for k, v in pairs(base) do p[k] = v end
    for k, v in pairs(overrides or {}) do p[k] = v end
    p.spellCritShare = 1 - p.physicalCritShare
    p.meleeCritShare = p.physicalCritShare - p.rangedCritShare
    return p
end

-- First entry is the leveling default. 'tree' is the in-game talent tree index.
A.Profiles = {
    WARRIOR = {
        profile("arms", "Arms", 1, melee, {meleeDPS = 6.2, mainHandDamage = .62, crit = 1.18, offhandScale = .25}),
        profile("fury", "Fury", 2, melee, {meleeDPS = 5.7, mainHandDamage = .14, hit = 1.52, crit = 1.50,
            haste = 1.03, expertise = .86, offhandScale = .39}),
        profile("protection", "Protection", 3, tank),
    },
    PALADIN = {
        profile("retribution", "Retribution", 3, melee, {mainHandDamage = .58, spell = .78, holy = .78,
            intellect = .38, mp5 = .45, physicalCritShare = .70, spellHitShare = .30}),
        profile("holy", "Holy", 1, healer, {intellect = .82, crit = .88, spirit = .27, mp5 = 1.9}),
        profile("protection", "Protection", 2, tank, {spell = .78, holy = .78, intellect = .42, mp5 = .92,
            physicalCritShare = .45, spellHitShare = .55}),
    },
    HUNTER = {
        profile("beastmastery", "Beast Mastery", 1, hunter, {stamina = .31, crit = 1.25}),
        profile("marksmanship", "Marksmanship", 2, hunter, {rangedDPS = 7.3, crit = 1.28}),
        profile("survival", "Survival", 3, hunter, {agility = .54, strength = .44, attack = .48,
            rangedAttack = .12, meleeDPS = 5.85, mainHandDamage = .43, rangedDPS = 1.65, rangedCritShare = .22}),
    },
    ROGUE = {
        profile("combat", "Combat", 2, melee, {agility = .50, strength = .50, mainHandDamage = .48, hit = 1.22}),
        profile("assassination", "Assassination", 1, melee, {agility = .50, strength = .50, mainHandDamage = .38,
            crit = 1.2, hit = 1.18}),
        profile("subtlety", "Subtlety", 3, melee, {agility = .52, strength = .50, mainHandDamage = .64, crit = 1.12}),
        profile("mutilate", "Assassination (Mutilate daggers)", 1, melee, {agility = .50, strength = .50,
            mainHandDamage = .36, crit = 1.2, daggers = true, hit = 1.18, offhandScale = .55}),
    },
    PRIEST = {
        profile("shadow", "Shadow", 3, caster, {shadow = 1, spirit = .38, crit = .62}),
        profile("discipline", "Discipline (healing)", 1, healer, {intellect = .80, spirit = .82}),
        profile("holy", "Holy", 2, healer, {spirit = .96, crit = .38}),
    },
    SHAMAN = {
        profile("enhancement", "Enhancement", 2, melee, {mainHandDamage = .34, intellect = .62,
            spell = .60, nature = .37, fire = .23, mp5 = .52, physicalCritShare = .62, spellHitShare = .38}),
        profile("elemental", "Elemental", 1, caster, {nature = .78, fire = .22, crit = 1.00, mp5 = .94}),
        profile("restoration", "Restoration", 3, healer, {crit = .67, mp5 = 2.12, spirit = .42}),
    },
    MAGE = {
        profile("frost", "Frost", 3, caster, {frost = .90, arcane = .10}),
        profile("arcane", "Arcane", 1, caster, {arcane = .95, frost = .05, intellect = .65, mp5 = .94}),
        profile("fire", "Fire", 2, caster, {fire = .96, arcane = .04, crit = 1.07}),
    },
    WARLOCK = {
        profile("affliction", "Affliction", 1, caster, {shadow = .86, fire = .14, stamina = .47, spirit = .15}),
        profile("demonology", "Demonology", 2, caster, {shadow = .65, fire = .35, stamina = .55, spirit = .16}),
        profile("destruction", "Destruction", 3, caster, {shadow = .33, fire = .67, crit = 1.03, stamina = .40}),
    },
    DRUID = {
        profile("cat", "Feral (Cat)", 2, melee, {agility = .50, crit = 1.14, feralAttack = .50, meleeDPS = 7}),
        profile("bear", "Feral (Bear)", 2, tank, {shield = false, block = 0, blockValue = 0, parry = 0,
            armor = .105, dodge = 1.30, agility = .66, attack = .25, feralAttack = .25, meleeDPS = 3.5}),
        profile("balance", "Balance", 1, caster, {arcane = .45, nature = .55, mp5 = .95}),
        profile("restoration", "Restoration", 3, healer, {spirit = 1.0, crit = .30}),
    },
}

-- Rounded PlayerExpectedStat values in the Forever 1.60.1.70938 build. Each
-- index is a character level. Only the classes using that stat are included.
-- Source and units: https://foreverdb.net/stats and linked class tables.
local agilityForCrit = {
    WARRIOR = {
        4, 4.2, 4.2, 4.4, 4.6, 4.8, 4.8, 5, 5.2, 5.2, 5.4, 5.6, 6, 6.2, 6.4,
        6.6, 6.8, 7.2, 7.4, 7.8, 7.8, 8, 8.4, 8.6, 9, 9.2, 9.4, 9.8, 10, 10.4,
        10.6, 10.8, 11.2, 11.4, 11.8, 12, 12.2, 12.6, 12.8, 13.2, 13.6, 13.8, 14.2, 14.4, 14.8,
        15, 15.4, 15.8, 16, 16.4, 16.8, 17, 17.4, 17.8, 18.2, 18.4, 18.8, 19.2, 19.6, 20,
    },
    PALADIN = {
        4.7, 4.9, 4.9, 5.1, 5.1, 5.3, 5.3, 5.6, 5.6, 5.8, 5.8, 6, 6.5, 6.5, 7,
        7, 7.2, 7.7, 7.7, 8.1, 8.4, 8.4, 8.8, 9.1, 9.3, 9.5, 9.8, 10, 10.2, 10.7,
        10.9, 10.9, 11.4, 11.6, 12.1, 12.3, 12.3, 12.8, 13, 13.5, 13.7, 13.7, 14.2, 14.4, 14.9,
        15.1, 15.3, 15.8, 16.1, 16.5, 16.8, 17, 17.5, 17.7, 18.1, 18.4, 18.6, 19.1, 19.3, 19.8,
    },
    HUNTER = {
        4.6, 4.8, 5, 5.4, 5.6, 5.8, 6, 6.2, 6.6, 6.8, 7.4, 8.4, 9.2, 10, 11,
        11.6, 12.4, 13.4, 14.2, 15.2, 15.8, 16.8, 17.6, 18.6, 19.4, 20.2, 21.2, 22, 23, 24,
        24.6, 25.6, 26.6, 27.4, 28.4, 29.2, 30.2, 31.2, 32.2, 33, 33.8, 34.8, 35.8, 36.8, 37.7,
        38.6, 39.5, 40.8, 41.8, 42.7, 43.7, 44.6, 45.7, 46.7, 47.8, 48.5, 49.8, 50.8, 52.1, 52.9,
    },
    ROGUE = {
        2.3, 2.4, 2.5, 2.7, 2.8, 2.9, 3.1, 3.2, 3.3, 3.5, 3.9, 4.3, 4.8, 5.2, 5.8,
        6.2, 6.6, 7.1, 7.6, 8.1, 8.6, 9, 9.5, 9.9, 10.5, 11, 11.4, 11.9, 12.4, 13,
        13.4, 13.9, 14.4, 14.9, 15.5, 16, 16.4, 16.9, 17.4, 18, 18.5, 19, 19.5, 20.1, 20.7,
        21.2, 21.7, 22.2, 22.7, 23.4, 23.9, 24.4, 25, 25.5, 26.1, 26.7, 27.2, 27.8, 28.3, 29,
    },
    SHAMAN = {
        6.1, 6.1, 6.4, 6.4, 6.7, 6.7, 6.7, 7, 7, 7.3, 7.3, 7.6, 7.6, 7.9, 8.2,
        8.5, 8.5, 8.8, 8.8, 9.4, 9.4, 9.7, 9.7, 10, 10.3, 10.6, 10.6, 10.9, 10.9, 11.5,
        11.5, 11.8, 12.1, 12.1, 12.7, 13, 13, 13.3, 13.3, 13.9, 14.2, 14.2, 14.5, 14.9, 15.2,
        15.5, 15.7, 16.1, 16.1, 16.7, 17, 17.3, 17.3, 17.6, 18.2, 18.5, 18.8, 18.8, 19.1, 19.7,
    },
    DRUID = {
        4.9, 4.9, 5.1, 5.1, 5.4, 5.4, 5.6, 5.6, 5.9, 6.3, 6.6, 6.6, 6.8, 6.8, 7.3,
        7.3, 7.6, 7.8, 7.8, 8.8, 8.8, 9, 9.3, 9.3, 9.8, 9.8, 10, 10.2, 10.2, 11.2,
        11.5, 11.5, 11.7, 11.9, 12.2, 12.4, 12.7, 12.7, 12.9, 13.9, 14.1, 14.1, 14.4, 14.6, 15.1,
        15.4, 15.4, 15.6, 15.8, 16.8, 17.1, 17.3, 17.6, 17.6, 18.1, 18.3, 18.6, 18.8, 19, 20,
    },
}
local intellectForSpellCrit = {
    PALADIN = {
        13.3, 14, 14, 14.7, 14.7, 15.3, 16, 16, 16.7, 16.7, 17.3, 18, 18.7, 19.3, 20.7,
        20.7, 21.3, 22.7, 22.7, 24, 24.7, 25.3, 26, 26.7, 28, 28.7, 28.7, 30, 30.7, 31.9,
        32.7, 33.3, 34, 34.7, 36, 36.6, 37.3, 38.6, 39.4, 40.7, 41.3, 42, 43.3, 43.3, 44.6,
        45.2, 46.7, 48.1, 48.8, 50, 50.8, 51.3, 52.6, 53.2, 54.6, 55.2, 55.9, 58.1, 58.8, 59.9,
    },
    PRIEST = {
        5.2, 5.5, 5.7, 6, 6.4, 6.7, 6.9, 7.1, 7.4, 7.9, 8.6, 9.5, 10.2, 11.4, 12.4,
        13.1, 14.3, 15, 15.9, 17.2, 17.9, 19, 19.8, 21, 21.9, 22.8, 23.8, 24.8, 25.7, 26.9,
        27.9, 28.8, 29.8, 31, 31.9, 32.9, 34, 35, 36, 37.2, 38, 39.2, 40.2, 41.5, 42.6,
        43.5, 44.8, 45.7, 46.9, 48.1, 49, 50.3, 51.3, 52.4, 53.8, 54.6, 55.9, 56.8, 58.5, 59.5,
    },
    SHAMAN = {
        7.8, 8.1, 8.5, 8.5, 8.9, 9.3, 9.6, 10, 10.4, 10.4, 11.1, 11.8, 13, 13.7, 14.8,
        15.6, 16.3, 17.4, 18.1, 19.3, 20, 20.7, 21.8, 22.6, 23.7, 24.4, 25.2, 26.3, 27, 28.2,
        29.2, 30, 31.2, 31.8, 33, 34.1, 34.8, 36, 36.6, 38.2, 38.9, 39.7, 40.8, 41.8, 42.9,
        44.1, 44.8, 45.9, 46.9, 48.1, 49.3, 50, 51.5, 52.4, 53.8, 54.3, 55.6, 57.1, 57.8, 59.2,
    },
    MAGE = {
        5.2, 5.4, 5.6, 6, 6.2, 6.5, 6.7, 6.9, 7.3, 7.5, 8.1, 9.2, 9.8, 11.7, 12.7,
        13.3, 14.2, 15, 15.8, 16.9, 17.5, 18.6, 19.2, 20.2, 21.1, 21.9, 22.9, 25.2, 26.2, 27.3,
        27.9, 29, 29.8, 30.6, 31.6, 32.5, 33.6, 34.4, 35.5, 36.2, 37, 39.5, 40.5, 41.5, 42.6,
        43.3, 44.4, 45.5, 46.5, 47.4, 48.3, 49.3, 50.3, 51.5, 52.6, 55.2, 56.5, 57.1, 58.5, 59.5,
    },
    WARLOCK = {
        6.7, 7, 7.3, 7.6, 7.9, 8.2, 8.5, 8.8, 9.1, 9.4, 10.3, 11.2, 12.1, 13, 13.9,
        14.5, 15.7, 16.7, 17.6, 18.5, 19.4, 20.3, 21.2, 22.4, 23.3, 23.9, 25.1, 26, 27.2, 28.2,
        28.8, 30, 30.9, 32.2, 33, 33.9, 35.2, 36.1, 37.3, 38.2, 39.1, 40.3, 41.2, 42.4, 43.7,
        44.6, 45.5, 46.7, 47.8, 49, 50, 51.3, 52.4, 53.8, 54.9, 55.9, 56.8, 58.1, 59.5, 60.6,
    },
    DRUID = {
        6.9, 7.2, 7.5, 7.8, 8.1, 8.4, 8.7, 8.7, 9.1, 10, 10.6, 11.6, 12.2, 13.1, 14.4,
        15, 15.9, 16.6, 17.5, 19, 19.7, 20.6, 21.2, 22.5, 23.4, 24, 25, 25.6, 26.9, 28.4,
        29.1, 30.3, 31, 31.8, 33.1, 33.8, 34.7, 35.6, 36.5, 38.5, 39.1, 40.3, 41, 42.2, 43.1,
        44.1, 45, 45.9, 47.2, 48.8, 49.8, 51, 51.5, 52.9, 54.1, 54.9, 55.9, 56.8, 58.1, 59.9,
    },
}

-- A percentage of an early weapon swing or healing spell is worth fewer
-- absolute points than the same percentage of a level-60 attack or heal.
-- This interpolation is a leveling preference, not a change to Blizzard's
-- fixed rating conversion. Flat spell power, AP and weapon DPS keep their units.
local ratings = {"hit", "crit", "haste", "expertise"}
local avoidance = {"dodge", "parry", "block"}

local function forLevel(base, level)
    local p = {}
    for k, v in pairs(base) do p[k] = v end
    p.level = level
    local progress = level / 60
    local ratingScale = .12 + .88 * progress * progress
    local leveling = (60 - level) / 59
    for _, stat in ipairs(ratings) do
        if p[stat] then p[stat] = p[stat] * ratingScale end
    end
    for _, stat in ipairs(avoidance) do
        if p[stat] then p[stat] = p[stat] * (.35 + .65 * progress) end
    end

    if p.dodge then
        -- Each skill point supplies 0.04% dodge, miss, parry and block where
        -- available. Value miss as a dodge; no assumed crit-immunity breakpoint.
        p.defenseSkill = .04 * (24 * p.dodge + 15 * p.parry + 5 * p.block)
        p.defense = p.defenseSkill -- Forever: one defense rating gives one skill.
        p.meleeDPS = p.meleeDPS + 1.3 * leveling -- weapon threat during leveling
    end
    if p.class == "WARRIOR" then
        p.spirit = (p.spirit or 0) + (p.shield and .12 or .36) * leveling
        if p.key == "fury" then
            -- Flurry becomes available from 37; never award a talent point.
            local later = math.max(0, math.min(1, (level - 36) / 12))
            p.crit = p.crit * (.72 + .28 * later)
        end
    end

    if not p.defense then p.stamina = p.stamina + .26 * leveling end
    if p.intellect and p.intellect > 0 then
        p.intellect = p.intellect + .50 * leveling
        p.spirit = (p.spirit or 0) + .25 * leveling
    end
    if p.class == "PRIEST" and p.key == "shadow" then
        -- Wands finish fights while mana regenerates. Shadowform becomes
        -- available at 40, so much of this early preference fades by then.
        local wandLeveling = math.max(0, math.min(1, (42 - level) / 22))
        p.rangedDPS = p.rangedDPS + 2.8 * wandLeveling
        p.spirit = p.spirit + .46 * wandLeveling
    elseif p.class == "MAGE" or p.class == "WARLOCK" then
        p.rangedDPS = p.rangedDPS + .94 * leveling * leveling
    end

    if p.class == "DRUID" and p.key == "cat" and level < 20 then
        -- Before Cat Form, Agility supplies no cat-specific melee attack power.
        p.agility = 0
        if level < 10 then -- a new Druid can also use Wrath and Moonfire
            p.spell, p.nature, p.arcane = .55, .40, .15
            p.intellect = .60
            p.physicalCritShare, p.meleeCritShare, p.spellCritShare, p.spellHitShare = .5, .5, .5, .5
        end
    end

    -- Only the applicable portion of unified crit is granted by a primary stat.
    local perCrit = 14 * (p.crit or 0)
    local agi, int = agilityForCrit[p.class], intellectForSpellCrit[p.class]
    p.mana = (p.intellect or 0) / 15
    p.agility = (p.agility or 0) + 2 * (p.armor or 0)
    if agi then p.agility = p.agility + perCrit * p.physicalCritShare / agi[level] end
    if int and p.spellCritShare > 0 then
        p.intellect = (p.intellect or 0) + perCrit * p.spellCritShare / int[level]
    end
    if p.shield then p.strength = p.strength + p.blockValue / 20 end
    return p
end

-- The UI selects the same resolved profile for the planner and hover tooltips.
-- Cache by preset and level; humanoid scenarios copy the result before editing.
local presets = {}
for class, list in pairs(A.Profiles) do
    for i, base in ipairs(list) do
        base.class = class
        local atCap = forLevel(base, 60)
        list[i] = atCap
        local preset = {base = base, levels = {[60] = atCap}}
        presets[atCap] = preset
    end
end

function A.ProfileForLevel(profile, playerOrLevel)
    local preset = presets[profile]
    if not preset then return profile end -- external or test-supplied weights
    local level = type(playerOrLevel) == "table" and playerOrLevel.level or playerOrLevel
    if type(level) ~= "number" then return profile end
    level = math.max(1, math.min(60, math.floor(level)))
    if not preset.levels[level] then
        local resolved = forLevel(preset.base, level)
        presets[resolved], preset.levels[level] = preset, resolved
    end
    return preset.levels[level]
end
