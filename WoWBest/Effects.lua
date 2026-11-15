local _, A = ...

-- Measured Forever tooltip values. The score is a long-run, on-cooldown
-- estimate on a generic target. Only the player's own resources are valued.
-- Per-item references: https://endgametools.com/en/wow-forever/items/<itemID>
-- Second Wind: 1.60.1.70888. Other four: 1.60.1.70938. Reviewed 2026-11-14.
-- These items changed in Forever. Recheck their tooltip on a game-data update.
local models = {}
A.EffectNotes = {}

-- Distinguish item-specific caveats from effects that actually have a score.
-- The Mushroom's advertised aura has conflicting character-sheet observations.
A.UnscoredEffectNotes = {
    [249396] = "Mystic Mushroom advertises 5% more Spirit. Its live bonus is unverified and has no score.",
    [263411] = "Idol of Shifting Tides saves up to 40 mana per shapeshift. How often you shift determines its value, so this saving has no score.",
}

-- Item-specific passive spell auras can already be represented by GetItemStats.
-- Count only the shortfall; do not apply the same flat stat a second time.
local function missing(stat, amount) return math.max(0, amount - (stat or 0)) end

-- The client may expose a school-specific passive as generic crit on the
-- item. Replace the contribution of this one percent, preserving any extra.
local function passiveCrit(stats, profile, share)
    local full = A.PercentStatWeight(profile, "crit")
    local credited = A.CombatStatPoints(stats, profile, "crit")
    return full * share - math.min(credited, full)
end

models[13965] = function(stats, profile) -- Blackhand's Breadth
    local share = profile.physicalCritShare
    if share == nil then share = (profile.meleeDPS or profile.rangedAttack) and 1 or 0 end
    local mark = not profile.healing and 5 * 20 / 300 * A.PercentStatWeight(profile, "crit") or 0
    return passiveCrit(stats, profile, share) + mark
end
A.EffectNotes[13965] = "Values physical crit for this build and the target mark averaged over 20 of 300 seconds. Orcs and Ogres receive a larger mark."

models[13968] = function(stats, profile) -- Eye of the Beast
    local critShare, hitShare = profile.spellCritShare, profile.spellHitShare
    if critShare == nil then critShare = profile.spell and not profile.meleeDPS and 1 or 0 end
    if hitShare == nil then hitShare = profile.healing and 0 or critShare end
    local hit = 7 * 20 / 300 * A.PercentStatWeight(profile, "hit") * hitShare
    return passiveCrit(stats, profile, critShare) + hit
end
A.EffectNotes[13968] = "Values the spell crit passive and the spell hit on-use for this build. Assumes the hit bonus is useful for 20 of 300 seconds."

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
