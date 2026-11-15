local _, A = ...

local driver = CreateFrame("Frame")
local current, refreshAt, snapshot, work
local tick
local frameBudgetEnds
local detailLimit = 15
local maxPending, timeout, sliceMS = 48, 12, 3
local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- Preserve exact item strings for suffixes/enchants. A plain ID is sufficient
-- for an unowned catalog entry. Multiple copies in bags and gear share a cap.
local function ownedRoutes()
    local byLink, owned = {}, {}
    local function add(link, worn, count)
        local id = link and tonumber(link:match("item:(%d+)"))
        if not id then return end
        local itemClass
        if C_Item and C_Item.GetItemInfoInstant then
            itemClass = select(6, C_Item.GetItemInfoInstant(id))
        end
        if itemClass and itemClass ~= 2 and itemClass ~= 4 then return end
        local key = link:match("|H(.-)|h") or link
        local row = byLink[key]
        if not row then
            row = {id = id, link = link, kind = "Owned", owned = true,
                maxCopies = 0, routeKey = "owned:" .. key, source = "In your bags"}
            owned[#owned + 1], byLink[key] = row, row
        end
        row.maxCopies = row.maxCopies + (count or 1)
        if worn then row.source = "Currently equipped" end
    end
    if GetInventoryItemLink then
        for slot = 1, 18 do
            if slot ~= 4 then add(GetInventoryItemLink("player", slot), true, 1) end
        end
    end
    if C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerNumSlots then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info then add(info.hyperlink, false, info.stackCount) end
            end
        end
    end
    return owned
end

local function addRoute(s, row)
    if not A.RouteSourceEnabled(row) then return end
    if not A.RouteAvailable(row, s.player) then
        local option = A.ProfessionTarget and A.ProfessionTarget(row, s.player)
        if option and option.slot then
            local bucket = s.paths[option.slot]
            if not bucket then bucket = {}; s.paths[option.slot] = bucket end
            local prior = bucket[option.id]
            if not prior or option.professionRank and option.professionRank < (prior.professionRank or math.huge) then
                bucket[option.id] = option
            end
        end
        return
    end
    if row.requiresCraftable then
        -- A craft proven by this character's actual recipe and materials can
        -- provide only the number of copies the client says can be made.
        local limited = {}
        for k, v in pairs(row) do limited[k] = v end
        limited.maxCopies = math.min(row.maxCopies or math.huge, A.PersonalCraftCount(row, s.player))
        limited.routeKey = "craft:" .. row.craftSpellID
        row = limited
    end
    local key = row.link or row.id
    local group = s.byKey[key]
    if not group then
        group = {record = row, routes = {}, sources = {}, sourceSet = {}}
        s.byKey[key], s.queue[#s.queue + 1] = group, group
    end
    if row.foreverStats and not group.record.foreverStats then group.record = row end
    if row.source and not group.sourceSet[row.source] then
        group.sourceSet[row.source] = true
        group.sources[#group.sources + 1] = row.source
    end
    -- One unlimited route dominates any other unlimited route for the same
    -- item. Retain distinct one-time options and owned copies for the solver.
    if not (row.choice or row.choices or row.maxCopies) then
        if group.unlimited then
            if group.unlimited.unconfirmed and not row.unconfirmed then
                group.altSource, group.unlimited = group.unlimited.source, row
            elseif row.source ~= group.unlimited.source and not group.altSource then
                group.altSource = row.source
            end
            return
        end
        group.unlimited = row
    end
    group.routes[#group.routes + 1] = row
end

local function accept(s, group, base)
    s.eligible = s.eligible + 1
    s.availableIDs[base.id] = true
    local routes = group.unlimited and {group.unlimited} or group.routes
    for _, row in ipairs(routes) do
        local item = {}
        for k, v in pairs(base) do item[k] = v end
        item.source, item.kind = row.source, row.kind
        item.choice, item.choices, item.maxCopies = row.choice, row.choices, row.maxCopies
        item.routeKey = row.routeKey or ((row.kind or "Gear") .. ":" .. tostring(row.questID or row.source) .. ":" .. row.id)
        item.sources = group.sources
        if group.unlimited and group.altSource then
            item.source = item.source .. "  •  Also: " .. group.altSource
        end
        s.items[#s.items + 1] = item
    end
end

local function inspect(s, group, now)
    if s.failed[group.record.id] then
        s.unverified = s.unverified + 1
        return true
    end
    local item, why = A.ReadCandidate(group.record, s.player, s.supplements[group.record.id])
    if item then
        accept(s, group, item)
    elseif why == "pending" then
        if not group.deadline then group.deadline = now + timeout end
        if now < group.deadline then
            group.nextPoll = now + .45
            return false
        end
        s.unverified = s.unverified + 1
    elseif why ~= "ineligible" then
        s.unverified = s.unverified + 1
    end
    return true
end

-- Both the baseline and a forced-slot ranking can explore many legal outfits.
-- The solver calls this checkpoint in its inner loops; the same prepared
-- index is reused for every clicked slot in this character snapshot.
local function checkpoint()
    if frameBudgetEnds and debugprofilestop() >= frameBudgetEnds then
        coroutine.yield()
    end
end

local function startWork(run, finish, fail)
    work = {thread = coroutine.create(run), finish = finish, fail = fail}
    driver:SetScript("OnUpdate", tick)
end

local function stopIfIdle()
    if not (current or work or refreshAt) then driver:SetScript("OnUpdate", nil) end
end

local function stepWork()
    local job = work
    frameBudgetEnds = debugprofilestop and (debugprofilestop() + sliceMS)
    local ok, a, b, c = coroutine.resume(job.thread)
    frameBudgetEnds = nil
    if ok and coroutine.status(job.thread) ~= "dead" then return end
    work = nil
    if ok then
        job.finish(a, b, c)
    else
        job.fail()
        if geterrorhandler then geterrorhandler()(a) else error(a) end
    end
    stopIfIdle()
end

function A.CancelSlotRequest()
    if work and work.isDetail then work = nil; stopIfIdle() end
end

local function pathsFor(s, slot)
    local primary = (slot == 12 and 11) or (slot == 14 and 13) or slot
    local options = {}
    for id, option in pairs(s.paths[primary] or {}) do
        if not s.availableIDs[id] then options[#options + 1] = option end
    end
    table.sort(options, function(a, b)
        if (a.professionRank or 0) ~= (b.professionRank or 0) then
            return (a.professionRank or 0) < (b.professionRank or 0)
        end
        return (a.name or tostring(a.id)) < (b.name or tostring(b.id))
    end)
    return options
end

function A.UnlockCount(slot)
    if not snapshot then return 0 end
    return #pathsFor(snapshot, slot)
end

function A.RequestSlot(slot, callback, showAll)
    A.CancelSlotRequest()
    local s = snapshot
    if not s or not A.IsVisible() or inCombat() then
        callback(nil, nil, nil, {}, inCombat() and "Gear checks resume after combat." or "Waiting for the gear scan…")
        return
    end
    local paths = pathsFor(s, slot)
    local cached = s.ranks[slot]
    if cached and (not showAll or not cached.more) then
        callback(cached.rows, s.loadout, s.profile, paths, nil, cached.more)
        return
    end
    callback(nil, s.loadout, s.profile, paths, showAll and "Ranking all compatible gear for this slot…" or "Comparing compatible loadouts…")
    startWork(function()
        return A.RankPrepared(s.solver, slot, showAll and math.huge or detailLimit + 1, {loadout = s.loadout, total = s.total})
    end, function(rows)
        local more = not showAll and #rows > detailLimit
        if more then table.remove(rows) end
        s.ranks[slot] = {rows = rows, more = more}
        callback(rows, s.loadout, s.profile, paths, nil, more)
    end, function()
        callback({}, s.loadout, s.profile, paths, "Slot comparison failed. Click Refresh to try again.")
    end)
    work.isDetail = true
end

local function calculate(s)
    current = nil
    A.UpdateStatus("Comparing complete loadouts and set bonuses…")
    startWork(function()
        local solver = A.PrepareSolver(s.items, s.player, s.profile, checkpoint)
        local loadout, total = A.SolvePrepared(solver)
        return solver, loadout, total
    end, function(solver, loadout, total)
        snapshot = {solver = solver, loadout = loadout, total = total, profile = s.profile,
            paths = s.paths, availableIDs = s.availableIDs, ranks = {}}
        local message = ("%d eligible item variants checked. Click a slot to compare gear."):format(s.eligible)
        if s.unverified > 0 then
            message = message .. (" %d could not be verified and were skipped."):format(s.unverified)
        end
        A.UpdateDisplay(loadout, message)
        if A.RefreshSlotDetail then A.RefreshSlotDetail() end
    end, function()
        A.UpdateDisplay(nil, "The comparison failed. Click Refresh to try again.")
    end)
end

tick = function()
    if not A.IsVisible() then A.StopScan() return end
    local now = GetTime()
    if inCombat() then return end
    if refreshAt and refreshAt <= now then
        refreshAt = nil
        local profile = A.ActiveProfile()
        if profile then A.StartScan(profile) end
    end
    if work then stepWork(); return end
    local s = current
    if not s then stopIfIdle(); return end
    local start = debugprofilestop and debugprofilestop() or 0
    local function timeLeft()
        return not debugprofilestop or debugprofilestop() - start < sliceMS
    end
    if s.buildAt <= #A.Catalog then
        for i = 1, 150 do
            local row = A.Catalog[s.buildAt]
            if row.foreverStats then s.supplements[row.id] = row.foreverStats end
            addRoute(s, row)
            s.buildAt = s.buildAt + 1
            if s.buildAt > #A.Catalog or not timeLeft() then break end
        end
        return
    end

    for i = #s.pending, 1, -1 do
        local group = s.pending[i]
        if now >= group.nextPoll or s.loaded[group.record.id] or s.failed[group.record.id] then
            if inspect(s, group, now) then table.remove(s.pending, i) end
            s.loaded[group.record.id] = nil
        end
        if not timeLeft() then break end
    end
    local count = 0
    while s.cursor <= #s.queue and #s.pending < maxPending and count < 24 and timeLeft() do
        local group = s.queue[s.cursor]
        s.cursor, count = s.cursor + 1, count + 1
        if not inspect(s, group, now) then s.pending[#s.pending + 1] = group end
    end
    local done = s.cursor > #s.queue and #s.pending == 0
    if done then
        calculate(s)
    elseif now >= s.nextReport then
        local scanned = s.cursor - 1 - #s.pending
        A.UpdateStatus(("Checking gear: %d / %d."):format(scanned, #s.queue))
        s.nextReport = now + .5
    end
end

function A.StopScan()
    current, refreshAt, snapshot, work = nil, nil, nil, nil
    driver:SetScript("OnUpdate", nil)
end

function A.StartScan(profile)
    A.StopScan()
    if inCombat() then
        A.UpdateDisplay(nil, "Gear checks resume after combat.")
        return
    end
    local player = A.GetPlayer()
    if not profile or not player.class or player.level <= 0 then
        A.UpdateDisplay(nil, "Your character information is still loading. Click Refresh in a moment.")
        return
    end
    local s = {player = player, profile = profile, items = {}, byKey = {}, queue = {}, cursor = 1,
        buildAt = 1, pending = {}, nextReport = GetTime() + .25,
        failed = {}, loaded = {}, supplements = {}, paths = {}, availableIDs = {}, unverified = 0, eligible = 0}
    current = s
    A.UpdateDisplay(nil, "Finding sources available at your level…")
    for _, row in ipairs(ownedRoutes()) do addRoute(s, row) end
    if A.SourceEnabled("PvP") and A.OpenPvPVendorRoutes then
        for _, row in ipairs(A.OpenPvPVendorRoutes()) do addRoute(s, row) end
    end
    if A.SourceEnabled("Auction") and A.MarketRoutes then
        for _, row in ipairs(A.MarketRoutes()) do addRoute(s, row) end
    end
    driver:SetScript("OnUpdate", tick)
end

function A.MarketChanged()
    if not A.SourceEnabled("Auction") then return end
    if A.IsVisible and A.IsVisible() and not inCombat() then
        refreshAt = GetTime() + .45
        driver:SetScript("OnUpdate", tick)
    end
end

driver:SetScript("OnEvent", function(_, event, id, success)
    if event == "ITEM_DATA_LOAD_RESULT" then
        if current then
            if success then current.loaded[id] = true else current.failed[id] = true end
        end
    elseif A.IsVisible and A.IsVisible() then
        if event == "PLAYER_REGEN_DISABLED" then
            A.StopScan()
            A.UpdateDisplay(nil, "Gear checks resume after combat.")
        else
            refreshAt = GetTime() + .45
            driver:SetScript("OnUpdate", tick)
        end
    end
end)

for _, event in ipairs({"PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
    "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "NEW_RECIPE_LEARNED",
    "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "ITEM_DATA_LOAD_RESULT"}) do
    -- Some event names vary between Forever builds.
    pcall(driver.RegisterEvent, driver, event)
end
