--!strict
-- Server owns progression, rewards, inventory, grants, movement effects, and purchases.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("OrbitShared")
local Config = require(Shared:WaitForChild("Config"))
local Rules = require(Shared:WaitForChild("Rules"))
local Remotes = ReplicatedStorage:WaitForChild("OrbitRemotes")
local Action = Remotes:WaitForChild("Action")
local State = Remotes:WaitForChild("State")
local Notice = Remotes:WaitForChild("Notice")
local World = workspace:WaitForChild("OrbitWorld")
local storeReady, Store = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
if not storeReady then Store = nil end

local sessions = {}
local loading = {}
local pads = {}
local catalogue = {}
local shuttingDown = false
local IN_FLIGHT = Enum.ProductPurchaseDecision.NotProcessedYet
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted

local function key(player) return "player:" .. player.UserId end
local function notice(player, text, kind)
	if player.Parent then Notice:FireClient(player, text, kind or "Info") end
end

local function playerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then return player, humanoid end
	return nil, nil
end

local function view(player)
	local s = sessions[player]
	if not s then return end
	local completed = if s.run.finished then 100 else s.run.stage - 1
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Stage.Value = completed
		stats.Wins.Value = s.data.Wins + s.pending.Wins
	end
	State:FireClient(player, {
		Stage = s.run.stage, Completed = completed, Finished = s.run.finished,
		Wins = s.data.Wins + s.pending.Wins,
		Best = math.max(s.data.Best, s.pending.Best), SkipCredits = s.data.SkipCredits,
		Skin = s.data.Skin, Skins = s.data.Skins, Equipped = s.equipped,
		Owned = s.owned, Catalogue = catalogue, Saving = s.persistent and s.saveHealthy,
		Settings = s.data.Settings,
		Running = s.run.started ~= nil and not s.run.finished,
		Elapsed = if s.run.finished then s.run.duration else (if s.run.started then workspace:GetServerTimeNow() - s.run.started else 0),
	})
end

local function safeFloor(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or root.AssemblyLinearVelocity.Magnitude > 3 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -7, 0), params)
	if not hit then return false end
	local safe = hit.Instance:FindFirstChild("Safe")
	return safe ~= nil and safe.Value == true
end

local function restoreSurface(ob)
	while ob.Parent do
		local occupied=false
		for player in sessions do
			local char=player.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local hum=char and char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health>0 then
				local p=ob.CFrame:PointToObjectSpace(root.Position)
				local feet=math.max(3.5,hum.HipHeight+root.Size.Y/2)
				if Rules.intersectsRestoringSurface(p.X,p.Y,p.Z,ob.Size.X,ob.Size.Y,ob.Size.Z,feet) then occupied=true;break end
			end
		end
		if not occupied then ob.CanCollide=true;return true end
		task.wait(.1)
	end
	return false
end

local function update(player, transform)
	local s = sessions[player]
	if not s or not s.persistent then return nil end
	while s.storageBusy do task.wait(.05) end
	if sessions[player] ~= s then return nil end
	s.storageBusy = true
	local success, result = pcall(function()
		return Store:UpdateAsync(key(player), function(raw)
			return transform(Rules.normalize(raw))
		end)
	end)
	s.storageBusy = false
	if not success then
		s.saveHealthy = false
		warn("[Orbit] Storage operation failed for user", player.UserId)
		return nil
	end
	s.saveHealthy = true
	return result
end

local function flush(player)
	local s = sessions[player]
	if not s then return false end
	while s.flushing do task.wait(.05) end
	if not s.persistent then return true end
	s.flushing = true
	local delta = table.clone(s.pending)
	local result = update(player, function(data) return Rules.flush(data, delta) end)
	if result then
		s.pending.Coins -= delta.Coins
		s.pending.Wins -= delta.Wins
		s.pending.Best = math.max(s.pending.Best, result.Best)
		s.data = result
	end
	s.flushing = false
	return result ~= nil
end

local function moveTo(player, pad)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return false end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	local position = pad.Position + Vector3.new(0, pad.Size.Y / 2 + hum.HipHeight + root.Size.Y / 2 + .3, 0)
	local marker = pad:FindFirstChild("Stage")
	local nextPad = if marker then pads[marker.Value + 1] else pads[1]
	local toward = if nextPad then nextPad.Position else pad.Position + Vector3.new(0,0,10)
	char:PivotTo(CFrame.lookAt(position,Vector3.new(toward.X,position.Y,toward.Z)))
	return true
