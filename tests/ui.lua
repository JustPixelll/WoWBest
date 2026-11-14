-- Exercise actual row/button handlers and asynchronous redraws without a WoW client.
local objects, methods = {}, {}
local function widget(kind, name, parent)
    local object = setmetatable({
        kind = kind, name = name, parent = parent, text = "", scripts = {}, shown = true,
        width = 580, height = 700, enabled = true,
    }, {__index = methods})
    objects[#objects + 1] = object
    return object
end
for _, name in ipairs({
    "SetPoint", "SetAllPoints", "SetColorTexture", "SetJustifyH", "SetTextColor", "SetFrameStrata",
    "SetClampedToScreen", "SetMovable", "EnableMouse", "RegisterForDrag", "SetHighlightTexture",
    "EnableMouseWheel", "SetHitRectInsets", "SetVerticalScroll", "SetScrollChild", "StopMovingOrSizing", "SetFrameLevel",
}) do methods[name] = function() end end
function methods:CreateTexture() return widget("Texture", nil, self) end
function methods:CreateFontString() return widget("Text", nil, self) end
function methods:GetFrameLevel() return 3 end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetWidth(w) self.width = w end
function methods:SetHeight(h) self.height = h end
function methods:SetSize(w, h) self.width, self.height = w, h end
function methods:SetText(t) self.text = t end
function methods:SetChecked(v) self.checked = v end
function methods:GetChecked() return self.checked end
function methods:GetStringHeight() return math.ceil(math.max(1, #self.text) / 90) * 15 end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetScript(event, callback) self.scripts[event] = callback end
methods.HookScript = methods.SetScript
function methods:Show()
    local was = self.shown
    self.shown = true
    if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local was = self.shown
    self.shown = false
    if was and self.scripts.OnHide then self.scripts.OnHide(self) end
end
local function byText(query, exact)
    for _, object in ipairs(objects) do
        if object:IsVisible() and (object.text == query or (not exact and object.text:find(query, 1, true))) then return object end
    end
end
local function click(object)
    assert(object and object.enabled and object:IsVisible(), "button unavailable")
    if object.kind == "CheckButton" then object:SetChecked(not object:GetChecked()) end
    if object.scripts.OnClick then object.scripts.OnClick(object) end
end

UIParent, CreateFrame, SlashCmdList, UISpecialFrames = widget("Frame"), widget, {}, {}
function UnitClass() return "Mage" end
function GetInventoryItemLink(_, slot) return slot == 1 and "|Hitem:9|h[Cloth hat]|h" end
GameTooltip = widget("Tooltip")
local ref
function SetItemRef(link) ref = link end
local profile, requests, cancelled = {name = "Frost", key = "frost"}, {}, 0
local A = {Profiles = {MAGE = {profile}}, SlotNames = {}}
for i = 1, 18 do A.SlotNames[i] = "Slot " .. i end
A.SlotNames[1], A.SlotNames[16], A.SlotNames[17] = "Head", "Main hand", "Off hand"
function A.GetPlayer() return {class = "MAGE", level = 19} end
function A.DetectProfile() return "frost" end
local scanProfile, scans = nil, 0
function A.StartScan(active) scanProfile, scans = active, scans + 1 end
assert(loadfile("WoWBest/Sources.lua"))("WoWBest", A)
function A.CancelSlotRequest() cancelled = cancelled + 1 end
function A.UnlockCount(slot) return (slot == 1 or slot == 17) and 1 or 0 end
function A.RequestSlot(slot, callback) requests[#requests + 1] = {slot = slot, callback = callback} end
function A.ScoreBreakdown() return {{label = "Stamina", amount = 4, weight = .5, points = 2}} end
function A.Score() return 2 end
local setBonus = {key = "42/2", name = "Silkweave", threshold = 2, modeled = true, score = 6, description = "+6 health"}
function A.ActiveSetBonuses(loadout) return loadout[16] and loadout[16].id == 20 and {setBonus} or {} end
assert(loadfile("WoWBest/UI.lua"))("WoWBest", A)
SlashCmdList.WOWBEST()
assert(scanProfile == profile and byText("Target: General PvE"))
WoWBestCharacterDB.profile = "frost"
click(byText("Target: General PvE"))
assert(scanProfile ~= profile and scanProfile.key == "frost" and scanProfile.targetType == "Humanoid")
assert(profile.targetType == nil and WoWBestCharacterDB.profile == "frost")
local baseline = {[16] = {id = 19, name = "Greatstaff", loc = "INVTYPE_2HWEAPON"}}
local otherMain = {id = 20, name = "One-handed sword"}
A.UpdateDisplay(baseline, "Ready")
assert(byText("1 path to unlock") and byText("Occupied by two-handed weapon"))

click(byText("Head").parent) -- empty slot must still open
assert(requests[1].slot == 1)
requests[1].callback(nil, nil, nil, nil, "Still loading")
assert(byText("Still loading"))
local locked = {{id = 2, name = "Green Tinted Goggles", requirement = "Requires Engineering 150", source = "Crafting", statSummary = "+8 Stamina"}}
requests[1].callback(nil, baseline, profile, locked, "Comparing loadouts")
assert(byText("Requires Engineering 150") and byText("Green Tinted Goggles") and byText("+8 Stamina"))
click(byText("Green Tinted Goggles").parent)
assert(ref == "item:2")
click(byText("Ranked gear"))
requests[1].callback({}, baseline, profile, locked)
assert(byText("No eligible alternative") and byText("Currently equipped: |Hitem:9|h[Cloth hat]|h"))
assert(not byText("Green Tinted Goggles"))
click(byText("All slots"))

click(byText("Off hand").parent)
local choices = {}
for i = 1, 7 do
    local item = {id = 100 + i, name = "Wand holder " .. i, source = "Smith in town"}
    choices[i] = {item = item, loadout = {[16] = otherMain, [17] = item}, total = 100 - i, delta = -i, rank = i}
end
requests[2].callback(choices, baseline, scanProfile, locked)
assert(byText("Frost (Humanoids)") and byText("Target: Humanoids"))
assert(byText("Best loadout: 100 pts") and byText("-1 vs best") and byText("occupies both hands"))
assert(byText("Greatstaff → One-handed sword") and byText("Gains Silkweave 2-piece"))
assert(byText("Stamina 4 × 0.5 = 2") and byText("1–5 of 7"))
for _, object in ipairs(objects) do if object:IsVisible() and object.text == "Next" then click(object); break end end
assert(byText("6–7 of 7") and byText("Wand holder 7"))
click(byText("Prev slot"))
assert(requests[3].slot == 16)
requests[2].callback(choices, baseline, profile, {}, "obsolete")
assert(not byText("Wand holder 7"))
A.UpdateDisplay(nil, "Player changed")
requests[3].callback(choices, baseline, profile, {}, "obsolete")
assert(byText("Player changed") and not byText("Wand holder 1"))
A.RefreshSlotDetail()
assert(#requests == 4 and requests[4].slot == 16)
SlashCmdList.WOWBEST()
requests[4].callback(choices, baseline, profile, {}, "obsolete")
assert(not A.IsVisible() and cancelled >= 4)
SlashCmdList.WOWBEST()
assert(scanProfile.targetType == "Humanoid" and byText("Target: Humanoids"))
click(byText("Target: Humanoids"))
assert(scanProfile == profile and WoWBestCharacterDB.targetType == nil and WoWBestCharacterDB.profile == "frost")
-- Staging several methods needs one rescan. Unapplied edits must disappear.
local previousScans = scans
click(byText("Sources: All"))
local quests = byText("Quests", true).parent
local dungeons = byText("Dungeons", true).parent
assert(quests:GetChecked() and dungeons:GetChecked())
click(quests)
click(dungeons)
assert(A.SourceEnabled("Quest") and scans == previousScans)
click(byText("Sources: All")) -- discard
click(byText("Sources: All"))
assert(quests:GetChecked() and dungeons:GetChecked() and byText("bag items always count"))
click(quests)
click(dungeons)
click(byText("Apply"))
assert(scans == previousScans + 1 and not A.SourceEnabled("Dungeon") and A.SourceEnabled("Auction"))
local twoOff = ("Sources: %d/%d"):format(#A.SourceMethods - 2, #A.SourceMethods)
assert(byText(twoOff))
click(byText(twoOff))
click(byText("Apply"))
assert(scans == previousScans + 1) -- unchanged settings do not start a scan

-- Apply with the detailed view open; late results from the old filter must be ignored.
A.UpdateDisplay(baseline, "Ready")
click(byText("Head").parent)
local stale = requests[#requests].callback
click(byText(twoOff))
click(byText("Owned only"))
click(byText("Apply"))
assert(not A.SourceEnabled("Auction") and byText("Sources: Owned only") and scans == previousScans + 2)
stale(choices, baseline, profile, {}, "obsolete")
assert(not byText("Wand holder 1"))
SlashCmdList.WOWBEST()
SlashCmdList.WOWBEST()
assert(byText("Sources: Owned only") and byText("Target: General PvE"))
click(byText("Sources: Owned only"))
click(byText("Select all"))
click(byText("Apply"))
assert(byText("Sources: All") and A.SourceEnabled("Quest") and WoWBestCharacterDB.disabledSources == nil)
assert(WoWBestCharacterDB.profile == "frost" and scanProfile == profile)
SlashCmdList.WOWBEST()
print("UI click, paging, scoring, filters, locked targets and async cancellation tests passed.")
