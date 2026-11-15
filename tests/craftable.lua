local A = {}
assert(loadfile("WoWBest/Gates.lua"))("WoWBest", A)

local row = {id = 1, kind = "Crafted", requiresKnownCraft = true, requiresCraftable = true,
    craftSpellID = 123, professionID = 164, professionRank = 300}
local function player() return {level = 60, classID = 1} end
C_SkillInfo = {GetSkillLineInfoByID = function(id) assert(id == 164) return {rank = 300} end}
local learned, count = true, 1
C_TradeSkillUI = {
    GetRecipeInfo = function(id) assert(id == 123) return {learned = learned} end,
    GetCraftableCount = function(id) assert(id == 123) return count end,
}
assert(A.RouteAvailable(row, player()))
learned = false
assert(not A.RouteAvailable(row, player()))
learned, count = true, 0
assert(not A.RouteAvailable(row, player()))
count = 3
for _, key in ipairs({"IsTradeSkillGuild", "IsTradeSkillGuildMember", "IsTradeSkillLinked", "IsNPCCrafting"}) do
    C_TradeSkillUI[key] = function() return true end
    assert(not A.RouteAvailable(row, player()))
    -- The character may personally know the recipe, but cannot prove
    -- that their inventory can produce the item through a foreign view.
    IsPlayerSpell = function() return true end
    assert(not A.RouteAvailable(row, player()))
    IsPlayerSpell = nil
    C_TradeSkillUI[key] = function() return false end
end
assert(A.RouteAvailable(row, player()))
C_TradeSkillUI.GetCraftableCount = function() error("data unavailable") end
assert(not A.RouteAvailable(row, player()))
C_TradeSkillUI.GetCraftableCount = nil
assert(not A.RouteAvailable(row, player()))
row.trainerRecipe = true
assert(not A.ProfessionTarget(row, player()))
row.owned = true
assert(A.RouteAvailable(row, player()))
print("Personal recipe and reagent availability tests passed")
