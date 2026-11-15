-- Native tooltip-to-score integration. WoWBest modules are loaded in release
-- TOC order; the fixtures below implement only client-facing WoW interfaces.
local A, frames, timers = {}, {}, {}
local post, now = nil, 0
Enum = {TooltipDataType = {Item = 0}, TooltipDataLineType = {ItemName = 22, EquipSlot = 21}}
SlashCmdList, UISpecialFrames = {}, {}
WoWBestCharacterDB = {profile = "arms"}
function CreateFrame()
    local f = {events = {}}
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(event, fn) self[event] = fn end
    frames[#frames + 1] = f
    return f
end
local function emit(event)
    for _, f in ipairs(frames) do if f.OnEvent and f.events[event] then f:OnEvent(event) end end
end
C_Timer = {After = function(delay, fn) timers[#timers + 1] = {when = now + delay, fn = fn} end}
local function advance(delta)
    now = now + delta
    while true do
        local at
        for i, t in ipairs(timers) do if t.when <= now then at = i; break end end
        if not at then return end
        local t = table.remove(timers, at)
        t.fn()
    end
end
TooltipDataProcessor = {AddTooltipPostCall = function(kind, fn) assert(kind == 0); post = fn end}
function InCombatLockdown() return false end
function GetTime() return now end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitRace() return "Human", "Human", 1 end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 19 end
function IsPlayerSpell(id) return id == 9077 end

local gear, equipped, requests = {}, {[5] = 10399, [7] = 10400, [10] = 999001}, {}
local hiddenID, use, protected = nil, true, {}
function issecretvalue(v) return rawequal(v, protected) end
local function item(id, loc, strength, armor)
    local str = "item:" .. id
    gear[id] = {id = id, link = str, loc = "INVTYPE_" .. loc, name = "Test " .. id,
        stats = {ITEM_MOD_STRENGTH_SHORT = strength, RESISTANCE0_NAME = armor}}
end
item(10399, "CHEST", 4, 89)
item(10400, "LEGS", 6, 73)
item(10401, "HAND", 1, 52)
item(999001, "HAND", 5, 52)
local function byLink(link)
    return gear[tonumber(tostring(link):match("item:(%d+)")) or link]
end
function GetInventoryItemID(_, slot) return equipped[slot] end
function GetInventoryItemLink(_, slot)
    local id = equipped[slot]
    if id and id ~= hiddenID then return gear[id].link end
end
C_Item = {
    GetItemInfoInstant = function(link)
        local g = byLink(link)
        if g then return g.id, nil, nil, g.loc, nil, 4, 2 end
    end,
    GetItemInfo = function(link)
        local g = byLink(link)
        return g.name, g.link, 2, 19, 14, nil, nil, 1, g.loc, nil, nil, 4, 2
    end,
    GetItemStats = function(link) return byLink(link).stats end,
    GetItemUniquenessByID = function() return false end,
    RequestLoadItemDataByID = function(id) requests[id] = (requests[id] or 0) + 1 end,
}
C_PlayerInfo = {CanUseItem = function(id) return id ~= 10401 or use end}
C_TooltipInfo = {GetHyperlink = function(link)
    return {lines = {{type = 22, leftText = byLink(link).name}, {type = 21, leftText = byLink(link).loc}}}
end}

GameTooltip = {lines = {}, scripts = {}, shown = false}
function GameTooltip:HookScript(name, fn) self.scripts[name] = fn end
function GameTooltip:IsShown() return self.shown end
function GameTooltip:Show() self.shown = true end
function GameTooltip:GetPrimaryTooltipData() return self.data end
function GameTooltip:GetPrimaryTooltipInfo() return self.info end
function GameTooltip:AddLine(content) self.lines[#self.lines + 1] = content end
function GameTooltip:RebuildFromTooltipInfo()
    self.lines = {}
    if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
    post(self, self.data)
    self:Show()
end
local function hover(id, getter, ...)
    GameTooltip.data = {id = id, type = 0, hyperlink = gear[id].link}
    GameTooltip.info = {getterName = getter, getterArgs = {...}, tooltipData = GameTooltip.data}
    GameTooltip:RebuildFromTooltipInfo()
    advance(0)
    return table.concat(GameTooltip.lines, "\n")
end
for line in io.lines("WoWBest/WoWBest.toc") do
    if line:match("%.lua$") then assert(loadfile("WoWBest/" .. line))("WoWBest", A) end
end
assert(post, "The installable TOC must register the native tooltip handler")
-- The worn gloves are individually four points better. Completing Defias
-- Leather adds 15 AP in the Humanoid scenario, or 7.5 Arms points.
hiddenID = 10399
assert(hover(10401, "GetBagItem", 0, 1) == "" and requests[10399] == 1)
hiddenID = nil
advance(.26)
local general = table.concat(GameTooltip.lines, "\n")
assert(general:find("Downgrade", 1, true) and general:find("-4.0 pts", 1, true), general)
WoWBestCharacterDB.targetType = "Humanoid"
A.InvalidateUpgradeTooltips()
advance(0)
local conditional = table.concat(GameTooltip.lines, "\n")
assert(conditional:find("Upgrade", 1, true) and conditional:find("+3.5 pts", 1, true), conditional)
-- Inventory getter marks a worn physical copy. A forbidden candidate must
-- never be promoted just because its modeled humanoid bonus is attractive.
assert(hover(999001, "GetInventoryItem", "player", 10):find("Equipped", 1, true))
use = false
emit("SKILL_LINES_CHANGED")
advance(0)
local forbidden = hover(10401, "GetMerchantItem", 4)
assert(forbidden:find("Unavailable", 1, true) and not forbidden:find("Upgrade", 1, true), forbidden)
print("Native upgrade integration passed: cold equipped link, set-sensitive percentage, worn item, ineligible item.")
