local _, A = ...
local epsilon = .000001

local function copy(tableIn)
    local out = {}
    for k,v in pairs(tableIn) do out[k]=v end
    return out
end

local function groupFor(slot)
    if slot==12 or slot==14 or slot==17 then return slot-1 end
    return slot
end

local function setID(item)
    local id=item.setID
    if not id or id==0 then id=item.itemSetID end
    if not id or id==0 then id=A.ItemSetIDs and A.ItemSetIDs[item.id] end
    return id
end

-- Each input is a physical copy. A ring can enter either socket, but that
-- cannot turn one copy into two. Acquisition choices do not apply to a bag.
local function physical(item,key)
    local v=copy(item)
    v.maxCopies,v.routeKey,v.choice,v.choices=1,key,nil,nil
    return v
end

-- If the solver chose to clear an unrelated slot to free a unique category,
-- do not silently reclaim its score while putting the original piece back.
local function legalLimits(load)
    local counts,caps={},{}
    local function add(key,cap)
        counts[key]=(counts[key] or 0)+1
        caps[key]=math.min(caps[key] or cap,cap)
    end
    for _,item in pairs(load) do
        local idCap=item.itemLimit or (item.unique==true and (item.uniqueLimit or 1))
        local group=item.uniqueGroup or (type(item.unique)~="boolean" and item.unique)
        -- Track every ID: a known cap on one variant also applies to another.
        add("id/"..item.id,idCap or math.huge)
        if group then add("group/"..group,item.uniqueLimit or 1) end
    end
    for key,n in pairs(counts) do if n>caps[key] then return false end end
    return true
end

