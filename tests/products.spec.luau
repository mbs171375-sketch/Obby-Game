-- Verify the creator's actual configured IDs, using simulated services (no purchases).
local ctx=require("./harness")({defaultProducts=true})
local checks=0
local function expect(value,message) checks+=1;assert(value,message) end
local products=ctx.Config.Products
expect(products.Speed.Id==2038121195 and products.Speed.Kind=="Pass","Speed Coil is the supplied Game Pass")
expect(products.Gravity.Id==2041634630 and products.Gravity.Kind=="Pass" and products.Gravity.Name=="Jump Boot","Jump Boot is the supplied Game Pass")
expect(products.Skip.Id==3720254856 and products.Skip.Kind=="Product" and products.Skip.Credits==10,"ten-skip Developer Product quantity")
expect(ctx.world.Lobby.OriginalStart.Safe.Value,"lobby spawn allows safe promotion cards")
expect(ctx.world.Lobby:FindFirstChild("Lobby lawn").Safe.Value,"lobby lawn allows safe promotion cards")
local p=ctx.addPlayer(123)
local function state() return ctx.state(p) end
expect(state().Catalogue.Skip.Enabled,"Developer Product price works without an asset-only sale flag")
expect(p.Character.Humanoid.WalkSpeed==16 and p.Character.Humanoid.JumpPower==50,"non-owner spawns with normal movement")
ctx.action:Fire(p,"EquipCoil","Speed");ctx.step(1);ctx.action:Fire(p,"EquipCoil","Gravity")
expect(p.Character.Humanoid.WalkSpeed==16 and p.Character.Humanoid.JumpPower==50,"unpaid equip attempts cannot grant either boost")
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2038121195,true)
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2041634630,true)
expect(p.Character.Humanoid.WalkSpeed==16 and p.Character.Humanoid.JumpPower==50,"purchase-finished signals without verified ownership grant nothing")
ctx.step(2)
ctx.action:Fire(p,"Buy","Speed")
expect(ctx.market.prompts[1].kind=="Pass" and ctx.market.prompts[1].id==2038121195,"Speed Buy opens the correct pass")
ctx.step(1);ctx.action:Fire(p,"Buy","Gravity")
expect(ctx.market.prompts[2].kind=="Pass" and ctx.market.prompts[2].id==2041634630,"Jump Boot Buy opens the correct pass")
ctx.step(1);ctx.action:Fire(p,"Buy","Skip")
expect(ctx.market.prompts[3].kind=="Product" and ctx.market.prompts[3].id==3720254856,"ten-pack Buy opens the correct Developer Product")
expect(state().SkipCredits==0,"opening checkout does not grant paid credits")
expect(p.Character.Humanoid.WalkSpeed==16 and p.Character.Humanoid.JumpPower==50,"opening purchase prompts does not grant either boost")
local receipt={PlayerId=123,ProductId=3720254856,PurchaseId="creator-product-test"}
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().SkipCredits==10,"configured purchase saves ten credits")
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().SkipCredits==10,"duplicate receipt cannot become twenty credits")
ctx.touch(p,1);ctx.step(1);ctx.setFloor(ctx.world.Stages.Stage001.SafePad)
ctx.action:Fire(p,"UseSkip")
expect(state().Stage==11 and state().SkipCredits==0,"one use moves forward ten stages")
ctx.market.owns['123:2038121195']=true
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2038121195,true)
expect(p.Character.Humanoid.WalkSpeed==32,"configured Speed Pass grants speed after ownership check")
ctx.market.owns['123:2041634630']=true
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2041634630,true)
expect(p.Character.Humanoid.JumpPower==100,"configured Jump Boot Pass grants higher jump after ownership check")
expect(p.Character.Humanoid.WalkSpeed==32 and p.Character.Humanoid.JumpPower==100,"both owned boosts work together")
ctx.step(2);ctx.action:Fire(p,"EquipCoil","Speed")
expect(p.Character.Humanoid.WalkSpeed==16 and p.Character.Humanoid.JumpPower==100,"speed toggle preserves jump boost")
ctx.step(2);ctx.action:Fire(p,"EquipCoil","Speed")
expect(p.Character.Humanoid.WalkSpeed==32,"speed toggle restores boost")
p.CharacterAdded:Fire(p.Character)
expect(p.Character.Humanoid.WalkSpeed==32 and p.Character.Humanoid.JumpPower==100,"boosts survive respawn")
ctx.touch(p,1);ctx.setFloor(ctx.world.Stages.Stage001.SafePad)
receipt.PurchaseId="automatic-ten-stage-skip"
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().Stage==11 and state().SkipCredits==0,"confirmed purchase automatically advances ten stages from safety")
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().Stage==11 and state().SkipCredits==0,"receipt replay never teleports again")
for i=12,95 do ctx.step(1);ctx.touch(p,i) end
ctx.setFloor(ctx.world.Stages.Stage095.SafePad)
receipt.PurchaseId="finish-cap"
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().Finished,"skip near finish caps at final stage")
expect(state().SkipCredits==4,"unused portion of ten stages stays saved")
expect(p.Character.HumanoidRootPart.Position.Y>ctx.world.VictoryIsland.FinishPad.Position.Y,"finish skip lands at the mouth finish pad")
ctx.market.owns['124:2038121195']=true;ctx.market.owns['124:2041634630']=true
local owned=ctx.addPlayer(124)
expect(ctx.state(owned).Owned.Speed and ctx.state(owned).Owned.Gravity,"existing ownership unlocks shop controls")
expect(owned.Character.Humanoid.WalkSpeed==16 and owned.Character.Humanoid.JumpPower==50,"even existing owners join with normal movement")
expect(owned.Character:FindFirstChild("EquippedCoil")==nil,"no paid coil appears on spawn")
ctx.action:Fire(owned,"EquipCoil","Speed");ctx.step(1);ctx.action:Fire(owned,"EquipCoil","Gravity")
expect(owned.Character.Humanoid.WalkSpeed==32 and owned.Character.Humanoid.JumpPower==100,"verified owner can deliberately enable both paid boosts")
-- Interrupt the actual production reservation between durable write and delivery.
ctx.touch(owned,1);ctx.setFloor(nil)
local interruption={PlayerId=124,ProductId=3720254856,PurchaseId="interrupted-use"}
expect(ctx.market.ProcessReceipt(interruption)=="PurchaseGranted" and ctx.state(owned).SkipCredits==10,"unsafe purchase saves all ten for later use")
ctx.setFloor(ctx.world.Stages.Stage001.SafePad)
local originalUpdate=ctx.storage.UpdateAsync
local interrupt=true
function ctx.storage:UpdateAsync(key,fn)
	local value=originalUpdate(self,key,fn)
	if interrupt and key=="player:124" and value and value.PendingSkip then
		interrupt=false
		owned.Character.Humanoid.Died:Fire()
	end
	return value
end
ctx.step(2);ctx.action:Fire(owned,"UseSkip")
expect(ctx.state(owned).SkipCredits==10 and ctx.state(owned).Stage==1,"interrupted ten-stage teleport refunds all ten")
expect(ctx.storage.records["player:124"].PendingSkip==nil,"failed delivery clears the reservation")
ctx.storage.UpdateAsync=originalUpdate
ctx.touch(owned,1);ctx.step(2);ctx.action:Fire(owned,"UseSkip")
expect(ctx.state(owned).Stage==11 and ctx.state(owned).SkipCredits==0,"refunded purchase can successfully deliver ten stages later")
expect(#ctx.errors==0,table.concat(ctx.errors,"\n"))
print(string.format("PASS: %d configured-product wiring assertions with service doubles (no real payments)",checks))