end

local function applyLook(player)
	local s = sessions[player]
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not root then return end
	local old = char:FindFirstChild("OrbitCosmetic")
	if old then old:Destroy() end
	for _, child in root:GetChildren() do if child.Name:match("^OrbitTrail") then child:Destroy() end end
	local original = char:FindFirstChild("OrbitOriginalColors")
	local colors = char:FindFirstChildOfClass("BodyColors")
	if colors and not original then
		original = Instance.new("Folder"); original.Name = "OrbitOriginalColors"; original.Parent = char
		for _, property in {"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"} do
			local stored=Instance.new("Color3Value");stored.Name=property;stored.Value=colors[property];stored.Parent=original
		end
	end
	if original and colors then
		for _, property in {"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"} do
			colors[property] = original[property].Value
		end
	end
	local skin
	for _, item in Config.Skins do if item.Id == s.data.Skin then skin = item end end
	if not skin or skin.Id == "Classic" then return end
	local folder = Instance.new("Folder")
	folder.Name = "OrbitCosmetic"
	folder.Parent = char
	local hue = Color3.fromRGB(table.unpack(skin.Color))
	if colors then
		colors.TorsoColor3 = hue; colors.LeftArmColor3 = hue; colors.RightArmColor3 = hue
		colors.LeftLegColor3 = hue:Lerp(Color3.fromRGB(40,30,70),.35)
		colors.RightLegColor3 = colors.LeftLegColor3
	end
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position = Vector3.new(-.7, 0, .65); b.Position = Vector3.new(.7, 0, .65)
	a.Name = "OrbitTrailLeft"; b.Name = "OrbitTrailRight"
	-- Attachments belong to a part, and are explicitly cleaned on re-equip.
	a.Parent = root; b.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a; trail.Attachment1 = b; trail.Lifetime = .45
	trail.Color = ColorSequence.new(hue); trail.LightEmission = .6
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,.15), NumberSequenceKeypoint.new(1,1) })
	trail.Parent = folder
	local head = char:FindFirstChild("Head")
	if head then
		local buddy = Instance.new("Part")
		buddy.Name = skin.Name .. " Halo"
		buddy.Shape = Enum.PartType.Ball
		buddy.Size = Vector3.new(1.1,1.1,1.1)
		buddy.Color = hue; buddy.Material = Enum.Material.Neon
		buddy.Massless = true; buddy.CanCollide = false; buddy.CanTouch = false; buddy.CanQuery = false
		buddy.CFrame = head.CFrame * CFrame.new(1.5,.8,0)
		buddy.Parent = folder
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head; weld.Part1 = buddy; weld.Parent = buddy
		for _, side in {-1,1} do
			local eye = Instance.new("Part")
			eye.Name = "BuddyEye"; eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(.16,.22,.12); eye.Color = Color3.fromRGB(25,20,45)
			eye.Massless = true; eye.CanCollide = false; eye.CanTouch = false; eye.CanQuery = false
			eye.CFrame = buddy.CFrame * CFrame.new(side*.19,.1,-.51); eye.Parent = folder
			local join=Instance.new("WeldConstraint");join.Part0=buddy;join.Part1=eye;join.Parent=eye
		end
	end
end

