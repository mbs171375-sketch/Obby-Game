-- Execute the production server script against deterministic service doubles.
-- This tests event wiring and persistence boundaries, not Roblox physics or live APIs.
local fs=require("@lune/fs")
local roblox=require("@lune/roblox")
local BaseConfig=require("../src/shared/Config")
local Rules=require("../src/shared/Rules")
return function(options)
options=options or {}
local Config=table.clone(BaseConfig)
Config.Products={}
for name,product in BaseConfig.Products do Config.Products[name]=table.clone(product) end
if not options.defaultProducts then
 Config.Products.Speed.Id=101;Config.Products.Gravity.Id=202;Config.Products.Skip.Id=303
end
local V,C=roblox.Vector3,roblox.CFrame
local now,timers,errors=10,{},{}
local taskMock={}
local function resume(thread,...)
	local ok,delay=coroutine.resume(thread,...)
	if not ok then table.insert(errors,tostring(delay));return end
	if coroutine.status(thread)~="dead" then table.insert(timers,{at=now+(delay or .01),thread=thread}) end
end
function taskMock.spawn(fn,...) local co=coroutine.create(fn);resume(co,...);return co end
function taskMock.wait(seconds) return coroutine.yield(seconds or .01) end
function taskMock.delay(seconds,fn,...) local args={...};table.insert(timers,{at=now+seconds,thread=coroutine.create(function() fn(table.unpack(args)) end)}) end
local function step(seconds)
	local target=now+seconds
	local iterations=0
	while true do
		local best,index=nil,nil
		for i,timer in timers do if timer.at<=target and (not best or timer.at<best.at) then best=timer;index=i end end
		if not best then break end
		table.remove(timers,index);now=best.at;resume(best.thread);iterations+=1
		assert(iterations<100000,"scheduler runaway")
	end
	now=target
end
local function signal()
	local result={listeners={}}
	function result:Connect(fn) table.insert(self.listeners,fn);return {Disconnect=function() end} end
	function result:Fire(...) for _,fn in table.clone(self.listeners) do taskMock.spawn(fn,...) end end
	return result
end

local Methods={}
local Obj={}
Obj.__index=function(self,key)
	if Methods[key] then return Methods[key] end
	if key=="Position" and self._props.CFrame then return self._props.CFrame.Position end
	if self._props[key]~=nil then return self._props[key] end
	for _,child in self._children do if child.Name==key then return child end end
	return nil
end
Obj.__newindex=function(self,key,value)
	if key=="Parent" then
		local old=self._props.Parent
		if old then for i,child in old._children do if child==self then table.remove(old._children,i);break end end end
		if value then table.insert(value._children,self) end
	end
	self._props[key]=value
end
local function new(cls)
	local ob=setmetatable({_props={ClassName=cls,Name=cls},_children={}},Obj)
	if cls=="Part" or cls=="SpawnLocation" then
		ob.CFrame=C.new();ob.Size=V.new(2,1,2);ob.AssemblyLinearVelocity=V.zero;ob.AssemblyAngularVelocity=V.zero;ob.Touched=signal()
	end
	if cls=="RemoteEvent" then ob.OnServerEvent=signal();ob.messages={} end
	if cls=="Player" then ob.CharacterAdded=signal();ob.CharacterAppearanceLoaded=signal() end
	if cls=="ProximityPrompt" then ob.Triggered=signal() end
	return ob
end
function Methods:IsA(cls)
	return self.ClassName==cls or cls=="Instance" or (cls=="BasePart" and (self.ClassName=="Part" or self.ClassName=="SpawnLocation"))
		or (cls=="GuiObject" and table.find({"Frame","ScrollingFrame","TextLabel","TextButton"},self.ClassName)~=nil)
end
function Methods:GetChildren() return table.clone(self._children) end
function Methods:GetDescendants()
	local list={}
	local function visit(ob) for _,child in ob._children do table.insert(list,child);visit(child) end end
	visit(self);return list
end
function Methods:FindFirstChild(name) for _,ob in self._children do if ob.Name==name then return ob end end;return nil end
function Methods:WaitForChild(name) return assert(self:FindFirstChild(name),"Missing instance "..name.." in "..self.Name) end
function Methods:FindFirstChildOfClass(cls) for _,ob in self._children do if ob:IsA(cls) then return ob end end;return nil end
function Methods:FindFirstAncestorOfClass(cls) local parent=self.Parent;while parent do if parent:IsA(cls) then return parent end;parent=parent.Parent end;return nil end
function Methods:Destroy() self.Parent=nil end
function Methods:Clone()
	local copy=new(self.ClassName)
	for key,value in self._props do if key~="Parent" then copy[key]=value end end
	return copy
end
function Methods:PivotTo(cf)
	if self.HumanoidRootPart then self.HumanoidRootPart.CFrame=cf;return end
	local delta=cf*self:GetPivot():Inverse()
	for _,ob in self:GetDescendants() do if ob:IsA("BasePart") then ob.CFrame=delta*ob.CFrame end end
	self.Pivot=cf
end
function Methods:GetPivot()
	if self.HumanoidRootPart then return self.HumanoidRootPart.CFrame end
	if self.Pivot then return self.Pivot end
	for _,ob in self:GetDescendants() do if ob:IsA("BasePart") then return ob.CFrame end end
	return C.new()
end
function Methods:FireClient(player,...) table.insert(self.messages,{player=player,args={...}}) end

