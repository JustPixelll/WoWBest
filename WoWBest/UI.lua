local addonName, A = ...

local frame, scroll, content, profileButton, targetButton, menu, context, statusText
local rows, menuButtons = {}, {}
local bagAlertButton
local sources = {checks = {}}
local detail = {slot = nil, generation = 0, cards = {}, pageSize = 5}
local result, lastStatus = nil, ""
local slots = {1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}
local healingPaces = {"short", "dungeon", "sustained"}
local paceNames = {short = "Short pull", dungeon = "Dungeon", sustained = "Sustained"}

local function settings()
    if type(WoWBestCharacterDB) ~= "table" then WoWBestCharacterDB = {} end
    return WoWBestCharacterDB
end

function A.BagAlertsEnabled()
    return settings().bagAlerts ~= false
end

local function bagAlertLabel()
    return A.BagAlertsEnabled() and "Bag alerts: On" or "Bag alerts: Off"
end

function A.SetBagAlertsEnabled(enabled)
    if type(enabled) ~= "boolean" or A.BagAlertsEnabled() == enabled then return end
    if enabled then settings().bagAlerts = nil else settings().bagAlerts = false end
    if bagAlertButton then bagAlertButton:SetText(bagAlertLabel()) end
    if not enabled and A.HideBagUpgrade then A.HideBagUpgrade() end
    if A.RefreshBagUpgrades then A.RefreshBagUpgrades() end
end

local function findProfile(profiles, key)
    for _, profile in ipairs(profiles) do
        if profile.key == key then return profile end
    end
end

local function selectedProfile(player)
    local profiles = A.Profiles[player.class] or {}
    local saved = findProfile(profiles, settings().profile)
    if saved then return saved, "manual" end
    local detected = A.DetectProfile and A.DetectProfile(player)
    if type(detected) == "table" then detected = detected.key end
    local active = detected and findProfile(profiles, detected)
    if active then return active, "detected" end
    return profiles[1], "default"
end

local function targetName(targetType)
    return targetType == "Humanoid" and "Humanoids" or "General PvE"
end

function A.ActiveProfile(player)
    player = player or A.GetPlayer()
    local profile = selectedProfile(player)
    if profile and player.class == "DRUID" and profile.key == "restoration" then
        if player.restoTalents == nil and A.GetRestoDruidTalents then
            player.restoTalents = A.GetRestoDruidTalents()
        end
        player.healingPace = settings().healingPace or "dungeon"
    end
    if profile and A.ProfileForLevel then profile = A.ProfileForLevel(profile, player) end
    if not profile or settings().targetType ~= "Humanoid" then return profile end
    -- The underlying spec weights are shared across characters and scans.
    local scenario = {}
    for key, value in pairs(profile) do scenario[key] = value end
    scenario.targetType = "Humanoid"
    return scenario
end

function A.IsVisible()
    return frame and frame:IsShown() or false
end

local function colorBackground(parent, r, g, b, a)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(r, g, b, a)
    return tex
end

local function text(parent, style, align)
    local font = parent:CreateFontString(nil, "ARTWORK", style)
    font:SetJustifyH(align or "LEFT")
    return font
end

local function itemLink(item)
    return item.link or ("item:" .. item.id)
end

local function showItemTip(self)
    if not self.item then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(itemLink(self.item))
    local note = A.EffectNotes and A.EffectNotes[self.item.id]
    if note then GameTooltip:AddLine("WoWBest estimate: " .. note, .75, .88, 1, true) end
    GameTooltip:Show()
end

local function hideItemTip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function itemName(item)
    return item and (item.name or item.link or ("Item " .. item.id)) or "Empty"
end

local function sameItem(a, b)
    if not a or not b then return a == b end
    return a.id == b.id and (not a.link or not b.link or a.link == b.link)
end

local function occupiedOffHand(loadout, slot)
    local main = loadout and loadout[16]
    return slot == 17 and main and main.loc == "INVTYPE_2HWEAPON"
end

local function number(n, precision)
    local value = string.format("%." .. (precision or 2) .. "f", n)
    return (value:gsub("0+$", ""):gsub("%.$", ""))
end

local function signed(n)
    if math.abs(n) < .005 then return "0" end
    return (n > 0 and "+" or "") .. number(n)
end