local function applyCoil(player)
	local s = sessions[player]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not s or not hum or not root then return end
	hum.UseJumpPower = true
	local speed = if s.owned.Speed and s.equipped.Speed then Config.SpeedCoilSpeed else Config.BaseWalkSpeed
	hum.WalkSpeed = if (s.boostUntil or 0) > os.clock() then math.max(speed,22) else speed
	hum.JumpPower = if s.owned.Gravity and s.equipped.Gravity then Config.GravityCoilJump else Config.BaseJumpPower
	local previous = char:FindFirstChild("EquippedCoil")
	if previous then previous:Destroy() end
	if not s.equipped.Speed and not s.equipped.Gravity then return end
	local coil = Instance.new("Model")
	coil.Name = "EquippedCoil"; coil.Parent = char
	local color = Color3.fromRGB(table.unpack(Config.Products[if s.equipped.Speed then "Speed" else "Gravity"].Color))
	for i = 1, 6 do
		local ring = Instance.new("Part")
		ring.Name = "CoilRing"; ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(.12,1.1,1.1); ring.Color = color; ring.Material = Enum.Material.Neon
		ring.CanCollide = false; ring.CanTouch = false; ring.CanQuery = false; ring.Massless = true
		ring.CFrame = root.CFrame * CFrame.new(1.6, -1 + i*.22, -.1) * CFrame.Angles(0,0,math.pi/2)
		ring.Parent = coil
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root; weld.Part1 = ring; weld.Parent = ring
	end
end

local function complete(player)
	local s = sessions[player]
	if not s or s.run.finished then return end
	s.run.stage = 101; s.run.finished = true
	s.run.duration = if s.run.started then workspace:GetServerTimeNow() - s.run.started else 0
	s.pending.Wins += 1; s.pending.Best = 100
	notice(player, "100 STAGES! Your last brain cell is legendary.", "Win")
	view(player)
	task.spawn(function() flush(player); view(player) end)
end

local function advance(player, target)
	local s = sessions[player]
	if not s or s.run.finished then return end
	if target == 101 then complete(player); return end
	s.run.stage = target
	s.pending.Best = math.max(s.pending.Best, target - 1)
	view(player)
	if (target - 1) % 10 == 0 then notice(player, "NEW WORLD! " .. pads[target].Parent.Theme.Value, "World") end
end

local function resetRun(player)
	local s = sessions[player]
	if not s then return end
	s.run = { stage = 1, finished = false, started = nil, lastAdvance = 0 }
	s.boostUntil = 0
	view(player)
end

for _, ob in World:GetDescendants() do
	if ob:IsA("BasePart") then
		local stageValue = ob:FindFirstChild("Stage")
		if stageValue then
			local index = stageValue.Value
			pads[index] = ob
			ob.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				local s = player and sessions[player]
				local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not s or not root or s.run.finished then return end
				if index == 1 and not s.run.started then
					s.run.started = workspace:GetServerTimeNow(); view(player); return
				end
				if not s.run.started or os.clock() - s.run.lastAdvance < .65 then return end
				if Rules.canAdvance(s.run.stage, index, (root.Position - ob.Position).Magnitude) then
					s.run.lastAdvance = os.clock(); advance(player, index)
				end
			end)
		end
		if ob:FindFirstChild("Hazard") then
			ob.Touched:Connect(function(hit)
				local _, hum = playerFromHit(hit)
				if hum then hum.Health = 0 end
			end)
		end
		if ob:FindFirstChild("Spring") then
			local cooldown = setmetatable({}, { __mode = "k" })
			ob.Touched:Connect(function(hit)
				local player, hum = playerFromHit(hit)
				local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and hum and os.clock() - (cooldown[player] or 0) > .7 then
					cooldown[player] = os.clock()
					local v = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 53), v.Z)
				end
			end)
		end
		if ob:FindFirstChild("Conveyor") then
			ob.AssemblyLinearVelocity = ob.CFrame.RightVector * ob.Conveyor.Value
		end
		if ob:FindFirstChild("SpeedBoost") then
			ob.Touched:Connect(function(hit)
				local player = playerFromHit(hit)
				local s = player and sessions[player]
				if not s or (s.boostUntil or 0) > os.clock() + 2.5 then return end
				s.boostUntil = os.clock() + 3
				applyCoil(player)
				task.delay(3,function() if sessions[player] == s then applyCoil(player) end end)
			end)
		end
		if ob:FindFirstChild("Fade") then
			task.spawn(function()
				task.wait(ob.Fade.Value)
				while ob.Parent do
					if not ob.CanCollide and not restoreSurface(ob) then return end
					ob.Transparency = 0; ob.Color = Color3.fromRGB(115,255,199)
					task.wait(3.5)
					ob.Color = Color3.fromRGB(255,199,82)
					task.wait(1.3)
					ob.CanCollide = false; ob.Transparency = .8
					task.wait(1.2)
				end
			end)
		end
		if ob:FindFirstChild("Crumble") then
			local crumbling=false
			local baseColor=ob.Color
			ob.Touched:Connect(function(hit)
				if crumbling or not playerFromHit(hit) then return end
				crumbling=true;ob.Color=Color3.fromRGB(255,190,76)
				task.wait(.75)
				ob.CanCollide=false;ob.Transparency=.9
				task.wait(3.5)
				if restoreSurface(ob) then ob.Transparency=0;ob.Color=baseColor;crumbling=false end
			end)
		end
	end
