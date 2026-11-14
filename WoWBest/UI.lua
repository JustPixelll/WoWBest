local addonName, A = ...

local frame, scroll, content, profileButton, menu, context, statusText
local rows, menuButtons = {}, {}
local result, lastStatus = nil, ""
local slots = {1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18}

local function settings()
    if type(WoWBestCharacterDB) ~= "table" then WoWBestCharacterDB = {} end
    return WoWBestCharacterDB
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

function A.ActiveProfile()
    local profile = selectedProfile(A.GetPlayer())
    return profile
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
        row.title:SetWidth(math.max(1, width - indent - 12))
        row.detail:SetWidth(math.max(1, width - indent - 12))
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", indent, -7)
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)

        local detail
        if item then
            row.title:SetText(item.link or item.name or ("Item " .. item.id))
            row.title:SetTextColor(1, 1, 1)
            detail = item.source or "Source unknown"
        else
            local main = result and result[16]
            local label = result and "No eligible item found" or "—"
            if slot == 17 and main and main.loc == "INVTYPE_2HWEAPON" then
                label = "Occupied by two-handed weapon"
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

local function updateHeader()
    if not frame then return end
    local player = A.GetPlayer()
    local profile, mode = selectedProfile(player)
    local className = UnitClass("player") or player.class or "Unknown class"
    context:SetText(("Level %s %s"):format(player.level or "?", className))
    if profile then
        local label = profile.name
        if mode == "detected" then label = "Auto: " .. label end
        if mode == "default" then label = "Default: " .. label end
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
        drawRows()
    end
end

local function scan()
    menu:Hide()
    updateHeader()
    local profile = A.ActiveProfile()
    A.UpdateDisplay(nil, profile and "Looking up gear…" or "No gear profile is available for this class.")
    if profile then A.StartScan(profile) end
end

local function selectProfile(key)
    settings().profile = key
    scan()
end

local function addMenuButton(index)
    local entry = CreateFrame("Button", nil, menu)
    entry:SetSize(menu:GetWidth() - 10, 23)
    entry:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 23)
    entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    entry.label = text(entry, "GameFontHighlight")
    entry.label:SetPoint("LEFT", 6, 0)
    entry.label:SetPoint("RIGHT", -6, 0)
    entry:SetScript("OnClick", function(self) selectProfile(self.key) end)
    menuButtons[index] = entry
    return entry
end

local function toggleMenu()
    if menu:IsShown() then menu:Hide() return end
    local profiles = A.Profiles[A.GetPlayer().class] or {}
    local saved = settings().profile
    local manual = findProfile(profiles, saved)
    for i = 1, #profiles + 1 do
        local profile = profiles[i - 1]
        local entry = menuButtons[i] or addMenuButton(i)
        local selected = (profile and profile == manual) or (not profile and not manual)
        entry.key = profile and profile.key or nil
        entry.label:SetText((selected and "|cffffd100" or "|cffffffff") ..
            (profile and profile.name or "Auto (active talents)") .. "|r")
        entry:Show()
    end
    for i = #profiles + 2, #menuButtons do menuButtons[i]:Hide() end
    menu:SetHeight(10 + (#profiles + 1) * 23)
    menu:Show()
end

local function makeRow(index)
    local row = CreateFrame("Button", nil, content)
    if index % 2 == 1 then colorBackground(row, .30, .36, .40, .16) end
    row.slot = text(row, "GameFontNormalSmall")
    row.slot:SetPoint("TOPLEFT", 6, -8)
    row.title = text(row, "GameFontHighlight")
    row.detail = text(row, "GameFontHighlightSmall")
    row.detail:SetTextColor(.78, .81, .83)
    row:SetScript("OnEnter", function(self)
        if self.item then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink(self.item))
            local note = A.EffectNotes and A.EffectNotes[self.item.id]
            if note then GameTooltip:AddLine("WoWBest estimate: " .. note, .75, .88, 1, true) end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row:SetScript("OnClick", function(self)
        if not self.item then return end
        local link = itemLink(self.item)
        if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
        if SetItemRef then
            local reference = link:match("|H([^|]+)|h") or ("item:" .. self.item.id)
            SetItemRef(reference, link, "LeftButton")
        end
    end)
    rows[index] = row
end

local function button(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 25)
    b:SetText(label)
    return b
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

    local label = text(frame, "GameFontNormal")
    label:SetPoint("TOPLEFT", 17, -49)
    label:SetText("Spec")
    profileButton = button(frame, "", math.min(238, frame:GetWidth() - 150))
    profileButton:SetPoint("LEFT", label, "RIGHT", 8, 0)
    profileButton:SetScript("OnClick", toggleMenu)
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
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 50)))
    end)

    menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameLevel(frame:GetFrameLevel() + 25)
    menu:SetPoint("TOPLEFT", profileButton, "BOTTOMLEFT", 0, -1)
    menu:SetWidth(profileButton:GetWidth())
    menu:EnableMouse(true)
    colorBackground(menu, .09, .115, .14, 1)
    menu:Hide()
    frame:SetScript("OnShow", scan)
    frame:SetScript("OnHide", function()
        menu:Hide()
        if A.StopScan then A.StopScan() end
    end)
    table.insert(UISpecialFrames, "WoWBestGearFrame")
end

SLASH_WOWBEST1 = "/wowbest"
SLASH_WOWBEST2 = "/wbest"
SlashCmdList.WOWBEST = function()
    if not frame then build() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
