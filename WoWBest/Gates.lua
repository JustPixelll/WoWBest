local _, A = ...

-- ChrRaces.PlayableRaceBit differs from raceID - 1 for the Skyborne.
-- The catalog generator keeps only playable bits; do not truncate to 32 bits.
local raceBits = {
    [1] = 0, [2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 7,
    [95] = 32, [96] = 33,
}

local function includesBit(mask, index)
    if mask == nil or mask == 0 or mask == -1 then return true end
    return index ~= nil and index >= 0 and math.floor(mask / 2 ^ index) % 2 == 1
end

local function readable(value)
    return not (issecretvalue and issecretvalue(value)) and value ~= nil
end

-- The character snapshot belongs to one planning run. Cache even negative
-- answers here so alternate routes do not repeat the same client query.
local function checked(player, group, id, read)
    player[group] = player[group] or {}
    local cache = player[group]
    if cache[id] == nil then
        local value = read(id)
        if value == nil then value = false end
        cache[id] = value
    end
    return cache[id]
end

local function questStatus(questID)
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    if C_QuestLog.IsQuestDisabledForSession then
        local disabled = C_QuestLog.IsQuestDisabledForSession(questID)
        if not readable(disabled) or disabled then return false end
    end
    local completed = C_QuestLog.IsQuestFlaggedCompleted(questID)
    if not readable(completed) then return false end
    -- A route may start with a visit to a quest giver. It need not be in the log yet.
    return completed and "completed" or "open"
end

local function skillRank(skillID)
    if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then return 0 end
    local info = C_SkillInfo.GetSkillLineInfoByID(skillID)
    if not readable(info) or not readable(info.rank) then return 0 end
    return info.rank
end

local function standing(factionID)
    if not (C_Reputation and C_Reputation.GetFactionDataByID) then return 0 end
    local info = C_Reputation.GetFactionDataByID(factionID)
    if not readable(info) or not readable(info.reaction) then return 0 end
    return info.reaction
end

local function pvpRank(factionID)
    if not (C_MajorFactions and C_MajorFactions.GetMajorFactionProgressionInfo) then return 0 end
    local info = C_MajorFactions.GetMajorFactionProgressionInfo(factionID)
    if not readable(info) or not readable(info.renownLevel) then return 0 end
    return info.renownLevel
end

local function learnedSpell(id)
    local check = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown)
    return check and check(id) == true
end

local function knowsRecipe(id)
    local query = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo
    local info = query and query(id)
    if info and info.learned == true then return true end
    return learnedSpell(id)
end

local function hasRequiredItem(id)
    return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, false) >= 1
end

local function questInLog(id)
    return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) == true
end

local function routeConditions(record, player, planning, owned)
    if record.minLevel and (not player.level or player.level < record.minLevel) then return false end
    if record.maxLevel and (not player.level or player.level > record.maxLevel) then return false end
    if record.faction and record.faction ~= player.faction then return false end
    if not includesBit(record.classMask, player.classID and player.classID - 1) then return false end
    if not includesBit(record.raceMask, raceBits[player.raceID]) then return false end
    if not owned and record.questID then
        local status = checked(player, "questRewards", record.questID, questStatus)
        if not status or (status == "completed" and record.once ~= false) then return false end
    end
    if not owned and not (planning and record.eventName) then
        if record.requiresItemID and not checked(player, "carriedRequirements", record.requiresItemID, hasRequiredItem) then return false end
        if record.requiresQuestInLog and not (record.questID and checked(player, "activeQuests", record.questID, questInLog)) then return false end
    end
    if record.wearSpellID and not checked(player, "knownProfessionSpells", record.wearSpellID, learnedSpell) then return false end
    if not owned and record.craftSpecSpellID and not checked(player, "knownProfessionSpells", record.craftSpecSpellID, learnedSpell) then return false end
    if not owned and record.requiresKnownCraft and not (planning and record.trainerRecipe) then
        if not record.craftSpellID or not checked(player, "knownRecipes", record.craftSpellID, knowsRecipe) then return false end
    end
    if record.repFactionID or record.minStanding then
        if not (record.repFactionID and record.minStanding) then return false end
        if checked(player, "standings", record.repFactionID, standing) < record.minStanding then return false end
    end
    if record.minPvPRank then
        -- Forever's Character panel uses the renown level of the Rank Points faction.
        local rank = checked(player, "pvpRanks", 2800, pvpRank)
        if rank < record.minPvPRank then return false end
    end
    return true