end
assert(#pads == 101, "Orbit requires all 100 stage starts and the finish pad")

-- Server animates obstacles; the owning client handles grounded platform carry.
local movers = {}
local nextHazardScan = 0
for _, ob in World:GetDescendants() do
	if ob:IsA("BasePart") and (ob:FindFirstChild("Spinner") or ob:FindFirstChild("MoveDistance") or ob:FindFirstChild("Pendulum")) then
		local cable
		if ob:FindFirstChild("Pendulum") then
			for _,child in ob.Parent:GetChildren() do
				if child:FindFirstChild("PendulumCable") and child.PendulumIndex.Value==ob.PendulumIndex.Value then cable=child end
			end
		end
		table.insert(movers, { part = ob, base = ob.CFrame, cable=cable })
	end
end
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	local scanHazards = now >= nextHazardScan
	if scanHazards then nextHazardScan = now + .08 end
	for _, mover in movers do
		local ob = mover.part
		if ob:FindFirstChild("Spinner") then
			ob.CFrame = mover.base * CFrame.Angles(0, now * ob.Spinner.Value, 0)
			-- CFrame-driven anchored hazards cannot rely solely on Touched events.
			if scanHazards then
				for player in sessions do
					local char = player.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					if root and hum and hum.Health > 0 then
						local p = ob.CFrame:PointToObjectSpace(root.Position)
						if math.abs(p.X) < ob.Size.X/2+1 and math.abs(p.Y) < ob.Size.Y/2+2.5 and math.abs(p.Z) < ob.Size.Z/2+1 then
							hum.Health = 0
						end
					end
				end
			end
		elseif ob:FindFirstChild("Pendulum") then
			local pivot=mover.base*CFrame.new(0,15,0)
			ob.CFrame=pivot*CFrame.Angles(0,0,math.sin(now*1.4+ob.Pendulum.Value)*.65)*CFrame.new(0,-15,0)
			if mover.cable then mover.cable.CFrame=CFrame.lookAt((pivot.Position+ob.Position)/2,pivot.Position) end
			if scanHazards then
				for player in sessions do
					local char=player.Character
					local root=char and char:FindFirstChild("HumanoidRootPart")
					local hum=char and char:FindFirstChildOfClass("Humanoid")
					if root and hum and (root.Position-ob.Position).Magnitude<ob.Size.X/2+1.1 then hum.Health=0 end
				end
			end
		else
			local offset=math.sin(now*math.pi*2/ob.MovePeriod.Value)*ob.MoveDistance.Value
			local axis=ob:FindFirstChild("MoveAxis")
			local cf = mover.base * (if axis and axis.Value=="Y" then CFrame.new(0,offset,0) else CFrame.new(0,0,offset))
			-- The owning client applies only its support's translation. Server PivotTo
			-- every Heartbeat fought the player's walking/jumping over the network.
			ob.CFrame = cf
		end
	end
end)

local function loadOwnership(player)
	local s = sessions[player]
	if not s then return end
	for name, product in Config.Products do
		if product.Kind == "Pass" and product.Id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, product.Id)
			if ok and sessions[player] == s then
				-- Ownership unlocks the shop control; joining never auto-equips a pass.
				s.owned[name] = owns == true
				if owns ~= true then s.equipped[name] = false end
			end
		end
	end
	applyCoil(player)
	view(player)
end

