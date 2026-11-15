-- Run from the repository root with Lua 5.1. Add --list to print the examples.
-- This is a fresh level-31 Night Elf or Tauren with all Druid weapon skills
-- trained, 3/3 Reflection, Bloom, no professions, reputations, owned gear or
-- completed/logged quests. The default filters allow commissionable crafts. The catalog's bare item facts contain
-- no assumed random suffix, gems or enchant. Client-only stats are unavailable.
local A, rows = {}, {}
for _, name in ipairs({"Catalog", "Profiles", "Effects", "SetData", "SetBonuses", "Engine",
    "TooltipStats", "Character", "Upgrade", "Gates", "Sources"}) do
    assert(loadfile("WoWBest/" .. name .. ".lua"))("WoWBest", A)
end

local locations = {
    [1]="HEAD",[2]="NECK",[3]="SHOULDER",[5]="CHEST",[6]="WAIST",[7]="LEGS",
    [8]="FEET",[9]="WRIST",[10]="HAND",[11]="FINGER",[12]="TRINKET",[13]="WEAPON",
    [14]="SHIELD",[15]="RANGED",[16]="CLOAK",[17]="2HWEAPON",[20]="ROBE",
    [21]="WEAPONMAINHAND",[22]="WEAPONOFFHAND",[23]="HOLDABLE",[25]="THROWN",
    [26]="RANGEDRIGHT",[28]="RELIC",
}
for _, row in ipairs(A.Catalog) do
    local previous = rows[row.id]
    if not previous or (row.minLevel or 1) < (previous.minLevel or 1) then rows[row.id] = row end
end
local skills = {[9077]=true, [198]=true, [199]=true, [200]=true, [227]=true, [1180]=true, [15590]=true}
function IsPlayerSpell(id) return skills[id] or false end
C_QuestLog = {IsQuestFlaggedCompleted=function() return false end}
C_Item = {}
function C_Item.GetItemInfo(id)
    local row = assert(rows[id])
    local loc = assert(locations[row.invType], tostring(row.invType))
    return row.name or ("Item "..id), "item:"..id, 2, row.itemLevel, row.minLevel or 1, nil, nil, 1,
        "INVTYPE_"..loc, nil, nil, row.classID, row.subclassID
end
function C_Item.GetItemStats() return {} end
C_PlayerInfo = {CanUseItem=function(id)
    local row = rows[id]
    -- The client applies class restrictions on relic subclasses (Idols = 8).
    return row.invType ~= 28 or row.subclassID == 8
end}
local tip = {lines={{type=22, leftText="Item"},{type=21, leftText="Equipment"}}}
C_TooltipInfo = {GetHyperlink=function() return tip end}

local onUpdate, loadout, resultMessage, player
local clock = 0
function CreateFrame()
    return {RegisterEvent=function() end, SetScript=function(_, script, fn)
        if script == "OnUpdate" then onUpdate = fn end
    end}
end
function GetTime() return clock end
function A.IsVisible() return true end
function A.GetPlayer() return player end
function A.UpdateStatus() end
function A.UpdateDisplay(load, message) loadout, resultMessage = load, message end
assert(loadfile("WoWBest/Planner.lua"))("WoWBest", A)
local preset
for _, p in ipairs(A.Profiles.DRUID) do if p.key == "restoration" then preset = p end end
local function run(faction, pace, dungeons)
    player = {class="DRUID",classID=11,level=31,faction=faction,
        raceID=faction=="Alliance" and 4 or 6, dual=false,
        restoTalents={reflection=3,bloom=1}, healingPace=pace}
    A.SetSourceEnabled("Dungeon",dungeons)
    local profile = A.ProfileForLevel(assert(preset), player)
    A.StartScan(profile)
    for i=1,1000 do
        if not onUpdate then break end
        clock = clock + .1
        onUpdate()
    end
    assert(not onUpdate and loadout, resultMessage)
    if arg and arg[1]=="--list" then
        print(faction .. " " .. pace .. (dungeons and "" or " (no dungeons)") .. " · " .. resultMessage .. (" Score %.2f"):format(A.LoadoutScore(loadout,profile)))
    end
    local quests, copies = {}, {}
    for slot=1,18 do
        local item = loadout[slot]
        if item then
            assert(item.minLevel<=31 and A.FitsGearSlot(item,slot,player,profile))
            assert(A.RouteSourceEnabled(item) and A.RouteAvailable(item,player))
            copies[item.id] = (copies[item.id] or 0) + 1
            assert(not item.itemLimit or copies[item.id]<=item.itemLimit)
            for _, choice in ipairs(item.choices or {}) do assert(not quests[choice]); quests[choice]=true end
            if item.choice then assert(not quests[item.choice]); quests[item.choice]=true end
            if arg and arg[1]=="--list" then
                local parts={}
                for _,p in ipairs(A.ScoreBreakdown(item,profile,slot)) do
                    parts[#parts+1]=("%s %.2f"):format(p.label,p.amount)
                end
                print(("%-10s  %-35s %6d %6.2f  %s  %s"):format(A.SlotNames[slot], item.name, item.id,
                    A.Score(item,profile,slot), table.concat(parts,", "),item.source or ""))
            end
        end
    end
    assert(loadout[16] and not (loadout[16].loc=="INVTYPE_2HWEAPON" and loadout[17]))
    -- The cache contained an area tag alongside a quest label for Talvash's
    -- necklace. Entering Uldaman cannot bypass its level-37 quest requirement.
    assert(not A.RouteAvailable(rows[7673],player))
    assert(rows[273031].itemLimit==1 and rows[274152].itemLimit==1)
    if dungeons then
        assert(loadout[16].id==9457 and loadout[17].id==273052)
        -- Check both staff alternatives individually from the source data.
        local friar = assert(A.ReadCandidate(rows[3415],player))
        local seer = assert(A.ReadCandidate(rows[2271],player))
        local hands = A.Score(loadout[16],profile,16) + A.Score(loadout[17],profile,17)
        assert(hands > A.Score(friar,profile,16) and A.Score(friar,profile,16) > A.Score(seer,profile,16))
        if faction=="Alliance" then
            local boots = {}
            for _,id in ipairs({279840,254013}) do
                assert(A.RouteAvailable(rows[id],player))
                boots[id] = A.Score(assert(A.ReadCandidate(rows[id],player)),profile,8)
            end
            if arg and arg[1]=="--list" then
                print(("Footpad comparison: Renewing %.2f, Earthen Silk %.2f. Staff comparison: Friar %.2f, Blessed Seer %.2f."):format(
                    boots[279840],boots[254013],A.Score(friar,profile,16),A.Score(seer,profile,16)))
            end
            local winner = pace=="short" and 279840 or 254013
            assert(loadout[8].id==winner and boots[winner]==math.max(boots[279840],boots[254013]))
        end
    else
        assert(not loadout[17] and loadout[16].loc=="INVTYPE_2HWEAPON")
    end
end
for _,faction in ipairs({"Alliance","Horde"}) do
    for _,pace in ipairs({"dungeon","short","sustained"}) do run(faction,pace,true) end
    run(faction,"dungeon",false)
end
print("Level-31 Restoration Druid full-catalog planning passed for both factions.")
