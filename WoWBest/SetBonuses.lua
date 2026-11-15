local _, A = ...

-- A set's skill requirement applies to its bonuses, not to wearing its pieces.
-- This must be checked separately from an item's own equip requirements.
local function meetsSetSkill(id)
    local gate = A.SetSkills[id]
    if not gate then return true end
    if not (C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID) then return false end
    local info = C_SkillInfo.GetSkillLineInfoByID(gate.id)
    if (issecretvalue and issecretvalue(info)) or not info then return false end
    local rank = info.rank
    return not (issecretvalue and issecretvalue(rank)) and type(rank) == "number" and rank >= gate.rank
end

local function eligibleModel(row, profile)
    return row.stats ~= nil and (not row.targetType or profile.targetType == row.targetType)
end

local function points(row, profile)
    if not eligibleModel(row, profile) then return 0 end
    return math.max(0, A.Score({stats = row.stats}, profile))
end

-- A.Score applies the exact same stat units and spec weights to gear and bonuses.
-- Multiple spells at the same threshold may contribute independently.
function A.SetBonusScore(id, count, profile)
    local rows = A.SetThresholds[id]
    if not rows or count < 1 or not meetsSetSkill(id) then return 0 end
    local total = 0
    for _, row in ipairs(rows) do
        if row.pieces > count then break end
        total = total + points(row, profile)
    end
    return total
end

-- Compare only sets present in either outfit. Inactive target-specific
-- numerical bonuses and thresholds retained on both sides introduce no new
-- uncertainty in this swap.
function A.HasUnmodeledSetChange(before, after, profile)
    local old, new = A.GetSetCounts(before), A.GetSetCounts(after)
    local function crosses(id, a, b)
        if a == b or not meetsSetSkill(id) then return false end
        local lower, upper = math.min(a,b), math.max(a,b)
        for _, row in ipairs(A.SetThresholds[id] or {}) do
            if row.pieces > upper then break end
            if row.pieces > lower and row.stats == nil
                and (not row.targetType or row.targetType == profile.targetType) then return true end
        end
        return false
    end
    for id, n in pairs(old) do
        if crosses(id,n,new[id] or 0) then return true end
    end
    for id, n in pairs(new) do
        if not old[id] and crosses(id,0,n) then return true end
    end
    return false
end

local function description(row)
    if row.spellID and not row.stats and C_Spell and C_Spell.GetSpellDescription then
        local live = C_Spell.GetSpellDescription(row.spellID)
        if not (issecretvalue and issecretvalue(live)) and live and live ~= "" then return live end
    end
    return row.description
end

-- Includes situational effects. Display code can distinguish "not modeled" from
-- a modeled stat whose weight is zero for this particular profile.
function A.ActiveSetBonuses(loadout, profile)
    local active = {}
    for id, count in pairs(A.GetSetCounts(loadout or {})) do
        if A.SetThresholds[id] and meetsSetSkill(id) then
            for _, bonus in ipairs(A.SetThresholds[id]) do
                if bonus.pieces > count then break end
                active[#active + 1] = {
                    key = id .. ":" .. bonus.pieces .. ":" .. (bonus.spellID or bonus.description),
                    setID = id, name = A.SetNames[id], threshold = bonus.pieces, pieces = bonus.pieces,
                    spellID = bonus.spellID, description = description(bonus), score = points(bonus, profile),
                    modeled = eligibleModel(bonus, profile), targetType = bonus.targetType,
                }
            end
        end
    end
    table.sort(active, function(a, b)
        if a.setID ~= b.setID then return a.setID < b.setID end
        if a.pieces ~= b.pieces then return a.pieces < b.pieces end
        return a.key < b.key
    end)
    return active
end
