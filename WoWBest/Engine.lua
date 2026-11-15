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

local statLabels = {
    strength="Strength", agility="Agility", intellect="Intellect", stamina="Stamina", spirit="Spirit",
    mana="Mana", health="Health", armor="Armor", hp5="Health per 5", mp5="Mana per 5",
    attack="Attack power", rangedAttack="Ranged attack power", feralAttack="Feral attack power",
    hit="Hit rating", crit="Crit rating", haste="Haste rating", expertise="Expertise",
    defense="Defense", dodge="Dodge", parry="Parry", block="Block", blockValue="Block value",
    spell="Spell power", spellDamage="Spell damage", healing="Healing",
    fire="Fire damage", frost="Frost damage", nature="Nature damage", arcane="Arcane damage",
    holy="Holy damage", shadow="Shadow damage",
}

-- Forever uses rating on its generic stats and some effects report a true
-- percentage change. Value a percentage point in the active profile's units.
local ratingPerPercent = {hit=10, crit=14, haste=10, dodge=12, parry=15, block=5, expertise=10}
local ratingTokens, percentTokens, percentStats = {}, {}, {}
for stat in pairs(ratingPerPercent) do
    ratingTokens[stat] = "ITEM_MOD_" .. stat:upper() .. "_RATING_SHORT"
    local key = stat:upper() .. "_PERCENT"
    percentTokens[stat], percentStats[key] = key, stat
end
local percentLabels = {
    hit="Hit chance (%)", crit="Crit chance (%)", haste="Haste (%)",
    dodge="Dodge chance (%)", parry="Parry chance (%)",
    block="Block chance (%)", expertise="Reduced dodge and parry chance (%)",
}

function A.PercentStatWeight(profile, stat)
    return profile[stat .. "Percent"] or (ratingPerPercent[stat] or 0) * (profile[stat] or 0)
end

local function combatStatAmount(stats, profile, stat)
    local rating = stats[ratingTokens[stat]]
    if rating ~= nil then return rating, profile[stat] or 0, statLabels[stat] end
    return stats[percentTokens[stat]] or 0, A.PercentStatWeight(profile,stat), percentLabels[stat]
end

-- Effects use this helper to subtract a passive the native item data already
-- credited. The native rating takes precedence over an equivalent % aura.
function A.CombatStatPoints(stats, profile, stat)
    local amount, weight = combatStatAmount(stats,profile,stat)
    return amount * weight
end

