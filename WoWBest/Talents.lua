local _, A = ...

-- Forever exposes one spec ID per *class*. Its three talent tabs are groups
-- in the active trait tree. Using their display order also works on non-English clients.
local function readTalents(player)
    local traits, talents = C_Traits, C_ClassTalents
    if not (traits and talents and talents.GetActiveConfigID and traits.GetConfigInfo
        and traits.GetGroupDisplayInfoByTreeID and traits.GetGroupCurrencyInfo) then return end
    local config = talents.GetActiveConfigID()
    if not config then return end
    local info = traits.GetConfigInfo(config)
    if not (info and info.treeIDs) then return end
    for _, treeID in ipairs(info.treeIDs) do
        local groups = traits.GetGroupDisplayInfoByTreeID(treeID)
        if groups and #groups == 3 then
            local sorted, ids = {}, {}
            for i, group in ipairs(groups) do
                if not (group.orderIndex and group.groupID) then return end
                sorted[i], ids[i] = group, group.groupID
            end
            table.sort(sorted, function(a, b) return a.orderIndex < b.orderIndex end)
            local spending = {}
            for _, entry in ipairs(traits.GetGroupCurrencyInfo(config, ids) or {}) do
                local total = 0
                for _, currency in ipairs(entry.currencyInfos or {}) do
                    total = total + (currency.spent or 0)
                end
                spending[entry.traitNodeGroupID] = total
            end
            local best, index = 0, nil
            for i, group in ipairs(sorted) do
                local spent = spending[group.groupID] or 0
                if spent > best then best, index = spent, i
                elseif spent == best then index = nil end
            end
            if not index or best == 0 then return end
            -- Feral points alone cannot identify a tank versus a damage build.
            if player.class == "DRUID" and index == 2 then return end
            for _, profile in ipairs(A.Profiles[player.class] or {}) do
                if profile.tree == index then return profile.key end
            end
        end
    end
end

function A.DetectProfile(player)
    if player.level < 10 or (InCombatLockdown and InCombatLockdown()) then return end
    local ok, key = pcall(readTalents, player)
    if ok then return key end
end

-- Single-entry nodes in the live Forever Druid tree. Verify the spell behind
-- each node even at rank zero, since a hotfix can reuse a node for a new talent.
-- https://forever.undrwrldcub.com/db/talent-nodes/
local restoNodes = {
    {key = "heartOfTheWild", node = 104958, spell = 17003, max = 5},
    {key = "reflection", node = 104920, spell = 17106, max = 3},
    {key = "bloom", node = 104918, spell = 1328621, max = 1},
    {key = "livingSpirit", node = 104911, spell = 1309631, max = 3},
}

local function readRestoRanks()
    local config = C_ClassTalents.GetActiveConfigID()
    -- An open editor can make activeRank describe a preview. Only score a
    -- complete, committed snapshot of the active character configuration.
    if not config or C_Traits.ConfigHasStagedChanges(config) ~= false then return end
    local ranks = {}
    for _, talent in ipairs(restoNodes) do
        local node = C_Traits.GetNodeInfo(config, talent.node)
        if not node or node.ID ~= talent.node or not node.entryIDs or #node.entryIDs ~= 1 then return end
        local entryID = node.entryIDs[1]
        local entry = C_Traits.GetEntryInfo(config, entryID)
        local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
        if not def or def.spellID ~= talent.spell then return end
        local rank = node.activeRank
        if type(rank) ~= "number" or rank < 0 or rank > talent.max or rank ~= math.floor(rank) then return end
        if rank > 0 and (not node.activeEntry or node.activeEntry.entryID ~= entryID
            or node.activeEntry.rank ~= rank) then return end
        ranks[talent.key] = rank
    end
    return ranks
end

-- The live UI calls this once per resolved profile, outside the item loop.
-- Nil distinguishes unavailable talent data from four confirmed zero ranks.
function A.GetRestoDruidTalents()
    if not C_ClassTalents or not C_Traits or (InCombatLockdown and InCombatLockdown()) then return end
    local ok, ranks = pcall(readRestoRanks)
    if ok then return ranks end
end
