-- Independent exhaustive enumeration, including forced slot and earned set score.
local A = {}
assert(loadfile("WoWBest/Engine.lua"))("WoWBest",A)
local profile={strength=1}
A.SetThresholds = {[1]={{pieces=2},{pieces=3}},[2]={{pieces=2}},[3]={{pieces=2}}}
function A.SetBonusScore(id,n)
    if id==1 then return n>=3 and 28 or n>=2 and 7 or 0 end
    return n>=2 and (id==2 and 23 or 17) or 0
end
local function equal(a,b,why)
    assert(a==b, (why or "comparison")..": "..tostring(a).." vs "..tostring(b))
end
local function item(id,loc,value,set,choice)
    return {id=id,loc="INVTYPE_"..loc,stats={ITEM_MOD_STRENGTH_SHORT=value},itemSetID=set,choice=choice}
end
local slots={1,5,11,12,16,17}
local function legal(slot,it,chosen,dual)
    local l=it.loc
    if slot==1 then return l=="INVTYPE_HEAD" end
    if slot==5 then return l=="INVTYPE_CHEST" end
    if slot==11 or slot==12 then return l=="INVTYPE_FINGER" end
    if slot==16 then return l=="INVTYPE_WEAPON" or l=="INVTYPE_2HWEAPON" end
    return chosen[16] and chosen[16].loc~="INVTYPE_2HWEAPON" and
        (l=="INVTYPE_SHIELD" or dual and l=="INVTYPE_WEAPON")
end
local function exhaustive(items,dual)
    local best=-math.huge
    local forced,chosen,used={},{},{}
    for _,s in ipairs(slots) do forced[s]={} end
    local function visit(i,raw)
        if i>#slots then
            local seen, counts={},{}
            for _,it in pairs(chosen) do
                local id=it.itemSetID
                if id and not seen[it.id] then seen[it.id]=true; counts[id]=(counts[id] or 0)+1 end
            end
            local total=raw
            for id,n in pairs(counts) do total=total+A.SetBonusScore(id,n) end
            best=math.max(best,total)
            for s,it in pairs(chosen) do
                local key=it.link or tostring(it.id)
                forced[s][key]=math.max(forced[s][key] or -math.huge,total)
            end
            return
        end
        local slot=slots[i]
        chosen[slot]=nil
        visit(i+1,raw)
        for _,it in ipairs(items) do
            if legal(slot,it,chosen,dual) and not (it.choice and used[it.choice] or it.unique and used[it.id]) then
                chosen[slot]=it
                if it.choice then used[it.choice]=true end
                if it.unique then used[it.id]=true end
                visit(i+1,raw+it.stats.ITEM_MOD_STRENGTH_SHORT)
                if it.choice then used[it.choice]=nil end
                if it.unique then used[it.id]=nil end
                chosen[slot]=nil
            end
        end
    end
    visit(1,0)
    return best,forced
end
local function run(items,dual,tag)
    local total,bySlot=exhaustive(items,dual)
    local ctx=A.PrepareSolver(items,{dual=dual},profile)
    local load,actual=A.SolvePrepared(ctx)
    equal(actual,total,tag.." winner")
    equal(A.LoadoutScore(load,profile),total,tag.." reconstructed score")
    for _,slot in ipairs(slots) do
        local rows=A.RankPrepared(ctx,slot,10,{loadout=load,total=actual})
        local expected=0
        for _ in pairs(bySlot[slot]) do expected=expected+1 end
        equal(#rows,expected,tag.." rows in slot "..slot)
        local seen={}
        for i,r in ipairs(rows) do
            local key=r.item.link or tostring(r.item.id)
            equal(r.total,bySlot[slot][key],tag.." exact forced total "..slot.." "..key)
            equal(r.loadout[slot],r.item,tag.." forced slot")
            equal(A.LoadoutScore(r.loadout,profile),r.total,tag.." reconstructed ranking")
            equal(r.delta,r.total-total,tag.." delta")
            assert(not seen[key] and (not rows[i-1] or rows[i-1].total>=r.total))
            seen[key]=true
        end
        local top=A.RankPrepared(ctx,slot,1)
        equal(#top, math.min(1,#rows))
        if top[1] then equal(top[1].total,rows[1].total,"top 1 vs full list") end
    end
end

local lone=item(1,"FINGER",1,1)
equal(A.GetSetCounts({[11]=lone,[12]=lone})[1],1)
local setRing=item(2,"FINGER",1,1)
local r,total=A.Solve({lone,setRing},{},profile)
equal(total,9,"distinct set rings trump two copies")
local two=item(3,"2HWEAPON",30)
local sword=item(4,"WEAPON",4,2)
local shield=item(5,"SHIELD",6,2)
run({two,sword,shield,lone,setRing},false,"forced hands")
local poor=item(10,"HEAD",0,2)
local chest=item(11,"CHEST",2,2)
run({poor,chest,item(12,"CHEST",10),item(13,"HEAD",8)},false,"weaker individual set pieces")
local a=item(14,"HEAD",6,2,"q")
local b=item(14,"HEAD",6,2,"q2")
run({a,b,item(15,"CHEST",40,2,"q"),item(16,"CHEST",15)},false,"duplicate acquisition routes")
local loci={"HEAD","CHEST","FINGER","WEAPON","2HWEAPON","SHIELD"}
math.randomseed(223741)
for t=1,220 do
    local items={}
    for i=1,8 do
        items[i]=item(i,loci[math.random(#loci)],math.random(0,12),
            math.random(4)>1 and math.random(3) or nil,
            math.random(3)==1 and "q"..math.random(3) or nil)
        items[i].unique=math.random(2)==1
    end
    run(items,t%2==0,"fuzz "..t)
end
-- The frame driver can safely suspend and resume both index construction and
-- exact ranking. Exercise the complete coroutine path on a larger set pool.
local lots={}
for i=1,600 do
    lots[i]=item(100+i,loci[i%#loci+1],i%47,i%3+1)
end
local yielded,chunk=0,coroutine.create(function()
    local context=A.PrepareSolver(lots,{dual=true},profile,coroutine.yield)
    local best,bestTotal=A.SolvePrepared(context)
    local alternatives=A.RankPrepared(context,1,3,{loadout=best,total=bestTotal})
    equal(#alternatives,3)
    equal(alternatives[1].total,bestTotal)
end)
while coroutine.status(chunk)~="dead" do
    local ok,why=coroutine.resume(chunk)
    assert(ok,tostring(why))
    yielded=yielded+1
end
assert(yielded>2,"large searches must yield between frames")
-- A new request may reuse a prepared context after the first request was
-- interrupted by the player closing a detail pane.
local suspend=false
local ctx=A.PrepareSolver(lots,{dual=true},profile,function()
    if suspend then coroutine.yield() end
end)
suspend=true
local abandoned=coroutine.create(function() A.SolvePrepared(ctx) end)
assert(coroutine.resume(abandoned) and coroutine.status(abandoned)=="suspended")
suspend=false
local resumed,score=A.SolvePrepared(ctx)
equal(A.LoadoutScore(resumed,profile),score)
local rows=A.ScoreBreakdown({stats={ITEM_MOD_STRENGTH_SHORT=9,DPS=6},classID=2},{strength=1,meleeDPS=2},16)
equal(rows[1].points,12)
equal(rows[2].points,9)
print("Set engine OK: joint thresholds, copy counts, constrained alternatives and 220 exhaustive random catalogs.")