end

function A.RouteAvailable(record, player)
    -- Ownership bypasses acquisition only. Character.lua still verifies the link.
    if record.kind == "Owned" or record.owned then return true end
    if record.professionID then
        local rank = checked(player, "skillRanks", record.professionID, skillRank)
        if rank < math.max(1, record.professionRank or 1) then return false end
    end
    return routeConditions(record, player, false)
end

local primarySkills = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
    [165] = "Leatherworking", [197] = "Tailoring", [186] = "Mining", [182] = "Herbalism", [393] = "Skinning",
}
local function levelForSkill(id, rank)
    if rank > 300 then return end
    if rank <= 75 then return 1 end
    if id == 356 then return end -- Only the novice fishing requirement is modeled.
    if id == 182 or id == 186 or id == 393 then
        if rank <= 150 then return 1 elseif rank <= 225 then return 10 else return 25 end
    end
    if rank <= 150 then return 10 elseif rank <= 225 then return 20 else return 35 end
end

function A.ProfessionTarget(record, player)
    local id, needed = record.professionID, record.professionRank
    local name = primarySkills[id] or (id == 356 and "Fishing")
    if not name or not needed or record.owned or not player.level then return end
    if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then return end
    local rank = checked(player, "skillRanks", id, skillRank)
    local owned = C_Item and C_Item.GetItemCount and checked(player, "carriedRequirements", record.id, hasRequiredItem)
    if owned then
        -- The person already has the item. Preserve the wearable skill goal;
        -- buying, crafting and quest completion are irrelevant to that copy.
        if not record.wearProfessionID or record.wearProfessionID ~= id then return end
        needed = record.wearProfessionRank
        if not needed or rank >= needed then return end
    end
    local requiredLevel = levelForSkill(id, needed)
    if not requiredLevel or player.level < requiredLevel then return end
    if rank >= needed and not record.eventName and not (record.trainerRecipe and record.requiresKnownCraft) then return end
    if A.RouteAvailable(record, player) then return end
    if not routeConditions(record, player, true, owned) then return end

    local localized = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
        and C_TradeSkillUI.GetTradeSkillDisplayName(id)
    local slot = A.PlanningSlot(record, player, localized and localized ~= "" and localized or name)
    if not slot then return end
    local details = {}
    if rank < needed then
        details[#details + 1] = ("%s %d (currently %d)."):format(name, needed, rank)
        if rank == 0 and primarySkills[id] then
            local count = 0
            for skillID in pairs(primarySkills) do
                if checked(player, "skillRanks", skillID, skillRank) > 0 then count = count + 1 end
            end
            if count >= 2 then details[#details + 1] = "Both primary slots are filled; this would require replacing a profession." end
        end
    end
    if not owned and record.requiresKnownCraft and record.trainerRecipe and record.craftSpellID and
        not checked(player, "knownRecipes", record.craftSpellID, knowsRecipe) then
        details[#details + 1] = "Learn the recipe from a trainer to craft this yourself."
    end
    if not owned and record.eventName then
        details[#details + 1] = record.eventName .. ": the event catch and active turn-in are required."
    end
    return {
        id = record.id, name = record.name, slot = slot, source = owned and "Already owned" or record.source,
        kind = record.kind, professionID = id, professionRank = needed, skillRank = rank,
        requirement = table.concat(details, " "), statSummary = record.statSummary,
        itemLevel = record.itemLevel, eventName = record.eventName,
    }
end
