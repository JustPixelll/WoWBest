local _, A = ...

-- Compare native item tooltips even if the planner has never been opened.
-- Hover state is per frame; equipment and hydrated comparisons are shared.
local states = setmetatable({}, {__mode = "k"})
local guidLinks, guidCount = {}, 0
local cache, cacheSize, revision, worn, player, profile = {}, 0, 0, nil, nil, nil
local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function accessible(value)
    return not (issecretvalue and issecretvalue(value))
end

local function readable(t)
    return accessible(t) and type(t) == "table" and (not canaccesstable or canaccesstable(t))
end

local function supported(tip)
    -- Hidden scanner and embedded tooltips are not interactive item surfaces.
    return tip == GameTooltip or tip == ItemRefTooltip or tip == ShoppingTooltip1 or tip == ShoppingTooltip2
        or tip == ItemRefShoppingTooltip1 or tip == ItemRefShoppingTooltip2
end

local notWornGetter = {
    GetBagItem = true, GetMerchantItem = true, GetQuestItem = true, GetQuestLogItem = true,
    GetLootItem = true, GetHyperlink = true,
}
local function identify(tip, data, cachedOnly)
    if not readable(data) or not accessible(data.id) or type(data.id) ~= "number" then return end
    if not accessible(data.guid) or not accessible(data.hyperlink) then return end
    local info = tip:GetPrimaryTooltipInfo()
    if not readable(info) or not accessible(info.getterName) then return end
    local args = info.getterArgs
    local origin
    if info.getterName == "GetInventoryItem" then
        if not readable(args) or not accessible(args[1]) or not accessible(args[2]) then return end
        if args[1] == "player" and type(args[2]) == "number" then origin = args[2] end
    end

    local link
    if cachedOnly then
        -- No item/location API reads in combat. A public hyperlink or a GUID
        -- resolved on a prior hover can identify an already-scored exact copy.
        local known = data.guid and guidLinks[data.guid]
        if data.guid and not known and not origin and not notWornGetter[info.getterName] then return end
        origin = origin or (known and known.slot)
        link = data.hyperlink or (known and known.link)
    else
        if not origin and data.guid and C_Item.GetItemLocation then
            local location = C_Item.GetItemLocation(data.guid)
            if readable(location) and accessible(location.equipmentSlotIndex) then
                origin = location.equipmentSlotIndex
            end
        end
        link = data.guid and C_Item.GetItemLinkByGUID and C_Item.GetItemLinkByGUID(data.guid)
        if not accessible(link) then return end
        link = link or data.hyperlink
    end
    -- A side tooltip may be a worn piece or a hypothetical hand partner.
    if tip ~= GameTooltip and tip ~= ItemRefTooltip and not origin then return end
    if not link and info.getterName == "GetHyperlink" and readable(args) and accessible(args[1]) then
        link = args[1]
    end
    -- A recipe can expose the link of its crafted result under the recipe ID.
    if type(link) ~= "string" or tonumber(link:match("item:(%d+)")) ~= data.id then return end
    if not cachedOnly then
        local _, _, _, loc, _, cls = C_Item.GetItemInfoInstant(link)
        if not accessible(loc) or not accessible(cls) then return end
        if (cls ~= 2 and cls ~= 4) or not loc or loc == "" then return end
        if data.guid and (not guidLinks[data.guid] or guidLinks[data.guid].link ~= link or guidLinks[data.guid].slot ~= origin) then
            if guidCount >= 256 then guidLinks, guidCount = {}, 0 end
            if not guidLinks[data.guid] then guidCount = guidCount + 1 end
            guidLinks[data.guid] = {link = link, slot = origin}
        end
    end
    return link, origin, data.id
end

local function signed(n)
    if n ~= 0 and math.abs(n) < .05 then return n > 0 and "+<0.1" or "-<0.1" end
    return n == 0 and "0" or ("%+.1f"):format(n)
end

