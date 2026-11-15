local _, A = ...

-- Source filters concern acquiring more gear. The carried copies are already owned.
local frame = CreateFrame("Frame")
local job, scheduledAt, shown, lateIDs
local announced = {}
local delay, retryInterval, timeout = .35, .35, 8

local function restricted(value)
    return issecretvalue and issecretvalue(value)
end

local function allowed()
    return A.BagAlertsEnabled and A.BagAlertsEnabled()
        and not (InCombatLockdown and InCombatLockdown())
        and C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo
end

local function hide()
    if shown then
        shown = nil
        if A.HideBagUpgrade then A.HideBagUpgrade() end
    end
end

function A.DismissBagUpgrade(alert)
    if alert == shown then hide() end
end

local function stop()
    scheduledAt, job = nil, nil
    frame:SetScript("OnUpdate", nil)
end

local function slotInfo(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if restricted(info) or info and canaccesstable and not canaccesstable(info) then return nil,nil,true end
    if info then
        if restricted(info.hyperlink) or restricted(info.itemID) then return nil,nil,true end
        return info.hyperlink, info.itemID
    end
    if C_Container.GetContainerItemID then
        local id = C_Container.GetContainerItemID(bag, slot)
        if restricted(id) then return nil,nil,true end
        return nil, id
    end
end

local function inspect(s, position)
    local link, id, hidden = slotInfo(position.bag, position.slot)
    if hidden then s.incomplete = true; return end
    local key, linkID = A.ItemVariantKey(link)
    if not key then
        if id then
            if not s.player.requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
                s.player.requested[id] = true
                C_Item.RequestLoadItemDataByID(id)
            end
            return id
        end
        return
    end
    if id and id ~= linkID then return id end
    local cached = s.variants[key]
    if cached == nil then
        if C_Item and C_Item.GetItemInfoInstant then
            local _, _, _, _, _, cls = C_Item.GetItemInfoInstant(link)
            if restricted(cls) then s.incomplete = true; return end
            if cls and cls ~= 2 and cls ~= 4 then s.variants[key] = false; return end
        end
        local item, status = A.ReadCandidate({id = linkID, link = link, owned = true}, s.player,
            A.GetItemSupplement(linkID))
        if not item then
            if status == "pending" then return linkID end
            if status == "ineligible" then s.variants[key] = false
            else s.incomplete = true end
            return
        end
        local direct = A.CompareEquippedUpgrade(item, s.worn, s.player, s.profile)
        cached = {item = item, direct = direct}
        s.variants[key] = cached
        if direct and direct.kind == "upgrade" and direct.delta > 0 then
            s.offers[key] = {item = item, result = direct, key = key, position = position}
        end
    end
    if cached then
        s.items[#s.items + 1] = {item = cached.item, direct = cached.direct, key = key, position = position}
    end
end

local function signature(alert, profile, worn)
    local result = alert.result
    local values = {profile.key, profile.targetType or "", tostring(result.slot), ("%.12g"):format(result.delta)}
    for _, slot in ipairs(result.changedSlots) do
        local previous = worn[slot]
        values[#values + 1] = slot .. "=" .. (previous and A.ItemVariantKey(previous.link) or "")
    end
    return table.concat(values, "|")
end

local function stillInBag(part)
    local link = slotInfo(part.position.bag, part.position.slot)
    return A.ItemVariantKey(link) == part.key
end

local function finish(s)
    local best, count = nil, 0
    for key, offer in pairs(s.offers) do
        offer.stamp = signature(offer, s.profile, s.worn)
        if announced[key] ~= offer.stamp then
            count = count + 1
            if not best or offer.result.delta > best.result.delta
                or offer.result.delta == best.result.delta and key < best.key then best = offer end
        end
    end
    stop()
    if best then
        local valid = true
        if best.parts then
            for _, part in ipairs(best.parts) do
                if not stillInBag(part) then valid = false; break end
            end
        else valid = stillInBag(best) end
        if not valid then hide(); A.RefreshBagUpgrades(); return end
    end
    if shown then
        local previous = s.offers[shown.key]
        if not previous or previous.stamp ~= shown.stamp then hide() end
    end
    -- Remember the entire batch. A bag sort stays quiet, while weaker fresh
    -- loot and items that become usable again can each trigger a later alert.
    for key in pairs(announced) do
        if not s.offers[key] and (not s.incomplete or s.variants[key] ~= nil) then announced[key] = nil end
    end
    if not best then return end
    for key, offer in pairs(s.offers) do announced[key] = offer.stamp end
    best.count, best.profile, shown = count, s.profile, best
    if A.ShowBagUpgrade then A.ShowBagUpgrade(best) end
end

local function newScan(now)
    local player = A.GetPlayer()
    if not player.class or not player.level or player.level <= 0 then return end
    local profile = A.ActiveProfile(player)
    if not profile then return end
    local s = {profile = profile, player = player, positions = {}, cursor = 1,
        deadline = now + timeout, retry = {}, pendingIDs = {}, variants = {}, items = {}, offers = {}}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local count = C_Container.GetContainerNumSlots(bag)
        if restricted(count) then s.incomplete = true
        else
            for slot = 1, count or 0 do s.positions[#s.positions + 1] = {bag = bag, slot = slot} end
        end
    end
    player.requested = player.requested or {}
    return s
end

local function update()
    local now = GetTime()
    if scheduledAt and now < scheduledAt then return end
    if not allowed() then stop(); hide(); return end
    scheduledAt = nil
    if not job then job = newScan(now) end
    if not job then stop(); hide(); return end
    if not job.worn then
        local status
        job.worn, status = A.ReadEquippedForUpgrade(job.player)
        if not job.worn then
            if status == "pending" and now < job.deadline then scheduledAt = now + retryInterval
            else
                if status == "pending" then
                    lateIDs = job.player.requested
                    for slot in pairs(A.SlotNames) do
                        local id = GetInventoryItemID("player", slot)
                        if not restricted(id) and id then lateIDs[id] = true end
                    end
                end
                stop()
                hide()
            end
            return
        end
    end
    if job.joint then
        local done, alerts = job.joint()
        if done then
            for _, offer in ipairs(alerts or {}) do job.offers[offer.key] = offer end
            finish(job)
        end
        return
    end
    local start = debugprofilestop and debugprofilestop()
    for _ = 1, 12 do
        local pos = job.positions[job.cursor]
        if not pos then
            if #job.retry > 0 and now < job.deadline then
                job.positions, job.cursor, job.retry, job.pendingIDs = job.retry, 1, {}, {}
                scheduledAt = now + retryInterval
                return
            end
            if #job.retry > 0 then job.incomplete, lateIDs = true, job.pendingIDs end
            if A.StartJointBagUpgrades then
                job.joint = A.StartJointBagUpgrades(job.items, job.worn, job.player, job.profile)
            end
            if not job.joint then finish(job) end
            return
        end
        local pendingID = inspect(job, pos)
        if pendingID then
            job.retry[#job.retry + 1] = pos
            job.pendingIDs[pendingID] = true
        end
        job.cursor = job.cursor + 1
        if start and debugprofilestop() - start >= 2 then return end
    end
end

function A.RefreshBagUpgrades()
    job, lateIDs = nil, nil
    if not allowed() then
        if A.BagAlertsEnabled and not A.BagAlertsEnabled() then announced = {} end
        stop()
        hide()
        return
    end
    -- Coalesce inventory bursts and never hydrate an item inside its event.
    scheduledAt = GetTime() + delay
    frame:SetScript("OnUpdate", update)
end

frame:SetScript("OnEvent", function(_, event, id, success)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEAVING_WORLD" then
        lateIDs = nil
        stop()
        hide()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        if not restricted(id) and not restricted(success) and success and lateIDs and lateIDs[id] then
            A.RefreshBagUpgrades()
        end
    else
        A.RefreshBagUpgrades()
    end
end)
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "SKILL_LINES_CHANGED",
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT"}) do
    pcall(frame.RegisterEvent, frame, event)
end