local function scoreItem(item, profile, slot, rows)
    local stats = item.stats or {}
    slot = slot or slotForLoc[item.loc]
    local score = 0
    local function credit(label, amount, weight)
        if not weight or amount == 0 or weight == 0 then return end
        local points = amount * weight
        score = score + points
        if rows then rows[#rows+1] = {label=label, amount=amount, weight=weight, points=points} end
    end
    for key, value in pairs(stats) do
        local stat = weightsByKey[key]
        local weight = stat and profile[stat]
        if stat == "health" then weight = (profile.stamina or 0) / 10
        elseif stat == "mana" then weight = profile.mana or (profile.intellect or 0) / 15
        elseif stat == "hp5" then weight = (profile.stamina or 0) * .20
        elseif stat == "spellDamage" and not profile.healing then weight = profile.spell
        end
        if stat and type(value)=="number" then
            credit(statLabels[stat], value, weight)
        elseif percentStats[key] and stats[ratingTokens[percentStats[key]]] == nil then
            local amount, perUnit, label = combatStatAmount(stats, profile, percentStats[key])
            credit(label, amount, perUnit)
        elseif key=="DEFENSE_SKILL" and not stats.ITEM_MOD_DEFENSE_SKILL_RATING_SHORT
                and not stats.ITEM_MOD_DEFENSE_RATING_SHORT then
            credit("Defense skill",value,profile.defenseSkill or profile.defense)
        elseif key=="HUMANOID_ATTACK_POWER" and profile.targetType=="Humanoid" then
            credit("Attack power vs Humanoids",value,profile.attack)
        elseif key=="FLAT_WEAPON_DAMAGE" then
            credit("Bonus weapon damage",value,profile.flatWeaponDamage)
        end
    end
    local average = item.minDamage and item.maxDamage and (item.minDamage + item.maxDamage) / 2
    local speed = item.weaponSpeed and item.weaponSpeed>0 and item.weaponSpeed
    local dps = stats.DPS or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or (average and speed and average / speed) or 0
    if slot == 16 then
        credit("Main-hand weapon DPS", dps, profile.meleeDPS)
        credit("Main-hand average hit", average or (speed and dps * speed) or 0, profile.mainHandDamage)
    elseif slot == 17 and item.classID == 2 then
        credit("Off-hand weapon DPS", dps, (profile.meleeDPS or 0) * (profile.offhandScale or .5))
    elseif slot == 18 then credit("Ranged weapon DPS", dps, profile.rangedDPS) end
    credit("Modeled item effect", 1, A.EffectScore and A.EffectScore(item, profile))
    return score
end

function A.Score(item, profile, slot)
    return scoreItem(item, profile, slot)
end

function A.ScoreBreakdown(item, profile, slot)
    local rows = {}
    scoreItem(item, profile, slot, rows)
    table.sort(rows, function(a, b)
        if math.abs(a.points) == math.abs(b.points) then return a.label < b.label end
        return math.abs(a.points) > math.abs(b.points)
    end)
    return rows
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

function A.PrimaryGearSlot(item)
    return slotForLoc[item.loc]
end

-- The planner and equipment tooltip use the same slot rules. Per-character
-- training and eligibility have already been checked by the item reader.
function A.FitsGearSlot(item, slot, player, profile)
    if not item then return false end
    local loc, main = item.loc, slotForLoc[item.loc]
    if not main then return false end
    if slot == 16 or slot == 17 then
        if profile.daggers and not (item.classID==2 and item.subID==15) then return false end
        if slot == 16 then return main==16 and not (profile.shield and loc=="INVTYPE_2HWEAPON") end
        if loc=="INVTYPE_SHIELD" then return true end
        if profile.shield then return false end
        if loc=="INVTYPE_HOLDABLE" then return true end
        return player.dual and (loc=="INVTYPE_WEAPON" or loc=="INVTYPE_WEAPONOFFHAND")
    end
    return slot==main or main==11 and slot==12 or main==13 and slot==14
end

local function rankBefore(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.item.id ~= b.item.id then return a.item.id < b.item.id end
    return a.order < b.order
end

local function itemSet(item)
    local id = item.setID
    if not id or id == 0 then id = item.itemSetID end
    if not id or id == 0 then id = A.ItemSetIDs and A.ItemSetIDs[item.id] end
    if id and id ~= 0 then return id end
end

function A.GetSetCounts(loadout)
    local counts, seen = {}, {}
    for slot, item in pairs(loadout) do
        if A.SlotNames[slot] and item.id and not seen[item.id] then
            local id = itemSet(item)
            if id then counts[id], seen[item.id] = (counts[id] or 0) + 1, true end
        end
    end
    return counts
end

function A.LoadoutScore(loadout, profile)
    local total = 0
    for slot, item in pairs(loadout) do
        if A.SlotNames[slot] then total = total + A.Score(item, profile, slot) end
    end
    if A.SetBonusScore then
        for id, count in pairs(A.GetSetCounts(loadout)) do
            total = total + (A.SetBonusScore(id, count, profile) or 0)
        end
    end
    return total
end

local both = {[11]=12, [13]=14, [16]=17}
local primary = {[12]=11, [14]=13, [17]=16}

-- Immutable score/slot index reused for the best plan and every detail panel.
-- A cooperative caller may yield from checkpoint; this code does not yield
-- inside a C sort/comparator. All solve-specific state is local to a request.
function A.PrepareSolver(items, player, profile, checkpoint)
    local ctx = {profile=profile, groups={}, entries={}, checkpoint=checkpoint, distinct={}}
    local owner, external = {}, {}
    ctx.external = external
    local budget = 0
    ctx.tick = function()
        if checkpoint then
            budget = budget + 1
            if budget >= 64 then budget = 0; checkpoint() end
        end
    end
    local lists = {}
    local function insert(slot, item, order, limits, id)
        local entry = {item=item, order=order, limits=limits, set=id, score=A.Score(item, profile, slot)}
        lists[slot] = lists[slot] or {}
        lists[slot][#lists[slot]+1] = entry
    end
    for i, item in ipairs(items) do
        ctx.tick()
        local slot = slotForLoc[item.loc]
        if slot and A.FitsGearSlot(item,slot,player,profile) then
            local id, limits = itemSet(item), itemLimits(item)
            local group = primary[slot] or slot
            for key in pairs(limits) do
                if owner[key] and owner[key] ~= group then external[key] = true end
                owner[key] = group
            end
            if id and A.SetThresholds and A.SetThresholds[id] and A.SetBonusScore then
                ctx.distinct[id] = ctx.distinct[id] or {}
                ctx.distinct[id][item.id] = true
            else id = nil end
            insert(slot, item, i, limits, id)
            if slot == 16 and A.FitsGearSlot(item,17,player,profile) then
                insert(17, item, i, limits, id)
            end
        end
    end
    -- Discard sets that cannot possibly confer points on this spec and pool.
    local active = {}
    ctx.bonus = {}
    for id, members in pairs(ctx.distinct) do
        local n = 0
        for _ in pairs(members) do n = n + 1 end
        n = math.min(n, 17)
        local values = {[0]=0}
        for k = 1, n do values[k] = A.SetBonusScore(id,k,profile) or 0 end
        if values[n] > 0 then active[id], ctx.bonus[id] = true, values end
    end
    for slot = 1, 18 do
        local list = lists[slot]
        if list then
            table.sort(list, rankBefore)
            for _, entry in ipairs(list) do
                if not active[entry.set] then entry.set = nil end
                ctx.tick()
            end
        end
    end
    for slot = 1, 18 do
        local list = lists[slot]
        if not primary[slot] and list then
            local other = both[slot]
            local second = other and (slot == 16 and (lists[17] or {}) or list)
            ctx.groups[#ctx.groups+1] = {slot=slot, other=other, first=list, second=second}
            ctx.entries[slot] = list
            if other then ctx.entries[other] = second end
        end
    end
    return ctx
end

local function fits(entry, caps, first)
    for key, limit in pairs(entry.limits) do
        local previous = first and first.limits[key]
        if previous then limit = math.min(limit, previous) end
        if (previous and 2 or 1) > math.min(limit, caps[key] or limit) then return false end
    end
    return true
end

-- A pattern fixes the set membership of both items in a slot group, including
-- empty slots. A repeated set item ID contributes only one distinct piece.
local function bestGroup(group, caps, tick)
    local answer
    if not group.required then answer = {score=0} end
    local best = answer and 0 or -math.huge
    local second = group.second
    local maxExtra = second and second[1] and math.max(second[1].score,0) or 0
    for _, first in ipairs(group.first) do
        tick()
        if first.score + maxExtra <= best then break end
        if fits(first,caps) then
            if not group.requireSecond and first.score > best then
                best, answer = first.score, {first=first,score=first.score}
            end
            if second and first.item.loc ~= "INVTYPE_2HWEAPON" then
                for _, other in ipairs(second) do
                    tick()
                    local sum = first.score + other.score
                    if sum <= best then break end
                    if (group.repeatRule == nil or group.repeatRule == (first.item.id == other.item.id))
                        and fits(other,caps,first) then
                        best, answer = sum, {first=first,second=other,score=sum}
                        break
                    end
                end
            end
        end
    end
    return answer
end

local function countKeys(entry, group, usage)
    if not entry then return end
    for key, limit in pairs(entry.limits) do
        local u = usage[key]
        if not u then u={limit=limit,total=0,counts={}}; usage[key]=u end
        u.limit, u.total = math.min(u.limit,limit), u.total+1
        u.counts[group] = (u.counts[group] or 0)+1
    end
end

-- Exact additive subproblem inside one combination of set patterns. If two
-- groups violate a shared limit, any valid solution consumes less in at least
-- one of them. Branch on that fact, preserving the other cached slot maxima.
local function repair(ctx, picks, baseBonus, floor)
    local selected, caps, initial = {}, {}, baseBonus
    for i, p in ipairs(picks) do
        selected[i], caps[i], initial = p.best, {}, initial + p.best.score
    end
    local best, bestScore = nil, floor
    local function search(bound)
        ctx.tick()
        if bound <= bestScore + 1e-8 then return end
        local usage = {}
        for i, result in ipairs(selected) do
            countKeys(result.first,i,usage)
            countKeys(result.second,i,usage)
        end
        local key, excess
        for k, u in pairs(usage) do
            local n = u.total-u.limit
            if n > 0 and (not excess or n > excess or n == excess and k < key) then key,excess=k,n end
        end
        if not key then
            best, bestScore = {}, bound
            for i, result in ipairs(selected) do
                local p = picks[i]
                if result.first then best[p.slot] = result.first.item end
                if result.second then best[p.other] = result.second.item end
            end
            return
        end
        local alternatives = {}
        for i, count in pairs(usage[key].counts) do
            local old = caps[i][key]
            caps[i][key] = count-1
            local result = bestGroup(picks[i],caps[i],ctx.tick)
            caps[i][key] = old
            if result then
                alternatives[#alternatives+1] = {i=i,cap=count-1,result=result,bound=bound-selected[i].score+result.score}
            end
        end
        table.sort(alternatives,function(a,b)
            if a.bound == b.bound then return a.i < b.i end
            return a.bound > b.bound
        end)
        for _, alt in ipairs(alternatives) do
            if alt.bound <= bestScore + 1e-8 then break end
            local i=alt.i
            local old, result = caps[i][key], selected[i]
            caps[i][key], selected[i] = alt.cap, alt.result
            search(alt.bound)
            caps[i][key], selected[i] = old, result
        end
    end
    search(initial)
    return best,bestScore
end

local function buckets(list,tick)
    local bySet, keys = {}, {}
    for _, e in ipairs(list or {}) do
        tick()
        local k = e.set or 0
        if not bySet[k] then bySet[k],keys[#keys+1]={},k end
        bySet[k][#bySet[k]+1]=e
    end
    table.sort(keys)
    return bySet,keys
end

local function makePatterns(ctx, group, forcedSlot, forced)
    -- Ring and trinket sockets are symmetric; a forced right socket is legal
    -- on its own. Off-hand weapons and shields still require a main hand.
    if (forcedSlot==12 or forcedSlot==14) and forcedSlot==group.other then
        group={slot=group.other,other=group.slot,first=group.second,second=group.first}
    end
    local pinFirst, pinSecond = forcedSlot == group.slot, forcedSlot ~= nil and forcedSlot == group.other
    local first = pinFirst and {forced} or group.first
    local second = pinSecond and {forced} or group.second
    local one, keys = buckets(first,ctx.tick)
    local two, others = buckets(second,ctx.tick)
    local out = {}
    local function append(firstSet,secondSet,repeatRule)
        ctx.tick()
        local p = {slot=group.slot,other=group.other,first=firstSet and one[firstSet] or {},
            second=secondSet and two[secondSet],required=pinFirst or pinSecond or firstSet~=nil,
            requireSecond=secondSet~=nil,repeatRule=repeatRule}
        p.best = bestGroup(p,{},ctx.tick)
        if not p.best then return end
        p.counts = {}
        if firstSet and firstSet ~= 0 then p.counts[firstSet]=1 end
        if secondSet and secondSet ~= 0 and not repeatRule then
            p.counts[secondSet]=(p.counts[secondSet] or 0)+1
        end
        out[#out+1]=p
    end
    if not pinFirst and not pinSecond then append(nil,nil) end
    for _, k in ipairs(keys) do
        if not pinSecond then append(k,nil) end
        for _, j in ipairs(others) do
            if j == k and j ~= 0 then
                append(k,j,false) -- two different set pieces
                append(k,j,true)  -- two copies of the same piece count once
            else append(k,j) end
        end
    end
    table.sort(out,function(a,b)
        if a.best.score ~= b.best.score then return a.best.score>b.best.score end
        local af, bf = a.best.first, b.best.first
        if not af or not bf then return af==nil and bf~=nil end
        if af.order~=bf.order then return af.order<bf.order end
        local as,bs = a.best.second,b.best.second
        if not as or not bs then return as==nil and bs~=nil end
        return as.order<bs.order
    end)
    return out
end

-- If less restrictive fallback p' scores as well as p and offers identical
-- set membership, p can still matter when p' has a source restriction. Keep
-- every underlying item in its bucket; no per-slot top-N cutoff is applied.
local function defaultPatterns(ctx)
    if not ctx.defaults then
        -- A scan may yield or be cancelled while these groups are building.
        -- Publish an index only after all of its slot groups are available.
        local complete = {}
        for i, group in ipairs(ctx.groups) do
            complete[i]=makePatterns(ctx,group)
        end
        ctx.defaults = complete
    end
    return ctx.defaults
end

local function solvePrepared(ctx, forcedSlot, forced, minimum)
    local defaults = defaultPatterns(ctx)
    local stages = {}
    for i, group in ipairs(ctx.groups) do
        local pinned = forcedSlot and (forcedSlot == group.slot or forcedSlot == group.other)
        local patterns = pinned and makePatterns(ctx,group,forcedSlot,forced) or defaults[i]
        if #patterns==0 then return nil,-math.huge end
        stages[#stages+1]={patterns=patterns,slot=group.slot}
    end
    -- Constrain the set choices early; independent slots can be added cheaply.
    table.sort(stages,function(a,b)
        if #a.patterns == #b.patterns then return a.slot<b.slot end
        return #a.patterns>#b.patterns
    end)

    local suffixCounts = {[#stages+1]={}}

    local best, bestScore, picks, counts = nil, minimum or -math.huge, {}, {}
    local function value(id,n)
        local scores=ctx.bonus[id]
        return scores[math.min(n,#scores)] or 0
    end
    -- Get an attainable incumbent immediately. The best raw pieces frequently
    -- already beat entire sets. This bound is used only after cross-slot
    -- acquisition limits have been repaired.
    local bonus=0
    for i,stage in ipairs(stages) do
        picks[i]=stage.patterns[1]
        for id,n in pairs(picks[i].counts) do counts[id]=(counts[id] or 0)+n end
    end
    for id,n in pairs(counts) do bonus=bonus+value(id,n) end
    local seed,seedScore=repair(ctx,picks,bonus,bestScore)
    if seed then best,bestScore=seed,seedScore end
    counts={}
    -- Remove a pattern only when a simpler pattern strictly dominates it for
    -- *every* attainable set bonus and every acquisition conflict. Caps
    -- used only in this slot group cannot consume another group's headroom.
    local function independent(p)
        local function safe(e)
            if not e then return true end
            for key in pairs(e.limits) do
                if ctx.external[key] then return false end
            end
            return true
        end
        return safe(p.best.first) and safe(p.best.second)
    end
    -- Upper envelope of marginal contribution from adding this many pieces
    -- to an otherwise arbitrary attainable partial set.
    local maxGain={}
    for id,scores in pairs(ctx.bonus) do
        local g={[0]=0,[1]=0,[2]=0}
        for n=0,#scores do
            for k=1,2 do g[k]=math.max(g[k],value(id,n+k)-value(id,n)) end
        end
        maxGain[id]=g
    end
    -- Bound the *whole-set gain* as well as each individual pattern. Raw
    -- losses to a fallback can be charged to a set because the corresponding
    -- fallbacks can replace all of its pieces simultaneously. Leave sets that
    -- occur in mixed patterns for the full search. Iterate as removing one
    -- dominated choice may expose further weak sets.
    local changed=true
    while changed do
        changed=false
        local solo, mixed = {}, {}
        for i,stage in ipairs(stages) do
            local fallback
            for _,p in ipairs(stage.patterns) do
                if not next(p.counts) and independent(p) then fallback=p.best.score; break end
            end
            local keep={}
            for _,p in ipairs(stage.patterns) do
                ctx.tick()
                local optimistic=p.best.score
                for id,k in pairs(p.counts) do optimistic=optimistic+maxGain[id][k] end
                if not fallback or optimistic>=fallback-1e-8 then
                    keep[#keep+1]=p
                    local id,k=next(p.counts)
                    if id then
                        if next(p.counts,id) or not fallback then
                            for x in pairs(p.counts) do mixed[x]=true end
                        else
                            solo[id]=solo[id] or {}
                            solo[id][i]=solo[id][i] or {}
                            local cost=fallback-p.best.score
                            solo[id][i][k]=math.min(solo[id][i][k] or math.huge,cost)
                        end
                    end
                end
            end
            stage.patterns=keep
        end
        local dominated={}
        for id,groups in pairs(solo) do
            if not mixed[id] then
                local costs={[0]=0}
                for _,options in pairs(groups) do
                    local update={}
                    for count,c in pairs(costs) do
                        update[count]=math.min(update[count] or math.huge,c)
                        for k,loss in pairs(options) do
                            update[count+k]=math.min(update[count+k] or math.huge,c+loss)
                        end
                    end
                    costs=update
                end
                local useful=false
                for n,loss in pairs(costs) do
                    if n>0 and value(id,n)>loss+1e-8 then useful=true; break end
                end
                if not useful then dominated[id]=true end
            end
        end
        if next(dominated) then
            for _,stage in ipairs(stages) do
                local keep={}
                for _,p in ipairs(stage.patterns) do
                    local id=next(p.counts)
                    if not dominated[id] then keep[#keep+1]=p else changed=true end
                end
                stage.patterns=keep
            end
        end
    end
    -- Refresh bounds after removing dominated choices.
    for i=#stages,1,-1 do
        local counts={}
        for _,p in ipairs(stages[i].patterns) do
            for id,n in pairs(p.counts) do counts[id]=math.max(counts[id] or 0,n) end
        end
        for id,n in pairs(suffixCounts[i+1]) do counts[id]=(counts[id] or 0)+n end
        suffixCounts[i]=counts
    end
    -- Fractional set-credit bound. Each new piece receives at most the
    -- largest average gain to any reachable threshold from the current count.
    -- A group can only take ONE of its patterns, so competing sets do not all
    -- collect the same free armor slot. Bound group losses after including
    -- those credits; this is much tighter than summing all possible bonuses.
    local function upper(i, raw)
        local earned, credits = raw, {}
        for id in pairs(ctx.bonus) do
            local n = counts[id] or 0
            local current = value(id,n)
            earned = earned + current
            local max = math.min(n+(suffixCounts[i][id] or 0),#ctx.bonus[id])
            local credit = 0
            for target=n+1,max do
                credit=math.max(credit,(value(id,target)-current)/(target-n))
            end
            credits[id]=credit
        end
        for j=i,#stages do
            local maximum=-math.huge
            for _,p in ipairs(stages[j].patterns) do
                ctx.tick()
                local v=p.best.score
                for id,k in pairs(p.counts) do v=v+credits[id]*k end
                maximum=math.max(maximum,v)
            end
            earned=earned+maximum
        end
        return earned
    end

    local function visit(i,raw)
        ctx.tick()
        local bound=upper(i,raw)
        if bound<=bestScore+1e-8 then return end
        if i>#stages then
            local result, score=repair(ctx,picks,bound-raw,bestScore)
            if result then best,bestScore=result,score end
            return
        end
        for _, p in ipairs(stages[i].patterns) do
            picks[i]=p
            for id,n in pairs(p.counts) do counts[id]=(counts[id] or 0)+n end
            visit(i+1,raw+p.best.score)
            for id,n in pairs(p.counts) do counts[id]=counts[id]-n end
        end
    end
    visit(1,0)
    return best,bestScore
end

function A.SolvePrepared(ctx)
    if not ctx.best then ctx.best,ctx.total=solvePrepared(ctx) end
    return ctx.best,ctx.total
end

function A.Solve(items,player,profile,checkpoint)
    return A.SolvePrepared(A.PrepareSolver(items,player,profile,checkpoint))
end

local function variant(item)
    local key = item.link and A.ItemVariantKey and A.ItemVariantKey(item.link)
    return key or item.link or ("item:" .. item.id)
end

local function rankedBefore(a,b)
    if a.total~=b.total then return a.total>b.total end
    if a.recommended~=b.recommended then return a.recommended end
    if a.item.id~=b.item.id then return a.item.id<b.item.id end
    return variant(a.item)<variant(b.item)
end

function A.RankPrepared(ctx, slot, limit, baseline)
    local pool=ctx.entries[slot]
    if not pool then return {} end
    limit=math.max(0,math.floor(limit or 10))
    if limit==0 then return {} end
    local bestTotal, baselineLoad
    if baseline then
        baselineLoad=baseline.loadout or baseline
        bestTotal=baseline.total or A.LoadoutScore(baselineLoad,ctx.profile)
    else
        baselineLoad,bestTotal=A.SolvePrepared(ctx)
    end
    local recommended=baselineLoad[slot] and variant(baselineLoad[slot])
    local indexed,rows,complements={},{},{}
    local all = limit >= #pool
    local single = not both[slot] and not primary[slot]
    local function equivalence(entry)
        local keys={tostring(entry.set or 0)}
        if not single then
            -- Forced items with no possible collision in the companion slot
            -- have an identical complementary problem (including paired
            -- main/off-hand restrictions). Check actual per-group keys.
            local blocked=ctx.partnerKeys and ctx.partnerKeys[slot]
            if not blocked then
                ctx.partnerKeys=ctx.partnerKeys or {}
                blocked={}
                local companion=both[slot] or primary[slot]
                for _,p in ipairs(ctx.entries[companion] or {}) do
                    ctx.tick()
                    for key in pairs(p.limits) do blocked[key]=true end
                end
                ctx.partnerKeys[slot]=blocked
            end
            if entry.set then return end -- same-ID pair only earns one piece
            for key in pairs(entry.limits) do if blocked[key] then return end end
            if slot==16 then keys[#keys+1]=entry.item.loc=="INVTYPE_2HWEAPON" and "2h" or "1h" end
        end
        for key,cap in pairs(entry.limits) do
            if cap<1 then return end
            if ctx.external[key] then keys[#keys+1]=("%d/%s=%d"):format(#key,key,cap) end
        end
        table.sort(keys)
        return table.concat(keys,"|")
    end
    -- Routes of the same item share a row. Rank by the best legal route, while
    -- keeping that route's item/source and the actual companion-slot changes.
    for _, e in ipairs(pool) do
        ctx.tick()
        local key=variant(e.item)
        local existing=indexed[key]
        local threshold=existing and existing.total or -math.huge
        if #rows>=limit then threshold=math.max(threshold,rows[#rows].total-1e-7) end
        local signature=equivalence(e)
        local previous=signature and complements[signature]
        local loadout,score
        if previous then
            score=previous.total+e.score-previous.raw
            if score>threshold+1e-8 then
                loadout={}
                for where,it in pairs(previous.loadout) do loadout[where]=it end
                loadout[slot]=e.item
            end
        else
            loadout,score=solvePrepared(ctx,slot,e,threshold)
            if loadout and signature then complements[signature]={total=score,raw=e.score,loadout=loadout} end
        end
        if loadout and (not existing or score>existing.total+1e-8) then
            -- Accumulation order and cached-complement subtraction can differ
            -- by floating-point dust for two ways to wear the same outfit.
            if math.abs(score-bestTotal)<1e-8 then score=bestTotal end
            local row={item=loadout[slot],loadout=loadout,total=score,delta=score-bestTotal,
                recommended=key==recommended}
            indexed[key]=row
            if not all then
                if existing then
                    for i,old in ipairs(rows) do if old==existing then table.remove(rows,i); break end end
                end
                local at=#rows+1
                for i,other in ipairs(rows) do
                    if rankedBefore(row,other) then at=i; break end
                end
                table.insert(rows,at,row)
                if #rows>limit then indexed[variant(table.remove(rows).item)]=nil end
            end
        end
    end
    -- A full list needs no cutoff. Keep the best legal route per variant and
    -- sort once, so browsing hundreds of options does not repeatedly shift them.
    if all then
        for _,row in pairs(indexed) do rows[#rows+1]=row end
        table.sort(rows,rankedBefore)
    end
    for i,r in ipairs(rows) do r.rank=i end
    return rows
end

function A.RankSlot(items,player,profile,slot,limit,baseline,checkpoint)
    return A.RankPrepared(A.PrepareSolver(items,player,profile,checkpoint),slot,limit,baseline)
end
