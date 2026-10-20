-- Execute the actual production server against isolated service doubles.
local ctx=require("./harness")()
local roblox=require("@lune/roblox")
local V=roblox.Vector3
local services,world,market,storage=ctx.services,ctx.world,ctx.market,ctx.storage
local playerService=services.Players
local action,step,addPlayer,state,touch=ctx.action,ctx.step,ctx.addPlayer,ctx.state,ctx.touch
local errors=ctx.errors
local checks=0
local function expect(value,message) checks+=1;assert(value,message) end
local p=addPlayer(7)
expect(state(p).Stage==1 and state(p).Coins==0,"new player state")
expect(p.Character.Humanoid.WalkSpeed==16,"baseline speed applied")
expect((p.Character.HumanoidRootPart.Position-world.Lobby.OriginalStart.Position).Magnitude<6,"initial lobby spawn")
expect(p.Character.HumanoidRootPart.CFrame.LookVector.Z>.9,"spawn faces course entrance")
touch(p,1);step(1);touch(p,3)
expect(state(p).Stage==1,"out-of-order crossing rejected")
touch(p,2)
expect(state(p).Stage==2 and state(p).Coins==2,"normal crossing awards coins")
touch(p,2)
expect(state(p).Coins==2,"repeat touch does not duplicate coins")
step(1);p.Character.Humanoid.Died:Fire()
expect(state(p).Stage==1 and state(p).Coins==2,"death resets run, keeps coins")
expect(#market.prompts==0,"no automatic purchase prompt")
touch(p,1)
for i=2,100 do step(1);touch(p,i) end
world.VictoryIsland.ArrivalPad.Touched:Fire(p.Character.HumanoidRootPart)
expect(not state(p).Finished and state(p).Stage==100,"arrival outside Tung's mouth does not award victory")
step(1);touch(p,101)
expect(state(p).Finished and state(p).Completed==100,"all 100 stages complete")
expect(state(p).Wins==1 and state(p).Coins==300,"one win and exact free-run rewards")
touch(p,101)
expect(state(p).Wins==1,"finish cannot be farmed by repeat touch")
expect(storage.records['player:7'].Wins==1,"win persisted")

action:Fire(p,"Restart")
expect(state(p).Stage==1 and not state(p).Finished,"restart resets only run")
expect(state(p).Coins==300,"restart keeps currency")
step(2)
action:Fire(p,"Skin","Frog")
expect(state(p).Skin=="Frog" and state(p).Coins==240,"real skin action charges earned currency")
expect(p.Character:FindFirstChild("OrbitCosmetic")~=nil,"skin creates companion/trail")
expect(p.Character.BodyColors.TorsoColor3==roblox.Color3.fromRGB(125,255,146),"skin applies character palette")
step(1);action:Fire(p,"Skin","Frog")
expect(state(p).Coins==240,"equipping owned skin is free")
step(1);action:Fire(p,"Skin","Classic")
expect(p.Character.BodyColors.TorsoColor3==roblox.Color3.fromRGB(180,180,180),"classic skin restores avatar palette")
step(1);action:Fire(p,"Settings","Promotions:off")
expect(storage.records['player:7'].Settings.Promotions==false,"reminder opt-out saved")
step(1);action:Fire(p,"Buy","Skip")
expect(#market.prompts==1 and market.prompts[1].id==303,"only explicit Buy opens configured prompt")
local receipt={PlayerId=7,ProductId=303,PurchaseId="purchase-one"}
expect(market.ProcessReceipt(receipt)=="PurchaseGranted","durably acknowledged receipt")
expect(state(p).SkipCredits==1,"receipt gives credit, not forced teleport")
expect(market.ProcessReceipt(receipt)=="PurchaseGranted" and state(p).SkipCredits==1,"receipt replay idempotent")
expect(market.ProcessReceipt({PlayerId=7,ProductId=999,PurchaseId="unknown"})=="NotProcessedYet","unknown products never acknowledged")
expect(market.ProcessReceipt({PlayerId=999,ProductId=303,PurchaseId="absent"})=="NotProcessedYet","offline player retries later")
touch(p,1);step(1);ctx.setFloor(nil);action:Fire(p,"UseSkip")
expect(state(p).SkipCredits==1 and state(p).Stage==1,"unsafe skip does not consume credit")
step(1);ctx.setFloor(world.Stages.Stage001.SafePad);action:Fire(p,"UseSkip")
expect(state(p).SkipCredits==0 and state(p).Stage==2,"safe credit usage advances exactly one stage")
expect(storage.records['player:7'].PendingSkip==nil,"delivered skip reservation settled")
step(1);p.Character.Humanoid.Died:Fire()
expect(state(p).Stage==1,"death after paid skip still restarts run")

-- Forged ownership, invalid payloads and rate floods must not grant items or open checkout.
step(5);action:Fire(p,"EquipCoil","Speed")
expect(p.Character.Humanoid.WalkSpeed==16,"unowned coil rejected")
local before=#market.prompts
for _=1,50 do action:Fire(p,"Buy","Skip") end
expect(#market.prompts-before<=10,"server-side request rate limit")
action:Fire(p,"Buy",{Id=303})
action:Fire(p,{},"Skip")
expect(#errors==0,"malformed client requests do not throw")
market.owns['7:101']=true;market.PromptGamePassPurchaseFinished:Fire(p,101,true)
expect(state(p).Owned.Speed and p.Character.Humanoid.WalkSpeed==23,"pass re-query authorizes and equips speed coil")
step(5);action:Fire(p,"EquipCoil","None")
expect(p.Character.Humanoid.WalkSpeed==16,"unequip restores baseline")
market.owns['7:202']=true;market.PromptGamePassPurchaseFinished:Fire(p,202,true)
expect(state(p).Owned.Gravity and p.Character.Humanoid.JumpPower==62,"gravity pass equips higher jump")
step(2);action:Fire(p,"EquipCoil","None")
expect(p.Character.Humanoid.JumpPower==50,"unequip restores jump strength")

storage.fail=true
local retry={PlayerId=7,ProductId=303,PurchaseId="retry-after-outage"}
expect(market.ProcessReceipt(retry)=="NotProcessedYet","storage failure does not acknowledge purchase")
storage.fail=false
expect(market.ProcessReceipt(retry)=="PurchaseGranted" and state(p).SkipCredits==1,"retry after recovery grants once")
local p2=addPlayer(8)
expect(state(p2).Stage==1 and state(p2).Coins==0,"multiplayer state isolated")
expect(state(p).Coins>0,"second player cannot reset first player's inventory")
storage.fail=true
local p3=addPlayer(9)
expect(not state(p3).Saving,"offline save fallback explicitly reported")
step(2);local prompts=#market.prompts;action:Fire(p3,"Buy","Skip")
expect(#market.prompts==prompts,"paid purchases disabled in session-only mode")
storage.fail=false
local spring,conveyor,boost,ferry,spinner,fade,hazard,lift,stairs,crumble,pendulum,cable
for _,ob in world:GetDescendants() do
	if ob:FindFirstChild("Spring") then spring=ob end
	if ob:FindFirstChild("Conveyor") then conveyor=ob end
	if ob:FindFirstChild("SpeedBoost") then boost=ob end
	if ob:FindFirstChild("MoveDistance") and not ob:FindFirstChild("MoveAxis") then ferry=ob end
	if ob:FindFirstChild("MoveAxis") and not ob:FindFirstChild("Fade") then lift=ob end
	if ob:FindFirstChild("MoveAxis") and ob:FindFirstChild("Fade") then stairs=ob end
	if ob:FindFirstChild("Crumble") then crumble=ob end
	if ob:FindFirstChild("Pendulum") then pendulum=ob end
	if ob:FindFirstChild("Spinner") then spinner=ob end
	if ob:FindFirstChild("Fade") then fade=ob end
	if ob:FindFirstChild("Hazard") then hazard=ob end
end
spring.Touched:Fire(p2.Character.HumanoidRootPart)
expect(p2.Character.HumanoidRootPart.AssemblyLinearVelocity.Y==53,"spring applies upward velocity")
expect(math.abs(conveyor.AssemblyLinearVelocity.Magnitude-5)<.001,"conveyor velocity initialized")
boost.Touched:Fire(p2.Character.HumanoidRootPart)
expect(p2.Character.Humanoid.WalkSpeed==22,"free boost increases speed")
step(3.1)
expect(p2.Character.Humanoid.WalkSpeed==16,"free boost expires to baseline")
p2.Character.HumanoidRootPart.AssemblyLinearVelocity=V.zero
p2.Character.HumanoidRootPart.CFrame=ferry.CFrame+V.new(0,3,0)
ctx.setFloor(ferry)
local oldPosition=p2.Character.HumanoidRootPart.Position
services.RunService.Heartbeat:Fire()
expect((p2.Character.HumanoidRootPart.Position-oldPosition).Magnitude<.001,"server never snaps a cloud rider against their controls")
local spinnerBefore=spinner.CFrame
step(.5);services.RunService.Heartbeat:Fire()
expect(spinner.CFrame~=spinnerBefore,"spinner changes orientation")
local sawHidden,sawSolid=false,false
for _=1,30 do step(.25);sawHidden=sawHidden or not fade.CanCollide;sawSolid=sawSolid or fade.CanCollide end
expect(sawHidden and sawSolid,"fade tiles cycle through solid and hidden states")
local liftBefore=lift.Position
p2.Character.HumanoidRootPart.AssemblyLinearVelocity=V.zero
p2.Character.HumanoidRootPart.CFrame=lift.CFrame+V.new(0,3,0)
ctx.setFloor(lift)
local riderBefore=p2.Character.HumanoidRootPart.Position
step(.45);services.RunService.Heartbeat:Fire()
expect(math.abs(lift.Position.Y-liftBefore.Y)>.001,"lifts move vertically")
expect(math.abs(lift.Position.X-liftBefore.X)<.001 and math.abs(lift.Position.Z-liftBefore.Z)<.001,"lift does not drift off its route")
expect((p2.Character.HumanoidRootPart.Position-riderBefore).Magnitude<.001,"server never rewrites a lift rider's character pose")
stairs.CanCollide=false
p2.Character.HumanoidRootPart.CFrame=stairs.CFrame+V.new(0,3,0)
ctx.setFloor(stairs)
local airPosition=p2.Character.HumanoidRootPart.Position
step(.01);services.RunService.Heartbeat:Fire()
expect((p2.Character.HumanoidRootPart.Position-airPosition).Magnitude<.001,"invisible stairs do not carry unsupported players")
crumble.Touched:Fire(p2.Character.HumanoidRootPart)
expect(crumble.CanCollide,"crumbling step gives a warning before vanishing")
step(.8);expect(not crumble.CanCollide,"stepped-on crumble platform disappears")
p2.Character.HumanoidRootPart.CFrame=crumble.CFrame
step(3.6);expect(not crumble.CanCollide,"platform must not restore inside a character")
p2.Character.HumanoidRootPart.CFrame=crumble.CFrame+V.new(0,12,0)
step(.2);expect(crumble.CanCollide,"platform restores after the character clears it")
local ballBefore=pendulum.CFrame
step(.4);services.RunService.Heartbeat:Fire()
expect(pendulum.CFrame~=ballBefore,"dodge ball swings in a pendulum arc")
for _,child in pendulum.Parent:GetChildren() do
	if child:FindFirstChild("PendulumCable") and child.PendulumIndex.Value==pendulum.PendulumIndex.Value then cable=child end
end
expect(math.abs((pendulum.Position-cable.Position).Magnitude-7.5)<.001,"cable follows the swinging ball")
p2.Character.Humanoid.Health=100
p2.Character.HumanoidRootPart.CFrame=pendulum.CFrame
step(.1);services.RunService.Heartbeat:Fire()
expect(p2.Character.Humanoid.Health==0,"swinging ball overlap detects a hit without relying on CFrame touch events")
hazard.Touched:Fire(p2.Character.HumanoidRootPart)
expect(p2.Character.Humanoid.Health==0,"hazard touch kills humanoid")
playerService.PlayerRemoving:Fire(p2)
expect(#errors==0,table.concat(errors,"\n"))
print(string.format("PASS: %d production-server assertions with service doubles (not engine playtests)",checks))

return ctx
