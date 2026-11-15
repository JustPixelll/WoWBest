local A={}
for _,name in ipairs({"Engine","Upgrade"}) do assert(loadfile("WoWBest/"..name..".lua"))("WoWBest",A) end
local p={strength=1, meleeDPS=2,offhandScale=.5}
local dual={dual=true}
local function it(id,loc,n,extra)
    local r={id=id,loc="INVTYPE_"..loc,stats={ITEM_MOD_STRENGTH_SHORT=n}}
    for k,v in pairs(extra or {}) do r[k]=v end
    return r
end
local function eq(x,y) assert(x==y, tostring(x).." ~= "..tostring(y)) end
local function cmp(c,w,pl,prof,origin)
    return A.CompareEquippedUpgrade(c,w,pl or dual,prof or p,origin)
end
local helm=it(1,"HEAD",6)
local ring=it(2,"FINGER",6)
local oldHead=it(3,"HEAD",4)
local result=cmp(helm,{[1]=oldHead,[11]=ring})
eq(result.total,12);eq(result.baseline,10);eq(result.delta,2);eq(result.percent,20);eq(result.slot,1)
eq(result.slotPercent,50);eq(result.swapBefore,4);eq(result.swapAfter,6)
eq(result.kind,"upgrade");eq(result.changedSlots[1],1);eq(#result.changedSlots,1)
result=cmp(oldHead,{[1]=helm,[11]=ring})
eq(result.total,10);eq(result.delta,-2);eq(result.kind,"downgrade")
result=cmp(helm,{[1]=helm,[11]=ring},nil,nil,1)
eq(result.kind,"equipped");eq(result.percent,0);eq(result.slotPercent,0);eq(#result.changedSlots,0)
eq(select(2,cmp(helm,{[1]=oldHead},nil,nil,1)),"incomplete")
result=cmp(oldHead,{})
eq(result.percent,nil);eq(result.slotPercent,nil);eq(result.swapBefore,0);eq(result.swapAfter,4);eq(result.delta,4)
result=cmp(it(4,"HEAD",4),{[1]=oldHead})
eq(result.kind,"neutral");eq(result.percent,0)
-- Same ID for an already worn ring vs a genuinely separate candidate copy.
result=cmp(ring,{[11]=ring})
eq(result.slot,12);eq(result.percent,100)
result=cmp(ring,{[11]=ring},nil,nil,11)
eq(result.slot,11);eq(result.percent,0)
local strongRing=it(5,"FINGER",10)
result=cmp(it(7,"FINGER",7),{[11]=strongRing,[12]=ring})
eq(result.slot,12);eq(result.total,17);eq(result.swapBefore,6);eq(result.swapAfter,7)
eq(result.slotPercent,100/6)
-- Forced two hand item must replace both hands even when net change is negative.
local sword=it(8,"WEAPON",13)
local shield=it(9,"SHIELD",9)
local two=it(10,"2HWEAPON",20)
result=cmp(two,{[16]=sword,[17]=shield})
eq(result.loadout[17],nil);eq(result.delta,-2);eq(#result.changedSlots,2)
eq(result.swapBefore,22);eq(result.swapAfter,20);eq(result.slotPercent,-200/22)
eq(select(2,cmp(shield,{[16]=two})),"needs-main-hand")
eq(select(2,cmp(it(11,"WEAPONOFFHAND",10),{[16]=sword},{dual=false})),"ineligible")
result=cmp(it(12,"WEAPONMAINHAND",17),{[16]=sword,[17]=shield})
eq(result.loadout[17],sword);eq(result.total,30)
result=cmp(it(12,"WEAPONMAINHAND",17),{[16]=sword,[17]=shield},{dual=false})
eq(result.loadout[17],shield);eq(result.total,26)
eq(select(2,cmp(two,{[16]=sword,[17]=shield},nil,{strength=1,shield=true})),"ineligible")
-- A Protection profile can inspect a head upgrade while currently using a
-- two-hander. Evaluating another slot cannot repair or discard the hands.
local tank={strength=1,shield=true}
result=cmp(helm,{[1]=oldHead,[16]=two},nil,tank)
eq(result.loadout[16],two);eq(result.swapBefore,4);eq(result.slotPercent,50);eq(result.percent,200/24)
-- Previously selected quest items and disabled source filters are facts on
-- the baseline; a new physical item never erases unrelated quest rewards.
local oldReward=it(70,"CHEST",5,{choice=991,kind="Quest",maxCopies=1})
local hovered=it(71,"HEAD",8,{choice=991,kind="Quest",maxCopies=1})
result=cmp(hovered,{[5]=oldReward})
eq(result.loadout[5],oldReward);eq(result.delta,8)
local weak=it(13,"WEAPON",2)
local strongMH=it(14,"WEAPONMAINHAND",21)
result=cmp(weak,{[16]=strongMH,[17]=shield})
eq(result.slot,17);eq(result.delta,-7)
-- Current one-hander can be moved to main hand to make room for an offhand.
result=cmp(shield,{[17]=sword})
eq(result.loadout[16],sword);eq(result.loadout[17],shield)
-- Best replacement may be the more valuable raw ring to retain the set bonus.
A.SetBonusScore=function(id,n) return id==3 and n>=2 and 20 or 0 end
local setRing=it(16,"FINGER",1,{setID=3})
local setHead=it(17,"HEAD",5,{setID=3})
result=cmp(it(20,"FINGER",5),{[11]=setRing,[12]=ring,[1]=setHead})
eq(result.slot,12);eq(result.baseline,32);eq(result.delta,-1)
-- Positive raw slot upgrade can still be a full-outfit downgrade after losing a bonus.
result=cmp(helm,{[1]=setHead,[11]=setRing})
eq(result.swapBefore,5);eq(result.swapAfter,6);eq(result.slotPercent,20)
eq(result.delta,-19);eq(result.percent,-1900/26)
-- Cross-slot unique conflicts can require additional removals, which must cost
-- their raw and set-bonus points. All other occupied sockets stay unchanged.
local uniqueCap=it(21,"HEAD",9,{unique="collection"})
local oldShared=it(22,"FINGER",8,{unique="collection",setID=3})
result=cmp(uniqueCap,{[11]=oldShared,[1]=setHead})
eq(result.loadout[11],nil);eq(result.delta,9-(8+5+20))
local limitedMain=it(32,"WEAPONMAINHAND",11,{unique="collection"})
result=cmp(uniqueCap,{[16]=limitedMain,[17]=sword})
eq(result.loadout[16],sword);eq(result.loadout[17],nil)
eq(result.delta,9-11)
local pinned=it(23,"FINGER",10,{unique=true})
result=cmp(pinned,{[11]=pinned,[12]=ring})
eq(result.slot,11);eq(result.delta,0)
-- Snapshot distinguishes pending item data from a genuinely vacant position.
GetInventoryItemID=function(_,slot) return slot==1 and 41 or nil end
GetInventoryItemLink=function(_,slot) return nil end
local requests,player=0,{}
C_Item={RequestLoadItemDataByID=function(id) eq(id,41);requests=requests+1 end}
local worn,why=A.ReadEquippedForUpgrade(player)
eq(worn,nil);eq(why,"pending")
A.ReadEquippedForUpgrade(player)
eq(requests,1)
issecretvalue=function(v) return v==41 end
eq(select(2,A.ReadEquippedForUpgrade(player)),"unverified")
issecretvalue=nil
GetInventoryItemLink=function(_,slot) return slot==1 and "item:41:12:0" or nil end
A.ReadCandidate=function() error("worn gear must not pass through candidate-only filters") end
A.ReadEquippedItem=function(record,player,extra)
    eq(record.id,41);eq(record.link,"item:41:12:0");eq(extra,"supplement");eq(record.owned,true)
    return it(41,"HEAD",1),"ok"
end
worn=A.ReadEquippedForUpgrade({}, {[41]="supplement"})
eq(worn[1].id,41);eq(worn[2],nil)
-- One cold pass requests both occupied sockets; never publish a partial baseline.
local missing,loaded,requested={}, {}, {}
missing[1],missing[16]=51,52
GetInventoryItemID=function(_,slot) return missing[slot] end
GetInventoryItemLink=function(_,slot) return loaded[slot] end
C_Item.RequestLoadItemDataByID=function(id) requested[id]=(requested[id] or 0)+1 end
A.ReadEquippedItem=function(row) return it(row.id,row.id==51 and "HEAD" or "WEAPON",10),"ok" end
player={}
worn,why=A.ReadEquippedForUpgrade(player)
eq(worn,nil);eq(why,"pending");eq(requested[51],1);eq(requested[52],1)
loaded[1]="item:51:0"
worn,why=A.ReadEquippedForUpgrade(player)
eq(worn,nil);eq(why,"pending");eq(requested[52],1)
loaded[16]="item:52:0"
worn=A.ReadEquippedForUpgrade(player)
eq(worn[1].id,51);eq(worn[16].id,52)
GetInventoryItemID=nil
eq(select(2,A.ReadEquippedForUpgrade({})),"unverified")
print("Equipped upgrades: real baseline %, paired sockets, hand displacement, set bonuses, uniqueness, cache misses.")