local function describe(result, reason, selected, candidate)
    local context = "WoWBest · " .. selected.name .. (selected.targetType == "Humanoid" and " (Humanoids)" or "")
    if not result then
        local messages = {
            ineligible = "Unavailable for this character or build",
            ["needs-main-hand"] = "Needs a compatible one-handed weapon",
            conflict = "Conflicts with equipped gear",
        }
        if messages[reason] then return {context .. " · " .. messages[reason], .78, .78, .78} end
        return
    end
    local slot = A.SlotNames[result.slot] or "Gear"
    local notes = A.UnscoredEffectNotes or {}
    local itemNote = candidate and notes[candidate.id]
    if result.alreadyEquipped then
        local message = ("%s · Equipped (%s)\n%.1f item pts · No change"):format(context, slot, result.swapBefore)
        return {itemNote and (message .. "\n" .. itemNote) or message, .76, .82, .88}
    end
    local function difference(percent, points)
        local amount = signed(points) .. " pts"
        if percent then return signed(percent) .. "% (" .. amount .. ")" end
        return amount .. " (from 0)"
    end
    local outfit = "Equipped loadout: " .. difference(result.percent, result.delta)
    local changed = #result.changedSlots > 1 and "Changed slots" or slot
    if #result.changedSlots == 1 and worn and not worn[result.slot] then changed = "Empty " .. slot:lower() end
    local direct = changed .. " item points: " .. difference(result.slotPercent, result.swapAfter - result.swapBefore)
    local labels = {upgrade = "Upgrade", downgrade = "Downgrade", neutral = "Even swap"}
    local colors = {upgrade = {.40, 1, .49}, downgrade = {1, .59, .47}, neutral = {.78, .82, .86}}
    local label = labels[result.kind]
    if result.unmodeledEffect then
        label = result.kind == "upgrade" and "Possible upgrade" or result.kind == "downgrade" and "Possible downgrade" or "Even on scored stats"
        local caveats = {}
        if itemNote then caveats[#caveats + 1] = itemNote end
        for _, changedSlot in ipairs(result.changedSlots) do
            local old = worn and worn[changedSlot]
            if old and notes[old.id] and notes[old.id] ~= itemNote then
                caveats[#caveats + 1] = notes[old.id]
            end
        end
        direct = direct .. "\n" .. (#caveats > 0 and table.concat(caveats, "\n") or "An item or set effect in this swap has no score.")
    end
    local color = colors[result.kind]
    return {context .. " · " .. label .. " (" .. slot .. ")\n" ..
        outfit .. "\n" .. direct, color[1], color[2], color[3]}
end

local function display(tip, state, key, annotation)
    if not annotation or state.rendered == key then return end
    tip:AddLine(annotation[1], annotation[2], annotation[3], annotation[4], true)
    state.rendered, state.message = key, annotation[1]
    local name = tip.GetName and tip:GetName()
    local count = tip.NumLines and tip:NumLines()
    if accessible(name) and name and accessible(count) and count then
        state.font = _G[name .. "TextLeft" .. count]
    end
end

local function compare(link, origin, id)
    player = player or A.GetPlayer()
    local candidate, status = A.ReadCandidate({id = id, link = link}, player, A.GetItemSupplement(id))
    if not candidate then return describe(nil, status, profile), status end
    if not worn then
        worn, status = A.ReadEquippedForUpgrade(player)
        if not worn then return nil, status end
    end
    local outcome, why = A.CompareEquippedUpgrade(candidate, worn, player, profile, origin)
    return describe(outcome, why, profile, candidate)
end

local function primaryMatches(tip, link, origin)
    if not tip:IsShown() or not tip.GetPrimaryTooltipData then return false end
    local active, slot = identify(tip, tip:GetPrimaryTooltipData())
    return active == link and slot == origin
end

local function track(tip, restricted)
    local state = states[tip]
    if not state then state = {}; states[tip] = state end
    if not state.hooked and not restricted then
        tip:HookScript("OnTooltipCleared", function() state.rendered, state.font = nil, nil end)
        tip:HookScript("OnHide", function() state.rendered, state.pending, state.font = nil, nil, nil end)
        state.hooked = true
    end
    return state
end

local function postCall(tip, data)
    if not supported(tip) or (tip.IsForbidden and tip:IsForbidden())
        or not tip.GetPrimaryTooltipInfo or not tip.GetPrimaryTooltipData then return end
    local primary = tip:GetPrimaryTooltipData()
    if not readable(data) or not readable(primary) or primary ~= data then return end
    local restricted = inCombat()
    local state = track(tip, restricted)
    if restricted and (not state.hooked or cacheSize == 0 or (tip.IsProtected and tip:IsProtected())) then return end
    local link, origin, id = identify(tip, data, restricted)
    if not link then return end
    local variant = A.ItemVariantKey(link)
    if not variant then return end
    local key = (origin or 0) .. "/" .. variant
    if cache[key] ~= nil then
        state.pending = nil
        display(tip, state, key, cache[key])
        return
    end
    if restricted or state.pending == key then return end
    profile = profile or A.ActiveProfile()
    if not profile then return end
    state.pending = key
    local generation = revision
    local tries = 0
    local function finish()
        if generation ~= revision or inCombat() or state.pending ~= key then return end
        if not primaryMatches(tip, link, origin) then state.pending = nil; return end
        local annotation, status = compare(link, origin, id)
        tries = tries + 1
        if status == "pending" and tries < 48 then
            C_Timer.After(.25, finish)
            return
        end
        state.pending = nil
        -- Transient/unknown reads are never cached as a zero or a downgrade.
        if annotation then
            if cacheSize >= 256 then cache, cacheSize = {}, 0 end
            cache[key], cacheSize = annotation, cacheSize + 1
            display(tip, state, key, annotation)
            tip:Show()
        end
    end
    -- Leave native tooltip construction before reading gear, stats or sets.
    C_Timer.After(0, finish)
end

function A.InvalidateUpgradeTooltips()
    cache, cacheSize, revision, worn, player, profile = {}, 0, revision + 1, nil, nil, nil
    guidLinks, guidCount = {}, 0
    for tip, state in pairs(states) do
        state.pending = nil
        -- A gear swap can arrive while a warm annotation is still displayed.
        -- Erase just our own public line. Never clear/rebuild a restricted tip.
        local font = state.font
        if inCombat() and font and not (tip.IsForbidden and tip:IsForbidden())
            and not (tip.IsProtected and tip:IsProtected()) and not (font.IsForbidden and font:IsForbidden()) then
            local message = font:GetText()
            if accessible(message) and message == state.message then font:SetText("") end
        end
        state.rendered, state.font = nil, nil
        if not inCombat() and not (tip.IsForbidden and tip:IsForbidden())
            and tip:IsShown() and tip.RebuildFromTooltipInfo and not state.redrawQueued then
            state.redrawQueued = true
            local frame, entry = tip, state
            C_Timer.After(0, function()
                entry.redrawQueued = nil
                if frame:IsShown() and not inCombat() and identify(frame, frame:GetPrimaryTooltipData()) then
                    frame:RebuildFromTooltipInfo()
                end
            end)
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
    and C_Timer and C_Timer.After and C_Item and C_Item.GetItemInfoInstant then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, postCall)
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Keep the last verified baseline, but suspend outstanding hydration.
            for _, state in pairs(states) do state.pending = nil end
        elseif event ~= "UNIT_INVENTORY_CHANGED" or (accessible(unit) and unit == "player") then
            A.InvalidateUpgradeTooltips()
        end
    end)
    for _, name in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
        "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2"}) do
        local tip = _G[name]
        if tip and not (tip.IsForbidden and tip:IsForbidden()) then track(tip, inCombat()) end
    end
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "PLAYER_LEVEL_UP", "SPELLS_CHANGED",
        "SKILL_LINES_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "UPDATE_FACTION",
        "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
    }) do pcall(events.RegisterEvent, events, event) end
end
