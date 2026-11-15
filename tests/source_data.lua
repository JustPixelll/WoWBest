-- Check the shipped source taxonomy on Lua 5.1 from the repository root.
local addon = {}
assert(loadfile("WoWBest/Catalog.lua"))("WoWBest", addon)

local function source(id, kind, questID)
    for _, row in ipairs(addon.Catalog) do
        if row.id == id and row.kind == kind and (not questID or row.questID == questID) then
            return row
        end
    end
    error(("No %s route for item %s / quest %s"):format(kind, id, tostring(questID)))
end

-- A town turn-in with an instance objective and a later reward in a dungeon chain.
assert(source(6087, "Quest", 166).requiresDungeon)
assert(source(15424, "Quest", 5730).requiresDungeon)
-- The same dungeon category also includes quests that players can finish outdoors.
assert(not source(1893, "Quest", 167).requiresDungeon)
assert(not source(2036, "Quest", 168).requiresDungeon)
assert(not source(4980, "Quest", 704).requiresDungeon)
assert(not source(6729, "Quest", 1137).requiresDungeon)
-- Alternative activities belong to each route independently.
assert(source(15136, "Dungeon").source:find("Razorfen Kraul", 1, true))
assert(not source(15136, "Drop").requiresDungeon)
assert(not source(4385, "Crafted").requiresDungeon)
assert(not source(20068, "PvP").requiresVendor)
assert(not source(272399, "Vendor").requiresDungeon)

-- A profession name in a recipe list cannot unlock unreleased reagents.
local reaper = source(12784, "Crafted")
assert(reaper.craftSpellID == 16994 and reaper.acquireProfessionID == 164 and reaper.acquireProfessionRank == 300)
assert(reaper.requiresKnownCraft and reaper.requiresCraftable)
assert(not source(4385, "Crafted").requiresCraftable)

-- A Riverglades reward with no verified quest offer can rank for an actual
-- quest holder. Raids and unverified battlegrounds are excluded from the snapshot.
assert(source(274948, "Quest", 95267).requiresQuestInLog)
assert(source(15860, "Quest", 4765).requiresDungeon)
local possible, world, dungeons = {}, {}, {}
for _, row in ipairs(addon.Catalog) do
    assert(row.questID ~= 8183 and row.questID ~= 9120 and row.questID ~= 7161)
    if row.unconfirmed then
        assert(row.kind == "Drop" and row.binding == "BoE" and row.source:find("unconfirmed", 1, true))
        possible[row.id] = true
    elseif row.kind == "Drop" then
        world[row.id] = true
    elseif row.kind == "Dungeon" and row.id == 16681 then
        dungeons[row.source] = true
    end
end
assert(possible[647] and world[4041])
for id in pairs(possible) do assert(not world[id], "duplicate unconfirmed world origin for " .. id) end
-- Two named dungeons share a single "Dungeon" in the upstream sourceTypes set.
assert(dungeons["Dungeon: Blackrock Spire"] and dungeons["Dungeon: Stratholme"])
assert(source(1935, "Dungeon").minLevel == 19)
print("Shipped activity classifications passed")
