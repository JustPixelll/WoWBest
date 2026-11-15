local _, A = ...

-- Ignore display color and localized names, preserve the entire item payload.
-- In particular the per-instance field can influence a random suffix. Neither
-- an item ID nor such a variant key identifies a physical equipped copy.
local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function hiddenTable(value)
    return secret(value) or value and canaccesstable and not canaccesstable(value)
end

function A.ItemVariantKey(link)
    if secret(link) or type(link) ~= "string" then return nil end
    local key = link:match("|H(item:[^|]+)|h") or link:match("^(item:[^|]+)$")
    if not key then return nil end
    local id = key:match("^item:(%d+):") or key:match("^item:(%d+)$")
    if id and tonumber(id) > 0 then return key, tonumber(id) end
end

local itemSupplements
function A.GetItemSupplement(id)
    if not itemSupplements then
        itemSupplements = {}
        for _, row in ipairs(A.Catalog or {}) do
            if row.foreverStats then itemSupplements[row.id] = row.foreverStats end
        end
    end
    return itemSupplements[id]
end

-- Weapon subclass -> the learned proficiency spell. This lets a newly trained
-- weapon work immediately, including Forever's new class/weapon combinations.
local weaponSkills = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199,
    [6] = 200, [7] = 201, [8] = 202, [10] = 227, [13] = 15590, [15] = 1180,
    [16] = 2567, [18] = 5011, [19] = 5009,
}
-- Every Forever class can wear cloth. The client still checks individual items.
local armorSkills = { [2] = 9077, [3] = 8737, [4] = 750, [6] = 9116 }
local bodyArmor = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_SHIELD = true,
}
local otherSlots = {
    INVTYPE_CLOAK = true, INVTYPE_NECK = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
    INVTYPE_HOLDABLE = true, INVTYPE_RELIC = true, INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true,
}

local function isLearned(spell)
    -- IsPlayerSpell includes passive proficiency spells on Forever.
    local check = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown)
    if check then return check(spell) == true end
end

function A.GetPlayer()
    local _, class, classID = UnitClass("player")
    local _, race, raceID = UnitRace("player")
    local dual
    if CanDualWield then dual = CanDualWield() else dual = isLearned(674) end
    return {
        class = class, classID = classID, race = race, raceID = raceID,
        level = UnitLevel("player"), faction = UnitFactionGroup("player"),
        dual = dual == true, learned = {}, requested = {},
    }
end

local function proficiency(classID, subID, loc, player)
    if not (bodyArmor[loc] or otherSlots[loc]) then return false end
    local spell
    if classID == 2 then
        spell = weaponSkills[subID]
        if not spell then return false end -- excludes fishing poles and NPC weapons
    elseif classID == 4 then
        -- Rings, cloaks, frills and relics have no armor training requirement.
        if bodyArmor[loc] then spell = armorSkills[subID] end
    else
        return false
    end
    if loc == "INVTYPE_WEAPONOFFHAND" and not player.dual then return false end
    if not spell then return true end
    player.learned = player.learned or {}
    if player.learned[spell] == nil then player.learned[spell] = isLearned(spell) end
    return player.learned[spell]
end

-- Match a Blizzard localized format with exactly one numeric argument. Avoid
-- guessing whether an unrelated number is damage, armor or a requirement.
local patterns = {}
local function numberIn(text, template)
    if not (text and template) then return nil end
    local pattern = patterns[template]
    if pattern == nil then
        local a, b = template:find("%%[%d%.$]*[dfgs]")
        if not a then
            patterns[template] = false
            return nil
        end
        local function literal(s) return (s:gsub("(%W)", "%%%1")) end
        pattern = "^" .. literal(template:sub(1, a - 1)) .. "([%d]+[.,]?[%d]*)" .. literal(template:sub(b + 1)) .. "$"
        patterns[template] = pattern
    end
    if pattern then
        local number = text:match(pattern)
        if number then return tonumber((number:gsub(",", "."))) end
    end
end

local function red(color)
    return color and color.r and color.g and color.b
        and color.r >= .85 and color.g <= .28 and color.b <= .28
end

local function secretColor(color)
    return hiddenTable(color) or color and (secret(color.r) or secret(color.g) or secret(color.b))
