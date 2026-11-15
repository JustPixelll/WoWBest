-- Run from the repository root using Lua 5.1.
local A, post, signal = {}, nil, nil
local timers, reads, comparisons, sets, combat = {}, 0, 0, 0, false
local secret = {}
function issecretvalue(value) return value == secret end
function canaccesstable(t) return t ~= secret end
function InCombatLockdown() return combat end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
local function drain()
    local runs = 0
    while #timers > 0 do
        runs = runs + 1
        assert(runs < 50, "timer loop")
        table.remove(timers, 1)()
    end
end
Enum = {TooltipDataType = {Item = 0}}
TooltipDataProcessor = {AddTooltipPostCall = function(_, callback) post = callback end}
function CreateFrame()
    return {RegisterEvent = function() end, SetScript = function(_, _, fn) signal = fn end}
end
local function tooltip(name)
    local tip = {shown = true, lines = {}, hooks = {}}
    function tip:AddLine(message)
        local n = #self.lines + 1
        self.lines[n] = message
        if name then _G[name .. "TextLeft" .. n] = {
            GetText = function() return self.lines[n] end,
            SetText = function(_, value) self.lines[n] = value end,
        } end
    end
    function tip:GetName() return name end
    function tip:NumLines() return #self.lines end
    function tip:IsForbidden() return self.forbidden end
    function tip:IsProtected() return self.protected end
    function tip:GetPrimaryTooltipData() return self.data end
    function tip:GetPrimaryTooltipInfo() return self.info end
    function tip:IsShown() return self.shown end
    function tip:Show() self.shown = true end
    function tip:HookScript(name, fn) self.hooks[name] = fn end
    function tip:clear() self.lines = {}; if self.hooks.OnTooltipCleared then self.hooks.OnTooltipCleared(self) end end
    function tip:RebuildFromTooltipInfo() self:clear(); post(self, self.data) end
    function tip:inspect(id, getter, variant, unit, slot, guid)
        self:clear()
        self.shown = true
        self.info = {getterName = getter, getterArgs = {unit, slot}}
        self.data = {id = id, hyperlink = variant, guid = guid}
        post(self, self.data)
    end
    return tip
end
GameTooltip, ItemRefTooltip, ShoppingTooltip1 = tooltip("GameTooltip"), tooltip("ItemRefTooltip"), tooltip("ShoppingTooltip1")
local links = {[1] = "|Hitem:1::::::99|h[Ring of the Bear]|h", [2] = "|Hitem:2|h[New ring]|h"}
C_Item = {
    GetItemInfoInstant = function(link) assert(not combat); return 1, nil, nil, "INVTYPE_FINGER", nil, link == "item:77" and 15 or 4 end,
    GetItemLinkByGUID = function(guid) assert(not combat); return guid == "equipped" and links[1] end,
    GetItemLocation = function(guid) assert(not combat); return guid == "equipped" and {equipmentSlotIndex = 11} end,
}
local active = {key = "arms", name = "Arms"}
function A.ActiveProfile() assert(not combat); return active end
function A.GetPlayer() assert(not combat); return {level = 10} end
function A.GetItemSupplement() return nil end
function A.ItemVariantKey(link) return link:match("item:[^|]+") end
A.SlotNames = {[11] = "Ring 1", [12] = "Ring 2"}
local remaining, wornPending = 0, false
function A.ReadCandidate(record)
    reads = reads + 1
    if remaining > 0 then remaining = remaining - 1; return nil, "pending" end
    if record.id == 3 then return nil, "ineligible" end
    return record
end
function A.ReadEquippedForUpgrade()
    sets = sets + 1
    if wornPending then wornPending = false; return nil, "pending" end
    return {[11] = {id = 1, link = links[1]}}
