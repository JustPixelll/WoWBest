-- Exercise the passive detector, item hydration, and live equipped comparison
-- together. Only the game API, saved preference and popup surface are simulated.
local A, now, enabled, combat, frame = {}, 0, true, false
local function loadModule(file) assert(loadfile("WoWBest/"..file..".lua"))("WoWBest", A) end
function CreateFrame()
    frame = {events = {}}
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, fn) self[event] = fn end
    return frame
end
function GetTime() return now end
function InCombatLockdown() return combat end
function UnitLevel() return 19 end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return "Alliance" end
function IsPlayerSpell(id) return id == 201 or id == 202 or id == 9116 end
NUM_BAG_SLOTS = 0
local variants = {
    ["item:990001"] = 10, ["item:990002"] = 12, ["item:990003::::::-21"] = 15,
    ["item:990003::::::-22"] = 18, ["item:990004"] = 100,
    ["item:990005"] = 1, ["item:990006"] = 20, ["item:990007"] = 2,
    ["item:990010"] = 20, ["item:990011"] = 12, ["item:990012"] = 15, ["item:990015"] = 20,
}
local bag, equipped, cold, requested, reads, alerts, hides = {}, {}, {}, {}, 0, {}, 0
function GetInventoryItemID(_, slot) return equipped[slot] and tonumber(equipped[slot]:match("%d+")) end
function GetInventoryItemLink(_, slot)
    local link = equipped[slot]
    if link and not cold[link] then return link end
end
C_Container = {
    GetContainerNumSlots = function() return 40 end,
    GetContainerItemInfo = function(_, slot)
        local link = bag[slot]
        if link then
            local id = tonumber(link:match("%d+"))
            return {itemID = id, hyperlink = not cold[link] and link or nil}
        end
    end,
}
local types = {
    ["item:990005"] = {"INVTYPE_HEAD", 4, 1}, ["item:990007"] = {"INVTYPE_NECK", 4, 0},
    ["item:990010"] = {"INVTYPE_2HWEAPON", 2, 8}, ["item:990011"] = {"INVTYPE_WEAPON", 2, 7},
    ["item:990012"] = {"INVTYPE_SHIELD", 4, 6},
}
local function itemType(link)
    local it = types[link]
    if it then return unpack(it) end
    return "INVTYPE_FINGER", 4, 0
end
C_Item = {
    RequestLoadItemDataByID = function(id) requested[id] = (requested[id] or 0) + 1 end,
    GetItemInfoInstant = function(link)
        local loc, cls, sub = itemType(link)
        return tonumber(link:match("%d+")), nil, nil, loc, nil, cls, sub
    end,
    GetItemInfo = function(link)
        local loc, cls, sub = itemType(link)
        return "Item", link, 2, 19, 1, nil, nil, 1, loc, nil, nil, cls, sub
    end,
    GetItemStats = function(link)
        reads = reads + 1
        return {ITEM_MOD_STRENGTH_SHORT = assert(variants[link],link)}
    end,
}
local blocked = {[990004] = true}
C_PlayerInfo = {CanUseItem = function(id) return not blocked[id] end}
C_TooltipInfo = {GetHyperlink = function() return {lines = {{leftText="Ring"}, {leftText="Finger"}}} end}
Enum = {TooltipDataLineType = {None = 0}}
for _, file in ipairs({"Profiles","Effects","SetData","SetBonuses","Engine","Character","Upgrade","BagCombinations","BagUpgrades"}) do
    loadModule(file)
end
function A.ActiveProfile(player)
    assert(player and player.class == "WARRIOR")
    return A.Profiles.WARRIOR[1]
