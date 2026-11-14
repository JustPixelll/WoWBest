local _, A = ...

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

local function inlineRed(text)
    if not text then return false end
    for hex in text:gmatch("|c%x%x(%x%x%x%x%x%x)") do
        if tonumber(hex:sub(1, 2), 16) >= 217 and tonumber(hex:sub(3, 4), 16) <= 71
            and tonumber(hex:sub(5, 6), 16) <= 71 then return true end
    end
    return false
end

local function itemTooltip(link, stats, plannedSkill)
    if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then return nil, "unverified" end
    local tooltip = C_TooltipInfo.GetHyperlink(link)
    if not tooltip or not tooltip.lines or #tooltip.lines < 2 then return nil, "pending" end
    local uniqueLimit
    local kinds = Enum and Enum.TooltipDataLineType or {}
    for _, line in ipairs(tooltip.lines) do
        local left = line.leftText
        if left and RETRIEVING_ITEM_INFO and left == RETRIEVING_ITEM_INFO then return nil, "pending" end
        local restriction = line.type == nil or line.type == kinds.None or line.type == kinds.EquipSlot
            or line.type == kinds.ErrorLine or line.type == kinds.UsageRequirement or line.type == kinds.DisabledLine
        if restriction then
            local leftRed = red(line.leftColor) or inlineRed(left)
            local rightRed = red(line.rightColor) or inlineRed(line.rightText)
            -- A planning preview may disregard only its named skill on a red line.
            -- Check each side separately: an armor type in red still disqualifies it.
            if leftRed and not (plannedSkill and left and left:find(plannedSkill, 1, true)) then return nil, "ineligible" end
            if rightRed and not (plannedSkill and line.rightText and line.rightText:find(plannedSkill, 1, true)) then return nil, "ineligible" end
        end
        if left then
            left = left:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if left == ITEM_UNIQUE or left == ITEM_UNIQUE_EQUIPPABLE then uniqueLimit = 1 end
            uniqueLimit = numberIn(left, ITEM_UNIQUE_MULTIPLE) or uniqueLimit
            stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT or numberIn(left, DPS_TEMPLATE)
            stats.RESISTANCE0_NAME = stats.RESISTANCE0_NAME or numberIn(left, ARMOR_TEMPLATE)
            stats.ITEM_MOD_BLOCK_VALUE_SHORT = stats.ITEM_MOD_BLOCK_VALUE_SHORT or numberIn(left, SHIELD_BLOCK_TEMPLATE)
        end
    end
    return true, nil, uniqueLimit
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
    if type(family) == "number" and family > 0 then
        item.unique, item.uniqueLimit = "group:" .. family, count or 1
    elseif C_Item.GetItemUniquenessByID then
        local unique, name, max, id = C_Item.GetItemUniquenessByID(item.link)
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
end