local function jointAlerts(bags,worn,player,profile,tick)
    local original,owners,sets,hands={},{},{},{}
    local base=A.LoadoutScore(worn,profile)
    local wornCounts=A.GetSetCounts(worn)
    for slot=1,18 do
        local item=worn[slot]
        if item then
            local view=physical(item,"equipped/"..slot)
            original[#original+1]=view
            owners[view]={item=item}
        end
    end
    local direct={}
    for index,b in ipairs(bags) do
        local id=setID(b.item)
        local slot=A.PrimaryGearSlot(b.item)
        local hand=(slot==16 or slot==17) and b.item.loc~="INVTYPE_2HWEAPON"
        if hand or (id and A.SetThresholds and A.SetThresholds[id]) then
            local view=physical(b.item,"bag/"..index)
            owners[view]=b
            if hand then hands[#hands+1]=view end
            if id and A.SetThresholds and A.SetThresholds[id] then
                sets[id]=sets[id] or {}
                sets[id][#sets[id]+1]=view
            end
        end
        tick()
    end

    local function best(views)
        local pool=copy(original)
        -- The solver uses input order as its last tie-breaker. Inventory
        -- sorting must not announce a second same-score suffix variant.
        table.sort(views,function(left,right)
            local a,b=owners[left],owners[right]
            if a.key~=b.key then return a.key<b.key end
            if a.position.bag~=b.position.bag then return a.position.bag<b.position.bag end
            return a.position.slot<b.position.slot
        end)
        for _,view in ipairs(views) do pool[#pool+1]=view end
        local plan=A.Solve(pool,player,profile,tick)
        local parts,touched={},{}
        for slot=1,18 do
            local owner=owners[plan[slot]]
            if owner and owner.position then
                parts[#parts+1]={item=owner.item,key=owner.key,position=owner.position,slot=slot,view=plan[slot]}
                touched[groupFor(slot)]=true
            end
        end
        local load=copy(worn)
        for slot=1,18 do
            if touched[groupFor(slot)] then
                local owner=owners[plan[slot]]
                load[slot]=owner and owner.item
            end
        end
        if not legalLimits(load) then return nil end
        return {parts=parts,load=load,delta=A.LoadoutScore(load,profile)-base}
    end

    local function single(view)
        if direct[view]==nil then
            local owner=owners[view]
            local result=owner.direct or A.CompareEquippedUpgrade(owner.item,worn,player,profile)
            direct[view]=result and math.max(0,result.delta) or 0
        end
        return direct[view]
    end
    local alerts={}
    local function consider(views,id)
        if #views<2 then return end
        if id then
            local available={}
            for _,v in ipairs(views) do available[v.id]=true end
            local first=next(available)
            if not first or not next(available,first) then return end
        end
        local plan=best(views)
        -- Remove pieces whose individual benefit can be obtained separately.
        -- For a set spanning three sockets, compare to each legal two-piece
        -- subset, preserving existing pieces, hand rules and set thresholds.
        while plan and #plan.parts>=2 and plan.delta>epsilon do
            local independent=0
            for _,p in ipairs(plan.parts) do independent=independent+single(p.view) end
            if plan.delta<=independent+epsilon then return end
            if id then
                local count=A.GetSetCounts(plan.load)[id] or 0
                if A.SetBonusScore(id,count,profile)<=A.SetBonusScore(id,wornCounts[id] or 0,profile)+epsilon then return end
            end
            local smaller
            if #plan.parts>2 then
                for _,omit in ipairs(plan.parts) do
                    local remaining={}
                    for _,p in ipairs(plan.parts) do if p~=omit then remaining[#remaining+1]=p.view end end
                    local subset=best(remaining)
                    if subset and #subset.parts>=2 and subset.delta>epsilon and plan.delta<=subset.delta+single(omit.view)+epsilon then
                        smaller=subset
                        break
                    end
                end
            end
            if not smaller then
                local changes,keys={},{}
                local before,after,uncertain=0,0,false
                for slot=1,18 do
                    local old,new=worn[slot],plan.load[slot]
                    if old~=new then
                        changes[#changes+1]=slot
                        if old then before=before+A.Score(old,profile,slot) end
                        if new then after=after+A.Score(new,profile,slot) end
                        if old and old.unmodeledEffect or new and new.unmodeledEffect then uncertain=true end
                    end
                end
                if not uncertain and A.HasUnmodeledSetChange then uncertain=A.HasUnmodeledSetChange(worn,plan.load,profile) end
                for _,p in ipairs(plan.parts) do keys[#keys+1]=p.key; p.view=nil end
                table.sort(keys)
                local first=plan.parts[1]
                local result={kind="upgrade",slot=first.slot,baseline=base,total=base+plan.delta,delta=plan.delta,
                    percent=base>0 and 100*plan.delta/base or nil,changedSlots=changes,loadout=plan.load,
                    swapBefore=before,swapAfter=after,slotPercent=before>0 and 100*(after-before)/before or nil,
                    unmodeledEffect=uncertain}
                alerts[#alerts+1]={parts=plan.parts,items=plan.parts,item=first.item,position=first.position,
                    key="joint/"..table.concat(keys,"|"),profile=profile,result=result}
                return
            end
            plan=smaller
        end
    end
    consider(hands)
    for id,views in pairs(sets) do consider(views,id); tick() end
    table.sort(alerts,function(a,b)
        if a.result.delta~=b.result.delta then return a.result.delta>b.result.delta end
        return a.key<b.key
    end)
    local out,used={},{}
    for _,alert in ipairs(alerts) do
        local overlaps=false
        for _,p in ipairs(alert.parts) do if used[p.position] then overlaps=true end end
        if not overlaps then
            out[#out+1]=alert
            for _,p in ipairs(alert.parts) do used[p.position]=true end
        end
    end
    return out
end

-- One call to step per UI update. The solver yields only at Lua checkpoints,
-- outside native sorts. A cancelled scan can simply discard its iterator.
function A.StartJointBagUpgrades(bags,worn,player,profile)
    if not bags or #bags<2 or not worn or not player or not profile then return nil end
    local ticks,started
    local function checkpoint()
        ticks=ticks+1
        if ticks>=24 or (started and debugprofilestop()-started>=2) then coroutine.yield() end
    end
    local worker=coroutine.create(function() return jointAlerts(bags,worn,player,profile,checkpoint) end)
    return function()
        ticks,started=0,debugprofilestop and debugprofilestop()
        local ok,alerts=coroutine.resume(worker)
        if not ok then error(alerts) end
        return coroutine.status(worker)=="dead",alerts
    end
end
