-- Lune's rbx-dom reader validates the generated Roblox XML and binary round-trip.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local root = roblox.deserializePlace(fs.readFile("dist/BrainrotOrbit.rbxlx"))
local checks = 0
local function expect(value,message) checks+=1;assert(value,message) end
local world = root:GetService("Workspace"):FindFirstChild("OrbitWorld")
expect(world~=nil,"world exists")
expect(#world.Stages:GetChildren()==100,"all 100 stages deserialize")
expect(world.Lobby.OriginalStart:IsA("SpawnLocation"),"original lobby spawn")
local spawns,scripts,parts=0,0,0
for _,ob in root:GetDescendants() do
	if ob:IsA("SpawnLocation") then spawns+=1 end
	if ob:IsA("BasePart") then parts+=1;expect(ob.Anchored,"static map part anchored") end
	if ob:IsA("LuaSourceContainer") then scripts+=1;expect(#ob.Source>0,"script sources embedded") end
end
expect(spawns==1,"exactly one spawn; no respawn checkpoints")
expect(scripts==4,"shared modules, server and client embedded")
for i=1,100 do
	local stage=world.Stages:FindFirstChild(string.format("Stage%03d",i))
	expect(stage~=nil,"stage exists")
	expect(stage.SafePad.Stage.Value==i,"numbered safe pad")
	expect(stage.SafePad.Safe.Value,"safe pad marker")
	expect(stage.SafePad.Color.R>0,"colours survive deserialization")
end
expect(world.VictoryIsland.FinishPad.Stage.Value==101,"finish marker")
expect(world.VictoryIsland.FinishPad.CFrame.Position.Z>world.VictoryIsland.ArrivalPad.CFrame.Position.Z+20,"win trigger is inside Tung's mouth, not on arrival")
expect(world.VictoryIsland.TungMouth:FindFirstChild("Tongue walkway").CanCollide,"tongue is a solid route into the mouth")
expect(root:GetService("ReplicatedStorage").OrbitRemotes.Action:IsA("RemoteEvent"),"action remote exists")
expect(root:GetService("StarterPlayer").StarterPlayerScripts.OrbitClient:IsA("LocalScript"),"client placement")
local binary=roblox.serializePlace(root)
fs.writeFile("dist/BrainrotOrbit.rbxl",binary)
local restored=roblox.deserializePlace(binary)
expect(#restored:GetService("Workspace").OrbitWorld.Stages:GetChildren()==100,"binary round-trip")
expect(restored:GetService("ServerScriptService").OrbitServer.Source==root:GetService("ServerScriptService").OrbitServer.Source,"script round-trip")
print(string.format("PASS: %d Roblox serialization assertions; %d parts; XML and binary places written",checks,parts))
