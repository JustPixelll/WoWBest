-- Exercise the public scan path with a simulated clock and an asynchronous cache.
local A, now, driver, refresh, pendingCalls = {}, 0, true, 0, 0
local scripts = {}
function CreateFrame()
    return {SetScript = function(_, name, fn) scripts[name] = fn end, RegisterEvent = function() end}
end
function GetTime() return now end
function InCombatLockdown() return not driver end
function A.IsVisible() return true end
function A.GetPlayer() return {class = "WARRIOR", level = 15, dual = true} end
function A.ActiveProfile() return {key = "arms", meleeDPS = 1} end
function A.RouteAvailable(row) return (row.minLevel or 0) <= 15 end
function A.UpdateStatus(message) A.message = message end
function A.UpdateDisplay(items, message) A.result, A.message = items, message end
local lookups = {}
function A.ReadCandidate(row)
    lookups[row.id] = (lookups[row.id] or 0) + 1
    if row.id == 7 then return nil, "pending" end
    if row.id == 5 then
        pendingCalls = pendingCalls + 1
        if pendingCalls <= 1 then return nil, "pending" end
    end
    return {id = row.id, name = tostring(row.id), loc = "INVTYPE_WEAPON", classID = 2, subID = 7, stats = {DPS = row.id}}, "ok"
end
A.Catalog = {
    {id = 11, source = "Future", minLevel = 16},
    {id = 7, source = "Never resolves"},
    {id = 1, source = "X", kind = "Drop"},
    {id = 1, source = "Y", kind = "Vendor"},
    {id = 5, source = "Already obtained", minLevel = 20},
    {id = 5, source = "Quest", questID = 12, choice = 12, maxCopies = 1},
}
assert(loadfile("WoWBest/Engine.lua"))("WoWBest", A)
assert(loadfile("WoWBest/Planner.lua"))("WoWBest", A)
local function step(dt)
    now = now + dt
    if scripts.OnUpdate then scripts.OnUpdate() end
end
A.StartScan(A.ActiveProfile())
for _ = 1, 20 do step(.1) end
assert(A.result and A.result[16].id == 5 and A.result[17].id == 1)
assert(A.result[17].source:match("Also: Y"))
assert(lookups[1] == 1 and not lookups[11])
for _ = 1, 150 do step(.1) end
assert(A.message:find("1 could not be verified", 1, true) and scripts.OnUpdate == nil)
driver = false
scripts.OnEvent(nil, "PLAYER_REGEN_DISABLED")
A.StartScan(A.ActiveProfile())
assert(A.message:find("after combat", 1, true) and not scripts.OnUpdate)
driver = true
scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
step(.5)
assert(scripts.OnUpdate)
scripts.OnEvent(nil, "ITEM_DATA_LOAD_RESULT", 7, false)
for _ = 1, 50 do step(.1) end
assert(A.result[16].id == 5 and not scripts.OnUpdate)
print("Planner tests passed.")
