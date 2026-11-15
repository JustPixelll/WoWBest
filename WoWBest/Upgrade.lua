local _, A = ...

local slots = {
    INVTYPE_HEAD=1, INVTYPE_NECK=2, INVTYPE_SHOULDER=3, INVTYPE_CHEST=5, INVTYPE_ROBE=5,
    INVTYPE_WAIST=6, INVTYPE_LEGS=7, INVTYPE_FEET=8, INVTYPE_WRIST=9, INVTYPE_HAND=10,
    INVTYPE_FINGER=11, INVTYPE_TRINKET=13, INVTYPE_CLOAK=15, INVTYPE_WEAPON=16,
    INVTYPE_2HWEAPON=16, INVTYPE_WEAPONMAINHAND=16, INVTYPE_WEAPONOFFHAND=17,
    INVTYPE_SHIELD=17, INVTYPE_HOLDABLE=17, INVTYPE_RANGED=18, INVTYPE_RANGEDRIGHT=18,
    INVTYPE_THROWN=18, INVTYPE_RELIC=18,
}

-- Exact links retain rolled suffixes and differentiate the physical items in
-- the two hand/ring/trinket sockets. A slot whose ID is present but whose link
-- is not cached is occupied, never an empty slot worth zero points.
function A.ReadEquippedForUpgrade(player, supplements)
    if not GetInventoryItemLink or not GetInventoryItemID then return nil,"unverified" end
    local worn, pending = {}, false
    for slot = 1,18 do
        if A.SlotNames[slot] then
            local id = GetInventoryItemID("player",slot)
            local link = GetInventoryItemLink("player",slot)
            if issecretvalue and (issecretvalue(id) or issecretvalue(link)) then return nil,"unverified" end
            if id or link then
                local linkID = link and tonumber(link:match("item:(%d+)"))
                if not linkID or id and id~=linkID then
                    pending=true
                    player.requested=player.requested or {}
                    if id and not player.requested[id] and C_Item and C_Item.RequestLoadItemDataByID then
                        player.requested[id]=true
                        C_Item.RequestLoadItemDataByID(id)
                    end
                else
                    local extra = supplements and supplements[linkID] or A.GetItemSupplement and A.GetItemSupplement(linkID)
                    local item,status = A.ReadEquippedItem({id=linkID,link=link,owned=true},player,extra)
                    if item then worn[slot]=item
                    elseif status=="pending" then pending=true
                    else return nil,"unverified" end
                end
            end
        end
    end
    if pending then return nil,"pending" end
    return worn
end

local function category(item)
    if item.uniqueGroup then return item.uniqueGroup end
    if type(item.unique)=="string" or type(item.unique)=="number" then return item.unique end
end

