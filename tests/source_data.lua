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
print("Shipped activity classifications passed")
