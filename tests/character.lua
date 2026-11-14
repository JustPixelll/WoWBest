-- Run from the repository root with lua tests/character.lua (or texlua).
local A = {}
assert(loadfile("WoWBest/Character.lua"))("WoWBest", A)
Enum = { TooltipDataLineType = {None = 0, EquipSlot = 21, ItemName = 22, UsageRequirement = 43, FlavorText = 37} }
DPS_TEMPLATE = "(%.1f Schaden pro Sekunde)"
ARMOR_TEMPLATE = "%d Rüstung"
SHIELD_BLOCK_TEMPLATE = "%d Blocken"
ITEM_UNIQUE = "Einzigartig"
ITEM_UNIQUE_EQUIPPABLE = "Einzigartig anlegbar"
ITEM_UNIQUE_MULTIPLE = "Einzigartig (%d)"
RETRIEVING_ITEM_INFO = "Gegenstandsinformationen werden abgefragt"

local learned, item, liveStats, tip, allowed, requestCount, uniqueFamily, uniqueCount, unique = {}, {}, {}, {}, true, 0
function UnitClass() return "Schurke", "ROGUE", 4 end
function UnitRace() return "Mensch", "Human", 1 end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 20 end
function IsPlayerSpell(spell) return learned[spell] == true end
C_Item = {
    GetItemInfo = function(query)
        if item.cached == false then return nil end
        return item.name or "Test", item.link or "item:1", 2, 25, item.minLevel or 10, nil, nil, 1,
            item.loc, 1234, 1, item.class, item.sub, 2
    end,
    GetItemInfoInstant = function() return 1, nil, nil, item.loc, nil, item.class, item.sub end,
    GetItemStats = function(link) assert(link == (item.link or "item:1")); return liveStats end,
    GetItemUniqueness = function() return uniqueFamily, uniqueCount end,
    GetItemUniquenessByID = function() return unique end,
    RequestLoadItemDataByID = function(id) assert(id == 1); requestCount = requestCount + 1 end,
}
C_PlayerInfo = {CanUseItem = function(id) assert(id == 1); return allowed end}
C_TooltipInfo = {GetHyperlink = function() return {lines = tip} end}
local function read(row, player)
    return A.ReadCandidate(row or {id = 1}, player or A.GetPlayer())
end
local function status(expected)
    local x, s = read()
    assert(not x and s == expected, tostring(s))
end
local function valid()
    local x, s = read()
    assert(x and s == "ok", tostring(s))
    return x
end
local function line(kind, text, right)
    return {type = kind, leftText = text, rightText = right}
end
local name = line(22, "Test")
local slot = line(21, "Einhändig", "Axt")
tip = {name, slot, line(0, "(12,3 Schaden pro Sekunde)")}
item = {class = 2, sub = 0, loc = "INVTYPE_WEAPON"}
assert(A.GetPlayer().dual == false)
status("ineligible") -- rogue axes require training
learned[196] = true
assert(valid().stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT == 12.3)
learned[674] = true
assert(A.GetPlayer().dual == true)
item.loc = "INVTYPE_WEAPONOFFHAND"
assert(valid())
learned[674] = false
status("ineligible")
item.loc = "INVTYPE_WEAPON"
item.minLevel = 30
status("ineligible")
item.minLevel = 1
item.cached = false
local cachePlayer = A.GetPlayer()
for i = 1,2 do local _, why = read(nil, cachePlayer); assert(why == "pending") end
assert(requestCount == 1)
item.cached = true
assert(read(nil, cachePlayer))
item = {class = 4, sub = 3, loc = "INVTYPE_WRIST"}
status("ineligible") -- no mail
learned[8737] = true
assert(valid())
item = {class = 4, sub = 1, loc = "INVTYPE_CLOAK"}
assert(valid()) -- a cloak is not a cloth body armor skill check
item = {class = 4, sub = 0, loc = "INVTYPE_FINGER"}
allowed = false
status("ineligible") -- class/race/reputation gate even if no explicit equip proficiency
allowed = true
local bad = line(43, "Benötigt Ingenieurskunst")
bad.leftColor = {r = 1, g = .1, b = .1}
tip = {name, slot, bad}
status("ineligible")
slot.rightColor = {r = 1, g = .125, b = .125}
tip = {name, slot}
status("ineligible")
slot.rightColor = nil
tip = {name, slot, line(0, "|cffff2020Benötigt Ingenieurskunst|r")}
status("ineligible")
tip = {name}
status("pending") -- incomplete tooltips must not bypass red requirements
tip = {name, slot, line(0, "Einzigartig (2)")}
local x = valid()
assert(x.unique and x.uniqueLimit == 2 and x.itemLimit == 2)
uniqueFamily, uniqueCount = 1234, 1
x = valid()
assert(x.unique == "group:1234" and x.uniqueLimit == 1 and x.itemLimit == 2)
uniqueFamily, uniqueCount = nil, nil
unique = true
tip = {name, slot}
assert(valid().unique == true)
unique = false
liveStats = {ITEM_MOD_SPELL_POWER_SHORT = 20, ITEM_MOD_HIT_RATING_SHORT = 10}
x = assert(read({id = 1, choice = "q5", source = "Dungeon", foreverStats = "sp20 heal20 spFrost9 hit1 spellCrit2"}))
assert(x.source == "Dungeon" and x.choice == "q5")
assert(x.stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT == nil and x.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT == nil)
assert(x.stats.ITEM_MOD_FROST_SPELL_DAMAGE_SHORT == 9 and x.stats.HIT_PERCENT == nil and x.stats.CRIT_PERCENT == 2)
liveStats = {}
x = assert(read({id = 1, foreverStats = "sp10 heal29 dmin16 dmax24 speed2000"}))
assert(x.stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT == 10 and x.stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT == 29)
assert(x.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT == 10)
C_PlayerInfo.CanUseItem = nil
status("unverified")
print("Character checks passed.")
