local A, objects, timers = {}, {}, {}
local combat, enabled, dismissal, ref = false, true, nil, nil
function InCombatLockdown() return combat end
function A.BagAlertsEnabled() return enabled end
function A.DismissBagUpgrade(alert) dismissal = alert end
function SetItemRef(_, link) ref = link end
A.SlotNames = {[1] = "Head", [12] = "Ring 2"}
C_Timer = {NewTimer = function(delay, run)
    local timer = {delay = delay, run = run, Cancel = function(t) t.cancelled = true end}
    timers[#timers + 1] = timer
    return timer
end}
local methods = {}
local function widget(kind, name, parent, template)
    local w = setmetatable({kind = kind, name = name, parent = parent, template = template, scripts = {},
        events = {}, shown = true, width = 800, str = ""}, {__index = methods})
    objects[#objects + 1] = w
    return w
end
for _, method in ipairs({"SetPoint", "SetAllPoints", "SetColorTexture", "SetFrameStrata", "SetClampedToScreen",
    "SetTextColor", "SetJustifyH", "SetTexture"}) do methods[method] = function() end end
function methods:SetWidth(w) self.width = w end
function methods:GetWidth() return self.width end
function methods:SetSize(w,h) self.width, self.height = w,h end
function methods:SetHeight(h) self.height = h end
function methods:GetStringHeight() return 15 end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetText(str) self.str = str end
function methods:SetScript(evt, fn) self.scripts[evt] = fn end
function methods:RegisterEvent(evt) self.events[evt] = true end
function methods:Hide() self.shown = false end
function methods:Show() self.shown = true end
function methods:CreateTexture() return widget("Texture",nil,self) end
function methods:CreateFontString() return widget("Font",nil,self) end
function methods:IsMouseOver() return self.hover end
function methods:SetOwner(owner) self.owner = owner end
function methods:IsOwned(owner) return self.owner == owner end
function methods:SetHyperlink(link) self.link = link end
CreateFrame, UIParent, GameTooltip = widget, widget("Root"), widget("GameTooltip")
assert(loadfile("WoWBest/BagAlert.lua"))("WoWBest", A)
local function offer(id, pct, count)
    return {
        key = "item:" .. id, count = count,
        item = {id = id, link = ("|Hitem:%d::::::7|h[Green goggles]|h"):format(id)},
        profile = {name = "Arms"},
        result = {kind = "upgrade", delta = 3.2, percent = pct, slot = 1},
    }
end
local function findText(fragment)
    for _, o in ipairs(objects) do if o:IsVisible() and o.str:find(fragment, 1, true) then return o end end
end
local a, b = offer(100, 1.2, 3), offer(101, nil, 1)
enabled = false; A.ShowBagUpgrade(a)
combat = true; enabled = true; A.ShowBagUpgrade(a)
assert(#objects == 2 and #timers == 0)
combat = false; A.ShowBagUpgrade(a)
local frame, itemButton, close
for _, o in ipairs(objects) do
    if o.name == "WoWBestBagAlert" then frame = o
    elseif o.template == "UIPanelCloseButton" then close = o
    elseif o.scripts.OnEnter and o.shown then itemButton = o end
end
assert(frame and frame.shown and itemButton and close)
assert(findText("3 new bag upgrades") and findText("+1.2% equipped score") and findText("Arms"))
assert(timers[1].delay == 14 and frame.events.PLAYER_REGEN_DISABLED)
local uncertain = offer(102, 2, 3)
uncertain.result.unmodeledEffect = true
A.ShowBagUpgrade(uncertain)
assert(findText("Possible bag upgrade") and findText("Item or set effect is unscored."))
A.ShowBagUpgrade(a)
assert(not findText("Possible bag upgrade") and not findText("effect is unscored"))
itemButton.scripts.OnEnter(itemButton)
assert(timers[1].cancelled and GameTooltip.link == a.item.link)
itemButton.scripts.OnClick(); assert(ref == a.item.link)
itemButton.scripts.OnLeave(); assert(timers[#timers].delay == 4 and not GameTooltip.shown)
local oldTimer = timers[#timers]
A.ShowBagUpgrade(b)
oldTimer.run()
assert(frame.shown and findText("+3.2 pts equipped score") and oldTimer.cancelled)
close.scripts.OnClick()
assert(dismissal == b and not frame.shown)
dismissal = nil; A.ShowBagUpgrade(a); frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
assert(not frame.shown and dismissal == nil)
A.ShowBagUpgrade(a); timers[#timers].run()
assert(not frame.shown and not dismissal)
local sword = {id = 103, link = "|Hitem:103::::::5|h[Training Sword]|h"}
local shield = {id = 104, link = "|Hitem:104|h[Ward Shield]|h"}
local joint = offer(sword.id, 2.5, 1)
A.SlotNames[16], A.SlotNames[17] = "Main hand", "Off hand"
joint.item, joint.result.slot = sword, 16
joint.parts = {{item = sword, slot = 16}, {item = shield, slot = 17}}
A.ShowBagUpgrade(joint)
local swordLabel, shieldLabel = findText("[Training Sword]"), findText("[Ward Shield]")
assert(swordLabel and shieldLabel and swordLabel.str:find("Main hand") and shieldLabel.str:find("Off hand"))
assert(findText("Together: +2.5% equipped score"))
shieldLabel.parent.scripts.OnEnter(shieldLabel.parent)
assert(GameTooltip.link == shield.link)
shieldLabel.parent.scripts.OnClick(); assert(ref == shield.link)
joint.parts[3] = {item = a.item, slot = 1}
A.ShowBagUpgrade(joint)
local more = assert(findText("Items 1/2"))
more.scripts.OnClick(); assert(findText("Items 2/2") and findText("[Green goggles]") and not findText("[Ward Shield]"))
more.scripts.OnClick(); assert(findText("[Training Sword]") and findText("[Ward Shield]"))
A.ShowBagUpgrade(b); assert(not findText("Items 1/2") and not findText("[Ward Shield]") and not findText("Together:"))
A.ShowBagUpgrade(a); enabled = false; A.ShowBagUpgrade(b)
assert(not frame.shown and not dismissal)
print("Bag popup: exact gear link, threshold summary, dismiss, expiry, disabled, stale timer and combat cleanup passed.")
