-- Level-31 healer relics. A personally crafted item can still be worn after
-- dropping its crafting profession. Its conditional effect has no fixed score.
local A = {}
for _, file in ipairs({"Catalog", "Profiles", "Effects", "Engine", "Character", "Gates", "Upgrade"}) do
    assert(loadfile("WoWBest/" .. file .. ".lua"))("WoWBest", A)
end
local items = {}
for _, row in ipairs(A.Catalog) do
    if A.UnscoredEffectNotes[row.id] and (not row.faction or row.faction == "Alliance") then
        items[row.id] = row
    end
end
local mushroom, tides = assert(items[249396]), assert(items[263411])
local function druid()
    return {level=31, class="DRUID", classID=11, faction="Alliance", raceID=4}
end
local rank = 0
C_SkillInfo = {GetSkillLineInfoByID=function() return {rank=rank} end}
C_QuestLog = {IsQuestFlaggedCompleted=function() return false end}
IsPlayerSpell = function(id) return id == mushroom.craftSpellID end
assert(not A.RouteAvailable(mushroom, druid()))
rank = 130
assert(A.RouteAvailable(mushroom, druid()))
assert(A.RouteAvailable(tides, druid()) and tides.questID == 5061)
rank = 0
assert(A.RouteAvailable({id=mushroom.id, owned=true}, druid()))
local function itemID(query) return tonumber(tostring(query):match("(%d+)")) end
C_Item = {
    GetItemInfo = function(query)
        local r = items[itemID(query)]
        return r.name, "item:" .. r.id, 2, r.itemLevel, r.minLevel, nil, nil, 1, "INVTYPE_RELIC", nil, nil, 4, 8
    end,
    GetItemStats = function() return {} end,
}
C_PlayerInfo = {CanUseItem = function() return true end}
C_TooltipInfo = {GetHyperlink=function(link)
    local row = items[itemID(link)]
    return {lines={{leftText=row.name}, {leftText="Relic"}}}
end}
local profile = A.ProfileForLevel(A.Profiles.DRUID[#A.Profiles.DRUID], 31)
assert(profile.key == "restoration")
local a = assert(A.ReadCandidate({id=mushroom.id, owned=true}, druid()))
local b = assert(A.ReadCandidate(tides, druid()))
for _, relic in ipairs({a, b}) do
    assert(relic.unmodeledEffect and A.Score(relic, profile) == 0)
    local swap = assert(A.CompareEquippedUpgrade(relic, {}, druid(), profile))
    assert(swap.kind == "neutral" and swap.slot == 18 and swap.unmodeledEffect)
end
assert(A.CompareEquippedUpgrade(b, {[18]=a}, druid(), profile).unmodeledEffect)
print("Restoration relic effects, actual ownership and personal crafting checks passed")
