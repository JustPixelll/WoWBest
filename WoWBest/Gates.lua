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

local foreignTradeViews = {"IsTradeSkillLinked", "IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsNPCCrafting"}

local function personalTradeData()
    if not C_TradeSkillUI then return false end
    for _, name in ipairs(foreignTradeViews) do
        local query = C_TradeSkillUI[name]
        if query then
            local ok, active = pcall(query)
            if not ok or not readable(active) or active then return false end
        end
    end
    return true
end

local function knowsRecipe(id)
    if learnedSpell(id) then return true end
    local query = C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo
    if not query or not personalTradeData() then return false end
    local ok, info = pcall(query, id)
    return ok and readable(info) and readable(info.learned) and info.learned == true
end

local function craftableCount(id)
    local query = C_TradeSkillUI and C_TradeSkillUI.GetCraftableCount
    if not query or not personalTradeData() then return 0 end
    local ok, count = pcall(query, id)
    if ok and readable(count) and type(count) == "number" and count >= 1 then return math.floor(count) end
    return 0
end

function A.PersonalCraftCount(record, player)
    if not record.craftSpellID then return 0 end
    return checked(player, "craftableRecipes", record.craftSpellID, craftableCount)
end

local function hasRequiredItem(id)
    return C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, false) >= 1
end

local function questInLog(id)
    return C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) == true
end

local function currentMerchant()
    local guid = UnitGUID and UnitGUID("npc")
    if not readable(guid) or type(guid) ~= "string" then return end
    local npcID = tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    if not npcID then return end
    local interaction = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
    local merchantType = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.Merchant
    local open
    if interaction and merchantType then
        open = interaction(merchantType)
    elseif MerchantFrame and MerchantFrame.IsShown then
        open = MerchantFrame:IsShown()
    end
    if readable(open) and open then return npcID end
end

local function purchasable(info, index)
    if CanAffordMerchantItem then
        local affordable = CanAffordMerchantItem(index)
        if not readable(affordable) or not affordable then return false end
    end
    return readable(info) and (not canaccesstable or canaccesstable(info)) and readable(info.numAvailable)
        and (info.numAvailable == -1 or info.numAvailable > 0)
        and readable(info.isPurchasable) and info.isPurchasable
end

local function openMerchantStock(id)
    if currentMerchant() ~= id then return end
    if not (GetMerchantNumItems and C_MerchantFrame and C_MerchantFrame.GetItemInfo) then return end
    local count = GetMerchantNumItems()
    if not readable(count) then return end
    local stock = {}
    for index = 1, count do
        local info = C_MerchantFrame.GetItemInfo(index)
        if purchasable(info, index) then
            local itemID = GetMerchantItemID and GetMerchantItemID(index)
            if not readable(itemID) then itemID = info.itemID end
            if not readable(itemID) and GetMerchantItemLink then
                local link = GetMerchantItemLink(index)
                if readable(link) then itemID = tonumber(link:match("item:(%d+)")) end
            end
            if readable(itemID) then stock[itemID] = true end
        end
    end
    return stock
end

local function currencyQuantity(id)
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
    if readable(info) and readable(info.quantity) then return info.quantity end
    return 0
end

-- These four outdoor suppliers sell PvP gear with incompletely recorded
-- standing requirements. Consult the player's own open shop for each listing.
local supplyOfficers = {
    [14753] = {"Illiyana Moonblaze", "Alliance"}, [14754] = {"Kelm Hargunth", "Horde"},
    [13217] = {"Thanthaldis Snowgleam", "Alliance"}, [13219] = {"Jekyll Flandring", "Horde"},
}

