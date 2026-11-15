local A={}
for _,file in ipairs({"Engine","Upgrade","BagCombinations","SetBonuses"}) do
    assert(loadfile("WoWBest/"..file..".lua"))("WoWBest",A)
end
A.SetSkills,A.SetThresholds,A.ItemSetIDs,A.SetNames={},{},{},{}
local profile={strength=1}
local function make(id,loc,points,extras)
    local item={id=id,link="item:"..id,loc="INVTYPE_"..loc,
        classID=loc:find("WEAPON") and 2 or 4, stats={ITEM_MOD_STRENGTH_SHORT=points}}
    for key,value in pairs(extras or {}) do item[key]=value end
    return item
end
local function scan(items,worn,dual,chosenProfile)
    local bags={}
    local player,p={level=19,dual=dual or false},chosenProfile or profile
    for i,item in ipairs(items) do
        bags[i]={item=item,key=item.link,position={bag=0,slot=i},direct=A.CompareEquippedUpgrade(item,worn,player,p)}
    end
    local step=A.StartJointBagUpgrades(bags,worn,player,p)
    if not step then return {},0 end
    for frames=1,1000 do
        local done,alerts=step()
        if done then return alerts,frames end
    end
    error("joint search did not finish")
end
local two=make(1,"2HWEAPON",12)
local main=make(2,"WEAPON",8)
local shield=make(3,"SHIELD",7)
local unrelated=make(4,"HEAD",50)
local worn={[16]=two,[5]=make(5,"CHEST",20)}
assert(A.CompareEquippedUpgrade(main,worn,{},profile).delta==-4)
assert(not A.CompareEquippedUpgrade(shield,worn,{},profile))
local found=scan({shield,unrelated,main},worn)
assert(#found==1)
local r=found[1].result
assert(r.delta==3 and r.baseline==32 and r.total==35 and r.slotPercent==25 and r.percent==100*3/32)
assert(r.loadout[5]==worn[5] and not r.loadout[1] and r.loadout[16]==main and r.loadout[17]==shield)
assert(#r.changedSlots==2 and r.changedSlots[1]==16 and r.changedSlots[2]==17)
assert(found[1].parts[1].slot==16 and found[1].parts[1].position.slot==3 and found[1].parts[2].item==shield)
assert(found[1].key==scan({main,shield,unrelated},worn)[1].key)
local sameID=make(2,"WEAPON",8,{link="item:2::::::31"})
assert(scan({main,shield,sameID},worn)[1].key==scan({sameID,shield,main},worn)[1].key,
    "moving equally scored variants cannot create a fresh announcement")
assert(#scan({unrelated,shield},worn)==0)
assert(#scan({main,shield},{[16]=make(10,"WEAPON",5),[17]=make(11,"SHIELD",5)})==0,
    "independent gains should use individual alerts")
assert(#scan({main,shield},worn,false,{strength=1,shield=true})==1,
    "the actual worn two-hander remains the Protection comparison baseline")

-- Two identical bag links can represent two physical weapons. One physical
-- copy can never fill both sockets, and unique-equipped still overrides two.
local blade=make(12,"WEAPON",7)
assert(#scan({blade,unrelated},worn,true)==0)
assert(#scan({blade,blade},worn,false)==0)
local duplicate=scan({blade,blade},worn,true)
assert(#duplicate==1 and duplicate[1].result.delta==2)
assert(duplicate[1].parts[1].position~=duplicate[1].parts[2].position)
blade.unique=true
assert(#scan({blade,blade},worn,true)==0)

-- Three individual downgrades become a five-point gain at a modeled threshold.
local hat=make(21,"HEAD",4,{setID=80})
local robe=make(22,"CHEST",4,{setID=80})
local glove=make(23,"HAND",4,{setID=80})
A.SetThresholds[80]={{pieces=3,stats={ITEM_MOD_STRENGTH_SHORT=8}}}
local otherHat=make(28,"HEAD",5)
local old={[1]=otherHat,[5]=make(29,"CHEST",5),[10]=make(30,"HAND",5),[16]=two}
local setAlert=scan({hat,robe,glove,unrelated},old)
assert(#setAlert==1 and #setAlert[1].parts==3 and setAlert[1].result.delta==5)
assert(setAlert[1].result.swapBefore==15 and setAlert[1].result.swapAfter==12)
assert(setAlert[1].result.loadout[16]==two)
assert(#scan({hat,robe,unrelated},old)==0)
-- No extra copy of a piece can advance a distinct set-member threshold.
assert(#scan({hat,hat,robe},old)==0)

-- The same effect applies on an unrelated slot. A bag weapon cannot get free
-- points by restoring a worn unique-group member that the optimizer removed.
local talisman=make(24,"TRINKET",5,{unique="category:20"})
local uniqueShield=make(25,"SHIELD",7,{unique="category:20"})
local limited=scan({main,uniqueShield},{[16]=two,[13]=talisman})
for _,alert in ipairs(limited) do
    assert(not (alert.result.loadout[13]==talisman and alert.result.loadout[17]==uniqueShield))
end
local many={}
for i=1,60 do many[i]=make(100+i,"HEAD",1) end
local _,frames=scan(many,worn)
assert(frames>1, "inventory search must allow other frames to run")
print("Joint bag upgrades: two hands, exact copies, set thresholds and cooperative scanning passed")
