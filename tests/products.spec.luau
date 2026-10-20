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
ctx.action:Fire(p,"Buy","Speed")
expect(ctx.market.prompts[1].kind=="Pass" and ctx.market.prompts[1].id==2038121195,"Speed Buy opens the correct pass")
ctx.step(1);ctx.action:Fire(p,"Buy","Gravity")
expect(ctx.market.prompts[2].kind=="Pass" and ctx.market.prompts[2].id==2041634630,"Jump Boot Buy opens the correct pass")
ctx.step(1);ctx.action:Fire(p,"Buy","Skip")
expect(ctx.market.prompts[3].kind=="Product" and ctx.market.prompts[3].id==3720254856,"ten-pack Buy opens the correct Developer Product")
expect(state().SkipCredits==0,"opening checkout does not grant paid credits")
local receipt={PlayerId=123,ProductId=3720254856,PurchaseId="creator-product-test"}
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().SkipCredits==10,"configured purchase saves ten credits")
expect(ctx.market.ProcessReceipt(receipt)=="PurchaseGranted" and state().SkipCredits==10,"duplicate receipt cannot become twenty credits")
ctx.touch(p,1);ctx.step(1);ctx.setFloor(ctx.world.Stages.Stage001.SafePad)
ctx.action:Fire(p,"UseSkip")
expect(state().Stage==2 and state().SkipCredits==9,"ten-pack is spent one stage at a time")
ctx.market.owns['123:2038121195']=true
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2038121195,true)
expect(p.Character.Humanoid.WalkSpeed==23,"configured Speed Pass grants speed after ownership check")
ctx.market.owns['123:2041634630']=true
ctx.market.PromptGamePassPurchaseFinished:Fire(p,2041634630,true)
expect(p.Character.Humanoid.JumpPower==62,"configured Jump Boot Pass grants higher jump after ownership check")
expect(#ctx.errors==0,table.concat(ctx.errors,"\n"))
print(string.format("PASS: %d configured-product wiring assertions with service doubles (no real payments)",checks))
