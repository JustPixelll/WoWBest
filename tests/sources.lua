-- Run from the repository root. Exercise the source choices through the real
-- planner/solver, including bag/equipment enumeration and a live market event.
local A = {}
local function loadAddon(file)
    assert(loadfile("WoWBest/" .. file .. ".lua"))("WoWBest", A)
end
local expected = {"Dungeon", "Quest", "Crafted", "Drop", "Vendor", "PvP", "Auction", "Event"}
WoWBestCharacterDB = {profile = "arms", targetType = "Humanoid"}
loadAddon("Sources")
local exposed = {}
for _, entry in ipairs(A.SourceMethods) do
    assert(type(entry.label) == "string" and #entry.label > 0 and not exposed[entry.key])
    exposed[entry.key] = true
end
for _, key in ipairs(expected) do assert(exposed[key] and A.SourceEnabled(key)) end
A.SetSourceEnabled("Dungeon", false)
loadAddon("Sources")
assert(not A.SourceEnabled("Dungeon"))
local saved = WoWBestCharacterDB
WoWBestCharacterDB = {profile = "holy"}
assert(A.SourceEnabled("Dungeon"))
A.SetSourceEnabled("Quest", false)
WoWBestCharacterDB = saved
assert(not A.SourceEnabled("Dungeon") and A.SourceEnabled("Quest"))
A.ResetSourceFilters()
assert(A.SourceEnabled("Dungeon") and saved.profile == "arms" and saved.targetType == "Humanoid")

local now, frames = 0, {}
function GetTime() return now end
function CreateFrame()
    local f = {events = {}}
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(key, fn) self[key] = fn end
    frames[#frames + 1] = f
    return f
end
local function fire(event, ...)
    for _, f in ipairs(frames) do if f.events[event] then f:OnEvent(event, ...) end end
end
local function settle()
    for _ = 1, 100 do
        local running = false
        now = now + .05
        for _, f in ipairs(frames) do
            if f.OnUpdate then running = true; f:OnUpdate(.05) end
        end
        if not running then return end
    end
    error("planner did not settle")
end

local facts = {
    [1] = {"2HWEAPON", 20, 2}, [2] = {"WEAPONMAINHAND", 6, 2},
    [3] = {"SHIELD", 4, 4}, [4] = {"HEAD", 1, 4}, [5] = {"CHEST", 1, 4},
    [6] = {"WRIST", 1, 4}, [7] = {"LEGS", 1, 4}, [8] = {"SHOULDER", 1, 4},
    [9] = {"FEET", 1, 4},
}
local reads = {}
loadAddon("Character")
-- Preserve the real planning checks; replace only character and item hydration.
function A.ReadCandidate(row)
    local f = assert(facts[row.id])
    reads[row.id] = (reads[row.id] or 0) + 1
    return {id = row.id, classID = f[3], loc = "INVTYPE_" .. f[1],
        stats = {ITEM_MOD_STRENGTH_SHORT = f[2]}}, "ok"
end
function A.GetPlayer() return {class = "WARRIOR", classID = 1, level = 19, dual = false} end
function A.ActiveProfile() return {key = "arms", strength = 1} end
function A.IsVisible() return true end
function A.UpdateStatus() end
function A.UpdateDisplay(loadout) A.latest = loadout end
-- No trained profession. Material facts come from the generated catalog;
-- the real gate classifies the head as an unlock and not an equipped item.
C_SkillInfo = {GetSkillLineInfoByID = function() return nil end}
C_QuestLog = {IsQuestFlaggedCompleted = function() return false end}
function GetInventoryItemLink(_, slot) if slot == 16 then return "item:2" end end
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and 1 or 0 end,
    GetContainerItemInfo = function() return {hyperlink = "item:3", stackCount = 1} end,
}
C_Item = {GetItemInfoInstant = function(id) return id, nil, nil, nil, nil, facts[id][3] end}
C_AuctionHouse = {
    GetNumItemSearchResults = function() return 1 end,
    GetItemSearchResultInfo = function()
        return {auctionID = 90, quantity = 1, buyoutAmount = 10, itemLink = "item:7",
            containsOwnerItem = false, containsAccountItem = false}
    end,
}
loadAddon("Gates")
loadAddon("Engine")
loadAddon("Market")
loadAddon("Planner")
A.Catalog = {
    {id = 1, kind = "Dungeon", source = "Dungeon boss"},
    {id = 1, kind = "Vendor", source = "Town merchant"},
    {id = 4, kind = "Crafted", source = "Crafted goggles", name = "Goggles", classID = 4,
        subclassID = 1, invType = 1, professionID = 202, professionRank = 100},
    {id = 5, kind = "Quest", questID = 35, requiresDungeon = true, source = "Dungeon quest"},
    {id = 6, kind = "Quest", questID = 36, eventName = "Festival", source = "Festival quest"},
    {id = 8, kind = "Drop", source = "World creature"},
    {id = 9, kind = "Quest", questID = 39, requiresPvP = true, source = "PvP quest"},
}
local function scan()
    reads = {}
    A.StartScan(A.ActiveProfile())
    settle()
    assert(A.latest and A.latest[16], "no weapon result")
    return A.latest
end
local function headPaths()
    local paths
    A.RequestSlot(1, function(rows, _, _, options) if rows then paths = options end end)
    settle()
    return assert(paths)
end
fire("AUCTION_HOUSE_SHOW")
fire("ITEM_SEARCH_RESULTS_UPDATED", {itemID = 7})
local result = scan()
assert(result[16].id == 1 and result[17] == nil and #result[16].sources == 2)
assert(result[5].id == 5 and result[9].id == 6 and result[7].id == 7 and result[8].id == 9)
assert(result[3].id == 8 and not result[1] and headPaths()[1].id == 4)

for _, key in ipairs({"Dungeon", "Event", "PvP", "Crafted", "Auction"}) do A.SetSourceEnabled(key, false) end
result = scan()
assert(result[16].id == 1 and result[16].source == "Town merchant")
assert(#result[16].sources == 1 and result[16].sources[1] == "Town merchant")
assert(not result[17] and not result[5] and not result[9] and not result[7] and not result[8])
assert(not reads[5] and not reads[6] and not reads[7] and not reads[9] and #headPaths() == 0)
assert(result[3].id == 8)
local slots
A.RequestSlot(16, function(rows) if rows then slots = rows end end)
settle()
assert(slots[1].item.source == "Town merchant" and #slots[1].item.sources == 1)

A.ResetSourceFilters()
A.SetSourceEnabled("Quest", false)
result = scan()
assert(not result[5] and not result[8] and not result[9])
assert(result[7].id == 7 and headPaths()[1].id == 4)
for _, key in ipairs(expected) do A.SetSourceEnabled(key, false) end
A.SetSourceEnabled("Owned", false)
result = scan()
assert(A.SourceEnabled("Owned") and result[16].id == 2 and result[17].id == 3)
assert(result[16].source == "Currently equipped" and result[17].source == "In your bags")
assert(#headPaths() == 0)
for id in pairs(reads) do assert(id == 2 or id == 3, "hydrated an excluded route") end
A.ResetSourceFilters()
fire("AUCTION_HOUSE_CLOSED")
result = scan()
assert(not result[7] and result[16].id == 1 and not result[17])
local rumored = {id = 8, kind = "Drop", source = "Unconfirmed source", unconfirmed = true}
table.insert(A.Catalog, 1, rumored)
assert(not A.RouteSourceEnabled(rumored))
A.SetUnconfirmedSourcesEnabled(true)
assert(A.RouteSourceEnabled(rumored))
result = scan()
assert(result[3].source:match("^World creature") and #result[3].sources == 2)
A.SetSourceEnabled("Drop", false)
assert(not A.RouteSourceEnabled(rumored))
A.SetUnconfirmedSourcesEnabled(false)
assert(not A.UnconfirmedSourcesEnabled())
-- One craftable ring may appear only once. Craftability changes on a new
-- character snapshot and the packaged source record must remain reusable.
facts[10] = {"FINGER", 8, 4}
local personal = {id=10, kind="Crafted", source="Personal craft", requiresKnownCraft=true,
    requiresCraftable=true, craftSpellID=110}
A.Catalog = {personal}
local count = 1
C_TradeSkillUI = {GetRecipeInfo=function() return {learned=true} end,
    GetCraftableCount=function() return count end}
result = scan()
assert(result[11].id == 10 and not result[12] and not personal.maxCopies)
count = 2
result = scan()
assert(result[11].id == 10 and result[12].id == 10)
-- The open PvP shop can supply a genuinely new item. Source settings also
-- control these live rows.
facts[11] = {"HEAD", 10, 4}
local readPvPShop = 0
function A.OpenPvPVendorRoutes()
    readPvPShop = readPvPShop + 1
    return {{id=11, kind="PvP", source="Open quartermaster", maxCopies=1}}
end
result = scan()
assert(result[1].id == 11 and readPvPShop == 1)
A.SetSourceEnabled("PvP", false)
result = scan()
assert(not result[1] and readPvPShop == 1)
print("Acquisition source filter and loadout tests passed")
