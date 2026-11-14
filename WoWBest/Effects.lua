local _, A = ...

-- Measured Forever tooltip values. The score is a long-run, on-cooldown
-- estimate on a generic target. Only the player's own resources are valued.
-- Per-item references: https://endgametools.com/en/wow-forever/items/<itemID>
-- Second Wind: 1.60.1.70888. Other four: 1.60.1.70938. Reviewed 2026-11-14.
-- These items changed in Forever. Recheck their tooltip on a game-data update.
local models = {}
A.EffectNotes = {}

-- Item-specific passive spell auras can already be represented by GetItemStats.
-- Count only the shortfall; do not apply the same flat stat a second time.
local function missing(stat, amount) return math.max(0, amount - (stat or 0)) end

local function passiveCrit(stats, profile, personalCrit)
    local rating = stats.ITEM_MOD_CRIT_RATING_SHORT or 0
    local fromPercent = (stats.CRIT_PERCENT or 0) * 14
    local reported = math.max(rating, fromPercent)
    -- A generic API crit key can conceal this item's narrower school.
    if personalCrit then return missing(reported, 14) * (profile.crit or 0) end
    return -math.min(reported, 14) * (profile.crit or 0)
end

models[13965] = function(stats, profile) -- Blackhand's Breadth
    local physical = (profile.meleeDPS or 0) > 0 or (profile.rangedAttack or 0) > 0
    -- The passive only affects melee/ranged attacks. Value the enemy mark for
    -- offensive profiles, ignoring its doubled bonus against Orcs and Ogres.
    local mark = not profile.healing and 5 * 14 * 20 / 300 * (profile.crit or 0) or 0
    return passiveCrit(stats, profile, physical) + mark
end
A.EffectNotes[13965] = "Includes the physical crit passive for weapon profiles and the mark averaged over 20 of 300 seconds on a normal target."

models[13968] = function(stats, profile) -- Eye of the Beast
    local caster = (profile.spell or 0) > 0 and not profile.meleeDPS
    local spellHit = caster and not profile.healing and 7 * 10 * 20 / 300 * (profile.hit or 0) or 0
    return passiveCrit(stats, profile, caster) + spellHit
end
A.EffectNotes[13968] = "Caster profiles count spell crit. Damaging caster profiles also average 7% spell hit over 20 of 300 seconds, assuming room below the hit cap."

models[20130] = function(_, profile) -- Diamond Flask
    return 20 * 60 / 360 * (profile.strength or 0)
end
A.EffectNotes[20130] = "Counts the Strength buff after a full channel: 20 for 60 of 360 seconds. The heal and time spent channeling have no score."

models[11819] = function(stats, profile) -- Second Wind
    local universal = stats.ITEM_MOD_SPELL_POWER_SHORT or 0
    local passive
    if profile.healing then
        passive = missing(universal + (stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT or 0), 15) * profile.healing
    else
        passive = missing(universal + (stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT or 0), 5) * (profile.spell or 0)
    end
    local manaPer5 = 63 * 10 * 5 / 900
    return passive + manaPer5 * (profile.mp5 or 0)
end
A.EffectNotes[11819] = "Includes the passive spell bonus and 630 mana per 900 seconds (3.5 mana per 5). Assumes the ordinary terrain bonus."

models[20503] = function(stats, profile) -- Enamored Water Spirit
    local flat = missing(stats.ITEM_MOD_MANA_REGENERATION_SHORT, 4)
    local totem = (33 * 12) * 5 / 600
    return (flat + totem) * (profile.mp5 or 0)
end
A.EffectNotes[20503] = "Counts 4 passive mana per 5 plus 396 personal mana per 600 seconds. Assumes all 12 totem pulses reach you."

function A.EffectScore(item, profile)
    local model = models[item.id]
    return model and model(item.stats or {}, profile) or 0
end
