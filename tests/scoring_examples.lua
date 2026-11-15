-- Level-19 equipment from the pinned Forever Cache.json in DATA.md. Source
-- gates and quest choices come from the shipped Catalog, set thresholds from
-- SetData. Run from the repository root: lua tests/scoring_examples.lua
local A = {}
for _, file in ipairs({"Catalog", "Profiles", "Effects", "SetData", "SetBonuses", "Engine", "TooltipStats",
    "Character", "Gates", "Upgrade", "BagCombinations"}) do
    assert(loadfile("WoWBest/" .. file .. ".lua"))("WoWBest", A)
end

-- Keep the inputs in tooltip units. The native API supplies primary stats and
-- the client tooltip supplies weapon damage/DPS, armor and shield block.
local info = {
    [7230] = {min=55, max=83, speed=3.50, str=11, agi=4},              -- Smite's Mighty Hammer
    [5191] = {min=30, max=57, speed=2.80, ap=12},                       -- Cruel Barb
    [1935] = {min=20, max=39, speed=1.90, str=3, agi=4},                -- Assassin's Blade
    [5196] = {min=18, max=35, speed=1.90, str=3, spi=3},                -- Smite's Reaver
    [5194] = {min=31, max=48, speed=2.70, sta=8, spi=8, heal=45, sp=15}, -- Taskmaster Axe
    [7002] = {armor=642, block=13, sta=8, spi=3},                       -- Arctic Buckler
    [270032] = {armor=44, sta=7, ap=10},                               -- Cultist's Armguards
    [10410] = {armor=78, str=5, agi=9, sta=4},                         -- Leggings of the Fang
    [10411] = {armor=61, agi=6, sta=6},                                -- Footpads of the Fang
    [10413] = {armor=52, str=4, agi=6},                                -- Gloves of the Fang
}
local stats = {str="STRENGTH", agi="AGILITY", sta="STAMINA", spi="SPIRIT", ap="ATTACK_POWER",
    heal="SPELL_HEALING_DONE", sp="SPELL_DAMAGE_DONE"}
local locs = {[7]="LEGS", [8]="FEET", [9]="WRIST", [10]="HAND", [13]="WEAPON", [14]="SHIELD", [17]="2HWEAPON"}
local player = {class="WARRIOR", classID=1, raceID=1, faction="Alliance", level=19, dual=false}
local records = {}
C_QuestLog = {IsQuestFlaggedCompleted=function() return false end}
for _, row in ipairs(A.Catalog) do
    if info[row.id] and A.RouteAvailable(row, player) then records[row.id] = row end
end
local function idOf(value)
    return type(value) == "number" and value or tonumber(value:match("item:(%d+)"))
end
IsPlayerSpell = function(id)
    -- A Warrior trained for the weapon and armor types in the fixture. Dual
    -- Wield requires level 20 on Forever and is absent at level 19.
    return id ~= 674
