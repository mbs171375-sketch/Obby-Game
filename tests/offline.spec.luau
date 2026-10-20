-- Explicit disabled-product fixture checks fallback when a creator removes the catalogue.
local ctx=require("./harness")({zeroProducts=true,storeUnavailable=true})
local checks=0
local function expect(value,message) checks+=1;assert(value,message) end
local p=ctx.addPlayer(404)
local state=function() return ctx.state(p) end
expect(state().Stage==1,"unpublished place starts at stage 1")
expect(not state().Saving,"unavailable store explicitly reported")
for _,id in {"Speed","Gravity","Skip"} do
	expect(ctx.Config.Products[id].Id==0,"disabled fixture product IDs stay zero")
	expect(not state().Catalogue[id].Enabled,"zero IDs are not on sale")
end
ctx.touch(p,1)
for i=2,101 do ctx.step(1);ctx.touch(p,i) end
expect(state().Finished and state().Completed==100,"all 100 stages can complete without storage or purchases")
expect(state().Coins==298 and state().Wins==1,"session-only rewards still work")
ctx.step(2);ctx.action:Fire(p,"Skin","Toast")
expect(state().Coins==268 and state().Skin=="Toast","session-only earned-currency shop works")
ctx.step(2);ctx.action:Fire(p,"Restart")
expect(state().Stage==1 and not state().Finished,"offline restart resets run")
expect(state().Coins==268 and state().Skin=="Toast","offline restart keeps session rewards")
ctx.step(2);ctx.action:Fire(p,"Buy","Skip")
expect(#ctx.market.prompts==0,"default build never opens unavailable checkout")
expect(ctx.market.ProcessReceipt({PlayerId=404,ProductId=303,PurchaseId="unconfigured"})=="NotProcessedYet","unconfigured receipts not acknowledged")
expect(#ctx.errors==0,table.concat(ctx.errors,"\n"))
print(string.format("PASS: %d shipped-default/unpublished-place assertions with service doubles",checks))
