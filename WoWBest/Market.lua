local _, A = ...

-- Only detailed gear listings from the current auctioneer visit. Browse rows
-- combine variants and owners and cannot establish which copies can be bought.
local open = false
local snapshots, removed = {}, {}

local function keyFor(key)
    return table.concat({ key.itemID, key.itemLevel or 0, key.itemSuffix or 0, key.battlePetSpeciesID or 0 }, ":")
end

local function coin(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor(copper / 100) % 100
    local c = copper % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, c) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end

local function changed()
    if A.MarketChanged then A.MarketChanged() end
end

local function refresh(key)
    if not (open and key and key.itemID and C_AuctionHouse and C_Item and C_Item.GetItemInfoInstant
        and C_AuctionHouse.GetNumItemSearchResults and C_AuctionHouse.GetItemSearchResultInfo) then return end
    local tag = keyFor(key)
    local classID = select(6, C_Item.GetItemInfoInstant(key.itemID))
    if classID ~= 2 and classID ~= 4 then return end
    local before, listings = snapshots[tag], {}
    for index = 1, C_AuctionHouse.GetNumItemSearchResults(key) do
        local entry = C_AuctionHouse.GetItemSearchResultInfo(key, index)
        if entry and entry.auctionID and not removed[entry.auctionID] and entry.buyoutAmount and entry.buyoutAmount > 0
            and entry.itemLink and tonumber(entry.itemLink:match("item:(%d+)")) == key.itemID
            and entry.containsOwnerItem == false and entry.containsAccountItem == false
            and entry.quantity and entry.quantity > 0 and (not entry.timeLeftSeconds or entry.timeLeftSeconds > 0) then
            local price = coin(entry.buyoutAmount)
            local expiry = entry.timeLeftSeconds and (GetTime() + entry.timeLeftSeconds)
            listings[entry.auctionID] = {
                id = key.itemID, link = entry.itemLink, kind = "Auction", maxCopies = entry.quantity,
                auctionID = entry.auctionID, buyout = entry.buyoutAmount, expires = expiry,
                routeKey = "auction:" .. entry.auctionID,
                source = "Auction House search · observed buyout " .. price ..
                    (entry.quantity > 1 and (" for " .. entry.quantity .. " copies") or ""),
            }
        end
    end
    if next(listings) then snapshots[tag] = listings else snapshots[tag] = nil end
    if before or snapshots[tag] then changed() end
end

function A.MarketRoutes()
    local routes, seen = {}, {}
    if open then
        local now = GetTime()
        for _, listings in pairs(snapshots) do
            for id, row in pairs(listings) do
                if not seen[id] and (not row.expires or row.expires > now) then
                    seen[id] = true
                    routes[#routes + 1] = row
                end
            end
        end
        table.sort(routes, function(a, b)
            if a.buyout ~= b.buyout then return a.buyout < b.buyout end
            return a.auctionID < b.auctionID
        end)
    end
    return routes
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_CLOSED" or
        event == "AUCTION_HOUSE_DISABLED" or event == "PLAYER_LEAVING_WORLD" then
        local hadGear = next(snapshots) ~= nil
        open, snapshots, removed = event == "AUCTION_HOUSE_SHOW", {}, {}
        if hadGear then changed() end
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_ADDED" then
        refresh(arg)
    elseif open and arg then
        removed[arg] = true
        local lost
        for _, listings in pairs(snapshots) do
            if listings[arg] then listings[arg], lost = nil, true end
        end
        if lost then changed() end
    end
end)
for _, event in ipairs({
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_DISABLED", "PLAYER_LEAVING_WORLD",
    "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTIONS_EXPIRED",
}) do
    events:RegisterEvent(event)
end
