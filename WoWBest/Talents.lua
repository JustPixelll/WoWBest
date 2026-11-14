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
