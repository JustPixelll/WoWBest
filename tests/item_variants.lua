-- Run from the repository root with Lua 5.1.
local A = {Catalog = {{id = 20, foreverStats = "armor50"}}}
assert(loadfile("WoWBest/Character.lua"))("WoWBest", A)
local function display(value, name)
    return "|cff0070dd|H" .. value .. "|h[" .. name .. "]|h|r"
end
local raw = "item:20:17:::::-21:675982:19:::1:23"
local full = display(raw, "Prospector's Ring of the Bear")
local enchantless = raw:gsub(":17:", "::", 1)
local differentSeed = raw:gsub("675982", "675983")
assert(A.ItemVariantKey(full) == raw and A.ItemVariantKey(display(raw, "Ring des Bären")) == raw)
assert(A.ItemVariantKey(differentSeed) ~= raw and A.ItemVariantKey(enchantless) ~= raw)
assert(not A.ItemVariantKey("|Hspell:20|h[Test]|h") and not A.ItemVariantKey("item:20suffix"))
assert(not A.ItemVariantKey("item:0") and not A.ItemVariantKey(nil))
assert(A.GetItemSupplement(20) == "armor50" and A.GetItemSupplement(999) == nil)

local gotStats, gotTip, gotUnique, requests = nil, nil, nil, 0
local liveStats = {ITEM_MOD_STAMINA_SHORT = 4}
local tip = {lines = {{leftText = "Prospector's Ring"}, {leftText = "Finger"}}}
local cached = true
C_Item = {
    GetItemInfo = function()
        if cached then return "Prospector's Ring", display("item:20", "Prospector's Ring"), 2, 20, 15, nil, nil, 1,
            "INVTYPE_FINGER", nil, nil, 4, 0 end
    end,
    GetItemStats = function(link) gotStats = link; return liveStats end,
    GetItemUniquenessByID = function(link) gotUnique = link; return false end,
    RequestLoadItemDataByID = function(id) assert(id == 20); requests = requests + 1 end,
}
C_PlayerInfo = {CanUseItem = function(id) return id == 20 end}
C_TooltipInfo = {GetHyperlink = function(link) gotTip = link; return tip end}
local player = {level = 19}
local function read() return A.ReadCandidate({id = 20, link = full}, player, A.GetItemSupplement(20)) end
local item = assert(read())
assert(gotStats == full and gotTip == full and gotUnique == full and item.link == full)
assert(item.stats.ITEM_MOD_STAMINA_SHORT == 4 and item.stats.RESISTANCE0_NAME == 50)
local _, reason = A.ReadCandidate({id = 21, link = full}, player)
assert(reason == "unverified") -- recipe/gear ID mismatch
cached = false
for i = 1, 3 do _, reason = read(); assert(reason == "pending") end
assert(requests == 1)
cached = true

local protected = {}
issecretvalue = function(v) return rawequal(v, protected) end
assert(not A.ItemVariantKey(protected))
liveStats = {ITEM_MOD_STAMINA_SHORT = protected}
_, reason = read()
assert(reason == "unverified")
liveStats = {}
tip.lines[2].rightColor = {r = protected, g = 0, b = 0}
_, reason = read()
assert(reason == "unverified")
tip.lines[2].rightColor, tip.lines[2].leftText = nil, protected
_, reason = read()
assert(reason == "unverified")
-- A fishing pole physically worn by the player must not prevent a comparison
-- of the player's other gear. Rankability and equipped baseline are separate.
issecretvalue = nil
tip = {lines = {{leftText = "Fishing Pole"}, {leftText = "Two-Hand"}}}
C_Item.GetItemInfo = function() return "Pole", "item:20", 1, 5, 1, nil, nil, 1, "INVTYPE_2HWEAPON", nil, nil, 2, 20 end
local row = {id = 20, link = "item:20"}
_, reason = A.ReadCandidate(row, player)
assert(reason == "ineligible")
assert(A.ReadEquippedItem(row, player).loc == "INVTYPE_2HWEAPON")
tip.lines[2].leftColor = {r=1, g=0, b=0}
assert(A.ReadEquippedItem(row, player) == nil)
-- An inaccessible table is guarded before reading any contained fields.
tip.lines[2].leftColor = nil
canaccesstable = function(t) return t ~= tip.lines end
_, reason = A.ReadEquippedItem(row, player)
assert(reason == "unverified")
print("Exact tooltip variants, equipped eligibility, hidden information and cold-cache checks passed.")
