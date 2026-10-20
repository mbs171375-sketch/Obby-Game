--!strict
-- All UI is built locally. Currency, movement benefits and purchases remain server-owned.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("OrbitShared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Remotes = ReplicatedStorage:WaitForChild("OrbitRemotes")
local Action, State, Notice = Remotes:WaitForChild("Action"), Remotes:WaitForChild("State"), Remotes:WaitForChild("Notice")

local palette = {
	Ink = Color3.fromRGB(28,22,50), Panel = Color3.fromRGB(42,33,70), Muted = Color3.fromRGB(189,181,213),
	White = Color3.fromRGB(255,250,255), Mint = Color3.fromRGB(109,250,209), Pink = Color3.fromRGB(255,126,204),
	Gold = Color3.fromRGB(255,218,111), Line = Color3.fromRGB(91,74,124),
}
local worlds = {
	"Noodle Nebula", "Toast Goblin City", "Banana Broadcast", "Froggy Frequency", "Capybara Cloud Club",
	"Spaghetti Storm", "Galaxy Gooseworks", "Jellybean Jailbreak", "Disco Dumpling", "Cosmic Crown",
}
local worldColors = {
	{255,116,207},{255,181,71},{255,230,70},{121,249,142},{255,191,148},
	{255,115,88},{174,181,255},{255,109,174},{211,135,255},{255,213,76},
}
local currentZone = 0
local hints = {
	"Find your rhythm. Small jumps, big brain.", "Look where you want to land.", "Balance mode. Slow down on the beam.",
	"Pink lava is still lava. Hop over it!", "Watch the sweep, then jump the laser.",
	"Mint = solid. Amber = move! Side path stays solid.", "Arrows push sideways. Steer against the drift.",
	"Cyan spring = a gentle extra hop.", "Ride the cloud, or use the side stones.", "Two lanes. Both work. Pick your vibe.",
}
local settings = { Music = true, SFX = true, Promotions = true, ReducedMotion = false }
local snapshot = { Stage = 1, Completed = 0, Coins = 0, Wins = 0, Best = 0, SkipCredits = 0,
	Skin = "Classic", Skins = {}, Owned = {}, Catalogue = {}, Equipped = "None", Saving = false, Finished = false, Elapsed = 0 }
local received = false
local receivedAt = os.clock()
local promotionState = Rules.newPromotion(os.clock())
local activePromotion, suspendedPromotion = nil, nil
local safeSince = nil
local modal = nil
local updateShop
local localCatalogue = {}
local refreshingPrices = false
local priceAttemptAt = -1000

local function priceInfo(id)
	local allowed = snapshot.Catalogue[id]
	local localInfo = localCatalogue[id]
	return if allowed and allowed.Enabled and localInfo then localInfo else nil
end

local function refreshPrices()
	if refreshingPrices then return end
	if os.clock() - priceAttemptAt < 20 then return end
	priceAttemptAt = os.clock()
	refreshingPrices = true
	for id,product in Config.Products do
		local allowed = snapshot.Catalogue[id]
		if allowed and allowed.Enabled and product.Id > 0 then
			local kind = if product.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			-- Client query obtains the player's regional price. Never invent a price or discount.
			local ok,info = pcall(MarketplaceService.GetProductInfoAsync,MarketplaceService,product.Id,kind)
			if ok and info.IsForSale and Rules.finite(info.PriceInRobux) then
				localCatalogue[id] = {Enabled=true,Price=info.PriceInRobux}
			else localCatalogue[id] = nil end
		end
	end
	refreshingPrices = false
	if updateShop then updateShop() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotOrbitUI"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function make(class, parent, props)
	local ob = Instance.new(class)
	for key,value in props do ob[key] = value end
	ob.Parent = parent
	return ob
end
local function corner(ob,radius) make("UICorner",ob,{ CornerRadius = UDim.new(0,radius or 14) }) end
local function stroke(ob,color,thickness) make("UIStroke",ob,{ Color = color or palette.Line, Thickness = thickness or 1.5, Transparency = .15 }) end
local function text(parent,value,size,color,pos,dimensions,bold)
	return make("TextLabel",parent,{ Name = "Text", BackgroundTransparency = 1, Text = value, TextColor3 = color or palette.White,
		TextSize = size or 16, Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		Position = pos or UDim2.new(), Size = dimensions or UDim2.fromScale(1,1), TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true })
end
local function frame(parent,color,pos,size)
	return make("Frame",parent,{ BackgroundColor3 = color, BorderSizePixel = 0, Position = pos, Size = size })
end
local function button(parent,label,pos,size,color,callback)
	local b = make("TextButton",parent,{ BackgroundColor3 = color or palette.Panel, BorderSizePixel = 0,
		Position = pos, Size = size, Text = label, TextColor3 = palette.White, TextSize = 14,
		Font = Enum.Font.GothamBold, AutoButtonColor = true, Selectable = true })
	corner(b,10); stroke(b)
	b.Activated:Connect(callback)
	return b
end
local function animate(ob,props,duration)
	if settings.ReducedMotion then for key,value in props do ob[key] = value end
	else TweenService:Create(ob,TweenInfo.new(duration or .25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props):Play() end
end

-- Original geometric mascot art: no external images or copied character assets.
local function mascot(parent,pos,size,color,kind)
	local art = frame(parent,palette.Ink,pos,size); art.BackgroundTransparency = 1
	local body = frame(art,color,UDim2.fromScale(.12,.18),UDim2.fromScale(.76,.68));corner(body,24)
	if kind == "Skip" then
		text(body,">>",30,palette.Ink,UDim2.fromScale(.05,0),UDim2.fromScale(.95,1),true).TextXAlignment = Enum.TextXAlignment.Center
	else
		for _,x in {.18,.57} do
			local eye=frame(body,palette.White,UDim2.fromScale(x,.22),UDim2.fromScale(.23,.35));corner(eye,20)
			local pupil=frame(eye,palette.Ink,UDim2.fromScale(.37,.2),UDim2.fromScale(.44,.63));corner(pupil,20)
		end
		local mouth=frame(body,palette.Ink,UDim2.fromScale(.4,.72),UDim2.fromScale(.2,.07));corner(mouth,5)
	end
	return art
end

-- A small corner readout leaves the centre and the course unobstructed.
local hud=frame(gui,palette.Ink,UDim2.fromOffset(12,12),UDim2.fromOffset(216,76))
hud.Name="CornerHUD";hud.BackgroundTransparency=.16;corner(hud,12);stroke(hud)
local stageLabel=text(hud,"STAGE 1 / 100",16,palette.White,UDim2.fromOffset(12,7),UDim2.new(1,-24,0,21),true)
local coinsLabel=text(hud,"0 COINS",11,palette.Gold,UDim2.fromOffset(12,31),UDim2.fromOffset(100,16),true)
local timerLabel=text(hud,"00:00.0",11,palette.Mint,UDim2.fromOffset(118,31),UDim2.fromOffset(80,16),true)
local worldLabel=text(hud,"01 / NOODLE NEBULA",10,palette.Muted,UDim2.fromOffset(12,50),UDim2.new(1,-24,0,15))
local progressTrack=frame(hud,palette.Panel,UDim2.fromOffset(12,69),UDim2.new(1,-24,0,3));corner(progressTrack,3)
local progressFill=frame(progressTrack,palette.Mint,UDim2.new(),UDim2.fromScale(0,1));corner(progressFill,3)
local saveLabel=text(gui,"Connecting...",10,palette.Gold,UDim2.fromOffset(12,90),UDim2.fromOffset(250,16))

local rail=frame(gui,palette.Ink,UDim2.new(1,-118,.5,-86),UDim2.fromOffset(102,172));corner(rail,14);stroke(rail)
local shopButton=button(rail,"SHOP",UDim2.fromOffset(8,8),UDim2.fromOffset(86,44),palette.Panel,function() end)
local settingsButton=button(rail,"SETTINGS",UDim2.fromOffset(8,60),UDim2.fromOffset(86,44),palette.Panel,function() end)
local restartButton=button(rail,"RESTART",UDim2.fromOffset(8,112),UDim2.fromOffset(86,44),palette.Panel,function() end)

local overlay = frame(gui,Color3.new(0,0,0),UDim2.fromScale(0,0),UDim2.fromScale(1,1))
overlay.BackgroundTransparency=.35;overlay.Visible=false;overlay.ZIndex=5
local panel=frame(overlay,palette.Ink,UDim2.fromScale(.5,.5),UDim2.new(.86,0,.78,0))
panel.AnchorPoint=Vector2.new(.5,.5);panel.ZIndex=6;corner(panel,20);stroke(panel)
make("UISizeConstraint",panel,{ MaxSize=Vector2.new(640,600),MinSize=Vector2.new(250,220) })
local panelTitle=text(panel,"THE VIBE SHOP",22,palette.Mint,UDim2.fromOffset(22,16),UDim2.new(1,-90,0,30),true)
local subtitle=text(panel,"Cosmetics use earned coins. Purchases are optional.",12,palette.Muted,UDim2.fromOffset(22,51),UDim2.new(1,-44,0,32))
local closeButton=button(panel,"X",UDim2.new(1,-52,0,16),UDim2.fromOffset(34,34),palette.Panel,function() end)
local scroll=make("ScrollingFrame",panel,{ BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(18,94),
	Size=UDim2.new(1,-36,1,-110),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=4,
	ScrollBarImageColor3=palette.Mint, ScrollingDirection=Enum.ScrollingDirection.Y })
make("UIListLayout",scroll,{ Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder })
make("UIPadding",scroll,{ PaddingBottom=UDim.new(0,12),PaddingRight=UDim.new(0,6) })

local toast=frame(gui,palette.Ink,UDim2.fromOffset(12,111),UDim2.fromOffset(270,54))
corner(toast,14);stroke(toast);toast.Visible=false;toast.ZIndex=10
make("UISizeConstraint",toast,{ MaxSize=Vector2.new(560,90) })
local toastText=text(toast,"",12,palette.White,UDim2.fromOffset(16,8),UDim2.new(1,-32,1,-16),true)
local toastSerial=0
local sfx=make("Sound",SoundService,{ Name="OrbitNotification",SoundId="rbxasset://sounds/electronicpingshort.wav",Volume=.15 })
local function notify(message,kind)
	toastSerial+=1;local serial=toastSerial
	toast.Visible=true;toastText.Text=message
	toastText.TextColor3=if kind=="Warning" then palette.Gold else palette.White
	if settings.SFX then sfx.PlaybackSpeed=if kind=="Win" then 1.5 else 1.1;sfx:Play() end
	task.delay(5,function() if toastSerial==serial then toast.Visible=false end end)
end

local promo=frame(gui,palette.Ink,UDim2.new(1,-16,0,174),UDim2.fromOffset(276,188))
promo.AnchorPoint=Vector2.new(1,0);promo.Visible=false;corner(promo,16);stroke(promo)
local promoKicker=text(promo,"OPTIONAL UPGRADE",10,palette.Muted,UDim2.fromOffset(14,10),UDim2.fromOffset(210,16),true)
local promoArt=mascot(promo,UDim2.fromOffset(12,35),UDim2.fromOffset(66,60),palette.Gold,"Speed")
local promoTitle=text(promo,"Speed Coil",16,palette.White,UDim2.fromOffset(88,35),UDim2.new(1,-102,0,25),true)
local promoBenefit=text(promo,"Run faster while equipped",11,palette.Muted,UDim2.fromOffset(88,63),UDim2.new(1,-102,0,34))
local promoFooter=text(promo,"Every stage can be completed for free.",10,palette.Muted,UDim2.fromOffset(14,156),UDim2.new(1,-28,0,25))
local promoBuy=button(promo,"",UDim2.fromOffset(14,111),UDim2.new(1,-28,0,36),palette.Panel,function()
	if activePromotion then Action:FireServer("Buy",activePromotion);promo.Visible=false;activePromotion=nil;rail.Visible=true end
end)
local promoClose=button(promo,"X",UDim2.new(1,-35,0,6),UDim2.fromOffset(27,27),palette.Panel,function()
	promo.Visible=false;activePromotion=nil;suspendedPromotion=nil;rail.Visible=true
end)

local function hidePromotion(suspend)
	if suspend and activePromotion then suspendedPromotion=activePromotion end
	activePromotion=nil;promo.Visible=false;rail.Visible=true
end
local function closeModal()
	overlay.Visible=false;modal=nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(panel) then GuiService.SelectedObject=nil end
end
closeButton.Activated:Connect(closeModal)
local function openModal(name)
	hidePromotion(true);modal=name;overlay.Visible=true
	panel.Size=UDim2.new(.86,0,.78,0)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=closeButton end
end
local function clearRows()
	for _,child in scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
end
local function row(title,detail,color,height)
	local r=frame(scroll,palette.Panel,UDim2.new(),UDim2.new(1,0,0,height or 108));corner(r,12)
	text(r,title,16,color or palette.White,UDim2.fromOffset(14,9),UDim2.new(1,-28,0,24),true)
	text(r,detail,12,palette.Muted,UDim2.fromOffset(14,35),UDim2.new(1,-28,0,31))
	return r
end
updateShop=function()
	if modal~="Shop" then return end
	clearRows()
	panelTitle.Text="THE VIBE SHOP"
	subtitle.Text=string.format("%d coins • %d skip credits • everything optional",snapshot.Coins,snapshot.SkipCredits)
	for _,id in {"Speed","Gravity","Skip"} do
		local product=Config.Products[id]
		local info=priceInfo(id)
		local owned=snapshot.Owned[id]
		local r=row(product.Name,product.Benefit,Color3.fromRGB(table.unpack(product.Color)),116)
		local available=info and info.Enabled and snapshot.Saving
		local label=if owned then (if snapshot.Equipped==id then "UNEQUIP" else "EQUIP")
			elseif available then "BUY • R$ "..tostring(info.Price) else "NOT ON SALE"
		local buy=button(r,label,UDim2.fromOffset(12,74),UDim2.new(.65,-18,0,31),palette.Ink,function()
			if owned then Action:FireServer("EquipCoil",if snapshot.Equipped==id then "None" else id)
			elseif available then Action:FireServer("Buy",id) end
		end)
		if not available and not owned then buy.TextColor3=palette.Muted end
		if id=="Skip" then
			button(r,"USE CREDIT",UDim2.new(.65,0,0,74),UDim2.new(.35,-12,0,31),palette.Ink,function()
				Action:FireServer("UseSkip");closeModal()
			end)
		end
	end
	for _,skin in Config.Skins do
		local owned=snapshot.Skins[skin.Id] or skin.Id=="Classic"
		local r=row(skin.Name,"Character colour + companion + matching trail",Color3.fromRGB(table.unpack(skin.Color)),112)
		local label=if snapshot.Skin==skin.Id then "EQUIPPED" elseif owned then "EQUIP" else tostring(skin.Cost).." COINS"
		button(r,label,UDim2.fromOffset(12,72),UDim2.new(1,-24,0,29),palette.Ink,function() Action:FireServer("Skin",skin.Id) end)
	end
end

local function showSettings()
	openModal("Settings");clearRows();panelTitle.Text="YOUR ORBIT"
	subtitle.Text="Keep the vibe. Adjust the noise. No purchase required."
	local names={ Music="Music",SFX="Sound effects",Promotions="Optional purchase reminders",ReducedMotion="Reduce interface motion" }
	for _,id in {"Music","SFX","Promotions","ReducedMotion"} do
		local detail=if id=="Promotions" then "Only while standing still on a safe island. Never opens checkout."
			elseif id=="Music" then (if #Config.MusicTracks>0 then "Brainrot Rap soundtrack. Turn the music on or off." else "Original tung-tung percussion loop.")
			elseif id=="ReducedMotion" then "Removes interface transitions and victory confetti." else "Short milestone and notification sounds."
		local r=row(names[id],detail,palette.White,112)
		local toggle
		toggle=button(r,if settings[id] then "ON" else "OFF",UDim2.fromOffset(12,73),UDim2.new(1,-24,0,28),palette.Ink,function()
			settings[id]=not settings[id];toggle.Text=if settings[id] then "ON" else "OFF"
			Action:FireServer("Settings",id..":"..(if settings[id] then "on" else "off"))
			if id=="Promotions" and not settings.Promotions then hidePromotion(false);suspendedPromotion=nil end
		end)
	end
end

shopButton.Activated:Connect(function() openModal("Shop");updateShop();task.spawn(refreshPrices) end)
for _,ob in workspace:WaitForChild("OrbitWorld"):WaitForChild("Lobby"):GetDescendants() do
	if ob:IsA("ProximityPrompt") and ob.Name=="OpenShop" then
		ob.Triggered:Connect(function() openModal("Shop");updateShop() end)
	end
end
settingsButton.Activated:Connect(showSettings)
restartButton.Activated:Connect(function()
	openModal("Restart");clearRows();panelTitle.Text=if snapshot.Finished then "ANOTHER ORBIT?" else "RESTART THIS RUN?"
	subtitle.Text="Coins, cosmetics and unused skip credits stay. Run progress returns to stage 1."
	local r=row("Back to the lobby", "There are no permanent checkpoints.",palette.Gold,145)
	button(r,"YES • RESTART RUN",UDim2.fromOffset(12,77),UDim2.new(1,-24,0,40),palette.Ink,function()
		Action:FireServer("Restart");closeModal()
	end)
end)
UserInputService.InputBegan:Connect(function(input,processed)
	if processed then return end
	if input.KeyCode==Enum.KeyCode.B or input.KeyCode==Enum.KeyCode.ButtonY then openModal("Shop");updateShop()
	elseif input.KeyCode==Enum.KeyCode.ButtonB then closeModal() end
end)

local function isSafe()
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 or hum.FloorMaterial==Enum.Material.Air or root.AssemblyLinearVelocity.Magnitude>2 then return false end
	local state=hum:GetState()
	if state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall then return false end
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char}
	params.RespectCanCollide=true
	local hit=workspace:Raycast(root.Position,Vector3.new(0,-7,0),params)
	local marker=hit and hit.Instance:FindFirstChild("Safe")
	return marker~=nil and marker.Value==true
end

local function showPromotion(id)
	local info=priceInfo(id)
	if not info or not info.Enabled or snapshot.Owned[id] or not snapshot.Saving then return end
	if id=="Skip" and (snapshot.Finished or not received) then return end
	activePromotion=id;promo.Visible=true;rail.Visible=false
	promoTitle.Text=Config.Products[id].Name
	promoBenefit.Text=Config.Products[id].Benefit
	promoBuy.Text="BUY • R$ "..tostring(info.Price)
	promoArt:Destroy()
	promoArt=mascot(promo,UDim2.fromOffset(12,35),UDim2.fromOffset(66,60),Color3.fromRGB(table.unpack(Config.Products[id].Color)),id)
	if not settings.ReducedMotion then
		promo.BackgroundTransparency=1;animate(promo,{BackgroundTransparency=0},.3)
	end
	local shownId=id
	task.delay(20,function() if activePromotion==shownId then hidePromotion(false) end end)
end

local function confetti()
	if settings.ReducedMotion then return end
	for i=1,40 do
		local chip=frame(gui,if i%2==0 then palette.Mint else palette.Pink,UDim2.fromScale(math.random(),-.03),UDim2.fromOffset(7,12))
		chip.Rotation=math.random(0,180);chip.ZIndex=12
		local tween=TweenService:Create(chip,TweenInfo.new(2+math.random(),Enum.EasingStyle.Linear),{
			Position=UDim2.fromScale(math.random(),1.1),Rotation=math.random(180,540),BackgroundTransparency=.7 })
		tween:Play();tween.Completed:Connect(function() chip:Destroy() end)
	end
end
Notice.OnClientEvent:Connect(function(message,kind)
	notify(message,kind)
	if kind=="Win" then confetti() end
end)
State.OnClientEvent:Connect(function(data)
	local first=not received
	snapshot=data;received=true;receivedAt=os.clock()
	if first and data.Settings then for key,value in data.Settings do if settings[key]~=nil then settings[key]=value end end end
	local stage=math.clamp(data.Stage,1,100)
	local zone=math.floor((stage-1)/10)+1
	if zone~=currentZone then
		currentZone=zone
		local tint=Color3.fromRGB(table.unpack(worldColors[zone]))
		animate(Lighting,{Ambient=Color3.fromRGB(110,97,148):Lerp(tint,.16)},1.5)
		local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then animate(atmosphere,{Color=Color3.fromRGB(210,225,255):Lerp(tint,.16)},1.5) end
	end
	worldLabel.Text=string.format("%02d / %s",zone,string.upper(worlds[zone]))
	stageLabel.Text=if data.Finished then "100 / 100 • LEGEND!" else string.format("STAGE %d / 100",stage)
	coinsLabel.Text=string.format("%d COINS",data.Coins)
	animate(progressFill,{Size=UDim2.fromScale(data.Completed/100,1)},.35)
	saveLabel.Text=if data.Saving then "" else "SESSION ONLY • SAVES OFFLINE"
	restartButton.Text=if data.Finished then "RUN AGAIN" else "RESTART"
	updateShop()
	for id,info in data.Catalogue do
		if info.Enabled and not localCatalogue[id] then task.spawn(refreshPrices);break end
	end
end)

local function layout()
	local camera=workspace.CurrentCamera
	if not camera then return end
	local compact=camera.ViewportSize.X<650
	hud.Size=UDim2.fromOffset(if compact then 180 else 216,76)
	stageLabel.TextSize=if compact then 14 else 16
	worldLabel.TextSize=if compact then 9 else 10
	coinsLabel.Size=UDim2.fromOffset(if compact then 82 else 100,16)
	timerLabel.Position=UDim2.fromOffset(if compact then 98 else 118,31)
	rail.Position=UDim2.new(1,if compact then -98 else -118,.5,-66)
	rail.Size=UDim2.fromOffset(if compact then 82 else 102,172)
	for _,b in {shopButton,settingsButton,restartButton} do b.Size=UDim2.fromOffset(if compact then 66 else 86,44);b.TextSize=if compact then 10 else 14 end
	promo.Size=UDim2.fromOffset(if compact then 238 else 276,188)
	promo.Position=UDim2.new(1,-16,0,if compact then 150 else 174)
end
local cameraConnection
local function bindCamera()
	if cameraConnection then cameraConnection:Disconnect() end
	local camera=workspace.CurrentCamera
	if camera then cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
	layout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera);bindCamera()

local dancers={}
for _,model in workspace.OrbitWorld:GetDescendants() do
	if model:IsA("Model") and model:FindFirstChild("Dance") then
		table.insert(dancers,{model=model,base=model:GetPivot(),phase=model.Dance.Value,moving=false})
	end
end
-- The player owns their character physics. Apply only the contacted floor's
-- small translation locally; never drag an airborne player or reuse a stale floor.
local supportPart,supportFrame,supportCharacter=nil,nil,nil
local function carryOnSupport()
	local char=player.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health<=0 or hum.FloorMaterial==Enum.Material.Air
		or hum:GetState()==Enum.HumanoidStateType.Jumping or hum:GetState()==Enum.HumanoidStateType.Freefall then
		supportPart=nil;supportFrame=nil;supportCharacter=nil;return
	end
	local feet=math.max(3,hum.HipHeight+root.Size.Y/2)
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={char};params.RespectCanCollide=true
	local hit=workspace:Raycast(root.Position,Vector3.new(0,-feet-.8,0),params)
	local floor=hit and hit.Instance
	if not floor or not floor.CanCollide or not floor:FindFirstChild("MoveDistance") then
		supportPart=nil;supportFrame=nil;supportCharacter=nil;return
	end
	local localPos=floor.CFrame:PointToObjectSpace(root.Position)
	if math.abs(localPos.X)>floor.Size.X/2+.3 or math.abs(localPos.Z)>floor.Size.Z/2+.3
		or math.abs(localPos.Y-floor.Size.Y/2-feet)>.8 then
		supportPart=nil;supportFrame=nil;supportCharacter=nil;return
	end
	if supportPart==floor and supportFrame and supportCharacter==char then
		local offset=floor.CFrame.Position-supportFrame.Position
		if offset.Magnitude<=4 then root.CFrame=root.CFrame+offset end
	end
	supportPart=floor;supportFrame=floor.CFrame;supportCharacter=char
end
RunService.RenderStepped:Connect(function()
	carryOnSupport()
	local now=workspace:GetServerTimeNow()
	for _,dancer in dancers do
		if settings.ReducedMotion then
			if dancer.moving then dancer.model:PivotTo(dancer.base);dancer.moving=false end
		else
			local phase=now*math.pi*(Config.MusicBPM or 132)/60+dancer.phase
			dancer.model:PivotTo(dancer.base*CFrame.new(0,math.sin(phase)*.65,0)*CFrame.Angles(0,math.sin(phase*.5)*.22,0))
			dancer.moving=true
		end
	end
	local elapsed=(snapshot.Elapsed or 0)+(if snapshot.Running then os.clock()-receivedAt else 0)
	timerLabel.Text=string.format("%02d:%04.1f",math.floor(elapsed/60),elapsed%60)
	local safe=isSafe()
	if safe then safeSince=safeSince or os.clock() else safeSince=nil end
	if not safe or modal then hidePromotion(true) end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(1)
		local safe=safeSince~=nil and os.clock()-safeSince>=2
		local busy=modal~=nil or activePromotion~=nil or not received
		local id=Rules.tickPromotion(promotionState,os.clock(),settings.Promotions,safe,busy or suspendedPromotion~=nil)
		if suspendedPromotion and safe and not modal and settings.Promotions then
			local nextId=suspendedPromotion;suspendedPromotion=nil;showPromotion(nextId)
		elseif id then showPromotion(id) end
	end
end)
task.spawn(function() while gui.Parent do task.wait(120);refreshPrices() end end)

-- Original percussion, not a recording of somebody else's song or voice.
-- Creator-owned Roblox audio IDs in MusicTracks take precedence over this bundled-sound beat.
local musicFolder=make("Folder",SoundService,{Name="OrbitMusic"})
local function voice(name,asset,speed,volume)
	return make("Sound",musicFolder,{Name=name,SoundId="rbxasset://sounds/"..asset,PlaybackSpeed=speed,Volume=volume})
end
task.spawn(function()
	if #Config.MusicTracks>0 then
		local index=1
		while gui.Parent do
			local sound=make("Sound",musicFolder,{SoundId="rbxassetid://"..tostring(Config.MusicTracks[index]),Volume=.18})
			sound:Play()
			local deadline=os.clock()+240
			local loadDeadline=os.clock()+12
			local loadWarned=false
			repeat
				sound.Volume=if settings.Music then .18 else 0
				if not sound.IsLoaded and os.clock()>loadDeadline and not loadWarned then
					loadWarned=true;notify("Music could not load. Check the audio asset's experience permissions.","Warning")
				end
				task.wait(.25)
				until (sound.IsLoaded and not sound.IsPlaying) or os.clock()>deadline
			sound:Destroy();index=index%#Config.MusicTracks+1
		end
	else
		local tung={voice("TungLow","action_footsteps_plastic.mp3",.52,.13),voice("TungMid","action_footsteps_plastic.mp3",.66,.11),voice("TungHigh","action_footsteps_plastic.mp3",.81,.10)}
		local clap=voice("SahurClap","action_jump.mp3",1.4,.055)
		local hat=voice("Hat","action_footsteps_plastic.mp3",2.4,.025)
		local bass=voice("Bass","electronicpingshort.wav",.32,.035)
		local beat=0
		local notes={0,0,3,7,0,5,3,-2}
		local function hit(sound) sound:Stop();sound.TimePosition=0;sound:Play() end
		while gui.Parent do
			local step=beat%16+1
			if settings.Music then
				if step==1 or step==4 or step==7 or step==9 or step==11 or step==15 then hit(tung[(beat%3)+1]) end
				if step==5 or step==13 then hit(clap) end
				if step%2==0 then hit(hat) end
				if step%2==1 then
					bass.PlaybackSpeed=.32*2^((notes[math.floor((step-1)/2)+1]+math.max(currentZone-1,0)%3*2)/12)
					hit(bass)
				end
			else for _,sound in musicFolder:GetChildren() do if sound:IsA("Sound") then sound:Stop() end end end
			beat+=1
			task.wait(60/math.clamp(Config.MusicBPM or 132,60,180)/2)
		end
	end
end)

Action:FireServer("Sync")
task.spawn(function()
	for _=1,10 do
		if received then return end
		task.wait(2);Action:FireServer("Sync")
	end
	notify("Server is still loading. Check the Output window if this continues.","Warning")
end)