local function setupPlayer(player)
	if sessions[player] or loading[player] then return end
	loading[player] = true
	if shuttingDown then player:Kick("Server is closing. Please join another orbit."); return end
	local ok, raw = pcall(function()
		if not Store then error("Save service unavailable") end
		return Store:GetAsync(key(player))
	end)
	if not player.Parent then loading[player] = nil; return end
	local data = Rules.normalize(if ok then raw else nil)
	sessions[player] = { data = data, pending = { Coins = 0, Wins = 0, Best = 0 },
		persistent = ok, saveHealthy = ok, flushing = false, busy = false, equipped = {}, owned = {},
		run = { stage = 1, started = nil, finished = false, lastAdvance = 0 }, tokens = 10, tokenAt = os.clock() }
	loading[player] = nil
	-- Recover a reservation interrupted by a crash/death; no purchase can silently disappear.
	if ok and data.PendingSkip then
		local token = data.PendingSkip
		local recovered = update(player,function(current) return Rules.resolveSkip(current,token,false) end)
		if recovered and sessions[player] then sessions[player].data = recovered end
	end
	if not player.Parent or not sessions[player] then return end
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
	for _, name in { "Stage", "Wins" } do
		local value = Instance.new("IntValue"); value.Name = name; value.Parent = stats
	end
	local function characterAdded(char)
		resetRun(player)
		local hum = char:WaitForChild("Humanoid", 10)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if not hum or not root or not player.Parent then return end
		hum.Died:Connect(function()
			resetRun(player)
			notice(player,"Your brain cell took a vacation. Back to the lobby!", "Death")
		end)
		-- Always original lobby spawn, regardless of prior run progress or skip purchases.
		player.RespawnLocation = nil
		moveTo(player, World.Lobby.OriginalStart)
		applyLook(player); applyCoil(player)
	end
	player.CharacterAdded:Connect(characterAdded)
	player.CharacterAppearanceLoaded:Connect(function(char)
		if player.Character == char then applyLook(player); applyCoil(player) end
	end)
	if player.Character then task.spawn(characterAdded, player.Character) end
	if not ok then
		task.delay(4, function()
			notice(player, "Save service unavailable: session-only progress. Paid purchases are disabled.", "Warning")
		end)
	end
	view(player)
	task.spawn(loadOwnership, player)
end

local function useSkip(player)
	local s = sessions[player]
	if not s or s.run.finished or not s.run.started then notice(player,"Start your run first."); return end
	if not safeFloor(player) then notice(player,"Stand still on a numbered safe island to use a skip."); return end
	local originalRun = s.run
	local originalStage = originalRun.stage
	if s.data.SkipCredits <= 0 then notice(player,"No skip credits available."); return end
	local amount = math.min(10,s.data.SkipCredits,101-originalStage)
	local target = originalStage + amount
	local spent = false
	local token = HttpService:GenerateGUID(false)
	local result = update(player, function(data)
		local updated, didSpend = Rules.reserveSkip(data,token,amount)
		spent = didSpend
		return updated
	end)
	if not result or not spent then notice(player,"Credit could not be used. Try again later.","Warning"); return end
	s.data = result
	if s.run ~= originalRun or s.run.stage ~= originalStage or not moveTo(player,pads[target]) then
		-- A death or disconnect during storage must not destroy the unused purchase.
		local refunded = update(player,function(data) return Rules.resolveSkip(data,token,false) end)
		if refunded then s.data = refunded end
		notice(player,if refunded then "Run changed. Your credit was returned." else "Credit recovery queued. Rejoin when saves are available.","Warning"); view(player); return
	end
	advance(player, target)
	local settled = update(player,function(data) return Rules.resolveSkip(data,token,true) end)
	if settled then s.data = settled end
	notice(player,string.format("Skipped %d stages! Death still resets the entire run.",amount))
	view(player)
end