local function healingReport(p)
    local ranks = p.restoTalents
    local talents = ranks and ("Reflection %d/3 · Bloom %d/1 · Living Spirit %d/3 · Heart of the Wild %d/5"):format(
        ranks.reflection or 0, ranks.bloom or 0, ranks.livingSpirit or 0, ranks.heartOfTheWild or 0)
        or "Talent ranks unavailable. Showing weights without talent bonuses."
    return {
        ("Level %d Restoration · %s"):format(p.level, paceNames[p.healingPace] or paceNames.dungeon),
        ("Points per +1: healing %s · damage and healing %s · damage only 0"):format(number(p.healing), number(p.spell)),
        ("Intellect %s · Spirit %s · mana per 5 sec %s"):format(number(p.intellect), number(p.spirit), number(p.mp5)),
        ("Crit rating %s · haste rating %s"):format(number(p.crit), number(p.haste)),
        talents,
    }
end

local function setChanges(before, after, profile)
    local changes, base, nextSet = {}, {}, {}
    for _, bonus in ipairs(before) do base[bonus.key] = bonus end
    for _, bonus in ipairs(A.ActiveSetBonuses and A.ActiveSetBonuses(after, profile) or {}) do
        nextSet[bonus.key] = true
        if not base[bonus.key] then
            changes[#changes + 1] = {verb = "Gains", bonus = bonus}
        end
    end
    for _, bonus in ipairs(before) do
        if not nextSet[bonus.key] then changes[#changes + 1] = {verb = "Loses", bonus = bonus} end
    end
    return changes
end

local function explainChoice(choice, bestSets)
    local item = choice.item
    local source = item.source or "Unknown"
    local lines = {"|cffffd275Source|r  " .. source}
    if item.unmodeledEffect then
        lines[#lines + 1] = A.UnscoredEffectNotes and A.UnscoredEffectNotes[item.id]
            or "This item has an additional effect without a numerical score."
    end
    local alternatives = {}
    for _, path in ipairs(item.sources or {}) do
        if not source:find(path, 1, true) then alternatives[#alternatives + 1] = path end
    end
    if #alternatives > 0 then
        lines[#lines + 1] = "|cffffd275Also available|r  " .. table.concat(alternatives, "\n")
    end
    local profile, selected = detail.profile, detail.slot
    if A.ScoreBreakdown then
        local parts = A.ScoreBreakdown(item, profile, selected)
        local terms = {}
        for _, part in ipairs(parts) do
            if part.amount and part.weight then
                terms[#terms + 1] = ("%s %s × %s = %s"):format(part.label,
                    number(part.amount), number(part.weight, 4), number(part.points))
            else
                terms[#terms + 1] = part.label .. " " .. signed(part.points)
            end
        end
        if #terms > 0 then
            lines[#lines + 1] = "|cffffd275Item score|r  " .. number(A.Score(item, profile, selected)) ..
                " pts   ·   " .. table.concat(terms, "   ·   ")
        else
            lines[#lines + 1] = "This profile assigns no modeled points to the item itself."
        end
    end
    for _, slot in ipairs(slots) do
        if slot ~= selected then
            local was, now = detail.baseline[slot], choice.loadout[slot]
            if not sameItem(was, now) then
                lines[#lines + 1] = ("|cffffd275%s|r  %s → %s"):format(A.SlotNames[slot], itemName(was), itemName(now))
            end
        end
    end
    for _, change in ipairs(setChanges(bestSets, choice.loadout, profile)) do
        local bonus = change.bonus
        local effect = bonus.description or ""
        local score = bonus.modeled and (" (" .. number(bonus.score or 0) .. " pts)") or " (unscored effect)"
        lines[#lines + 1] = ("%s %s %d-piece: %s%s"):format(change.verb, bonus.name, bonus.threshold, effect, score)
    end
    return table.concat(lines, "\n")
end

local function showItemReference(self)
    if not self.item then return end
    local link = itemLink(self.item)
    if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
    if SetItemRef then
        local ref = link:match("|H([^|]+)|h") or link
        SetItemRef(ref, link, "LeftButton")
    end
end

local function detailCard(index)
    local card = detail.cards[index]
    if card then return card end
    card = CreateFrame("Button", nil, detail.content)
    colorBackground(card, .30, .36, .40, .16)
    card.title = text(card, "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 8, -7)
    card.body = text(card, "GameFontHighlightSmall")
    card.body:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.body:SetTextColor(.81, .84, .87)
    card:SetScript("OnEnter", showItemTip)
    card:SetScript("OnLeave", hideItemTip)
    card:SetScript("OnClick", showItemReference)
    detail.cards[index] = card
    return card
end

local function renderDetail()
    if not detail.slot or not detail.content or not A.IsVisible() then return end
    local width = detail.scroll:GetWidth()
    if width <= 0 then return end
    detail.content:SetWidth(width)
    local pos, count = 0, 0
    local function card(item, title, body)
        count = count + 1
        local row = detailCard(count)
        row.item = item
        row.title:SetWidth(width - 16)
        row.body:SetWidth(width - 16)
        row.title:SetText(title)
        row.body:SetText(body or "")
        local height = math.ceil(row.title:GetStringHeight() + (body and row.body:GetStringHeight() + 4 or 0) + 14)
        row:SetSize(width, height)
        row:SetPoint("TOPLEFT", detail.content, "TOPLEFT", 0, -pos)
        row:Show()
        pos = pos + height + 3
    end

    local choices, locked = detail.choices, detail.locked or {}
    local showingLocked = detail.tab == "locked"
    local list = showingLocked and locked or (choices or {})
    local pages = math.max(1, math.ceil(#list / detail.pageSize))
    detail.page = math.min(detail.page or 1, pages)
    local first = (detail.page - 1) * detail.pageSize + 1
    local last = math.min(#list, first + detail.pageSize - 1)
    detail.pageText:SetText(#list > 0 and ("%d–%d of %d"):format(first, last, #list) or "")
    detail.previous:SetEnabled(detail.page > 1)
    detail.next:SetEnabled(detail.page < pages)
    detail.ranked:SetEnabled(showingLocked)
    detail.targets:SetEnabled(not showingLocked)
    detail.ranked:SetText("Ranked gear" .. (choices and " (" .. #choices .. ")" or ""))
    detail.targets:SetText("Paths to unlock" .. (detail.profile and " (" .. #locked .. ")" or ""))
    if choices and detail.more and not showingLocked then detail.showAll:Show() else detail.showAll:Hide() end

    if not choices and (not showingLocked or not detail.profile) then
        card(nil, detail.message or "Checking this slot…")
    elseif showingLocked then
        if #locked == 0 then
            card(nil, "No additional unlock paths found for this slot.")
        else
            card(nil, "|cffffd275Paths to unlock|r", "These items have an unmet requirement. The ranked loadouts cover gear currently available to your character.")
        end
        for i = first, last do
            local item = locked[i]
            local facts = {item.requirement or "Additional requirements apply"}
            if item.statSummary then facts[#facts + 1] = item.statSummary end
            facts[#facts + 1] = item.source or "Source unknown"
            card(item, item.link or itemName(item), table.concat(facts, "\n"))
        end
    else
        local base = detail.baseline
        local bestSets = A.ActiveSetBonuses and A.ActiveSetBonuses(base, detail.profile) or {}
        local description = "Ranked by the best compatible outfit containing each item. Points use the weights for " .. detail.profile.name .. " (" .. targetName(detail.profile.targetType) .. ")."
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", detail.slot)
        description = "Currently equipped: " .. (worn or "Empty") ..
            "\nRecommended: " .. itemName(base[detail.slot]) .. "\n" .. description
        if #choices > 0 then
            description = description .. " Best loadout: " .. number(choices[1].total - choices[1].delta) .. " pts."
        end
        if not base[17] and occupiedOffHand(base, detail.slot) then
            description = description .. "\nThe recommended two-handed weapon occupies both hands."
        end
        if #bestSets > 0 then
            local active = {}
            for _, bonus in ipairs(bestSets) do
                local estimate = bonus.modeled and (number(bonus.score or 0) .. " pts") or "unscored effect"
                active[#active + 1] = ("%s %d-piece · %s (%s)"):format(
                    bonus.name, bonus.threshold, bonus.description or "", estimate)
            end
            description = description .. "\nActive in the best loadout:\n" .. table.concat(active, "\n")
        end
        card(nil, #choices > 0 and "|cffffd275How to read the ranking|r" or (detail.message or "No eligible alternative found"), description)
        for i = first, last do
            local choice = choices[i]
            local item = choice.item
            local rankLabel = ("#%d  "):format(choice.rank or i)
            local name = item and (item.link or itemName(item)) or "Empty"
            local comparison = math.abs(choice.delta) < .000001 and "equals best" or
                (math.abs(choice.delta) < .005 and "<0.01 pts from best" or (signed(choice.delta) .. " vs best"))
            local outcome = ("Full loadout: %s pts   ·   %s"):format(number(choice.total), comparison)
            local body = item and (outcome .. "\n" .. explainChoice(choice, bestSets)) or outcome
            card(item, "|cffffd275" .. rankLabel .. "|r" .. name, body)
        end
    end

    for i = count + 1, #detail.cards do detail.cards[i]:Hide() end
    detail.content:SetHeight(math.max(1, pos))
end

local function invalidateDetail(message)
    detail.generation = detail.generation + 1
    if A.CancelSlotRequest then A.CancelSlotRequest() end
    detail.choices, detail.locked, detail.baseline, detail.profile = nil, nil, nil, nil
    detail.message, detail.more = message, false
end

local function changePage(direction)
    detail.page = math.max(1, detail.page + direction)
    detail.scroll:SetVerticalScroll(0)
    renderDetail()
end

local function changeTab(tab)
    detail.chooseDefaultTab = false
    detail.tab, detail.page = tab, 1
    detail.scroll:SetVerticalScroll(0)
    renderDetail()
end

function A.RefreshSlotDetail()
    if not (detail.slot and A.IsVisible()) then return end
    invalidateDetail("Finding eligible alternatives…")
    local slot, generation = detail.slot, detail.generation
    renderDetail()
    A.RequestSlot(slot, function(choices, baseline, profile, locked, status, more)
        if detail.slot ~= slot or generation ~= detail.generation or not A.IsVisible() then return end
        detail.choices, detail.baseline, detail.profile = choices, baseline or {}, profile
        detail.locked, detail.message = locked, status
        detail.more = more
        if detail.chooseDefaultTab and baseline and profile and locked and (#locked > 0 or choices) then
            detail.chooseDefaultTab = false
            if not baseline[slot] and not occupiedOffHand(baseline, slot) and #locked > 0 then
                detail.tab, detail.page = "locked", 1
            end
        end
        renderDetail()
    end, detail.all)
end

local function closeDetail()
    if not detail.slot then return end
    detail.slot = nil
    invalidateDetail()
    detail.frame:Hide()
    scroll:Show()
end

local function openDetail(slot)
    detail.all = false
    detail.slot, detail.page, detail.tab, detail.chooseDefaultTab = slot, 1, "ranked", true
    detail.title:SetText(A.SlotNames[slot] or ("Slot " .. slot))
    if GameTooltip:IsShown() then GameTooltip:Hide() end
    menu:Hide()
    sources.menu:Hide()
    scroll:Hide()
    detail.frame:Show()
    detail.scroll:SetVerticalScroll(0)
    A.RefreshSlotDetail()
end

local function adjacentSlot(step)
    for index, slot in ipairs(slots) do
        if slot == detail.slot then
            openDetail(slots[(index - 1 + step) % #slots + 1])
            return
        end
    end
end

local function drawRows()
    if not content or not frame:IsShown() then return end
    local width = scroll:GetWidth()
    if not width or width <= 0 then return end
    content:SetWidth(width)

    local indent = math.min(106, math.floor(width * .25))
    local offset = 0
    for i, slot in ipairs(slots) do
        local row = rows[i]
        local item = result and result[slot]
        row.item = item
        row.slot:SetText(A.SlotNames[slot] or ("Slot " .. slot))
        row.slot:SetWidth(indent - 12)
        row.title:SetWidth(math.max(1, width - indent - 27))
        row.detail:SetWidth(math.max(1, width - indent - 12))
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", indent, -7)
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)

        local detail
        if item then
            row.title:SetText(item.link or item.name or ("Item " .. item.id))
            row.title:SetTextColor(1, 1, 1)
            detail = item.source or "Source unknown"
        else
            local label = result and "No eligible item found" or "—"
            if occupiedOffHand(result, slot) then
                label = "Occupied by two-handed weapon"
            end
            local count = result and A.UnlockCount and A.UnlockCount(slot) or 0
            if count > 0 then
                detail = ("%d %s to unlock  •  Click to explore"):format(count, count == 1 and "path" or "paths")
            end
            row.title:SetText(label)
            row.title:SetTextColor(.58, .61, .65)
        end
        row.detail:SetText(detail or "")
        local lineHeight = math.max(row.slot:GetStringHeight(), row.title:GetStringHeight())
        local height = math.ceil(lineHeight + 14 + (detail and row.detail:GetStringHeight() + 2 or 0))
        row:SetSize(width, height)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -offset)
        offset = offset + height
    end
    content:SetHeight(math.max(1, offset))
end

local function sourceSummary()
    local count = 0
    for _, method in ipairs(A.SourceMethods) do
        if A.SourceEnabled(method.key) then count = count + 1 end
    end
    if count == 0 then return "Sources: Owned only" end
    local label = count == #A.SourceMethods and "All" or ("%d/%d"):format(count, #A.SourceMethods)
    return "Sources: " .. label .. (A.UnconfirmedSourcesEnabled() and " + leads" or "")
end

local function updateHeader()
    if not frame then return end
    local player = A.GetPlayer()
    local profile, mode = selectedProfile(player)
    local className = UnitClass("player") or player.class or "Unknown class"
    context:SetText(("Level %s %s"):format(player.level or "?", className))
    targetButton:SetText("Target: " .. targetName(settings().targetType))
    sources.button:SetText(sourceSummary())
    if profile then
        local label = profile.name
        if mode == "detected" then label = "Auto: " .. label end
        if mode == "default" then label = "Default: " .. label end
        if player.class == "DRUID" and profile.key == "restoration" then
            label = label .. " · " .. (paceNames[settings().healingPace] or paceNames.dungeon)
        end
        profileButton:SetText(label)
    else
        profileButton:SetText("No profile available")
    end
end

function A.UpdateStatus(message)
    lastStatus = message or ""
    if statusText then statusText:SetText(lastStatus) end
end

function A.UpdateDisplay(items, message)
    result = items
    if message ~= nil then A.UpdateStatus(message) end
    if A.IsVisible() then
        updateHeader()
        if detail.slot and not items then
            invalidateDetail(message or "Checking gear…")
            renderDetail()
        else
            drawRows()
        end
    end
end

local function scan()
    menu:Hide()
    sources.menu:Hide()
    updateHeader()
    local profile = A.ActiveProfile()
    A.UpdateDisplay(nil, profile and "Looking up gear…" or "No gear profile is available for this class.")
    if profile then A.StartScan(profile) end
end

local function scoringChanged()
    if A.InvalidateUpgradeTooltips then A.InvalidateUpgradeTooltips() end
    if A.RefreshBagUpgrades then A.RefreshBagUpgrades() end
    if A.IsVisible() then scan() end
end

local function selectProfile(key)
    settings().profile = key
    scoringChanged()
end

local function selectHealingPace(pace)
    if menu then menu:Hide() end
    if pace == (settings().healingPace or "dungeon") then return end
    settings().healingPace = pace
    scoringChanged()
end

local function addMenuButton(index)
    local entry = CreateFrame("Button", nil, menu)
    entry:SetSize(menu:GetWidth() - 10, 23)
    entry:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 23)
    entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    entry.label = text(entry, "GameFontHighlight")
    entry.label:SetPoint("LEFT", 6, 0)
    entry.label:SetPoint("RIGHT", -6, 0)
    entry:SetScript("OnClick", function(self)
        if self.pace then selectHealingPace(self.pace) else selectProfile(self.key) end
    end)
    menuButtons[index] = entry
    return entry
end

local function toggleMenu()
    sources.menu:Hide()
    if menu:IsShown() then menu:Hide() return end
    local player = A.GetPlayer()
    local profiles = A.Profiles[player.class] or {}
    local saved = settings().profile
    local manual = findProfile(profiles, saved)
    for i = 1, #profiles + 1 do
        local profile = profiles[i - 1]
        local entry = menuButtons[i] or addMenuButton(i)
        local selected = (profile and profile == manual) or (not profile and not manual)
        entry.pace = nil
        entry.key = profile and profile.key or nil
        entry.label:SetText((selected and "|cffffd100" or "|cffffffff") ..
            (profile and profile.name or "Auto (active talents)") .. "|r")
        entry:Show()
    end
    local count = #profiles + 1
    local selected = selectedProfile(player)
    if player.class == "DRUID" and selected and selected.key == "restoration" then
        local pace = settings().healingPace or "dungeon"
        for _, key in ipairs(healingPaces) do
            count = count + 1
            local entry = menuButtons[count] or addMenuButton(count)
            entry.key, entry.pace = nil, key
            entry.label:SetText((key == pace and "|cffffd100" or "|cffffffff") .. "Healing: " .. paceNames[key] .. "|r")
            entry:Show()
        end
    end
    for i = count + 1, #menuButtons do menuButtons[i]:Hide() end
    menu:SetHeight(10 + count * 23)
    menu:Show()
end

local function makeRow(index)
    local row = CreateFrame("Button", nil, content)
    if index % 2 == 1 then colorBackground(row, .30, .36, .40, .16) end
    row.slot = text(row, "GameFontNormalSmall")
    row.slot:SetPoint("TOPLEFT", 6, -8)
    row.title = text(row, "GameFontHighlight")
    local marker = text(row, "GameFontNormal")
    marker:SetPoint("TOPRIGHT", -6, -6)
    marker:SetText("›")
    row.detail = text(row, "GameFontHighlightSmall")
    row.detail:SetTextColor(.78, .81, .83)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnEnter", showItemTip)
    row:SetScript("OnLeave", hideItemTip)
    row:SetScript("OnClick", function(self)
        if self.item and HandleModifiedItemClick and HandleModifiedItemClick(itemLink(self.item)) then return end
        openDetail(slots[index])
    end)
    rows[index] = row
end

local function button(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 25)
    b:SetText(label)
    return b
end

-- Checkboxes are a draft until Apply. Reopening reads the committed state so
-- closing the menu (or refreshing or switching specs) discards pending edits.
local function toggleSources()
    if sources.menu:IsShown() then sources.menu:Hide(); return end
    menu:Hide()
    for _, check in ipairs(sources.checks) do check:SetChecked(A.SourceEnabled(check.key)) end
    sources.unconfirmed:SetChecked(A.UnconfirmedSourcesEnabled())
    sources.menu:Show()
end

local function applySources()
    local leads = not not sources.unconfirmed:GetChecked()
    local all, changed = true, leads ~= A.UnconfirmedSourcesEnabled()
    for _, check in ipairs(sources.checks) do
        local enabled = not not check:GetChecked()
        if not enabled then all = false end
        if A.SourceEnabled(check.key) ~= enabled then changed = true end
    end
    sources.menu:Hide()
    if not changed then return end
    A.SetUnconfirmedSourcesEnabled(leads)
    if all then
        A.ResetSourceFilters()
    else
        for _, check in ipairs(sources.checks) do
            local enabled = not not check:GetChecked()
            if A.SourceEnabled(check.key) ~= enabled then A.SetSourceEnabled(check.key, enabled) end
        end
    end
    scan()
end

local function buildSources()
    sources.button = button(frame, "Sources", 145)
    sources.button:SetPoint("TOPRIGHT", -38, -8)
    sources.button:SetScript("OnClick", toggleSources)
    local panel = CreateFrame("Frame", nil, frame)
    sources.menu = panel
    panel:SetFrameLevel(frame:GetFrameLevel() + 30)
    panel:SetPoint("TOPRIGHT", sources.button, "BOTTOMRIGHT", 0, -2)
    panel:SetSize(282, 135 + #A.SourceMethods * 24)
    panel:EnableMouse(true)
    colorBackground(panel, .09, .115, .14, 1)
    local caption = text(panel, "GameFontHighlightSmall")
    caption:SetPoint("TOPLEFT", 10, -10)
    caption:SetText("Equipped gear and bag items always count.\nDungeon quests need both Dungeons and Quests.")
    local function checkbox(labelText, y)
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", 7, y)
        check:SetHitRectInsets(0, -224, 0, 0)
        local label = text(check, "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(labelText)
        return check
    end
    for i, method in ipairs(A.SourceMethods) do
        local check = checkbox(method.label, -45 - 24 * (i - 1))
        check.key = method.key
        sources.checks[i] = check
    end
    sources.unconfirmed = checkbox("Include unconfirmed sources", -50 - #A.SourceMethods * 24)
    local hint = text(panel, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", sources.unconfirmed, "BOTTOMLEFT", 3, -1)
    hint:SetText("Adds leads whose Forever source is unverified.")
    local all = button(panel, "Select all", 75)
    all:SetPoint("BOTTOMLEFT", 8, 7)
    all:SetScript("OnClick", function()
        for _, check in ipairs(sources.checks) do check:SetChecked(true) end
    end)
    local ownedOnly = button(panel, "Owned only", 84)
    ownedOnly:SetPoint("LEFT", all, "RIGHT", 3, 0)
    ownedOnly:SetScript("OnClick", function()
        for _, check in ipairs(sources.checks) do check:SetChecked(false) end
        sources.unconfirmed:SetChecked(false)
    end)
    local apply = button(panel, "Apply", 74)
    apply:SetPoint("BOTTOMRIGHT", -8, 7)
    apply:SetScript("OnClick", applySources)
    panel:Hide()
end

local function buildDetail()
    local pane = CreateFrame("Frame", nil, frame)
    detail.frame = pane
    pane:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", -2, -7)
    pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 12)
    local back = button(pane, "All slots", 72)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetScript("OnClick", closeDetail)
    detail.title = text(pane, "GameFontNormalLarge", "CENTER")
    detail.title:SetPoint("LEFT", back, "RIGHT", 6, 0)
    local nextSlot = button(pane, "Next slot", 76)
    nextSlot:SetPoint("TOPRIGHT", 0, 0)
    nextSlot:SetScript("OnClick", function() adjacentSlot(1) end)
    local prevSlot = button(pane, "Prev slot", 76)
    prevSlot:SetPoint("RIGHT", nextSlot, "LEFT", -3, 0)
    prevSlot:SetScript("OnClick", function() adjacentSlot(-1) end)
    detail.title:SetPoint("RIGHT", prevSlot, "LEFT", -6, 0)
    detail.ranked = button(pane, "Ranked gear", 126)
    detail.ranked:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -6)
    detail.ranked:SetScript("OnClick", function() changeTab("ranked") end)
    detail.targets = button(pane, "Paths to unlock", 148)
    detail.targets:SetPoint("LEFT", detail.ranked, "RIGHT", 4, 0)
    detail.targets:SetScript("OnClick", function() changeTab("locked") end)
    detail.showAll = button(pane, "Show all", 80)
    detail.showAll:SetPoint("LEFT", detail.targets, "RIGHT", 4, 0)
    detail.showAll:SetScript("OnClick", function()
        detail.all = true
        A.RefreshSlotDetail()
    end)
    detail.showAll:Hide()

    detail.previous = button(pane, "Previous", 76)
    detail.previous:SetPoint("BOTTOMLEFT", 0, 0)
    detail.previous:SetScript("OnClick", function() changePage(-1) end)
    detail.next = button(pane, "Next", 76)
    detail.next:SetPoint("BOTTOMRIGHT", 0, 0)
    detail.next:SetScript("OnClick", function() changePage(1) end)
    detail.pageText = text(pane, "GameFontHighlightSmall", "CENTER")
    detail.pageText:SetPoint("LEFT", detail.previous, "RIGHT", 5, 0)
    detail.pageText:SetPoint("RIGHT", detail.next, "LEFT", -5, 0)

    detail.scroll = CreateFrame("ScrollFrame", "WoWBestDetailScroll", pane, "UIPanelScrollFrameTemplate")
    detail.scroll:SetPoint("TOPLEFT", detail.ranked, "BOTTOMLEFT", 0, -5)
    detail.scroll:SetPoint("BOTTOMRIGHT", detail.next, "TOPRIGHT", -21, 5)
    detail.content = CreateFrame("Frame", nil, detail.scroll)
    detail.content:SetSize(1, 1)
    detail.scroll:SetScrollChild(detail.content)
    detail.scroll:HookScript("OnSizeChanged", renderDetail)
    detail.scroll:EnableMouseWheel(true)
    detail.scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 50)))
    end)
    pane:Hide()
end

local function build()
    frame = CreateFrame("Frame", "WoWBestGearFrame", UIParent)
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(math.min(610, UIParent:GetWidth() - 16), math.min(635, UIParent:GetHeight() - 24))
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    colorBackground(frame, .055, .064, .075, .97)

    local title = text(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 17, -14)
    title:SetText("WoWBest")
    context = text(frame, "GameFontHighlight")
    context:SetPoint("LEFT", title, "RIGHT", 14, 0)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() frame:Hide() end)
    buildSources()
    bagAlertButton = button(frame, bagAlertLabel(), 108)
    bagAlertButton:SetPoint("RIGHT", sources.button, "LEFT", -4, 0)
    bagAlertButton:SetScript("OnClick", function() A.SetBagAlertsEnabled(not A.BagAlertsEnabled()) end)

    local label = text(frame, "GameFontNormal")
    label:SetPoint("TOPLEFT", 17, -49)
    label:SetText("Spec")
    profileButton = button(frame, "", math.min(238, frame:GetWidth() - 305))
    profileButton:SetPoint("LEFT", label, "RIGHT", 8, 0)
    profileButton:SetScript("OnClick", toggleMenu)
    profileButton:SetScript("OnEnter", function(self)
        local p = A.ActiveProfile()
        if not (p and p.class == "DRUID" and p.key == "restoration") then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for _, line in ipairs(healingReport(p)) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    profileButton:SetScript("OnLeave", hideItemTip)
    targetButton = button(frame, "", 147)
    targetButton:SetPoint("LEFT", profileButton, "RIGHT", 4, 0)
    targetButton:SetScript("OnClick", function()
        local db = settings()
        if db.targetType == "Humanoid" then db.targetType = nil else db.targetType = "Humanoid" end
        scoringChanged()
    end)
    local refresh = button(frame, "Refresh", 72)
    refresh:SetPoint("RIGHT", frame, "TOPRIGHT", -16, -55)
    refresh:SetScript("OnClick", scan)

    statusText = text(frame, "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", 17, -78)
    statusText:SetPoint("TOPRIGHT", -18, -78)
    statusText:SetTextColor(.84, .85, .86)
    statusText:SetText(lastStatus)

    scroll = CreateFrame("ScrollFrame", "WoWBestGearScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", -2, -9)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 15)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    for i = 1, #slots do makeRow(i) end
    scroll:HookScript("OnSizeChanged", drawRows)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        menu:Hide()
        sources.menu:Hide()
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 50)))
    end)

    buildDetail()

    menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameLevel(frame:GetFrameLevel() + 25)
    menu:SetPoint("TOPLEFT", profileButton, "BOTTOMLEFT", 0, -1)
    menu:SetWidth(profileButton:GetWidth())
    menu:EnableMouse(true)
    colorBackground(menu, .09, .115, .14, 1)
    menu:Hide()
    frame:SetScript("OnShow", scan)
    frame:SetScript("OnHide", function()
        sources.menu:Hide()
        closeDetail()
        menu:Hide()
        if A.StopScan then A.StopScan() end
    end)
    table.insert(UISpecialFrames, "WoWBestGearFrame")
end

SLASH_WOWBEST1 = "/wowbest"
SLASH_WOWBEST2 = "/wbest"
SlashCmdList.WOWBEST = function(message)
    local command, option = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if command == "healing" then
        local p = A.ActiveProfile()
        if not (p and p.class == "DRUID" and p.key == "restoration") then
            print("WoWBest: Select Restoration on your Druid in /wowbest to inspect healing weights.")
            return
        end
        if option ~= "" then
            if not paceNames[option] then print("WoWBest: /wowbest healing short, dungeon or sustained"); return end
            selectHealingPace(option)
            p = A.ActiveProfile()
        end
        for _, line in ipairs(healingReport(p)) do print("WoWBest: " .. line) end
        return
    end
    if command == "alerts" then
        if option == "on" then A.SetBagAlertsEnabled(true)
        elseif option == "off" then A.SetBagAlertsEnabled(false)
        elseif option == "" then A.SetBagAlertsEnabled(not A.BagAlertsEnabled())
        else print("WoWBest: /wowbest alerts on or /wowbest alerts off"); return end
        print("WoWBest: " .. bagAlertLabel())
        return
    end
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