end
local lastOrigin, lastLink
function A.CompareEquippedUpgrade(candidate, _, _, _, origin)
    comparisons, lastOrigin, lastLink = comparisons + 1, origin, candidate.link
    if origin then return {kind = "equipped", alreadyEquipped = true, slot = origin, swapBefore = 11} end
    if candidate.id == 4 or candidate.id == 8 then return {unmodeledEffect = candidate.id == 8, kind = "upgrade", slot = 12, delta = 4, changedSlots = {12}, swapBefore = 0, swapAfter = 4} end
    return {kind = "downgrade", slot = 11, delta = -8, percent = -4, changedSlots = {11}, swapBefore = 5, swapAfter = 6, slotPercent = 20}
end
assert(loadfile("WoWBest/Tooltip.lua"))("WoWBest", A)
assert(post and signal)

remaining, wornPending = 1, true
GameTooltip:inspect(1, "GetBagItem", links[1])
assert(comparisons == 0 and #GameTooltip.lines == 0)
drain()
assert(lastLink == links[1] and lastOrigin == nil and #GameTooltip.lines == 1)
local line = GameTooltip.lines[1]
assert(line:find("Downgrade", 1, true) and line:find("Equipped loadout: -4.0%", 1, true))
assert(line:find("Ring 1 item points: +20.0%", 1, true))
post(GameTooltip, GameTooltip.data)
assert(#GameTooltip.lines == 1)
GameTooltip:RebuildFromTooltipInfo()
assert(#GameTooltip.lines == 1 and comparisons == 1)
for _, getter in ipairs({"GetMerchantItem", "GetLootItem", "GetQuestItem", "GetHyperlink"}) do
    ItemRefTooltip:inspect(1, getter, links[1])
    assert(#ItemRefTooltip.lines == 1 and comparisons == 1)
end
local otherRoll = "|Hitem:1::::::101|h[Ring of the Owl]|h"
GameTooltip:inspect(1, "GetBagItem", otherRoll)
drain()
assert(lastLink == otherRoll and comparisons == 2)
-- The same link on a player paper-doll slot is physically worn. A side tooltip
-- without a concrete location may be a hypothetical hand partner.
GameTooltip:inspect(1, "GetInventoryItem", links[1], "player", 11); drain()
assert(lastOrigin == 11 and GameTooltip.lines[1]:find("Equipped (Ring 1)", 1, true))
ShoppingTooltip1:inspect(1, nil, nil, nil, nil, "equipped")
assert(ShoppingTooltip1.lines[1]:find("Equipped (Ring 1)", 1, true))
ShoppingTooltip1:inspect(1, nil, links[1]); drain()
assert(#ShoppingTooltip1.lines == 0)

-- Hover changes while the candidate loads, including recipe/result mismatch.
GameTooltip:inspect(2, "GetLootItem", links[2])
GameTooltip:inspect(3, "GetQuestItem", "item:3")
drain()
assert(lastLink ~= links[2] and #GameTooltip.lines == 1 and GameTooltip.lines[1]:find("Unavailable"))
for _, sample in ipairs({{5, links[1]}, {77, "item:77"}, {1, secret}}) do
    GameTooltip:inspect(sample[1], "GetMerchantItem", sample[2]); drain()
    assert(#GameTooltip.lines == 0)
end
GameTooltip:inspect(4, "GetLootItem", "item:4"); drain()
assert(GameTooltip.lines[1]:find("Empty ring 2", 1, true) and GameTooltip.lines[1]:find("(from 0)", 1, true))

-- Recompute still-visible tips on player/profile changes. Former requests and
-- cached annotations must not survive a changed outfit or a combat transition.
active = {key = "fury", name = "Fury", targetType = "Humanoid"}
local old = sets
signal(nil, "PLAYER_EQUIPMENT_CHANGED"); drain()
assert(sets == old + 1 and #GameTooltip.lines == 1 and GameTooltip.lines[1]:find("Fury (Humanoids)", 1, true))
GameTooltip:inspect(2, "GetLootItem", links[2])
ShoppingTooltip1:inspect(1, nil, nil, nil, nil, "equipped"); drain()
local priorReads = reads
combat = true
signal(nil, "PLAYER_REGEN_DISABLED"); drain()
-- Public precomputed comparisons survive entering combat. No item API,
-- unit/skill/profile queries or scoring is permitted on this path.
ShoppingTooltip1:inspect(1, nil, nil, nil, nil, "equipped")
assert(#ShoppingTooltip1.lines == 1 and ShoppingTooltip1.lines[1]:find("Equipped (Ring 1)", 1, true))
GameTooltip:inspect(4, "GetHyperlink", "item:4")
assert(#GameTooltip.lines == 1 and GameTooltip.lines[1]:find("Empty ring 2"))
GameTooltip:inspect(4, "GetHyperlink", "item:4::::::19"); drain()
assert(#GameTooltip.lines == 0 and reads == priorReads)
GameTooltip:inspect(4, "GetHyperlink", secret); drain(); assert(#GameTooltip.lines == 0)
GameTooltip.protected = true
GameTooltip:inspect(4, "GetHyperlink", "item:4"); drain(); assert(#GameTooltip.lines == 0)
GameTooltip.protected = false
GameTooltip:inspect(4, "GetHyperlink", "item:4")
signal(nil, "UNIT_INVENTORY_CHANGED", "pet"); assert(GameTooltip.lines[1] ~= "")
signal(nil, "PLAYER_EQUIPMENT_CHANGED")
assert(GameTooltip.lines[1] == "" and ShoppingTooltip1.lines[1] == "")
GameTooltip:inspect(4, "GetHyperlink", "item:4"); drain()
assert(#GameTooltip.lines == 0 and reads == priorReads)
-- An uncached item remains blank until combat ends even if its base ID matches.
GameTooltip:inspect(2, "GetLootItem", links[2]); drain()
assert(#GameTooltip.lines == 0 and reads == priorReads)
combat = false; signal(nil, "PLAYER_REGEN_ENABLED"); drain()
assert(#GameTooltip.lines == 1)
GameTooltip:inspect(44, "GetBagItem", "item:44")
GameTooltip.shown = false; GameTooltip.hooks.OnHide(); drain()
assert(#GameTooltip.lines == 0)
local scanned = tooltip()
scanned:inspect(3, "GetItemByID", "item:3"); drain()
assert(#scanned.lines == 0)
GameTooltip:inspect(8, "GetLootItem", "item:8"); drain()
assert(GameTooltip.lines[1]:find("Possible upgrade", 1, true))
assert(GameTooltip.lines[1]:find("effect in this swap has no score", 1, true))
assert(loadfile("WoWBest/Effects.lua"))("WoWBest", A)
local mushroomID, tidesID = 249396, 263411
function A.ReadEquippedForUpgrade()
    return {[18]={id=tidesID,link="item:"..tidesID}}
end
function A.CompareEquippedUpgrade(_, _, _, _, origin)
    if origin then return {alreadyEquipped=true, slot=18, swapBefore=0} end
    return {kind="neutral", slot=18, unmodeledEffect=true, changedSlots={18}, delta=0, swapBefore=0, swapAfter=0}
end
A.SlotNames[18] = "Relic"
signal(nil, "PLAYER_EQUIPMENT_CHANGED"); drain()
GameTooltip:inspect(mushroomID, "GetBagItem", "item:" .. mushroomID); drain()
assert(GameTooltip.lines[1]:find("Even on scored stats",1,true))
assert(GameTooltip.lines[1]:find(A.UnscoredEffectNotes[mushroomID],1,true))
assert(GameTooltip.lines[1]:find(A.UnscoredEffectNotes[tidesID],1,true))
GameTooltip:inspect(tidesID, "GetInventoryItem", "item:" .. tidesID, "player", 18); drain()
assert(GameTooltip.lines[1]:find("Equipped",1,true) and GameTooltip.lines[1]:find(A.UnscoredEffectNotes[tidesID],1,true))
print("Native tooltip cache, exact variants, equipped origins, percentages, invalidation and stale hover tests passed.")