local fallbackKeys = {
    sp = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", heal = "ITEM_MOD_SPELL_HEALING_DONE_SHORT",
    spFire = "ITEM_MOD_FIRE_SPELL_DAMAGE_SHORT", spFrost = "ITEM_MOD_FROST_SPELL_DAMAGE_SHORT",
    spArcane = "ITEM_MOD_ARCANE_SPELL_DAMAGE_SHORT", spNature = "ITEM_MOD_NATURE_SPELL_DAMAGE_SHORT",
    spHoly = "ITEM_MOD_HOLY_SPELL_DAMAGE_SHORT", spShadow = "ITEM_MOD_SHADOW_SPELL_DAMAGE_SHORT",
    mpr = "ITEM_MOD_MANA_REGENERATION_SHORT", hpr = "ITEM_MOD_HEALTH_REGEN_SHORT",
    blockValue = "ITEM_MOD_BLOCK_VALUE_SHORT", armor = "RESISTANCE0_NAME",
}
local function fillSupplement(item, tokens)
    if not tokens then return end
    local stats, minDamage, maxDamage, speed = item.stats
    local hit, crit = 0, 0
    for key, number in tokens:gmatch("(%a+)(%-?%d+)") do
        local amount = tonumber(number)
        local token = fallbackKeys[key]
        -- 'sp' and 'heal' here are TOTAL healing and damage, including any
        -- shared spell power. Never layer these totals over live shared SP.
        if token and stats[token] == nil and
            (key ~= "sp" and key ~= "heal" or not stats.ITEM_MOD_SPELL_POWER_SHORT) then
            stats[token] = amount
        elseif key == "hit" or key == "spellHit" then hit = math.max(hit, amount)
        elseif key == "crit" or key == "spellCrit" then crit = math.max(crit, amount)
        elseif key == "uniq" and amount == 1 and not item.unique then
            item.unique, item.uniqueLimit = true, 1
        elseif key == "dmin" then minDamage = amount
        elseif key == "dmax" then maxDamage = amount
        elseif key == "speed" then speed = amount end
    end
    -- The older Forever source uses percentages. Current clients ordinarily
    -- supply unified ratings; never award both representations.
    if hit > 0 and not stats.ITEM_MOD_HIT_RATING_SHORT and not stats.ITEM_MOD_HIT_SPELL_RATING_SHORT
        and not stats.ITEM_MOD_HIT_MELEE_RATING_SHORT and not stats.ITEM_MOD_HIT_RANGED_RATING_SHORT then
        stats.HIT_PERCENT = hit
    end
    if crit > 0 and not stats.ITEM_MOD_CRIT_RATING_SHORT and not stats.ITEM_MOD_CRIT_SPELL_RATING_SHORT
        and not stats.ITEM_MOD_CRIT_MELEE_RATING_SHORT and not stats.ITEM_MOD_CRIT_RANGED_RATING_SHORT then
        stats.CRIT_PERCENT = crit
    end
    if not stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT and minDamage and maxDamage and speed and speed > 0 then
        stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT = (minDamage + maxDamage) * 500 / speed
    end
end

function A.ReadCandidate(record, player, supplement)
    local id = record.id
    if not id or not player.level or player.level < 1 then return nil, "unverified" end
    if record.minLevel and record.minLevel > player.level then return nil, "ineligible" end
    if not (C_Item and C_Item.GetItemInfo and C_Item.GetItemStats and C_PlayerInfo and C_PlayerInfo.CanUseItem) then
        return nil, "unverified"
    end
    local query = record.link or id
    if C_Item.GetItemInfoInstant then
        local _, _, _, slot, _, classID, subID = C_Item.GetItemInfoInstant(query)
        if slot and slot ~= "" and classID and subID and proficiency(classID, subID, slot, player) == false then
            return nil, "ineligible"
        end
    end
    local name, link, quality, itemLevel, minLevel, _, _, _, loc, texture, _, classID, subID, bindType, _, setID = C_Item.GetItemInfo(query)
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
    local trained = proficiency(classID, subID, loc, player)
    if trained == nil then return nil, "unverified" end
    if not trained then return nil, "ineligible" end
    local usable = C_PlayerInfo.CanUseItem(id)
    if usable == nil then return nil, "unverified" end
    if not usable then return nil, "ineligible" end

    local live = C_Item.GetItemStats(link)
    if live == nil then return nil, "pending" end
    local stats = {}
    for stat, value in pairs(live) do
        if type(value) == "number" then stats[stat] = value end
    end
    local ok, status, tipLimit = itemTooltip(link, stats)
    if not ok then return nil, status end
    local item = {}
    for field, value in pairs(record) do item[field] = value end
    item.name, item.link, item.loc, item.quality, item.itemLevel = name, link, loc, quality, itemLevel
    item.classID, item.subID, item.stats = classID, subID, stats
    item.minLevel, item.texture, item.bindType, item.setID = minLevel, texture, bindType, setID
    readUnique(item, tipLimit)
    fillSupplement(item, record.foreverStats or supplement)
    return item, "ok"
end
