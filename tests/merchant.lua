local A = {}
assert(loadfile("WoWBest/Gates.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Sources.lua"))("WoWBest", A)
local row = {id = 19491, kind = "Vendor", eventVendorID = 14828, eventName = "Darkmoon Faire",
             requiredCurrencyID = 515, requiredCurrencyAmount = 1200}
local function allowed(player)
    return A.RouteSourceEnabled(row) and A.RouteAvailable(row, player or {})
end

assert(not allowed())
local npc, merchantOpen, tickets = 14828, true, 1200
local stock = {{numAvailable = -1, isPurchasable = true}}
local item = 19491
UnitGUID = function(unit)
    assert(unit == "npc")
    return "Creature-0-4457-1-11234-" .. npc .. "-0000AABBCC"
end
MerchantFrame = {IsShown = function() return merchantOpen end}
GetMerchantNumItems = function() return #stock end
GetMerchantItemLink = function(index) return "|Hitem:" .. item .. ":0|h[Example]|h" end
C_MerchantFrame = {GetItemInfo = function(index) return stock[index] end}
C_CurrencyInfo = {GetCurrencyInfo = function(id)
    assert(id == 515)
    return {quantity = tickets}
end}
assert(allowed())
npc = 14829
assert(not allowed())
npc, merchantOpen = 14828, false
assert(not allowed())
merchantOpen, tickets = true, 1199
assert(not allowed())
tickets, stock[1].numAvailable = 1200, 0
assert(not allowed())
stock[1].numAvailable, stock[1].isPurchasable = 1, false
assert(not allowed())
stock[1].isPurchasable, item = true, 19426
assert(not allowed())
item = 19491
local reads = 0
GetMerchantItemID = function(index) reads = reads + 1; return item end
local player = {}
assert(allowed(player) and allowed(player) and reads == 1)
for _, category in ipairs({"Event", "Vendor"}) do
    A.SetSourceEnabled(category, false)
    assert(not allowed())
    A.SetSourceEnabled(category, true)
    assert(allowed())
end
Enum = {PlayerInteractionType = {Merchant = 5}}
C_PlayerInteractionManager = {IsInteractingWithNpcOfType = function(kind)
    assert(kind == 5)
    return false
end}
assert(not allowed()) -- a visible old frame cannot override the live interaction
print("Event merchant tests passed.")

-- Outdoor Warsong and Alterac supply shops. Validate current buy-list gear,
-- current gold/currency costs, and the merchant-specific requirement tooltip.
assert(loadfile("WoWBest/Character.lua"))("WoWBest", A)
local side, gold, rgblines, itemClass = "Alliance", 10000, nil, 4
npc, merchantOpen, item = 14753, true, 200
UnitFactionGroup = function() return side end
C_PlayerInteractionManager.IsInteractingWithNpcOfType = function() return merchantOpen end
GetMoney = function() return gold end
GetMerchantItemLink = function(index) return "|Hitem:" .. item .. ":0:77|h[Example]|h" end
C_Item = {GetItemInfoInstant = function(link) return item, "Armor", "Misc", "INVTYPE_FINGER", 1, itemClass, 0 end}
C_TooltipInfo = {GetMerchantItem = function() return {lines = rgblines or {{leftText = "Example"}, {leftText = "Finger"}}} end}
local costCount, costAmount, costLink, costName = 0, 10, "|Hcurrency:515|h[Tickets]|h", "Tickets"
GetMerchantItemCostInfo = function() return costCount end
GetMerchantItemCostItem = function() return 123, costAmount, costLink, costName end
local rowInfo = {isPurchasable = true, isUsable = true, numAvailable = -1, stackCount = 1, price = 6000, hasExtendedCost = false}
stock = {rowInfo}
local function rows() return A.OpenPvPVendorRoutes() end
assert(#rows() == 1 and rows()[1].maxCopies == 1 and rows()[1].kind == "PvP")
assert(rows()[1].link:find(":0:77", 1, true) and rows()[1].source:find("Illiyana", 1, true))
CanAffordMerchantItem = function() return false end
assert(#rows() == 0)
CanAffordMerchantItem = function() return true end
gold = 14000
assert(rows()[1].maxCopies == 2)
stock[2] = rowInfo
assert(#rows() == 1) -- repeated tabs/pages cannot create unbounded stock
stock[2] = nil
rowInfo.numAvailable = 1
assert(rows()[1].maxCopies == 1)
rowInfo.numAvailable = 0
assert(#rows() == 0)
rowInfo.numAvailable, rowInfo.isUsable = -1, false
assert(#rows() == 0)
rowInfo.isUsable, gold = true, 5999
assert(#rows() == 0)
gold, tickets, costCount, rowInfo.hasExtendedCost = 14000, 9, 1, true
assert(#rows() == 0)
tickets = 10
assert(rows()[1].maxCopies == 1 and rows()[1].source:find("10 Tickets", 1, true))
costLink = "|Hitem:20558|h[Marks]|h"
assert(#rows() == 0) -- cannot promise a barter trade that might consume a selected item
costCount = 0
assert(#rows() == 0) -- extended cost data has not loaded
rowInfo.hasExtendedCost = false
rgblines = {{leftText = "Example"}, {leftText = "Requires reputation", leftColor = {r = 1, g = 0.1, b = 0.1}}}
assert(#rows() == 0)
rgblines = {}
assert(#rows() == 0)
rgblines, side = nil, "Horde"
assert(#rows() == 0)
npc = 14754
assert(rows()[1].source:find("Kelm Hargunth", 1, true))
npc = 13219
assert(rows()[1].source:find("Jekyll Flandring", 1, true))
npc, side = 13217, "Alliance"
assert(rows()[1].source:find("Thanthaldis Snowgleam", 1, true))
npc = 14828
assert(#rows() == 0)
npc, itemClass = 13217, 0
assert(#rows() == 0)
itemClass, merchantOpen = 4, false
assert(#rows() == 0)
print("Live PvP merchant tests passed.")
