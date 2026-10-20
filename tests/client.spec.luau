-- UI/event simulation on service doubles. Does not claim pixels, audio or touch physics work.
local ctx=require("./server.spec")
local fs=require("@lune/fs")
local r=require("@lune/roblox")
local services,Methods=ctx.services,ctx.Methods
local originalNew=ctx.new
local function new(cls)
	local ob=originalNew(cls)
	if cls=="TextButton" then ob.Activated=ctx.signal() end
	if cls=="ScreenGui" or cls=="Frame" then ob.Visible=true end
	if cls=="Sound" then ob.IsLoaded=true;ob.IsPlaying=false end
	return ob
end
function Methods:Play() self.IsPlaying=true;self.PlayCount=(self.PlayCount or 0)+1 end
function Methods:Stop() self.IsPlaying=false end
function Methods:GetPropertyChangedSignal(name)
	self.Changes=self.Changes or {}
	if not self.Changes[name] then self.Changes[name]=ctx.signal() end
	return self.Changes[name]
end
function Methods:IsDescendantOf(parent)
	local p=self.Parent
	while p do if p==parent then return true end;p=p.Parent end
	return false
end
function Methods:GetState() return "Running" end
local p=ctx.addPlayer(10)
services.Players.LocalPlayer=p
local playerGui=new("PlayerGui");playerGui.Name="PlayerGui";playerGui.Parent=p
services.SoundService=services.SoundService or new("SoundService")
services.UserInputService={GamepadEnabled=false,InputBegan=ctx.signal()}
services.GuiService={}
services.RunService.RenderStepped=ctx.signal()
services.TweenService={Create=function(_,ob,_,props)
	local tween={Completed=ctx.signal()}
	function tween:Play() for k,v in props do ob[k]=v end;self.Completed:Fire() end
	return tween
end}
ctx.workspace.CurrentCamera=new("Camera")
ctx.workspace.CurrentCamera.ViewportSize=r.Vector2.new(1280,720)
local remotes=services.ReplicatedStorage.OrbitRemotes
for _,remote in remotes:GetChildren() do remote.OnClientEvent=ctx.signal() end
local originalFire=Methods.FireClient
function Methods:FireClient(player,...)
	originalFire(self,player,...)
	if player==p then self.OnClientEvent:Fire(...) end
end
function Methods:FireServer(...) self.OnServerEvent:Fire(p,...) end
local E=table.clone(ctx.env.Enum)
E.Font={Gotham="Gotham",GothamBold="GothamBold"}
E.TextXAlignment={Left="Left",Center="Center",Right="Right"}
E.ZIndexBehavior={Sibling="Sibling"}
E.EasingStyle={Quart="Quart",Linear="Linear"};E.EasingDirection={Out="Out"}
E.AutomaticSize={Y="Y"};E.ScrollingDirection={Y="Y"};E.SortOrder={LayoutOrder="LayoutOrder"}
E.KeyCode={B="B",ButtonY="Y",ButtonB="PadB"}
E.HumanoidStateType={Jumping="Jumping",Freefall="Freefall"};E.Material=table.clone(E.Material);E.Material.Air="Air"
local env=setmetatable({Instance={new=new},Enum=E,UDim2=r.UDim2,UDim=r.UDim,Vector2=r.Vector2,
	TweenInfo={new=function(...) return {...} end},math=math},{__index=ctx.env})
local code=assert(loadstring(fs.readFile("src/client/Game.client.luau"),"OrbitClient"));setfenv(code,env);code()
local gui=playerGui.BrainrotOrbitUI
local checks=0
local function expect(value,message) checks+=1;assert(value,message) end
local function findText(value,class)
	for _,ob in gui:GetDescendants() do if ob.Text==value and (not class or ob.ClassName==class) then return ob end end
	return nil
end
local function click(value)
	local ob=assert(findText(value,"TextButton"),"Button missing: "..value)
	ob.Activated:Fire();return ob
end
expect(gui~=nil,"client builds persistent UI")
local soundtrack=services.SoundService.OrbitMusic:GetChildren()[1]
expect(soundtrack.SoundId=="rbxassetid://127002536892791","requested Brainrot Rap asset selected")
expect(findText("STAGE 1 / 100")~=nil,"initial server sync reaches HUD")
expect(gui.CornerHUD.Size.X.Scale==0 and gui.CornerHUD.Size.X.Offset==216,"desktop stage readout stays in a small corner card")
expect(gui.CornerHUD.Position.X.Scale==0 and gui.CornerHUD.Position.Y.Scale==0,"stage card never occupies the middle of the screen")
for _,child in gui:GetChildren() do
	if child.ClassName=="Frame" and child.Visible then expect(child.Size.X.Scale<.5,"no visible full-width gameplay overlay") end
