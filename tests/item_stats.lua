local A = {}
assert(loadfile("WoWBest/TooltipStats.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Character.lua"))("WoWBest", A)
Enum = {TooltipDataLineType = {None=0, ItemName=22, ItemEnchantmentPermanent=15,
    ItemSpellTriggerOnUse=44, ItemSpellTriggerOnEquip=45, ItemSpellTriggerOnProc=46, FlavorText=37}}
local stats, lines, itemClass, id, baseStats, baseLink, exact
local function line(left, right, kind) return {type=kind or 0, leftText=left, rightText=right} end
C_PlayerInfo = {CanUseItem = function() return true end}
IsPlayerSpell = function() return true end
C_Item = {
    GetItemInfo = function() return "Gear", "item:" .. id, 3, 50, 1, nil, nil, 1,
        itemClass == 2 and "INVTYPE_WEAPON" or "INVTYPE_FINGER", nil, nil, itemClass, itemClass == 2 and 7 or 0 end,
    GetItemStats = function(link)
        if link == baseLink then return baseStats end
        assert(link == exact or link == 'item:'..id, link)
        return stats
    end,
    GetDetailedItemLevelInfo = function(link)
        assert(link == exact or link == 'item:'..id)
        return 51
    end,
}
C_TooltipInfo = {GetHyperlink=function(link)
    assert(link == exact or link == 'item:'..id)
    local all = {line("Gear",nil,22),line("Slot")}
    for _,v in ipairs(lines) do all[#all+1] = v end
    return {lines=all}
end}
local function read(num, live, tooltip, cls, link)
    id, stats, lines, itemClass, exact = num, live or {}, tooltip or {}, cls or 4, link
    local result, why = A.ReadCandidate({id=id, link=link}, {level=60})
    assert(result,why)
    return result
end
local r = read(5191) -- pinned Cruel Barb fallback is ignored in a nonweapon slot
assert(not r.weaponSpeed and r.stats.ITEM_MOD_ATTACK_POWER_SHORT == 12)
r = read(5191,{},nil,2)
assert(r.weaponSpeed==2.8 and r.minDamage==30 and r.maxDamage==57 and r.itemLevel==51)
r = read(1935,{},nil,2)
assert(r.weaponSpeed==1.9 and r.minDamage==20 and r.maxDamage==39)
r = read(1935,{}, {line("38 - 59 Schaden","Tempo 2,80")},2,"item:1935::::::-12:1234")
assert(r.weaponSpeed==2.8 and r.minDamage==38 and r.maxDamage==59 and not r.stats.ITEM_MOD_AGILITY_SHORT)
DPS_TEMPLATE="(%.1f Schaden pro Sekunde)"
r = read(1935, {}, {line("15 - 20 Schaden","Tempo 2,00"),line("(11,5 Schaden pro Sekunde)")},2)
assert(not r.minDamage and r.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT==11.5 and r.weaponSpeed==2)
r = read(19325,{ITEM_MOD_HIT_MELEE_RATING_SHORT=10,ITEM_MOD_HIT_SPELL_RATING_SHORT=10,
    ITEM_MOD_CRIT_RATING_SHORT=14,ITEM_MOD_CRIT_MELEE_RATING_SHORT=14})
assert(r.stats.ITEM_MOD_HIT_RATING_SHORT==10 and not r.stats.ITEM_MOD_HIT_SPELL_RATING_SHORT)
assert(r.stats.ITEM_MOD_CRIT_RATING_SHORT==14 and not r.stats.HIT_PERCENT and not r.stats.CRIT_PERCENT)
assert(read(19325).stats.CRIT_PERCENT==1)
r = read(19325,{ITEM_MOD_ATTACK_POWER_SHORT=14,ITEM_MOD_RANGED_ATTACK_POWER_SHORT=14})
assert(r.stats.ITEM_MOD_ATTACK_POWER_SHORT==14 and not r.stats.ITEM_MOD_RANGED_ATTACK_POWER_SHORT)
r = read(999998,{ITEM_MOD_ATTACK_POWER_SHORT=14,ITEM_MOD_RANGED_ATTACK_POWER_SHORT=20},
    {line("Equip: +14 Attack Power."),line("Equip: +6 Ranged Attack Power.")})
assert(r.stats.ITEM_MOD_ATTACK_POWER_SHORT==14 and r.stats.ITEM_MOD_RANGED_ATTACK_POWER_SHORT==6)
r = read(276336,{ITEM_MOD_SPELL_POWER_SHORT=5,ITEM_MOD_SPELL_HEALING_DONE_SHORT=15})
assert(r.stats.ITEM_MOD_SPELL_POWER_SHORT==5 and r.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT==10
    and not r.stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT)
r = read(276336,{ITEM_MOD_SPELL_POWER_SHORT=5,ITEM_MOD_SPELL_HEALING_DONE_SHORT=10})
assert(r.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT==10)
r = read(276336,{ITEM_MOD_SPELL_POWER_SHORT=5},{line("Equip: Increases healing done by up to 21 and damage done by up to 7 for all magical spells and effects.",nil,45)})
assert(r.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT==16 and r.stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT==2)
r = read(18082,{},nil,2)
assert(r.stats.ITEM_MOD_SPELL_POWER_SHORT==54 and not r.stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT and r.unmodeledEffect)
r = read(19838,{ITEM_MOD_ARMOR_SHORT=197,ITEM_MOD_EXTRA_ARMOR_SHORT=90,ITEM_MOD_BONUS_ARMOR_SHORT=90})
assert(r.stats.RESISTANCE0_NAME==197 and r.stats.ITEM_MOD_EXTRA_ARMOR_SHORT==90 and not r.stats.ITEM_MOD_ARMOR_SHORT)
assert(not r.stats.ITEM_MOD_MANA_REGENERATION_SHORT) -- MP5 is a two-piece set threshold, never an item stat
r = read(999998,{}, {line("Equip: +34 Attack Power against Beasts.",nil,45),
    line("Use: Increases your attack speed and casting speed by 20%.",nil,44),line("(2) Set: Increases healing done by up to 99.")})
assert(not r.stats.ITEM_MOD_ATTACK_POWER_SHORT and not r.stats.HASTE_PERCENT and not r.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT)
assert(r.unmodeledEffect)
r = read(999998,{}, {line("Equip: +18 Attack Power against Humanoids.",nil,45),line("Equip: Improves your chance to hit by 0.5%.",nil,45)})
assert(r.stats.HUMANOID_ATTACK_POWER==18 and r.stats.HIT_PERCENT==.5 and not r.stats.ITEM_MOD_ATTACK_POWER_SHORT)
A.EffectNotes={[999998]="Handled"}
assert(not read(999998,{}, {line("Proc",nil,46)}).unmodeledEffect)
baseLink="item:999998:0:::::-12:1234"
local enhanced="item:999998:17:::::-12:1234"
local tip={line("Verzaubert: +5 Beweglichkeit",nil,15)}
ENCHANTED_TOOLTIP_LINE="Verzaubert: %s"
ITEM_MOD_AGILITY_SHORT="Beweglichkeit"
baseStats={ITEM_MOD_AGILITY_SHORT=7}
assert(read(999998,{ITEM_MOD_AGILITY_SHORT=7},tip,4,enhanced).stats.ITEM_MOD_AGILITY_SHORT==12)
assert(read(999998,{ITEM_MOD_AGILITY_SHORT=12},tip,4,enhanced).stats.ITEM_MOD_AGILITY_SHORT==12)
assert(read(999998,{ITEM_MOD_AGILITY_SHORT=9},tip,4,enhanced).stats.ITEM_MOD_AGILITY_SHORT==12)
assert(read(999998,{}, {line("Verzaubert: Crusader",nil,15)},4,enhanced).unmodeledEffect)
baseStats=nil
assert(read(999998,{ITEM_MOD_AGILITY_SHORT=7},tip,4,enhanced).unmodeledEffect)
-- Actual Forever healing gear. A permanent enchant cannot erase the staff's
-- +52 healing / +17 damage, including when the passive is absent in a localized
-- tooltip. A random suffix remains an independent, unverified variant.
baseLink="item:3415:0"
baseStats={}
local staffInt="item:3415:723"
local spell="ITEM_MOD_SPELL_POWER_SHORT"
local damage,heal="ITEM_MOD_SPELL_DAMAGE_DONE_SHORT","ITEM_MOD_SPELL_HEALING_DONE_SHORT"
local intellect="ITEM_MOD_INTELLECT_SHORT"
local intTip={line("Verzaubert: +3 Intellect",nil,15)}
for _,native in ipairs({{}, {[intellect]=3}, {[intellect]=6}}) do
    r=read(3415,native,intTip,2,staffInt)
    assert(r.stats[intellect]==6 and r.stats[heal]==52 and r.stats[damage]==17)
end
local powerTip={line("Enchanted: +5 Spell Power",nil,15)}
for _,native in ipairs({{}, {[spell]=5}, {[spell]=5,[damage]=22,[heal]=57}}) do
    r=read(3415,native,powerTip,2,"item:3415:5")
    assert(r.stats[spell]==5 and r.stats[heal]==52 and r.stats[damage]==17)
end
r=read(3415,{},nil,2,"item:3415::::::-12:1234")
assert(not r.stats[heal] and not r.stats[damage])
assert(loadfile("WoWBest/Engine.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Profiles.lua"))("WoWBest", A)
local resto
for _,p in ipairs(A.Profiles.DRUID) do if p.key=="restoration" then resto=A.ProfileForLevel(p,31) end end
assert(resto, "Missing Restoration Druid profile")
-- Measure only the magic contribution; each item also carries primary stats.
local function healingContribution(item)
    local st=item.stats
    return A.Score({stats={[spell]=st[spell],[damage]=st[damage],[heal]=st[heal]}},resto)
end
assert(healingContribution(read(3415,{},nil,2))==52*resto.healing)
r=read(2271,{},nil,2) -- Staff of the Blessed Seer, +28 damage AND healing
assert(r.stats[spell]==28 and not r.stats[damage] and not r.stats[heal])
assert(healingContribution(r)==28*resto.healing)
r=read(6911,{[spell]=12,[heal]=12}) -- Moss Cinch, +12 spell DAMAGE only
assert(r.stats[damage]==12 and not r.stats[spell] and not r.stats[heal])
assert(healingContribution(r)==0)
r=read(3415,{[spell]=52,[heal]=52,[damage]=17},nil,2)
assert((r.stats[spell] or 0)+(r.stats[heal] or 0)==52)
assert((r.stats[spell] or 0)+(r.stats[damage] or 0)==17)
print("Exact-link stat normalization, real cache passives, stock and modified weapon ranges, enchant reconciliation, and proc uncertainty passed.")