local decoded=roblox.deserializePlace(fs.readFile("dist/BrainrotOrbit.rbxlx"))
local function import(real)
	local ob=new(real.ClassName);ob.Name=real.Name
	if real:IsA("ValueBase") then ob.Value=real.Value end
	if real:IsA("BasePart") then
		ob.CFrame=real.CFrame;ob.Size=real.Size;ob.Anchored=real.Anchored;ob.Color=real.Color;ob.CanCollide=real.CanCollide
	end
	for _,child in real:GetChildren() do import(child).Parent=ob end
	return ob
end
local scene=import(decoded)
local services={}
for _,ob in scene:GetChildren() do services[ob.Name]=ob end
local workspace=services.Workspace
function workspace:GetServerTimeNow() return now end
local floor=nil
function workspace:Raycast() return if floor then {Instance=floor} else nil end
local playerService=new("Players");services.Players=playerService
playerService.PlayerAdded=signal();playerService.PlayerRemoving=signal()
local playerList={}
function playerService:GetPlayers() return table.clone(playerList) end
function playerService:GetPlayerByUserId(id) for _,p in playerList do if p.UserId==id then return p end end;return nil end
function playerService:GetPlayerFromCharacter(char) for _,p in playerList do if p.Character==char then return p end end;return nil end
local storage={records={},fail=false}
function storage:GetAsync(key) if self.fail then error("simulated storage failure") end;return self.records[key] end
function storage:UpdateAsync(key,fn)
	if self.fail then error("simulated storage failure") end
	local value=fn(self.records[key]);if value~=nil then self.records[key]=value end;return value
end
services.DataStoreService={GetDataStore=function() if options.storeUnavailable then error("unpublished place") end;return storage end}
local market={PromptGamePassPurchaseFinished=signal(),prompts={},owns={}}
function market:GetProductInfo() return {PriceInRobux=25,IsForSale=true} end
function market:GetProductInfoAsync() return {PriceInRobux=20,IsForSale=true} end
function market:UserOwnsGamePassAsync(user,id) return self.owns[tostring(user)..":"..id] or false end
function market:PromptGamePassPurchase(player,id) table.insert(self.prompts,{kind="Pass",id=id,player=player}) end
function market:PromptProductPurchase(player,id) table.insert(self.prompts,{kind="Product",id=id,player=player}) end
services.MarketplaceService=market
services.RunService={Heartbeat=signal()}
services.TweenService={}
local guid=0
services.HttpService={GenerateGUID=function() guid+=1;return "token-"..guid end}
local mockGame={}
function mockGame:GetService(name) return assert(services[name],"Unknown service "..name) end
function mockGame:BindToClose(fn) self.close=fn end
local function enumGroup(names) local out={};for _,name in names do out[name]=name end;return out end
local enums={
	ProductPurchaseDecision=enumGroup({"NotProcessedYet","PurchaseGranted"}),
	RaycastFilterType=enumGroup({"Exclude"}),PartType=enumGroup({"Ball","Cylinder"}),
	Material=enumGroup({"Neon"}),InfoType=enumGroup({"GamePass","Product"}),
}
local env=setmetatable({game=mockGame,workspace=workspace,task=taskMock,Instance={new=new},
	Vector3=V,CFrame=C,Enum=enums,Color3=roblox.Color3,ColorSequence=roblox.ColorSequence,
	NumberSequence=roblox.NumberSequence,NumberSequenceKeypoint=roblox.NumberSequenceKeypoint,
	RaycastParams={new=function() return {} end},os={clock=function() return now end},
	warn=function(...) end,
	require=function(module) if module.Name=="Config" then return Config elseif module.Name=="Rules" then return Rules end;error("Unexpected module") end,
},{__index=getfenv()})
local code=assert(loadstring(fs.readFile("src/server/Game.server.luau"),"OrbitServer"))
setfenv(code,env);code()

local function addPlayer(id)
	local p=new("Player");p.UserId=id;p.Name="Tester"..id;p.Parent=scene
	local char=new("Model");char.Name=p.Name;char.Parent=workspace;p.Character=char
	local root=new("Part");root.Name="HumanoidRootPart";root.Size=V.new(2,2,1);root.Parent=char
	local hum=new("Humanoid");hum.Name="Humanoid";hum.Health=100;hum.HipHeight=2;hum.Died=signal();hum.Parent=char
	local head=new("Part");head.Name="Head";head.Parent=char
	local colors=new("BodyColors");colors.Name="BodyColors"
	for _,property in {"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"} do colors[property]=roblox.Color3.fromRGB(180,180,180) end
	colors.Parent=char
	table.insert(playerList,p);playerService.PlayerAdded:Fire(p)
	return p
end
local world=workspace.OrbitWorld
local action=services.ReplicatedStorage.OrbitRemotes.Action.OnServerEvent
local stateRemote=services.ReplicatedStorage.OrbitRemotes.State
local function state(player)
	for i=#stateRemote.messages,1,-1 do if stateRemote.messages[i].player==player then return stateRemote.messages[i].args[1] end end
	error("No player state")
end
local function touch(player,index)
	local pad=if index==101 then world.VictoryIsland.FinishPad else world.Stages:FindFirstChild(string.format("Stage%03d",index)).SafePad
	player.Character.HumanoidRootPart.CFrame=pad.CFrame+V.new(0,3,0)
	floor=pad;pad.Touched:Fire(player.Character.HumanoidRootPart)
end

return {new=new,Methods=Methods,services=services,workspace=workspace,scene=scene,market=market,
 step=step,signal=signal,task=taskMock,errors=errors,env=env,addPlayer=addPlayer,touch=touch,
 setFloor=function(value) floor=value end,now=function() return now end,state=state,
 storage=storage,action=action,world=world,Config=Config}
end