end

local function inlineRed(text)
    if not text then return false end
    for hex in text:gmatch("|c%x%x(%x%x%x%x%x%x)") do
        if tonumber(hex:sub(1, 2), 16) >= 217 and tonumber(hex:sub(3, 4), 16) <= 71
            and tonumber(hex:sub(5, 6), 16) <= 71 then return true end
    end
    return false
end

local function startsWith(text, label)
    return type(label) == "string" and label ~= "" and text:sub(1, #label) == label
end


-- Short stat labels come from the client locale. Numeric stat and permanent
-- enchant lines may be absent from the native stat map on a particular build.
local statNames = {STRENGTH="Strength", AGILITY="Agility", STAMINA="Stamina",
    INTELLECT="Intellect", SPIRIT="Spirit", ATTACK_POWER="Attack Power", RANGED_ATTACK_POWER="Ranged Attack Power",
    SPELL_POWER="Spell Power", HEALTH="Health", MANA="Mana", HIT_RATING="Hit Rating", CRIT_RATING="Critical Strike Rating"}
local function numericStat(text)
    local num, label = text:match("^([+-]%d+) (.+)$")
    if not num then label, num = text:match("^(.+) ([+-]%d+)$") end
    if not num then return end
    for token, english in pairs(statNames) do
        local key = "ITEM_MOD_" .. token .. "_SHORT"
        if label == _G[key] or label == english then return key, tonumber(num) end
    end
    if label == ALL_STATS or label == "All Stats" then return "all", tonumber(num) end
end

local function readEnchant(left, facts)
    local template = ENCHANTED_TOOLTIP_LINE
    local start = template and template:find("%s", 1, true)
    if start then
        local before, after = template:sub(1, start-1), template:sub(start+2)
        if startsWith(left, before) and (#after == 0 or left:sub(-#after) == after) then
            left = left:sub(#before + 1, #left - #after)
        end
    end
    left = left:gsub("^Enchanted: ", "")
    local key, amount = numericStat(left)
    if not key then facts.unknownEnchant = true; return end
    facts.enchant = facts.enchant or {}
    if key == "all" then
        for _, stat in ipairs({"STRENGTH","AGILITY","STAMINA","INTELLECT","SPIRIT"}) do
            facts.enchant["ITEM_MOD_" .. stat .. "_SHORT"] = amount
        end
    else facts.enchant[key] = amount end
end

local function separateEnchant(stats, live, facts, linkKey)
    -- Normalize the base item first. A +spell power enchant must not consume
    -- part of the underlying weapon's separate healing/damage bonus.
    local cleared, changed = linkKey:gsub("^(item:%d+:)[1-9]%d*", "%10", 1)
    if changed == 0 then return false end
    local base = C_Item.GetItemStats(cleared)
    if not base or hiddenTable(base) then return false end
    local keys = facts.enchant
    if keys.ITEM_MOD_SPELL_POWER_SHORT then
        -- The same enchant can appear in all three raw spell-power channels.
        -- Restore them together or it can remain inside a healing/damage total.
        keys = {ITEM_MOD_SPELL_POWER_SHORT=true, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT=true,
            ITEM_MOD_SPELL_HEALING_DONE_SHORT=true}
        for key in pairs(facts.enchant) do keys[key]=true end
    end
    for key in pairs(keys) do
        local before = base[key]
        if secret(before) or (before ~= nil and type(before) ~= "number") then return false end
    end
    for key in pairs(keys) do
        if live[key] ~= nil or base[key] ~= nil then stats[key] = base[key] end
    end
    return true
end

-- The damage and speed columns share one tooltip row in Forever. Match only a
-- two-number range paired with a labeled, single swing interval. This accepts
-- translated labels and decimal commas without reading unrelated numbers.
local function readWeaponLine(left, right, facts)
    local low, high = left:match("^%s*(%d+)%s*[-–]%s*(%d+)%s*[^%d]*$")
    local number = right:match("^%D*(%d+[%.,]%d+)%D*$")
    if not low or not number then return end
    local speed = tonumber((number:gsub(",", ".")))
    if speed and speed > 0 and tonumber(high) >= tonumber(low) then
        facts.dmin, facts.dmax, facts.speed = tonumber(low), tonumber(high), speed * 1000
    end
end

local function inspectTooltip(tooltip, stats, plannedSkill, facts, weapon)
    if hiddenTable(tooltip) then return nil, "unverified" end
    if not tooltip then return nil, "pending" end
    local lines = tooltip.lines
    if hiddenTable(lines) then return nil, "unverified" end
    if not lines or #lines < 2 then return nil, "pending" end
    local uniqueLimit, effect
    local kinds = Enum and Enum.TooltipDataLineType or {}
    for _, line in ipairs(lines) do
        if hiddenTable(line) or secret(line.type) or secret(line.leftText) or secret(line.rightText) then
            return nil, "unverified"
        end
        local left = line.leftText
        if left and RETRIEVING_ITEM_INFO and left == RETRIEVING_ITEM_INFO then return nil, "pending" end
        local restriction = line.type == nil or line.type == kinds.None or line.type == kinds.EquipSlot
            or line.type == kinds.ErrorLine or line.type == kinds.UsageRequirement or line.type == kinds.DisabledLine
        if restriction then
            if secretColor(line.leftColor) or secretColor(line.rightColor) then return nil, "unverified" end
            local leftRed = red(line.leftColor) or inlineRed(left)
            local rightRed = red(line.rightColor) or inlineRed(line.rightText)
            -- A planning preview may disregard only its named skill on a red line.
            -- Check each side separately: an armor type in red still disqualifies it.
            if leftRed and not (plannedSkill and left and left:find(plannedSkill, 1, true)) then return nil, "ineligible" end
            if rightRed and not (plannedSkill and line.rightText and line.rightText:find(plannedSkill, 1, true)) then return nil, "ineligible" end
        end
        if left then
            left = left:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if facts then
                local kind = line.type
                if kind and kind == kinds.ItemEnchantmentPermanent then
                    readEnchant(left, facts)
                elseif not kind or kind == kinds.None then
                    local key, amount = numericStat(left)
                    if key and key ~= "all" and stats[key] == nil then stats[key] = amount end
                end
                if (kind ~= nil and (kind == kinds.ItemSpellTriggerOnProc or kind == kinds.ItemSpellTriggerOnUse))
                    or startsWith(left, ITEM_SPELL_TRIGGER_ONUSE) or startsWith(left, ITEM_SPELL_TRIGGER_ONPROC)
                    or left:match("^Use:") or left:match("^Chance on hit:") or left:match("^Equip: Chance on ") then effect = true end
                -- The complete sentence must describe an unconditional stat.
                -- Do not match a substring on an enchant, set, proc or use line.
                if (not kind or kind == kinds.None or kind == kinds.ItemSpellTriggerOnEquip)
                    and (left:sub(1, 6) == "Equip:" or left:sub(1, 8) == "Restores") then
                    for _, rule in ipairs(A.PassiveTooltipRules or {}) do
                        local first, second = left:match(rule[1])
                        if first then
                            facts[rule[2]] = (facts[rule[2]] or 0) + tonumber((first:gsub(",", "")))
                            if second then facts[rule[3]] = (facts[rule[3]] or 0) + tonumber((second:gsub(",", ""))) end
                            break
                        end
                    end
                end
                if weapon and line.rightText then readWeaponLine(left, line.rightText, facts) end
            end
            if left == ITEM_UNIQUE or left == ITEM_UNIQUE_EQUIPPABLE then uniqueLimit = 1 end
            uniqueLimit = numberIn(left, ITEM_UNIQUE_MULTIPLE) or uniqueLimit
            stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or numberIn(left, DPS_TEMPLATE)
            stats.RESISTANCE0_NAME = stats.RESISTANCE0_NAME or numberIn(left, ARMOR_TEMPLATE)
            stats.ITEM_MOD_BLOCK_VALUE_SHORT = stats.ITEM_MOD_BLOCK_VALUE_SHORT or numberIn(left, SHIELD_BLOCK_TEMPLATE)
        end
    end
    return true, nil, uniqueLimit, effect
end

local function itemTooltip(link, stats, plannedSkill, facts, weapon)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil, "unverified" end
    return inspectTooltip(C_TooltipInfo.GetHyperlink(link), stats, plannedSkill, facts, weapon)
end

function A.MerchantListingUsable(index)
    local read = C_TooltipInfo and C_TooltipInfo.GetMerchantItem
    return read and inspectTooltip(read(index), {}) == true
end

local planningSlots = {
    [1] = {"INVTYPE_HEAD", 1}, [2] = {"INVTYPE_NECK", 2}, [3] = {"INVTYPE_SHOULDER", 3},
    [5] = {"INVTYPE_CHEST", 5}, [6] = {"INVTYPE_WAIST", 6}, [7] = {"INVTYPE_LEGS", 7},
    [8] = {"INVTYPE_FEET", 8}, [9] = {"INVTYPE_WRIST", 9}, [10] = {"INVTYPE_HAND", 10},
    [11] = {"INVTYPE_FINGER", 11}, [12] = {"INVTYPE_TRINKET", 13}, [13] = {"INVTYPE_WEAPON", 16},
    [14] = {"INVTYPE_SHIELD", 17}, [15] = {"INVTYPE_RANGED", 18}, [16] = {"INVTYPE_CLOAK", 15},
    [17] = {"INVTYPE_2HWEAPON", 16}, [20] = {"INVTYPE_ROBE", 5}, [21] = {"INVTYPE_WEAPONMAINHAND", 16},
    [22] = {"INVTYPE_WEAPONOFFHAND", 17}, [23] = {"INVTYPE_HOLDABLE", 17}, [25] = {"INVTYPE_THROWN", 18},
    [26] = {"INVTYPE_RANGEDRIGHT", 18}, [28] = {"INVTYPE_RELIC", 18},
}

-- A non-ranked preview. In particular, do not call ReadCandidate with simulated
-- professions or insert this item into the equippable set.
function A.PlanningSlot(record, player, skillName)
    local slot = planningSlots[record.invType]
    if not slot or not record.classID or record.subclassID == nil then return end
    if not proficiency(record.classID, record.subclassID, slot[1], player) then return end
    if C_Item and C_Item.IsItemDataCachedByID and C_Item.IsItemDataCachedByID(record.id) then
        local _, link, _, _, level, _, _, _, loc, _, _, cls, sub = C_Item.GetItemInfo(record.id)
        if not link or not level or level > player.level or cls ~= record.classID or sub ~= record.subclassID then return end
        if loc ~= slot[1] and not (loc == "INVTYPE_ROBE" and slot[2] == 5) then return end
        if not itemTooltip(link, {}, skillName) then return end
    end
    return slot[2]
end

local function readUnique(item, tipLimit)
    local family, count
    if C_Item.GetItemUniqueness then family, count = C_Item.GetItemUniqueness(item.link) end
    if secret(family) or secret(count) then return false end
    if type(family) == "number" and family > 0 then
        item.unique, item.uniqueLimit = "group:" .. family, count or 1
    elseif C_Item.GetItemUniquenessByID then
        local unique, name, max, id = C_Item.GetItemUniquenessByID(item.link)
        if secret(unique) or secret(name) or secret(max) or secret(id) then return false end
        if id and id > 0 then
            item.unique, item.uniqueLimit = "group:" .. id, max or 1
        elseif name and name ~= "" then
            item.unique, item.uniqueLimit = "group:" .. name, max or 1
        elseif unique or family == -1 then
            item.unique, item.uniqueLimit = true, tipLimit or max or count or 1
        end
    elseif family == -1 then
        item.unique, item.uniqueLimit = true, tipLimit or count or 1
    end
    if tipLimit then
        -- Some items have a personal ownership limit in addition to a group.
        item.itemLimit = tipLimit
        if not item.unique then item.unique, item.uniqueLimit = true, tipLimit end
    end
    return true
end

local fallbackKeys = {
    str="STRENGTH", agi="AGILITY", int="INTELLECT", spi="SPIRIT", sta="STAMINA",
    ap="ATTACK_POWER", rap="RANGED_ATTACK_POWER", spFire="FIRE_SPELL_DAMAGE", spFrost="FROST_SPELL_DAMAGE",
    spArcane="ARCANE_SPELL_DAMAGE", spNature="NATURE_SPELL_DAMAGE", spHoly="HOLY_SPELL_DAMAGE",
    spShadow="SHADOW_SPELL_DAMAGE", mpr="MANA_REGENERATION", hpr="HEALTH_REGEN",
    blockValue="BLOCK_VALUE", extraArmor="EXTRA_ARMOR", health="HEALTH", mana="MANA",
}
for token, key in pairs(fallbackKeys) do fallbackKeys[token] = "ITEM_MOD_" .. key .. "_SHORT" end
fallbackKeys.armor = "RESISTANCE0_NAME"
fallbackKeys.humanoidAP, fallbackKeys.flatWeapon = "HUMANOID_ATTACK_POWER", "FLAT_WEAPON_DAMAGE"

local ratings = {hit="HIT", crit="CRIT", haste="HASTE", dodge="DODGE", parry="PARRY", block="BLOCK", expertise="EXPERTISE"}
local function aliases(stats, canonical, ...)
    local value = stats[canonical]
    local variant
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if stats[key] then variant = math.max(variant or stats[key], stats[key]) end
        stats[key] = nil
    end
    stats[canonical] = value or variant
end

local function unifyStats(stats)
    for _, stat in ipairs({"HIT", "CRIT", "HASTE"}) do
        local key = "ITEM_MOD_" .. stat
        aliases(stats, key .. "_RATING_SHORT", key .. "_MELEE_RATING_SHORT",
            key .. "_SPELL_RATING_SHORT", key .. "_RANGED_RATING_SHORT")
    end
    aliases(stats, "RESISTANCE0_NAME", "ITEM_MOD_ARMOR_SHORT")
    aliases(stats, "ITEM_MOD_EXTRA_ARMOR_SHORT", "ITEM_MOD_BONUS_ARMOR_SHORT")
    aliases(stats, "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DEFENSE_RATING_SHORT")
end

local function tokensInto(values, tokens)
    if not tokens then return end
    for token, amount in tokens:gmatch("(%a+)(%-?%d+%.?%d*)") do values[token] = tonumber(amount) end
end

-- A permanent enchant is added to the underlying item's stats. A random
-- suffix, gem, or bonus field can change those base stats in its own right.
local function standardVariant(key)
    if not key then return true end
    local position = 0
    for field in (key .. ":"):gmatch("([^:]*):") do
        position = position + 1
        -- item:ID:enchant:gem1..gem4:suffix:uniqueID:linkLevel:spec:...
        if ((position >= 4 and position <= 8) or position >= 12) and field ~= "" and field ~= "0" then return false end
    end
    return true
end

local function fillPassive(item, value, typedSpellLine)
    local stats = item.stats
    for token, key in pairs(fallbackKeys) do
        if stats[key] == nil then stats[key] = value[token] end
    end
    -- Some clients expose one generic AP aura in both attack fields. Keep a
    -- genuine ranged-only addition, and avoid scoring the generic amount a
    -- second time for hunters. Only disambiguate with item-specific evidence.
    local attack = stats.ITEM_MOD_ATTACK_POWER_SHORT
    if value.ap and attack == value.ap then
        for _, pair in ipairs({{"ITEM_MOD_RANGED_ATTACK_POWER_SHORT", value.rap},
                               {"ITEM_MOD_FERAL_ATTACK_POWER_SHORT", value.feralAP}}) do
            local stat, extra = pair[1], pair[2]
            if stats[stat] == attack + (extra or 0) then stats[stat] = extra end
        end
    elseif not value.ap and value.humanoidAP and attack == value.humanoidAP then
        stats.ITEM_MOD_ATTACK_POWER_SHORT = nil
    end
    for token, kind in pairs(ratings) do
        if stats["ITEM_MOD_" .. kind .. "_RATING_SHORT"] then
            stats[kind .. "_PERCENT"] = nil
        elseif not stats[kind .. "_PERCENT"] then stats[kind .. "_PERCENT"] = value[token] end
    end
    if not stats.ITEM_MOD_DEFENSE_SKILL_RATING_SHORT then stats.DEFENSE_SKILL = value.defense end
    if value.uniq == 1 and not item.unique then item.unique, item.uniqueLimit = true, 1 end

    -- These tooltip/snapshot amounts are TOTALS in each school. If the client
    -- exposes a shared component, only its residual belongs in the specific
    -- damage/heal key. Separate independent native stats otherwise survive.
    local shared = stats.ITEM_MOD_SPELL_POWER_SHORT or value.shared or 0
    if typedSpellLine and not value.shared and (shared == value.sp or shared == value.heal) then
        -- A client may report an explicit damage-only or healing-only line as
        -- generic spell power. Only the portion present in BOTH channels can
        -- be shared. A distinct value (e.g. an additional effect) survives.
        local common = math.min(value.sp or 0, value.heal or 0)
        if shared > common then
            if not value.sp and stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT == shared then
                stats.ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = nil
            end
            if not value.heal and stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT == shared then
                stats.ITEM_MOD_SPELL_HEALING_DONE_SHORT = nil
            end
            shared = common
        end
    end
    stats.ITEM_MOD_SPELL_POWER_SHORT = shared ~= 0 and shared or nil
    local function component(key, direct)
        if direct == nil and value.shared == nil then return end
        local total = (direct or 0) + (value.shared or 0)
        if not stats[key] or stats[key] == total then
            local extra = math.max(0, total - shared)
            stats[key] = extra ~= 0 and extra or nil
        end
    end
    component("ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", value.sp)
    component("ITEM_MOD_SPELL_HEALING_DONE_SHORT", value.heal)
end

local function finalizeStats(item, tooltipFacts, record, key, supplement)
    local value = {}
    local typedSpellLine = tooltipFacts.heal or tooltipFacts.sp
    if standardVariant(key) then
        tokensInto(value, record.foreverStats or supplement)
        -- Older overlays may list the same universal hit/crit for both
        -- spell and melee, or under the spell name alone.
        value.hit = value.hit or value.spellHit
        value.crit = value.crit or value.spellCrit
        local cache = A.TooltipStatFallbacks and A.TooltipStatFallbacks[item.id]
        if cache and (cache:match("shared%d") or cache:match("heal%d") or cache:match("sp%d")) then
            value.shared, value.heal, value.sp = nil, nil, nil
            typedSpellLine = true
        end
        tokensInto(value, cache)
    end
    if tooltipFacts.shared or tooltipFacts.heal or tooltipFacts.sp then
        value.shared, value.heal, value.sp = nil, nil, nil
    end
    for token, amount in pairs(tooltipFacts) do
        if type(amount) == "number" then value[token] = amount end
    end
    fillPassive(item, value, typedSpellLine)
    if value.proc == 1 then item.unmodeledEffect = true end
    if item.classID ~= 2 then return end
    local dps = item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or item.stats.DPS
    local speed = value.speed and value.speed / 1000
    if speed and speed > 0 then item.weaponSpeed = speed end
    local low, high = value.dmin, value.dmax
    if low and high and low >= 0 and high >= low then
        -- A single physical range may omit a second elemental damage school.
        -- Prefer the total independently displayed DPS times swing interval
        -- for the mean if the two observations disagree.
        if dps and speed and math.abs((low + high) / (2 * speed) - dps) > .12 then
            item.minDamage, item.maxDamage = nil, nil
        else
            item.minDamage, item.maxDamage = low, high
            if not dps and speed and speed > 0 then item.stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = (low + high) / (2 * speed) end
        end
    end
end

local function readItem(record, player, supplement, equipped)
    local id = record.id
    if secret(id) or secret(record.link) or not id or not player.level or player.level < 1 then return nil, "unverified" end
    if record.minLevel and record.minLevel > player.level then return nil, "ineligible" end
    if not (C_Item and C_Item.GetItemInfo and C_Item.GetItemStats and C_PlayerInfo and C_PlayerInfo.CanUseItem) then
        return nil, "unverified"
    end
    local inputKey
    if record.link then
        local key, linkID = A.ItemVariantKey(record.link)
        if linkID ~= id then return nil, "unverified" end
        inputKey = key
    end
    local query = record.link or id
    if not equipped and C_Item.GetItemInfoInstant then
        local _, _, _, slot, _, classID, subID = C_Item.GetItemInfoInstant(query)
        if secret(slot) or secret(classID) or secret(subID) then return nil, "unverified" end
        if slot and slot ~= "" and classID and subID and proficiency(classID, subID, slot, player) == false then
            return nil, "ineligible"
        end
    end
    local name, link, quality, itemLevel, minLevel, _, _, _, loc, texture, _, classID, subID, bindType, _, setID = C_Item.GetItemInfo(query)
    if secret(name) or secret(link) or secret(minLevel) or secret(loc) or secret(classID) or secret(subID)
        or secret(setID) then return nil, "unverified" end
    if not name or not link then
        player.requested = player.requested or {}
        if C_Item.DoesItemExistByID and not C_Item.DoesItemExistByID(id) then return nil, "ineligible" end
        if not player.requested[id] and C_Item.RequestLoadItemDataByID then
            player.requested[id] = true
            C_Item.RequestLoadItemDataByID(id)
        end
        return nil, "pending"
    end
    if type(minLevel) ~= "number" then return nil, "unverified" end
    if minLevel > player.level then return nil, "ineligible" end
    if not equipped then
        local trained = proficiency(classID, subID, loc, player)
        if trained == nil then return nil, "unverified" end
        if not trained then return nil, "ineligible" end
    end
    local usable = C_PlayerInfo.CanUseItem(id)
    if secret(usable) or usable == nil then return nil, "unverified" end
    if not usable then return nil, "ineligible" end

    -- GetItemInfo may normalize an item's link; the hover/bag link is the
    -- authority on its rolled suffix, enchantments, and bonus/context fields.
    local statLink = record.link or link
    local live = C_Item.GetItemStats(statLink)
    if hiddenTable(live) then return nil, "unverified" end
    if live == nil then return nil, "pending" end
    local stats = {}
    for stat, value in pairs(live) do
        if secret(stat) or secret(value) then return nil, "unverified" end
        if type(value) == "number" then stats[stat] = value end
    end
    unifyStats(stats)
    local facts = {}
    local ok, status, tipLimit, effect = itemTooltip(statLink, stats, nil, facts, classID == 2)
    if not ok then return nil, status end
    local item = {}
    for field, value in pairs(record) do item[field] = value end
    -- Keep a full display link when the client supplied one for the same
    -- payload. A raw item string is still suitable for all client lookups.
    if inputKey and inputKey ~= A.ItemVariantKey(link) then link = statLink end
    item.name, item.link, item.loc, item.quality, item.itemLevel = name, link, loc, quality, itemLevel
    item.classID, item.subID, item.stats = classID, subID, stats
    item.minLevel, item.texture, item.bindType, item.setID = minLevel, texture, bindType, setID
    if not readUnique(item, tipLimit) then return nil, "unverified" end
    local normalizedKey = inputKey or A.ItemVariantKey(statLink)
    local enchantKnown = not facts.enchant or normalizedKey and separateEnchant(stats, live, facts, normalizedKey)
    finalizeStats(item, facts, record, normalizedKey, supplement)
    if facts.enchant and enchantKnown then
        for stat, bonus in pairs(facts.enchant) do
            local total = (stats[stat] or 0) + bonus
            -- The client may expose an exact total while omitting the base
            -- field. Preserve that stronger evidence when both are available.
            if live[stat] ~= nil then
                if bonus >= 0 then total = math.max(total, live[stat])
                else total = math.min(total, live[stat]) end
            end
            stats[stat] = total
        end
    end
    item.unmodeledEffect = (A.UnscoredEffectNotes and A.UnscoredEffectNotes[id] ~= nil)
        or ((effect or item.unmodeledEffect) and not (A.EffectNotes and A.EffectNotes[id]))
        or facts.unknownEnchant or not enchantKnown or nil
    if C_Item.GetDetailedItemLevelInfo then
        local effectiveLevel = C_Item.GetDetailedItemLevelInfo(statLink)
        if not secret(effectiveLevel) and type(effectiveLevel) == "number" and effectiveLevel > 0 then item.itemLevel = effectiveLevel end
    end
    return item, "ok"
end

function A.ReadCandidate(record, player, supplement)
    return readItem(record, player, supplement, false)
end

-- Only the player inventory-slot reader calls this. Actual worn gear (such
-- as a fishing pole) contributes to the baseline even when the optimizer
-- excludes its subclass from proposed equipment. Keep live requirements.
function A.ReadEquippedItem(record, player, supplement)
    return readItem(record, player, supplement, true)
end
