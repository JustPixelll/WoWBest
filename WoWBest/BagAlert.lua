local _, A = ...

local frame, heading, summary, pages
local rows, current, timer, page = {}, nil, nil, 1

local function cancelTimer()
    if timer then
        timer:Cancel()
        timer = nil
    end
end

local function hideTips()
    for _, row in ipairs(rows) do
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    end
end

function A.HideBagUpgrade()
    cancelTimer()
    current = nil
    if frame then hideTips(); frame:Hide() end
end

local function hideAfter(seconds)
    cancelTimer()
    local expected = current
    timer = C_Timer.NewTimer(seconds, function()
        if current == expected then A.HideBagUpgrade() end
    end)
end

local function showItemTip(row)
    if not current or not row.item or (InCombatLockdown and InCombatLockdown()) then return end
    cancelTimer()
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(row.item.link or ("item:" .. row.item.id))
    GameTooltip:Show()
end

local function makeRow()
    local row = CreateFrame("Button", nil, frame)
    row:SetWidth(frame:GetWidth() - 28)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 0, 0)
    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.title:SetPoint("LEFT", 26, 0)
    row.title:SetWidth(row:GetWidth() - 26)
    row.title:SetJustifyH("LEFT")
    row:SetScript("OnEnter", showItemTip)
    row:SetScript("OnLeave", function()
        if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
        if current then hideAfter(4) end
    end)
    row:SetScript("OnClick", function()
        if not current or not row.item or (InCombatLockdown and InCombatLockdown()) then return end
        local link = row.item.link or ("item:" .. row.item.id)
        if SetItemRef then SetItemRef(link:match("|H([^|]+)|h") or link, link, "LeftButton") end
    end)
    return row
end

local function draw()
    hideTips()
    local parts = current.parts
    if not parts or #parts == 0 then parts = {{item = current.item, slot = current.result.slot}} end
    local joint = #parts > 1
    local y = 11 + heading:GetStringHeight()
    for i, row in ipairs(rows) do
        local part = parts[(page - 1) * #rows + i]
        row.item = part and part.item
        if row.item then
            local label = row.item.link or row.item.name or ("Item " .. row.item.id)
            local slot = part.slot and A.SlotNames[part.slot]
            row.title:SetText(joint and slot and ("|cffe8c57c" .. slot .. "|r  " .. label) or label)
            row.icon:SetTexture(row.item.texture or 134400)
            local height = math.max(24, row.title:GetStringHeight() + 4)
            row:SetPoint("TOPLEFT", 12, -y)
            row:SetHeight(height)
            row:Show()
            y = y + height
        else
            row:Hide()
        end
    end
    local totalPages = math.ceil(#parts / #rows)
    if totalPages > 1 then
        pages:SetText(("Items %d/%d  ›"):format(page, totalPages))
        pages:Show()
    else
        pages:Hide()
    end
    local result = current.result
    local hasPercent = result.percent and result.percent > 0
    local measure, unit = hasPercent and result.percent or result.delta, hasPercent and "%" or " pts"
    local gain = measure < .1 and ("<0.1" .. unit) or ("+%.1f%s"):format(measure, unit)
    local details = (joint and "Together: " or "") .. gain .. " equipped score"
    if not joint then details = details .. " · " .. (A.SlotNames[result.slot] or "Gear") end
    if current.profile and current.profile.name then details = details .. " · " .. current.profile.name end
    if result.unmodeledEffect then details = details .. "\nItem or set effect is unscored." end
    summary:SetPoint("TOPLEFT", 12, -y - 3)
    summary:SetWidth(frame:GetWidth() - (totalPages > 1 and 120 or 24))
    summary:SetText(details)
    frame:SetHeight(y + 12 + math.max(totalPages > 1 and 22 or 0, summary:GetStringHeight()))
    frame:Show()
    for _, row in ipairs(rows) do
        if row.item and row:IsMouseOver() then showItemTip(row); return end
    end
    hideAfter(14)
end

local function build()
    frame = CreateFrame("Frame", "WoWBestBagAlert", UIParent)
    frame:Hide()
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(math.min(336, UIParent:GetWidth() - 20))
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
    frame:SetClampedToScreen(true)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.055, .070, .078, .96)
    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetPoint("TOPLEFT")
    stripe:SetPoint("BOTTOMLEFT")
    stripe:SetWidth(3)
    stripe:SetColorTexture(.36, .83, .52, 1)

    heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", 12, -8)
    heading:SetWidth(frame:GetWidth() - 44)
    heading:SetJustifyH("LEFT")
    rows[1], rows[2] = makeRow(), makeRow()
    summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    summary:SetTextColor(.83, .86, .89)
    summary:SetJustifyH("LEFT")
    pages = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    pages:SetSize(92, 22)
    pages:SetPoint("BOTTOMRIGHT", -9, 5)
    pages:SetScript("OnClick", function()
        if not current then return end
        local parts = current.parts
        if parts and #parts > #rows then
            page = page % math.ceil(#parts / #rows) + 1
            draw()
        end
    end)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        local dismissed = current
        A.HideBagUpgrade()
        if dismissed and A.DismissBagUpgrade then A.DismissBagUpgrade(dismissed) end
    end)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_LEAVING_WORLD")
    frame:SetScript("OnEvent", A.HideBagUpgrade)
end

function A.ShowBagUpgrade(alert)
    if not alert or (InCombatLockdown and InCombatLockdown()) or (A.BagAlertsEnabled and not A.BagAlertsEnabled()) then
        A.HideBagUpgrade()
        return
    end
    local item, result = alert.item, alert.result
    if not (item and item.id and result and result.kind == "upgrade" and result.delta and result.delta > 0) then
        A.HideBagUpgrade()
        return
    end
    if not frame then build() end
    current, page = alert, 1
    local count = alert.count or 1
    if result.unmodeledEffect then
        heading:SetText("WoWBest · Possible bag upgrade")
        heading:SetTextColor(1, .79, .41)
    else
        heading:SetText(count > 1 and ("WoWBest · %d new bag upgrades"):format(count) or "WoWBest · Bag upgrade")
        heading:SetTextColor(.56, .92, .67)
    end
    draw()
end