Action.OnServerEvent:Connect(function(player, action, argument)
	local s = sessions[player]
	if not s or type(action) ~= "string" or #action > 32 then return end
	local now = os.clock()
	s.tokens = math.min(10, s.tokens + (now - s.tokenAt)*2); s.tokenAt = now
	if s.tokens < 1 then return end
	s.tokens -= 1
	if action == "Sync" then view(player); return end
	if s.busy then return end
	if argument ~= nil and (type(argument) ~= "string" or #argument > 40) then return end
	s.busy = true
	local ok, err = pcall(function()
		if action == "Restart" then
			resetRun(player); moveTo(player, World.Lobby.OriginalStart)
		elseif action == "EquipCoil" then
			if argument == "None" then
				s.equipped = {}; applyCoil(player); view(player)
			elseif (argument == "Speed" or argument == "Gravity") and s.owned[argument] then
				s.equipped[argument] = not s.equipped[argument]; applyCoil(player); view(player)
			end
		elseif action == "UseSkip" then
			useSkip(player)
		elseif action == "Settings" then
			if not argument then return end
			local name, value = argument:match("^(%a+):(%a+)$")
			if s.data.Settings[name] == nil or (value ~= "on" and value ~= "off") then return end
			local enabled = value == "on"
			if s.persistent then
				local result = update(player,function(data) data.Settings[name] = enabled; return data end)
				if result then s.data = result else notice(player,"Preference changed locally; could not save it.","Warning") end
			else s.data.Settings[name] = enabled end
		elseif action == "Buy" then
			local product, info = Config.Products[argument], catalogue[argument]
			if not product or not info or not info.Enabled then notice(player,"This optional item is not on sale."); return end
			if not s.persistent or not s.saveHealthy then notice(player,"Purchases disabled until save service is available."); return end
			if product.Kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player,product.Id)
				-- Always request Roblox's official prompt. Existing passes cannot be rebought.
				if s.owned[argument] then
					loadOwnership(player)
					if s.owned[argument] then
						s.equipped[argument] = true; applyCoil(player); view(player)
						notice(player,"Pass already owned: equipped without another charge.")
					end
				end
			elseif argument == "Skip" then
				MarketplaceService:PromptProductPurchase(player,product.Id)
			end
		end
	end)
	s.busy = false
	if not ok then warn("[Orbit] Action failed", action, err); notice(player,"That action could not finish. Please try again.","Warning") end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,id,purchased)
	if not purchased then return end
	for name, product in Config.Products do
		if product.Kind == "Pass" and product.Id == id then
			-- Re-query ownership; the close event does not itself grant inventory.
			task.spawn(function()
				loadOwnership(player)
				local s = sessions[player]
				if s and s.owned[name] then s.equipped[name] = true; applyCoil(player); view(player) end
			end)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(receipt)
	if Config.Products.Skip.Id <= 0 or receipt.ProductId ~= Config.Products.Skip.Id then return IN_FLIGHT end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local s = player and sessions[player]
	if not s or not s.persistent then return IN_FLIGHT end
	local newlyGranted = false
	local result = update(player,function(data)
		local updated, granted = Rules.grantReceipt(data,tostring(receipt.PurchaseId),Config.Products.Skip.Credits)
		newlyGranted = granted
		return updated
	end)
	if not result or not result.Receipts[tostring(receipt.PurchaseId)] then return IN_FLIGHT end
	s.data = result
	view(player)
	if newlyGranted and not s.busy and s.run.started and not s.run.finished and safeFloor(player) then
		s.busy = true
		local ok, err = pcall(useSkip,player)
		s.busy = false
		if not ok then warn("[Orbit] Saved skip awaits manual use",err) end
	elseif newlyGranted then
		notice(player,"10 stage skips saved! Stand on a safe island and press SKIP +10 in the shop.")
	end
	return GRANTED
end

task.spawn(function()
	for name, product in Config.Products do
		catalogue[name] = { Enabled = false, Price = nil }
		if product.Id > 0 then
			local kind = if product.Kind == "Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.Id, kind)
			local saleAllowed=ok and type(info)=="table" and (if product.Kind=="Pass" then info.IsForSale==true else info.IsForSale~=false)
			if saleAllowed and Rules.finite(info.PriceInRobux) and info.PriceInRobux>=0 then
				catalogue[name] = { Enabled = true, Price = info.PriceInRobux }
			end
		end
	end
	for player in sessions do view(player) end
end)

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do task.spawn(setupPlayer,player) end
Players.PlayerRemoving:Connect(function(player)
	flush(player)
	sessions[player] = nil
end)
task.spawn(function()
	while not shuttingDown do
		task.wait(60)
		for player in sessions do task.spawn(function() flush(player); view(player) end) end
	end
end)
game:BindToClose(function()
	shuttingDown = true
	local pending = 0
	for player in sessions do
		pending += 1
		task.spawn(function() flush(player); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(.1) end
end)
