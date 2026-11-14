local _, A = ...

A.SlotNames = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulders", [5] = "Chest",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [9] = "Wrists",
    [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back", [16] = "Main hand",
    [17] = "Off hand", [18] = "Ranged / relic",
}

local slotForLoc = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_CHEST = 5,
    INVTYPE_ROBE = 5, INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8,
    INVTYPE_WRIST = 9, INVTYPE_HAND = 10, INVTYPE_FINGER = 11, INVTYPE_TRINKET = 13,
    INVTYPE_CLOAK = 15, INVTYPE_WEAPON = 16, INVTYPE_2HWEAPON = 16,
    INVTYPE_WEAPONMAINHAND = 16, INVTYPE_WEAPONOFFHAND = 17, INVTYPE_HOLDABLE = 17,
    INVTYPE_SHIELD = 17, INVTYPE_RANGED = 18, INVTYPE_RANGEDRIGHT = 18,
    INVTYPE_THROWN = 18, INVTYPE_RELIC = 18,
}

local statKeys = {
    STRENGTH = "strength", AGILITY = "agility", INTELLECT = "intellect",
    STAMINA = "stamina", SPIRIT = "spirit", HEALTH = "health", MANA = "mana",
    HEALTH_REGEN = "hp5", ARMOR = "armor", EXTRA_ARMOR = "armor",
    CRIT_RATING = "crit", HIT_RATING = "hit", HASTE_RATING = "haste",
    EXPERTISE_RATING = "expertise", ATTACK_POWER = "attack",
    RANGED_ATTACK_POWER = "rangedAttack", FERAL_ATTACK_POWER = "feralAttack",
    SPELL_POWER = "spell", SPELL_DAMAGE_DONE = "spellDamage", SPELL_HEALING_DONE = "healing",
    MANA_REGENERATION = "mp5", DEFENSE_SKILL_RATING = "defense",
    DEFENSE_RATING = "defense", DODGE_RATING = "dodge", PARRY_RATING = "parry",
    BLOCK_RATING = "block", BLOCK_VALUE = "blockValue", ARCANE_SPELL_DAMAGE = "arcane",
    FIRE_SPELL_DAMAGE = "fire", FROST_SPELL_DAMAGE = "frost", SHADOW_SPELL_DAMAGE = "shadow",
    NATURE_SPELL_DAMAGE = "nature", HOLY_SPELL_DAMAGE = "holy",
}
local weightsByKey = {RESISTANCE0_NAME = "armor"}
for key, stat in pairs(statKeys) do
    weightsByKey["ITEM_MOD_" .. key .. "_SHORT"] = stat
end

function A.Score(item, profile, slot)
    local stats = item.stats or {}
    slot = slot or slotForLoc[item.loc]
    local score = 0
    for key, value in pairs(stats) do
        local stat = weightsByKey[key]
        local weight = stat and profile[stat]
        if stat == "health" then weight = (profile.stamina or 0) / 10
        elseif stat == "mana" then weight = (profile.intellect or 0) / 15
        elseif stat == "hp5" then weight = (profile.stamina or 0) * .20
        elseif stat == "spellDamage" and not profile.healing then
            weight = profile.spell
        end
        if weight and type(value) == "number" then score = score + value * weight end
    end
    -- Forever uses rating on current items. A source supplying an actual percentage
    -- must mark the unit explicitly. The conversion here uses the level-60 scale.
    score = score + (stats.HIT_PERCENT or 0) * 10 * (profile.hit or 0)
                  + (stats.CRIT_PERCENT or 0) * 14 * (profile.crit or 0)
    local dps = stats.DPS or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or 0
    if slot == 16 then score = score + dps * (profile.meleeDPS or 0)
    elseif slot == 17 and item.classID == 2 then
        score = score + dps * (profile.meleeDPS or 0) * (profile.offhandScale or .5)
    elseif slot == 18 then score = score + dps * (profile.rangedDPS or 0)
    end
    return score + (A.EffectScore and A.EffectScore(item, profile) or 0)
end

-- Limits have distinct namespaces. An item can simultaneously use up a unique
-- category, the only copy from a particular source and a quest reward choice.
local function itemLimits(item)
    local limits = {}
    local function add(prefix, key, limit)
        limits[prefix .. tostring(key)] = limit
    end
    if item.itemLimit or item.unique == true then
        add("item/", item.id, item.itemLimit or item.uniqueLimit or 1)
    end
    local category = item.uniqueGroup or (type(item.unique) ~= "boolean" and item.unique)
    if category then add("unique/", category, item.uniqueLimit or 1) end
    if item.maxCopies then add("route/", item.routeKey or item.id, item.maxCopies) end
    if item.choice then add("quest/", item.choice, 1) end
    for _, choice in ipairs(item.choices or {}) do add("quest/", choice, 1) end
    return limits
end

local function allowedHand(item, profile, player)
    local loc = item.loc
    if profile.shield and (loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_HOLDABLE"
        or loc == "INVTYPE_WEAPONOFFHAND") then return false end
    if profile.daggers and (slotForLoc[loc] == 16 or slotForLoc[loc] == 17)
        and not (item.classID == 2 and item.subID == 15) then return false end
    if loc == "INVTYPE_WEAPONOFFHAND" and not player.dual then return false end
    return true