end
local dancer=ctx.workspace.OrbitWorld.Lobby:FindFirstChild("Tung Tung Tung Sahur")
local danceBase=dancer:GetPivot()
services.RunService.RenderStepped:Fire()
expect(dancer:GetPivot()~=danceBase,"brainrot scenery animates")
click("SHOP")
expect(findText("THE VIBE SHOP")~=nil,"shop button opens catalogue")
expect(findText("BUY • R$ 20","TextButton")~=nil,"shop uses player's locally fetched regional price")
local prompts=#ctx.market.prompts
expect(prompts>0,"fixture includes earlier server tests")
local buy=findText("BUY • R$ 20","TextButton")
buy.Activated:Fire()
expect(#ctx.market.prompts==prompts+1,"deliberate buy activation prompts purchase")
click("X")
click("SETTINGS")
local function settingToggle(label)
	for _,ob in gui:GetDescendants() do
		if ob.Text==label then
			for _,child in ob.Parent:GetChildren() do if child.ClassName=="TextButton" then return child end end
		end
	end
	error("Setting missing: "..label)
end
settingToggle("Music").Activated:Fire();ctx.step(1)
for _,sound in services.SoundService.OrbitMusic:GetChildren() do expect(not sound.IsPlaying or sound.Volume==0,"music toggle silences soundtrack") end
settingToggle("Sound effects").Activated:Fire()
local chime=services.SoundService.OrbitNotification
local playCount=chime.PlayCount or 0
remotes.Notice:FireClient(p,"Quiet notification","Info")
expect((chime.PlayCount or 0)==playCount,"SFX toggle mutes notification playback")
settingToggle("Reduce interface motion").Activated:Fire()
expect(settingToggle("Reduce interface motion").Text=="ON","reduced-motion setting responds")
services.RunService.RenderStepped:Fire()
expect(dancer:GetPivot()==danceBase,"reduced motion restores the stationary scenery pose")
local toggle
for _,ob in gui:GetDescendants() do
	if ob.Text=="Optional purchase reminders" then
		for _,child in ob.Parent:GetChildren() do if child.ClassName=="TextButton" then toggle=child end end
	end
end
expect(toggle~=nil and toggle.Text=="ON","reminder setting is accessible")
toggle.Activated:Fire();expect(toggle.Text=="OFF","reminder toggle responds")
toggle.Activated:Fire();expect(toggle.Text=="ON","reminders can be reenabled")
-- Close the actual modal close button (promotion X may be constructed but hidden).
local overlay
for _,ob in gui:GetChildren() do if ob.ClassName=="Frame" and ob.ZIndex==5 then overlay=ob end end
for _,ob in overlay:GetDescendants() do if ob.ClassName=="TextButton" and ob.Text=="X" then ob.Activated:Fire() end end
expect(not overlay.Visible,"modal close button responds")

-- At 50 seconds, the card queues while airborne and never starts checkout automatically.
ctx.setFloor(nil)
local before=#ctx.market.prompts
ctx.step(50);services.RunService.RenderStepped:Fire()
local promoTitle=findText("Speed Coil","TextLabel")
expect(promoTitle~=nil and not promoTitle.Parent.Visible,"no card during danger")
ctx.touch(p,1);p.Character.Humanoid.FloorMaterial="Concrete"
ctx.setFloor(ctx.workspace.OrbitWorld.Stages.Stage001.SafePad)
services.RunService.RenderStepped:Fire();ctx.step(3)
expect(promoTitle.Parent.Visible,"queued promotion displays after two safe seconds")
expect(#ctx.market.prompts==before,"automatic card never opens checkout")
p.Character.HumanoidRootPart.AssemblyLinearVelocity=r.Vector3.new(5,0,0)
services.RunService.RenderStepped:Fire()
expect(not promoTitle.Parent.Visible,"movement instantly hides promotion")
p.Character.HumanoidRootPart.AssemblyLinearVelocity=r.Vector3.zero
services.RunService.RenderStepped:Fire();ctx.step(3)
expect(promoTitle.Parent.Visible,"promotion resumes at safety")
local card=promoTitle.Parent
for _,ob in card:GetChildren() do if ob.ClassName=="TextButton" and ob.Text=="X" then ob.Activated:Fire() end end
expect(not card.Visible,"promotion X dismisses card")
expect(findText("SHOP","TextButton").Parent.Visible,"dismissing card restores menu access")
ctx.step(46)
expect(findText("Skip Current Stage","TextLabel")~=nil,"next timed offer alternates to skip")

-- Exercise the layout branch used by portrait phones.
ctx.workspace.CurrentCamera.ViewportSize=r.Vector2.new(375,812)
ctx.workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Fire()
expect(gui.CornerHUD.Size.X.Offset==180,"phone stage card stays 180 pixels wide")
expect(findText("STAGE 1 / 100").TextSize==14,"compact stage text layout")
expect(card.Size.X.Offset==238,"compact promotion width fits portrait screen")
expect(#ctx.errors==0,table.concat(ctx.errors,"\n"))
print(string.format("PASS: %d client-wiring assertions with service doubles (not visual/device tests)",checks))
