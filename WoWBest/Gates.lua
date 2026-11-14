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

function A.RouteAvailable(record, player)
    -- Ownership bypasses acquisition only. Character.lua still checks whether the
    -- actual item link can be worn, including its level and skill requirements.
    if record.kind == "Owned" or record.owned then return true end
    if record.minLevel and (not player.level or player.level < record.minLevel) then return false end
    if record.maxLevel and (not player.level or player.level > record.maxLevel) then return false end
    if record.faction and record.faction ~= player.faction then return false end
    if not includesBit(record.classMask, player.classID and player.classID - 1) then return false end
    if not includesBit(record.raceMask, raceBits[player.raceID]) then return false end
    if record.questID then
        local status = checked(player, "questRewards", record.questID, questStatus)
        if not status or (status == "completed" and record.once ~= false) then return false end
    end
    if record.professionID then
        local rank = checked(player, "skillRanks", record.professionID, skillRank)
        if rank < math.max(1, record.professionRank or 1) then return false end
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
