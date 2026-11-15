-- Reference search over physical copies, independent of the planner's slot
-- groups and the tooltip's displacement algorithm. Non-hand gear stays fixed
-- unless displaced by the candidate or its unique-equipped group.
local A = {}
for _, module in ipairs({"Engine", "Upgrade"}) do assert(loadfile("WoWBest/"..module..".lua"))("WoWBest",A) end
local mh = {INVTYPE_WEAPON=true, INVTYPE_2HWEAPON=true, INVTYPE_WEAPONMAINHAND=true}
local oh = {INVTYPE_WEAPON=true, INVTYPE_WEAPONOFFHAND=true, INVTYPE_SHIELD=true, INVTYPE_HOLDABLE=true}
local shoulder, left, right, main, off = 3,11,12,16,17
local slots={shoulder,left,right,main,off}
local profile={strength=1,meleeDPS=4,offhandScale=.5}
function A.SetBonusScore(_,n) return n>=2 and 13 or 0 end
local function raw(points)
    local score,sets,seen=0,{},{}
    for s,it in pairs(points) do
        score=score+it.stats.ITEM_MOD_STRENGTH_SHORT
        if s==main then score=score+4*(it.stats.DPS or 0)
        elseif s==off then score=score+2*(it.stats.DPS or 0) end
        if it.setID and not seen[it.id] then
            seen[it.id]=true
            sets[it.setID]=(sets[it.setID] or 0)+1
        end
    end
    for _,n in pairs(sets) do if n>=2 then score=score+13 end end
    return score
end
local function valid(load,dual)
    if load[off] then
        if not load[main] or load[main].loc=="INVTYPE_2HWEAPON" then return false end
        if not oh[load[off].loc] or (load[off].classID==2 and not dual) then return false end
    end
    if load[main] and not mh[load[main].loc] then return false end
    local cats,ids={},{}
    for _,it in pairs(load) do
        if it.uniqueGroup then
            if cats[it.uniqueGroup] then return false end
            cats[it.uniqueGroup]=true
        end
        if it.itemLimit then
            if ids[it.id] then return false end
            ids[it.id]=true
        end
    end
    return true
end
local function conflicts(it,c)
    return it and ((it.id==c.id and it.itemLimit) or (it.uniqueGroup and it.uniqueGroup==c.uniqueGroup))
end
local function oracle(wear,c,dual)
    local load,taken,answer={},{},-math.huge
    local function visit(i)
        if i>#slots then
            if taken[c] and valid(load,dual) then answer=math.max(answer,raw(load)) end
            return
        end
        local s=slots[i]
        local opts,free={},{[false]=true}
        local function add(it)
            if it and not free[it] then free[it]=true;opts[#opts+1]=it end
        end
        if s==main or s==off then
            local changesHands = mh[c.loc] or oh[c.loc]
            if changesHands then add(c);add(wear[main]);add(wear[off]);opts[#opts+1]=false
            elseif conflicts(wear[main],c) then
                add(wear[s]);if s==main then add(wear[off]) end
                opts[#opts+1]=false
            else
                add(wear[s])
                if not wear[s] or conflicts(wear[s],c) then opts[#opts+1]=false end
            end
        else
            local match=(s==shoulder and c.loc=="INVTYPE_SHOULDER") or
                ((s==left or s==right) and c.loc=="INVTYPE_FINGER")
            add(wear[s]);if match then add(c) end
            if not wear[s] or conflicts(wear[s],c) then opts[#opts+1]=false end
        end
        for _,it in ipairs(opts) do
            if not it then load[s]=nil;visit(i+1)
            elseif not taken[it] then
                load[s],taken[it]=it,true
                -- Reject impossible hand sockets before enumerating the tail.
                if s~=main and s~=off or s==main and mh[it.loc] or s==off and oh[it.loc] then visit(i+1) end
                load[s],taken[it]=nil,nil
            end
        end
    end
    visit(1)
    return answer
end
local types={"SHOULDER","FINGER","WEAPON","WEAPONMAINHAND","WEAPONOFFHAND","2HWEAPON","SHIELD","HOLDABLE"}
local function make(id,kind)
    local weapon=kind:find("WEAPON")~=nil
    return {id=id,loc="INVTYPE_"..kind,classID=weapon and 2 or 4,subID=weapon and 7 or 0,
        stats={ITEM_MOD_STRENGTH_SHORT=math.random(0,8),DPS=weapon and math.random(1,10) or nil},
        uniqueGroup=math.random(4)==1 and "g"..math.random(3) or nil,
        setID=math.random(3)>1 and math.random(2) or nil}
end
math.randomseed(91827)
for trial=1,1200 do
    local dual=trial%2==0
    local equipment={}
    for _,s in ipairs(slots) do
        if math.random(4)>1 then
            local kind
            if s==shoulder then kind="SHOULDER"
            elseif s==main then kind=({"WEAPONMAINHAND","WEAPON","2HWEAPON"})[math.random(3)]
            elseif s==off then kind=({"WEAPON","WEAPONOFFHAND","HOLDABLE","SHIELD"})[math.random(4)]
            else kind="FINGER" end
            equipment[s]=make(s,kind)
            if not valid(equipment,dual) then equipment[s]=nil end
        end
    end
    local c=make(90,types[math.random(#types)])
    local correct=oracle(equipment,c,dual)
    local result=A.CompareEquippedUpgrade(c,equipment,{dual=dual},profile)
    assert((result and result.total or -math.huge)==correct,
        ("case %d got %s expected %s"):format(trial,tostring(result and result.total),tostring(correct)))
    if result then
        assert(valid(result.loadout,dual) and result.loadout[result.slot]==c and raw(result.loadout)==result.total)
        assert(result.delta==raw(result.loadout)-raw(equipment))
    end
end
print("Native percentages: 1,200 physical-copy comparisons agree with independent enumeration.")