local function purchaseTerms(index, info, gold)
    if not readable(info.price) or info.price < 0 or info.price > gold then return end
    local copies = info.numAvailable == -1 and 2 or math.min(info.numAvailable, 2)
    local terms = {}
    if info.price > 0 then
        copies = math.min(copies, math.floor(gold / info.price))
        terms[1] = ("%dg %ds %dc"):format(math.floor(info.price / 10000), math.floor(info.price / 100) % 100, info.price % 100)
    end
    local count = GetMerchantItemCostInfo and GetMerchantItemCostInfo(index)
    if not readable(count) or not readable(info.hasExtendedCost) then return end
    if info.hasExtendedCost and count == 0 then return end
    for costIndex = 1, count do
        if not GetMerchantItemCostItem then return end
        local _, amount, link, name = GetMerchantItemCostItem(index, costIndex)
        if not readable(link) or not readable(amount) or amount < 1 then return end
        local id = tonumber(link:match("currency:(%d+)"))
        -- Item exchanges could consume another piece in the proposed outfit.
        -- Unknown payment types or opaque currency balances cannot fund a copy.
        if not id then return end
        copies = math.min(copies, math.floor(currencyQuantity(id) / amount))
        if copies == 0 then return end
        terms[#terms + 1] = amount .. " " .. (readable(name) and name or ("currency #" .. id))
    end
    -- A zero price with no currency can be an incomplete merchant row.
    if #terms > 0 then return copies, table.concat(terms, " + ") end
end

local function pvpListing(index, gold, npcID, supplier)
    local info = C_MerchantFrame.GetItemInfo(index)
    if not purchasable(info, index) or not readable(info.isUsable) or not info.isUsable
        or not readable(info.stackCount) or info.stackCount ~= 1 then return end
    local link = GetMerchantItemLink(index) -- the sales list, never buyback
    local variant, itemID = A.ItemVariantKey(link)
    if not variant then return end
    local _, _, _, loc, _, itemClass = C_Item.GetItemInfoInstant(link)
    if not readable(loc) or loc == "" or not readable(itemClass) or (itemClass ~= 2 and itemClass ~= 4) then return end
    local copies, price = purchaseTerms(index, info, gold)
    if not copies or copies < 1 or not A.MerchantListingUsable(index) then return end
    return {
        id = itemID, link = link, kind = "PvP", faction = supplier[2], maxCopies = copies,
        routeKey = "pvp-vendor:" .. npcID .. ":" .. variant,
        source = "PvP: " .. supplier[1] .. " (open shop) · " .. price,
    }
end

function A.OpenPvPVendorRoutes()
    local rows = {}
    local npcID = currentMerchant()
    local supplier = supplyOfficers[npcID]
    if not supplier or not UnitFactionGroup or UnitFactionGroup("player") ~= supplier[2] then return rows end
    if not (GetMerchantNumItems and GetMerchantItemLink and C_MerchantFrame and C_MerchantFrame.GetItemInfo
        and C_Item and C_Item.GetItemInfoInstant and GetMoney) then return rows end
    local count, gold = GetMerchantNumItems(), GetMoney()
    if not readable(count) or not readable(gold) then return rows end
    local seen = {}
    for index = 1, count do
        local row = pvpListing(index, gold, npcID, supplier)
        if row and not seen[row.routeKey] then
            seen[row.routeKey] = true
            rows[#rows + 1] = row
        end
    end
    return rows
end

local function routeConditions(record, player, planning, owned)
    if record.minLevel and (not player.level or player.level < record.minLevel) then return false end
    if record.maxLevel and (not player.level or player.level > record.maxLevel) then return false end
    if record.faction and record.faction ~= player.faction then return false end
    if not includesBit(record.classMask, player.classID and player.classID - 1) then return false end
    if not includesBit(record.raceMask, raceBits[player.raceID]) then return false end
    if not owned and record.eventVendorID then
        local stock = checked(player, "eventMerchantStock", record.eventVendorID, openMerchantStock)
        if not stock or not stock[record.id] then return false end
        if not record.requiredCurrencyID or not record.requiredCurrencyAmount then return false end
        if checked(player, "currencyBalances", record.requiredCurrencyID, currencyQuantity) < record.requiredCurrencyAmount then
            return false
        end
    end
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
    if not owned and record.requiresCraftable then
        if planning or A.PersonalCraftCount(record, player) < 1 then return false end
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
    if id == 356 then
        -- Launch trainer Myizz Luckycatch offers Journeyman at character level 10.
        if rank <= 150 then return 10 end
        return
    end
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