-- Ownership caps and unique-equipped categories are acquisition-independent.
-- Quest-choice and maxCopies route markers cannot invalidate gear already worn.
local function conflictWithCandidate(load,slot)
    local new = load[slot]
    local group = category(new)
    local idCap = new.itemLimit or (new.unique==true and (new.uniqueLimit or 1))
    local groupCap = group and (new.uniqueLimit or 1)
    local copies, grouped = {}, {}
    for s,it in pairs(load) do
        if it.id==new.id then
            local max=it.itemLimit or (it.unique==true and (it.uniqueLimit or 1))
            if max then idCap=math.min(idCap or max,max) end
            copies[#copies+1]=s
        end
        if group and group==category(it) then
            local max=it.uniqueLimit or 1
            groupCap=math.min(groupCap,max)
            grouped[#grouped+1]=s
        end
    end
    if idCap and #copies>idCap then return copies end
    if groupCap and #grouped>groupCap then return grouped end
end

local function handMain(it,profile)
    if not it then return false end
    local loc=it.loc
    if loc~="INVTYPE_WEAPON" and loc~="INVTYPE_WEAPONMAINHAND" and loc~="INVTYPE_2HWEAPON" then return false end
    if profile.shield and loc=="INVTYPE_2HWEAPON" then return false end
    return not profile.daggers or it.classID==2 and it.subID==15
end

local function handOff(it,player,profile)
    if not it then return false end
    if profile.daggers and (it.classID~=2 or it.subID~=15) then return false end
    if it.loc=="INVTYPE_SHIELD" then return true end
    if profile.shield then return false end
    if it.loc=="INVTYPE_HOLDABLE" then return true end
    return player.dual and (it.loc=="INVTYPE_WEAPON" or it.loc=="INVTYPE_WEAPONOFFHAND")
end

local function copy(load)
    local out={}
    for slot,it in pairs(load) do out[slot]=it end
    return out
end

-- One additional candidate, with all unrelated gear fixed. Allow hand partners
-- to switch sockets and remove other worn items ONLY to resolve a unique cap.
-- All totals come from the same nonlinear item/set scorer used by the planner.
function A.CompareEquippedUpgrade(candidate,equipped,player,profile,originSlot)
    if not candidate or not equipped or not profile or not player then return nil,"incomplete" end
    local primary=slots[candidate.loc]
    if not primary then return nil,"ineligible" end
    local baseline=A.LoadoutScore(equipped,profile)
    if originSlot then
        local original=equipped[originSlot]
        if not original or original.id~=candidate.id then return nil,"incomplete" end
        if original.link and candidate.link and A.ItemVariantKey
            and A.ItemVariantKey(original.link)~=A.ItemVariantKey(candidate.link) then return nil,"incomplete" end
        local wornPoints=A.Score(original,profile,originSlot)
        return {kind="equipped",alreadyEquipped=true,slot=originSlot,baseline=baseline,total=baseline,
            delta=0,percent=baseline>0 and 0 or nil,changedSlots={},loadout=equipped,
            swapBefore=wornPoints,swapAfter=wornPoints,slotPercent=wornPoints>0 and 0 or nil}
    end
    local best,bestChanges,bestTotal,bestSlot
    local function consider(load,slot)
        local conflict=conflictWithCandidate(load,slot)
        if conflict then
            for _,other in ipairs(conflict) do
                if other~=slot then
                    local fork=copy(load)
                    fork[other]=nil
                    -- An off-hand weapon can move into the vacated main hand.
                    -- Shields, held items and off-hand-only weapons cannot.
                    if other==16 then
                        local survivor=fork[17]
                        fork[17]=nil
                        if slot~=17 and handMain(survivor,profile) then
                            local moved=copy(fork)
                            moved[16]=survivor
                            consider(moved,slot)
                        end
                    end
                    if fork[slot] then consider(fork,slot) end
                end
            end
            return
        end
        local total=A.LoadoutScore(load,profile)
        local changes={}
        for s=1,18 do
            if equipped[s]~=load[s] then changes[#changes+1]=s end
        end
        if not best or total>bestTotal+1e-8 or math.abs(total-bestTotal)<=1e-8 and
                (#changes<#bestChanges or #changes==#bestChanges and slot<bestSlot) then
            best,bestTotal,bestSlot,bestChanges=load,total,slot,changes
        end
    end
    local function replace(slot)
        local load=copy(equipped)
        load[slot]=candidate
        consider(load,slot)
    end
    if primary==16 or primary==17 then
        local mainOK,offOK=handMain(candidate,profile),handOff(candidate,player,profile)
        if not mainOK and not offOK then return nil,"ineligible" end
        local function hands(main,off,slot)
            local load=copy(equipped)
            load[16],load[17]=main,off
            consider(load,slot)
        end
        if mainOK then
            hands(candidate,nil,16)
            if candidate.loc~="INVTYPE_2HWEAPON" then
                for s=16,17 do
                    local partner=equipped[s]
                    if handOff(partner,player,profile) then hands(candidate,partner,16) end
                end
            end
        end
        if offOK then
            for s=16,17 do
                local partner=equipped[s]
                if handMain(partner,profile) and partner.loc~="INVTYPE_2HWEAPON" then hands(partner,candidate,17) end
            end
        end
        if not best and not mainOK then return nil,"needs-main-hand" end
    else
        replace(primary)
        if primary==11 or primary==13 then replace(primary+1) end
    end
    if not best then return nil,"conflict" end
    local delta=bestTotal-baseline
    if math.abs(delta)<1e-8 then delta=0 end
    -- Direct swap (Pawn-style) and full outfit describe different baselines:
    -- only changed sockets count here, with weapon DPS in its actual socket.
    -- Thresholds belong to the complete outfit, never to an individual piece.
    local before,after=0,0
    for _,s in ipairs(bestChanges) do
        if equipped[s] then before=before+A.Score(equipped[s],profile,s) end
        if best[s] then after=after+A.Score(best[s],profile,s) end
    end
    return {kind=delta>0 and "upgrade" or delta<0 and "downgrade" or "neutral",
        slot=bestSlot,baseline=baseline,total=bestTotal,delta=delta,
        percent=baseline>0 and 100*delta/baseline or nil,loadout=best,changedSlots=bestChanges,
        swapBefore=before,swapAfter=after,slotPercent=before>0 and 100*(after-before)/before or nil}
end