end
function A.BagAlertsEnabled() return enabled end
function A.ShowBagUpgrade(alert) alerts[#alerts + 1] = alert end
function A.HideBagUpgrade() hides = hides + 1 end
local function event(e, ...) assert(frame.events[e]); frame:OnEvent(e, ...) end
local function advance(frames)
    for _ = 1, frames do
        now = now + .1
        if frame.OnUpdate then frame:OnUpdate() end
    end
end
local record = "item:990003::::::-22"
bag = {"item:990002", "item:990003::::::-21", "item:990004", record, record}
equipped[11], equipped[12] = "item:990001","item:990002"
cold[record], cold[equipped[11]] = true, true
event("PLAYER_ENTERING_WORLD"); advance(15)
assert(#alerts == 0 and requested[990001] == 1)
cold[equipped[11]] = nil
advance(13)
assert(#alerts == 0 and requested[990003] == 1)
cold[record] = nil
advance(15)
assert(#alerts == 1 and alerts[1].key == record and alerts[1].count == 3)
assert(alerts[1].result.delta == 8 and alerts[1].result.slot == 11)
-- An unrelated event or bag reshuffle does not announce the same upgrade again.
bag[1], bag[5] = bag[5], bag[1]
event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 1 and not frame.OnUpdate)
A.DismissBagUpgrade(alerts[1]); assert(hides == 1)
event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 1)
-- Remove or equip the winning item to discover the next best physical copy.
bag = {"item:990003::::::-21", "item:990004"}
equipped[11] = record
event("PLAYER_EQUIPMENT_CHANGED"); advance(15)
assert(#alerts == 2 and alerts[2].result.delta == 3 and alerts[2].result.slot == 12)
-- Unrelated equipment changes while suspended never read bag/character data.
combat = true
event("PLAYER_REGEN_DISABLED")
local before = reads
event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 2 and reads == before and not frame.OnUpdate)
combat = false; enabled = false; event("PLAYER_REGEN_ENABLED"); advance(15)
assert(#alerts == 2 and reads == before and not frame.OnUpdate)
-- An item filling a zero-score / empty baseline still has a positive point delta.
equipped, bag = {}, {record}
enabled = true; A.RefreshBagUpgrades(); advance(15)
assert(#alerts == 3 and alerts[3].result.percent == nil and alerts[3].result.delta == 18)
-- Removing a reported item clears its dedup marker, also after an empty scan.
bag = {}; event("BAG_UPDATE_DELAYED"); advance(15)
bag = {record}; event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 4)
-- The old +18 ring in the bag cannot mask weaker *new* improvements.
local head, neck, stronger = "item:990005", "item:990007", "item:990006"
bag = {record, head, neck}; event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 5 and alerts[5].key == neck and alerts[5].count == 2)
bag = {head, neck, record}; event("BAG_UPDATE_DELAYED"); advance(15)
assert(#alerts == 5)
-- Temporarily ineligible, then usable again with precisely the original gain.
blocked[990005] = true; event("SPELLS_CHANGED"); advance(15)
blocked[990005] = nil; event("SPELLS_CHANGED"); advance(15)
assert(#alerts == 6 and alerts[6].key == head and alerts[6].count == 1)
-- A cold new primary is hydrated before picking the strongest fresh offer.
bag = {record, head, neck, stronger}; cold[stronger] = true
event("BAG_UPDATE_DELAYED"); advance(20)
assert(#alerts == 6 and requested[990006] == 1)
cold[stronger] = nil; advance(15)
assert(#alerts == 7 and alerts[7].key == stronger and alerts[7].count == 1)
-- Opting back in deliberately checks the present bags, even if the gear stayed put.
enabled = false; A.RefreshBagUpgrades(); advance(10)
enabled = true; A.RefreshBagUpgrades(); advance(15)
assert(#alerts == 8 and alerts[8].key == stronger and alerts[8].count == 4)
-- A late cache fill wakes an otherwise idle reader only for the requested ID.
bag = {}; event("BAG_UPDATE_DELAYED"); advance(15)
bag = {stronger}; cold[stronger] = true; event("BAG_UPDATE_DELAYED"); advance(115)
assert(#alerts == 8 and not frame.OnUpdate)
event("GET_ITEM_INFO_RECEIVED", 990111, true); assert(not frame.OnUpdate)
cold[stronger] = nil; event("GET_ITEM_INFO_RECEIVED", 990006, true); advance(15)
assert(#alerts == 9 and alerts[9].key == stronger)
-- A new sword and shield that individually cannot beat the equipped two-hander
-- must appear together, with the two actual bag locations and one joint score.
local twoHand, sword, shield = "item:990010", "item:990011", "item:990012"
equipped, bag = {[16] = twoHand}, {shield, sword}
event("PLAYER_EQUIPMENT_CHANGED"); advance(40)
local joint = alerts[10]
assert(#alerts == 10 and joint.count == 1 and joint.result.delta == 7)
assert(#joint.parts == 2 and joint.parts[1].key == sword and joint.parts[1].slot == 16)
assert(joint.parts[2].key == shield and joint.parts[2].slot == 17)
bag = {sword, shield}; event("BAG_UPDATE_DELAYED"); advance(40)
assert(#alerts == 10)
bag = {sword, shield, head}; event("BAG_UPDATE_DELAYED"); advance(40)
assert(#alerts == 11 and alerts[11].key == head and alerts[11].count == 1)
bag = {sword, head}; event("BAG_UPDATE_DELAYED"); advance(40)
assert(#alerts == 11)
-- Equal gains pick the same representative regardless of bag-slot order.
equipped, bag = {}, {"item:990015", stronger}; event("PLAYER_EQUIPMENT_CHANGED"); advance(20)
assert(#alerts == 12 and alerts[12].key == stronger and alerts[12].count == 2)
bag = {stronger, "item:990015"}; event("BAG_UPDATE_DELAYED"); advance(20)
assert(#alerts == 12)
print("Bag-upgrade checks passed: exact variants, fresh batches, delayed caches, eligibility, and legal joint swaps.")
