-- Run from the repository root using Lua 5.1.
local A = {}
local emit, changes, now = nil, 0, 20
function CreateFrame()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, handler) emit = function(...) handler(nil, ...) end end,
    }
end
function GetTime() return now end
function A.MarketChanged() changes = changes + 1 end
C_Item = { GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, id == 9 and 7 or 4 end }
local rows = {}
C_AuctionHouse = {
    GetNumItemSearchResults = function() return #rows end,
    GetItemSearchResultInfo = function(_, i) return rows[i] end,
}
assert(loadfile("WoWBest/Market.lua"))("WoWBest", A)
local function listing(auctionID)
    return { auctionID = auctionID, quantity = 1, itemLink = "|cff00ff00|Hitem:1::::::98|h[Sky Ring]|h|r",
        buyoutAmount = 10203, containsOwnerItem = false, containsAccountItem = false }
end
local key = {itemID = 1, itemSuffix = 98}
rows = {listing(22)}
emit("ITEM_SEARCH_RESULTS_UPDATED", key)
assert(#A.MarketRoutes() == 0)
emit("AUCTION_HOUSE_SHOW")
for i = 2, 9 do rows[i] = listing(i) end
rows[2].containsOwnerItem = true
rows[3].containsAccountItem = true
rows[4].itemLink = nil
rows[5].buyoutAmount = nil
rows[6].buyoutAmount = 0
rows[7].timeLeftSeconds = 0
rows[8].quantity = 0
rows[9].itemLink = "item:2"
emit("ITEM_SEARCH_RESULTS_UPDATED", key)
local first = A.MarketRoutes()
assert(#first == 1 and first[1].id == 1 and first[1].link == rows[1].itemLink)
assert(first[1].routeKey == "auction:22" and first[1].maxCopies == 1)
assert(first[1].source:find("1g 2s 3c", 1, true))
local second = {itemID = 1, itemSuffix = 99}
local cheap = listing(26)
cheap.itemLink, cheap.buyoutAmount, cheap.timeLeftSeconds = "item:1::::::99", 300, 15
rows = {cheap}
emit("ITEM_SEARCH_RESULTS_ADDED", second)
assert(#A.MarketRoutes() == 2 and A.MarketRoutes()[1].auctionID == 26)
-- Omitted auctions disappear on re-querying the same item key, and unrelated
-- searches never inflate copies. Purchased listings can't return in a late event.
rows = {}
emit("ITEM_SEARCH_RESULTS_UPDATED", key)
assert(#A.MarketRoutes() == 1)
now = 36
assert(#A.MarketRoutes() == 0)
rows = {listing(22)}
emit("ITEM_SEARCH_RESULTS_UPDATED", key)
emit("AUCTION_HOUSE_PURCHASE_COMPLETED", 22)
emit("ITEM_SEARCH_RESULTS_ADDED", key)
assert(#A.MarketRoutes() == 0)
emit("AUCTION_HOUSE_CLOSED")
emit("AUCTION_HOUSE_SHOW")
emit("ITEM_SEARCH_RESULTS_UPDATED", key)
assert(#A.MarketRoutes() == 1)
emit("AUCTION_HOUSE_CLOSED")
assert(#A.MarketRoutes() == 0 and changes >= 4)
print("Market tests passed.")