end
C_PlayerInfo = {CanUseItem=function() return true end}
C_Item = {
    GetItemInfo = function(query)
        local id = idOf(query)
        local row = assert(records[id])
        return row.name, "item:" .. id, 3, row.itemLevel, row.minLevel, nil, nil, 1,
            "INVTYPE_" .. locs[row.invType], 1, 1, row.classID, row.subclassID, 1
    end,
    GetItemStats = function(link)
        local out, item = {}, info[idOf(link)]
        for key, token in pairs(stats) do out["ITEM_MOD_" .. token .. "_SHORT"] = item[key] end
        return out
    end,
}
Enum = {TooltipDataLineType={None=0, EquipSlot=21, ItemName=22, UsageRequirement=43}}
DPS_TEMPLATE, ARMOR_TEMPLATE, SHIELD_BLOCK_TEMPLATE = "(%.2f damage per second)", "%d Armor", "%d Block"
DAMAGE_TEMPLATE, WEAPON_SPEED = "%d - %d Damage", "Speed %.2f"
C_TooltipInfo = {GetHyperlink=function(link)
    local row, item = records[idOf(link)], info[idOf(link)]
    local lines = {{type=22,leftText=row.name}, {type=21,leftText="Equipment"}}
    if item.min then
        lines[#lines+1] = {type=0, leftText=DAMAGE_TEMPLATE:format(item.min, item.max), rightText=WEAPON_SPEED:format(item.speed)}
        lines[#lines+1] = {type=0, leftText=DPS_TEMPLATE:format((item.min + item.max) / (2 * item.speed))}
    end
    if item.armor then lines[#lines+1] = {type=0, leftText=ARMOR_TEMPLATE:format(item.armor)} end
    if item.block then lines[#lines+1] = {type=0, leftText=SHIELD_BLOCK_TEMPLATE:format(item.block)} end
    return {lines=lines}
end}

local gear = {}
for id in pairs(info) do gear[id] = assert(A.ReadCandidate(assert(records[id]), player)) end
local function profile(class, key)
    local character = {class=class, classID=class=="WARRIOR" and 1 or 2, level=19, dual=false}
    for _, p in ipairs(A.Profiles[class]) do if p.key == key then return A.ProfileForLevel(p, character) end end
    error("missing " .. key)
end
local arms = profile("WARRIOR", "arms")
local tank = profile("WARRIOR", "protection")
local heal = profile("PALADIN", "holy")
-- Against an evasion, rank-one Overpower adds weapon damage plus 5 at
-- level 12. Both of these blades do ~15.5 DPS, but their base average
-- hits are 43.5 and 29.5. Off-hand swing damage has no Overpower credit.
-- https://bindonforever.com/spell/7384
local function swing(item, slot)
    for _,row in ipairs(A.ScoreBreakdown(item, arms, slot)) do
        if row.label=="Main-hand average hit" then return row.amount, row.points end
    end
end
local barb, barbPoints=swing(gear[5191],16)
local dagger, daggerPoints=swing(gear[1935],16)
assert(barb==43.5 and dagger==29.5 and barbPoints>daggerPoints and daggerPoints>0)
assert(not swing(gear[5191],17))
local pool = {gear[7230], gear[5191], gear[1935], gear[5196], gear[5194], gear[7002], gear[270032]}
local loadout = A.Solve(pool, player, arms)
assert(loadout[16].id == 7230 and not loadout[17], "Arms should select the offensive two-hander from this pool")
assert(loadout[9].id == 270032, "a two-hander leaves the wrist reward available")
assert(A.Score(gear[5191], arms, 16) > A.Score(gear[5196], arms, 16), "Cruel Barb versus Smite's Reaver")
assert(A.Score(gear[5194], heal, 16) > A.Score(gear[7230], heal, 16), "the healing axe must outrank the raw DPS hammer for Holy")
assert(gear[5194].stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT == 45, "healing and damage on Taskmaster Axe are distinct")

-- https://www.wowhead.com/forever/quest=1200/blackfathom-villainy
-- Both items are bind-on-pickup choices for Alliance. Test both legal plans,
-- including the tradeoff that picking a shield consumes the wrist option.
assert(gear[7002].choice == 1200 and gear[270032].choice == 1200)
local tanks = A.Solve(pool, player, tank)
assert(tanks[16] and tanks[16].loc == "INVTYPE_WEAPON" and tanks[17].id == 7002)
assert(not tanks[9], "the tank cannot also plan the alternative quest reward")
local wristOnly = A.Solve({gear[5191], gear[270032]}, player, tank)
assert(wristOnly[9].id == 270032, "the wrist reward remains independently attainable")

-- The tank owns a two-hander and carries these two physical drops. Scoring
-- the shield alone would need a main hand; the sword alone loses DPS.
local wornHammer={[16]=gear[7230]}
local swordSwap=A.CompareEquippedUpgrade(gear[5191],wornHammer,player,tank)
assert(swordSwap.delta<0 and not A.CompareEquippedUpgrade(gear[7002],wornHammer,player,tank))
local inventory={
    {item=gear[5191],key="item:5191",position={bag=0,slot=2},direct=swordSwap},
    {item=gear[7002],key="item:7002",position={bag=0,slot=3}},
}
local step=A.StartJointBagUpgrades(inventory,wornHammer,player,tank)
local done,alerts
repeat done,alerts=step() until done
assert(#alerts==1 and alerts[1].result.delta>0)
assert(alerts[1].result.loadout[16]==gear[5191] and alerts[1].result.loadout[17]==gear[7002])

-- Wailing Caverns changed the three-piece Viper bonus in Forever. The two
-- pieces grant Intellect, the third grants 10 AP, and each threshold counts once.
local pieces = {[7]=gear[10410], [8]=gear[10411], [10]=gear[10413]}
local base = A.Score(pieces[7], arms, 7) + A.Score(pieces[8], arms, 8) + A.Score(pieces[10], arms, 10)
local setStats = {ITEM_MOD_INTELLECT_SHORT=10, ITEM_MOD_ATTACK_POWER_SHORT=10}
local bonus = A.LoadoutScore(pieces, arms) - base
assert(bonus > 0 and math.abs(bonus - A.Score({stats=setStats}, arms)) < 0.00001)
print("Forever level-19 Warrior, shield/quest, healing weapon and set scoring examples passed")
