local _, A = ...

local driver = CreateFrame("Frame")
local current, refreshAt
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
    if not A.RouteAvailable(row, s.player) then return end
    local key = row.link or row.id
    local group = s.byKey[key]
    if not group then
        group = {record = row, routes = {}}
        s.byKey[key], s.queue[#s.queue + 1] = group, group
    end
    if row.foreverStats and not group.record.foreverStats then group.record = row end
    -- One unlimited route dominates any other unlimited route for the same
    -- item. Retain distinct one-time options and owned copies for the solver.
    if not (row.choice or row.choices or row.maxCopies) then
        if group.unlimited then
            if row.source ~= group.unlimited.source and not group.altSource then group.altSource = row.source end
            return
        end
        group.unlimited = row
    end
    group.routes[#group.routes + 1] = row
end

local function accept(s, group, base)
    s.eligible = s.eligible + 1
    local routes = group.unlimited and {group.unlimited} or group.routes
    for _, row in ipairs(routes) do
        local item = {}
        for k, v in pairs(base) do item[k] = v end
        item.source, item.kind = row.source, row.kind
        item.choice, item.choices, item.maxCopies = row.choice, row.choices, row.maxCopies
        item.routeKey = row.routeKey or ((row.kind or "Gear") .. ":" .. tostring(row.questID or row.source) .. ":" .. row.id)
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

local function publish(s, done)
    local scanned = s.cursor - 1 - #s.pending
    local message
    if done then
        message = ("%d eligible item variants checked."):format(s.eligible)
        if s.unverified > 0 then
            message = message .. (" %d could not be verified and were skipped."):format(s.unverified)
        end
    else
        message = ("Checking gear: %d / %d. Results are provisional."):format(scanned, #s.queue)
    end
    if s.publishedCount ~= #s.items or done then
        A.UpdateDisplay(A.Solve(s.items, s.player, s.profile), message)
        s.publishedCount = #s.items
    else
        A.UpdateStatus(message)
    end
end

local function tick()
    if not A.IsVisible() then current, refreshAt = nil, nil return end
    local now = GetTime()
    if inCombat() then return end
    if refreshAt and refreshAt <= now then
        refreshAt = nil
        local profile = A.ActiveProfile()
        if profile then A.StartScan(profile) end
    end
    local s = current
    if not s then return end
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
    if done or now >= s.nextReport then
        publish(s, done)
        s.nextReport = now + 1.5
    end
    if done then
        current = nil
        if not refreshAt then driver:SetScript("OnUpdate", nil) end
    end
end

function A.StopScan()
    current, refreshAt = nil, nil
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
        failed = {}, loaded = {}, supplements = {}, unverified = 0, eligible = 0}
    current = s
    A.UpdateDisplay(nil, "Finding sources available at your level…")
    for _, row in ipairs(ownedRoutes()) do addRoute(s, row) end
    for _, row in ipairs(A.MarketRoutes and A.MarketRoutes() or {}) do addRoute(s, row) end
    driver:SetScript("OnUpdate", tick)
end

function A.MarketChanged()
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
            A.UpdateStatus("Gear checks resume after combat.")
        else
            refreshAt = GetTime() + .45
            driver:SetScript("OnUpdate", tick)
        end
    end
end)

for _, event in ipairs({"PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED",
    "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
    "QUEST_TURNED_IN", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    "ITEM_DATA_LOAD_RESULT"}) do
    -- Some event names vary between Forever builds.
    pcall(driver.RegisterEvent, driver, event)
end
