local Rules = require("../src/shared/Rules")
local checks = 0
local function expect(value, message)
	checks += 1
	assert(value, message)
end

-- Sequential, nearby stage arrivals only; reject NaN, infinity, fractions and remote hops.
expect(Rules.canAdvance(1,2,8),"normal stage crossing")
expect(Rules.canAdvance(100,101,17),"finish boundary")
for _,target in {0,1,3,102,2.5,0/0,math.huge} do
	expect(not Rules.canAdvance(1,target,1),"invalid stage rejected")
end
for _,distance in {-1,17.01,math.huge,0/0} do
	expect(not Rules.canAdvance(1,2,distance),"invalid or distant crossing rejected")
end

-- Timer queues in danger and alternates actual offers, with no catch-up spam.
expect(Rules.intersectsRestoringSurface(0,0,0,7,.8,4.2,3.5),"body intersects a hidden platform")
expect(Rules.intersectsRestoringSurface(0,3,0,7,.8,4.2,3.5),"legs intersect the restore zone")
expect(not Rules.intersectsRestoringSurface(0,5,0,7,.8,4.2,3.5),"player safely above the surface")
expect(not Rules.intersectsRestoringSurface(10,0,0,7,.8,4.2,3.5),"player beside the surface")
expect(not Rules.intersectsRestoringSurface(0,-4,0,7,.8,4.2,3.5),"player safely below the surface")
local state=Rules.newPromotion(0)
expect(Rules.tickPromotion(state,49,true,true,false)==nil,"no early promotion")
expect(Rules.tickPromotion(state,50,true,false,false)==nil and state.queued,"danger queues offer")
expect(Rules.tickPromotion(state,51,true,true,true)==nil,"modal prevents offer")
expect(Rules.tickPromotion(state,52,true,true,false)=="Speed","queued coil delivered at safety")
expect(Rules.tickPromotion(state,53,true,true,false)==nil,"no repeated offer")
expect(Rules.tickPromotion(state,100,true,true,false)=="Skip","second offer is skip")
expect(Rules.tickPromotion(state,150,true,true,false)=="Gravity","coil types alternate")
expect(Rules.tickPromotion(state,200,true,true,false)=="Skip","skip alternates")
Rules.tickPromotion(state,250,true,false,false)
expect(Rules.tickPromotion(state,251,false,true,false)==nil and not state.queued,"disable clears queue")
expect(Rules.tickPromotion(state,280,true,true,false)==nil,"disable restarts interval")
expect(Rules.tickPromotion(state,10000,true,true,false)=="Speed","long absence coalesces to one offer")
expect(Rules.tickPromotion(state,10001,true,true,false)==nil,"no catchup spam")

-- Corrupt/missing data cannot inject currency, unknown preference keys or invalid ownership.
local data=Rules.normalize({Coins=-20,Wins=0/0,Best=999,SkipCredits=2.9,Skin="Hacker",
	Skins={Frog=true,Toast="yes"},Settings={Music=false,Promotions=false,Fake=true}})
expect(data.Coins==0 and data.Wins==0 and data.Best==100 and data.SkipCredits==2,"sanitize counters")
expect(data.Skin=="Classic" and data.Skins.Classic and data.Skins.Frog and not data.Skins.Toast,"sanitize cosmetics")
expect(not data.Settings.Music and not data.Settings.Promotions and data.Settings.Fake==nil,"sanitize settings")
expect(Rules.normalize(nil).Coins==0,"new player")
expect(Rules.normalize("corrupt").Coins==0,"invalid record")

-- Durable receipt idempotency even when an old receipt is replayed after other purchases.
data=Rules.newProfile()
local granted
data,granted=Rules.grantReceipt(data,"receipt-a")
expect(granted and data.SkipCredits==1,"first purchase grants one credit")
data,granted=Rules.grantReceipt(data,"receipt-a")
expect(not granted and data.SkipCredits==1,"duplicate purchase does not grant")
data=Rules.grantReceipt(data,"receipt-b")
data,granted=Rules.grantReceipt(data,"receipt-a")
expect(not granted and data.SkipCredits==2,"old receipt replay does not grant")
local previous=data
data=Rules.flush(data,{Coins=20,Wins=1,Best=15})
expect(data.Coins==20 and data.Wins==1 and data.Best==15 and data.SkipCredits==2,"autosave preserves paid balance")
expect(previous.Coins==0,"transforms do not mutate stored input")
data=Rules.flush(data,{Coins=0,Wins=0,Best=5})
expect(data.Best==15,"best never decreases")

-- A pending credit cannot be spent twice. Crashes refund once; successful delivery consumes once.
local reserved
data,reserved=Rules.reserveSkip(data,"run-a")
expect(reserved and data.SkipCredits==1 and data.PendingSkip=="run-a","reservation persists")
local second,spent=Rules.reserveSkip(data,"run-b")
expect(not spent and second.SkipCredits==1,"concurrent reservation refused")
data=Rules.resolveSkip(data,"wrong-token",false)
expect(data.SkipCredits==1 and data.PendingSkip=="run-a","wrong refund token ignored")
data=Rules.resolveSkip(data,"run-a",false)
expect(data.SkipCredits==2 and not data.PendingSkip,"interrupted skip refunded")
data=Rules.resolveSkip(data,"run-a",false)
expect(data.SkipCredits==2,"refund replay is idempotent")
data=Rules.reserveSkip(data,"run-c")
data=Rules.resolveSkip(data,"run-c",true)
expect(data.SkipCredits==1 and not data.PendingSkip,"successful skip consumes exactly one")
local empty=Rules.newProfile()
empty,spent=Rules.reserveSkip(empty,"freebie")
expect(not spent and empty.SkipCredits==0,"no free credits or negative balance")

-- Currency purchases are atomic and equipping owned cosmetics is free.
data.Coins=100
local bought
data,bought=Rules.buySkin(data,"Frog",60)
expect(bought and data.Coins==40 and data.Skin=="Frog","coin purchase")
data,bought=Rules.buySkin(data,"Frog",60)
expect(bought and data.Coins==40,"re-equip does not charge")
data,bought=Rules.buySkin(data,"Cosmic",160)
expect(not bought and data.Coins==40 and not data.Skins.Cosmic,"insufficient funds rejected")
for _,cost in {-1,0/0,math.huge,1.5} do
	local _,success=Rules.buySkin(data,"Invalid",cost)
	expect(not success,"invalid cost rejected")
end
data=Rules.grantReceipt(data,"receipt-c")
expect(data.Skins.Frog and data.Coins==40 and data.SkipCredits==2,"receipt preserves cosmetics and coins")

-- Fail closed at the receipt ledger limit; never discard evidence and regrant old purchases.
local full=Rules.newProfile()
for i=1,4000 do full.Receipts[tostring(i)]=true end
expect(Rules.grantReceipt(full,"new")==nil,"full ledger refuses new receipt safely")
local replay=Rules.grantReceipt(full,"1")
expect(replay~=nil and replay.SkipCredits==0,"known receipt can still be acknowledged")

print(string.format("PASS: %d game-rule assertions",checks))
