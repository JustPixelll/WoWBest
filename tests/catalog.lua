-- Smoke-test the actual packaged TOC and catalog on Lua 5.1.
local A, ids, kinds = {}, {}, {}
local function frame() return {RegisterEvent = function() end, SetScript = function() end} end
CreateFrame, SlashCmdList = frame, {}
for file in io.lines("WoWBest/WoWBest.toc") do
    if file:match("%.lua$") then assert(loadfile("WoWBest/" .. file))("WoWBest", A) end
end
assert(type(SlashCmdList.WOWBEST) == "function" and type(A.StartScan) == "function")
for _, row in ipairs(A.Catalog) do
    assert(type(row.id) == "number" and row.id > 0)
    assert(type(row.source) == "string" and #row.source > 0)
    assert(row.minLevel >= 1 and row.minLevel <= 60)
    ids[row.id], kinds[row.kind] = true, true
    if row.choice then assert(row.questID and row.maxCopies) end
end
for _, kind in ipairs({"Quest", "Dungeon", "Crafted", "Vendor", "Drop", "PvP"}) do assert(kinds[kind]) end
local distinct = 0
for _ in pairs(ids) do distinct = distinct + 1 end
assert(distinct >= 3000 and #A.Catalog > distinct)
assert(A.Profiles.WARRIOR and A.Profiles.DRUID)
local iron = {id = 5191, classID = 2, loc = "INVTYPE_WEAPON", stats = {DPS = 14}}
local twohand = {id = 7230, classID = 2, loc = "INVTYPE_2HWEAPON", stats = {DPS = 20}}
local shield = {id = 12, classID = 4, loc = "INVTYPE_SHIELD", stats = {RESISTANCE0_NAME = 200}}
assert(ids[iron.id] and ids[twohand.id])
for _, prof in ipairs(A.Profiles.WARRIOR) do
    local set = A.Solve({iron, twohand, shield}, {dual = false}, prof)
    assert(set[16] ~= twohand or not set[17])
    if prof.key == "protection" then assert(set[16] == iron and set[17] == shield) end
end
print(("Packaged TOC loaded, %d items and %d routes."):format(distinct, #A.Catalog))
