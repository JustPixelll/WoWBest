local _, A = ...

A.SourceMethods = {
    {key = "Dungeon", label = "Dungeons"},
    {key = "Quest",   label = "Quests"},
    {key = "Crafted", label = "Crafting"},
    {key = "Drop",    label = "World drops"},
    {key = "Vendor",  label = "Vendors"},
    {key = "PvP",     label = "PvP"},
    {key = "Auction", label = "Auction House"},
    {key = "Event",   label = "Events"},
}

local known = {}
for _, method in ipairs(A.SourceMethods) do known[method.key] = true end

-- Store only opt-outs. An existing character and a newly added source both
-- start with the full catalog, and changing one key preserves spec/target.
function A.SourceEnabled(key)
    if key == "Owned" then return true end
    if not known[key] then return false end
    local disabled = type(WoWBestCharacterDB) == "table" and WoWBestCharacterDB.disabledSources
    return type(disabled) ~= "table" or disabled[key] ~= true
end

function A.SetSourceEnabled(key, enabled)
    if not known[key] or type(enabled) ~= "boolean" or A.SourceEnabled(key) == enabled then return end
    if type(WoWBestCharacterDB) ~= "table" then WoWBestCharacterDB = {} end
    local disabled = WoWBestCharacterDB.disabledSources
    if type(disabled) ~= "table" then
        disabled = {}
        WoWBestCharacterDB.disabledSources = disabled
    end
    if enabled then
        disabled[key] = nil
        if not next(disabled) then WoWBestCharacterDB.disabledSources = nil end
    else
        disabled[key] = true
    end
end

function A.ResetSourceFilters()
    if type(WoWBestCharacterDB) == "table" then WoWBestCharacterDB.disabledSources = nil end
end

-- A second activity can be required by a particular route. Buying an actual
-- auction listing or using an owned copy does not require repeating its origin.
function A.RouteSourceEnabled(row)
    if row.owned or row.kind == "Owned" then return true end
    return A.SourceEnabled(row.kind)
        and (not row.requiresDungeon or A.SourceEnabled("Dungeon"))
        and (not row.requiresPvP or A.SourceEnabled("PvP"))
        and (not row.eventName or A.SourceEnabled("Event"))
end