end

local function rankBefore(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.item.id ~= b.item.id then return a.item.id < b.item.id end
    return a.order < b.order
end

local function buildGroups(items, player, profile)
    local lists = {}
    local function insert(slot, item, order, limits)
        local list = lists[slot]
        if not list then list = {}; lists[slot] = list end
        list[#list + 1] = {item = item, order = order, limits = limits, score = A.Score(item, profile, slot)}
    end
    for index, item in ipairs(items) do
        local slot = slotForLoc[item.loc]
        if slot and allowedHand(item, profile, player) then
            local limits = itemLimits(item)
            insert(slot, item, index, limits)
            if player.dual and not profile.shield and item.loc == "INVTYPE_WEAPON" then
                insert(17, item, index, limits)
            end
        end
    end
    local groups = {}
    for slot = 1, 18 do
        if slot ~= 17 and lists[slot] then
            local other = (slot == 11 or slot == 13 or slot == 16) and slot + 1 or nil
            local first = lists[slot]
            local second = other and (slot == 16 and (lists[17] or {}) or first) or nil
            table.sort(first, rankBefore)
            if second and second ~= first then table.sort(second, rankBefore) end
            groups[#groups + 1] = {slot = slot, other = other, first = first, second = second}
        end
    end
    return groups
end

local function fits(entry, caps, first)
    for key, limit in pairs(entry.limits) do
        local previous = first and first.limits[key]
        if previous then limit = math.min(limit, previous) end
        if (previous and 2 or 1) > math.min(limit, caps[key] or limit) then return false end
    end
    return true
end

-- The two lists are score-ordered. Bound both loops instead of building the
-- Cartesian product (hundreds of weapons or rings at 60). No top-N truncation.
local function bestGroup(group, caps)
    local best = {score = 0}
    local second = group.second
    local maxExtra = second and second[1] and math.max(second[1].score, 0) or 0
    for _, first in ipairs(group.first) do
        if first.score + maxExtra <= best.score then break end
        if fits(first, caps) then
            if first.score > best.score then best = {score = first.score, first = first} end
            if second and first.item.loc ~= "INVTYPE_2HWEAPON" then
                for _, other in ipairs(second) do
                    local combined = first.score + other.score
                    if combined <= best.score then break end
                    if fits(other, caps, first) then
                        best = {score = combined, first = first, second = other}
                        break
                    end
                end
            end
        end
    end
    return best
end

local function countKeys(entry, index, usage)
    if not entry then return end
    for key, limit in pairs(entry.limits) do
        local u = usage[key]
        if not u then
            u = {limit = limit, total = 0, counts = {}}
            usage[key] = u
        end
        u.limit = math.min(u.limit, limit)
        u.total = u.total + 1
        u.counts[index] = (u.counts[index] or 0) + 1
    end
end

local function findConflict(selected)
    local usage = {}
    for i, result in ipairs(selected) do
        countKeys(result.first, i, usage)
        countKeys(result.second, i, usage)
    end
    local chosen, violation = nil, 0
    for key, u in pairs(usage) do
        local excess = u.total - u.limit
        if excess > violation or (excess == violation and chosen and key < chosen) then
            chosen, violation = key, excess
        end
    end
    return chosen, usage[chosen]
end

-- Solve each independent slot group first. If their combined best set violates
-- a limit across groups, at least one group must consume less of that resource.
-- Explore those alternatives, retaining local caps, and prune by the sum of the
-- independently optimal scores. This also handles quests spanning armour slots.
function A.Solve(items, player, profile)
    local groups = buildGroups(items, player, profile)
    local caps, selected, initial = {}, {}, 0
    for i, group in ipairs(groups) do
        caps[i] = {}
        selected[i] = bestGroup(group, caps[i])
        initial = initial + selected[i].score
    end

    local best, bestScore = {}, -math.huge
    local function search(bound)
        if bound <= bestScore + 1e-8 then return end
        local key, conflict = findConflict(selected)
        if not key then
            best, bestScore = {}, bound
            for i, group in ipairs(groups) do
                local result = selected[i]
                if result.first then best[group.slot] = result.first.item end
                if result.second then best[group.other] = result.second.item end
            end
            return
        end

        -- Most promising repair first, establishing a good feasible bound early.
        local alternatives = {}
        for i, count in pairs(conflict.counts) do
            local oldCap = caps[i][key]
            caps[i][key] = count - 1
            local replacement = bestGroup(groups[i], caps[i])
            caps[i][key] = oldCap
            alternatives[#alternatives + 1] = {
                i = i, cap = count - 1, result = replacement,
                bound = bound - selected[i].score + replacement.score,
            }
        end
        table.sort(alternatives, function(a, b)
            if a.bound == b.bound then return a.i < b.i end
            return a.bound > b.bound
        end)
        for _, alt in ipairs(alternatives) do
            if alt.bound <= bestScore + 1e-8 then break end
            local i = alt.i
            local oldCap, oldResult = caps[i][key], selected[i]
            caps[i][key], selected[i] = alt.cap, alt.result
            search(alt.bound)
            caps[i][key], selected[i] = oldCap, oldResult
        end
    end
    search(initial)
    return best, bestScore
end
