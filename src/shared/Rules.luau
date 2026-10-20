--!strict
-- Engine-independent decisions, exercised directly by the Luau test runner.
local Rules = {}
export type Profile = {
	Version: number, Coins: number, Wins: number, Best: number, SkipCredits: number,
	Skins: {[string]: boolean}, Skin: string, Receipts: {[string]: boolean},
	Settings: {[string]: boolean}, PendingSkip: string?,
}
export type PromotionState = {nextAt: number, queued: boolean, nextKind: string, coil: string}

function Rules.finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Rules.canAdvance(current: number, target: number, distance: number): boolean
	return Rules.finite(target) and target % 1 == 0 and target == current + 1
		and target <= 101 and Rules.finite(distance) and distance <= 17 and distance >= 0
end

function Rules.intersectsRestoringSurface(x: number, y: number, z: number, width: number, height: number, depth: number, feet: number): boolean
	return math.abs(x)<width/2+1.5 and math.abs(z)<depth/2+1.5
		and y-feet<height/2+.15 and y+2.5>-height/2
end

function Rules.newPromotion(now: number): PromotionState
	return { nextAt = now + 50, queued = false, nextKind = "Coil", coil = "Speed" }
end

function Rules.tickPromotion(state: PromotionState, now: number, enabled: boolean, safe: boolean, busy: boolean): string?
	if not enabled then
		state.queued = false
		state.nextAt = now + 50
		return nil
	end
	if now >= state.nextAt then
		state.queued = true
		state.nextAt = now + 50
	end
	if not state.queued or not safe or busy then return nil end
	state.queued = false
	if state.nextKind == "Coil" then
		state.nextKind = "Skip"
		local result = state.coil
		state.coil = if state.coil == "Speed" then "Gravity" else "Speed"
		return result
	end
	state.nextKind = "Coil"
	return "Skip"
end

function Rules.newProfile(): Profile
	return { Version = 1, Coins = 0, Wins = 0, Best = 0, SkipCredits = 0,
		Skins = { Classic = true }, Skin = "Classic", Receipts = {},
		Settings = { Music = true, SFX = true, Promotions = true, ReducedMotion = false } }
end

function Rules.normalize(raw: any): Profile
	if type(raw) ~= "table" then return Rules.newProfile() end
	local clean = Rules.newProfile()
	local function counter(value: any): number
		return if Rules.finite(value) then math.max(0,math.floor(value)) else 0
	end
	clean.Coins = counter(raw.Coins)
	clean.Wins = counter(raw.Wins)
	clean.Best = counter(raw.Best)
	clean.SkipCredits = counter(raw.SkipCredits)
	clean.Best = math.min(100, clean.Best)
	if type(raw.Skins) == "table" then
		for key, value in raw.Skins do
			if type(key) == "string" and value == true then clean.Skins[key] = true end
		end
	end
	if type(raw.Skin) == "string" and clean.Skins[raw.Skin] then clean.Skin = raw.Skin end
	if type(raw.Receipts) == "table" then
		for key, value in raw.Receipts do
			if type(key) == "string" and value == true then clean.Receipts[key] = true end
		end
	end
	if type(raw.Settings) == "table" then
		for key in clean.Settings do
			if type(raw.Settings[key]) == "boolean" then clean.Settings[key] = raw.Settings[key] end
		end
	end
	if type(raw.PendingSkip) == "string" then clean.PendingSkip = raw.PendingSkip end
	return clean
end

function Rules.grantReceipt(raw: any, purchaseId: string, quantity: number?): (Profile?, boolean)
	local data = Rules.normalize(raw)
	if data.Receipts[purchaseId] then return data, false end
	local credits=quantity or 1
	if not Rules.finite(credits) or credits%1~=0 or credits<1 or credits>100 then return nil,false end
	-- Fail closed instead of dropping old receipt IDs and granting replayed purchases.
	local count = 0
	for _ in data.Receipts do count += 1 end
	if count >= 4000 then return nil, false end
	data.Receipts[purchaseId] = true
	data.SkipCredits += credits
	return data, true
end

function Rules.spendCredit(raw: any): (Profile, boolean)
	local data = Rules.normalize(raw)
	if data.SkipCredits < 1 then return data, false end
	data.SkipCredits -= 1
	return data, true
end

function Rules.reserveSkip(raw: any, token: string): (Profile, boolean)
	local data = Rules.normalize(raw)
	if data.PendingSkip or data.SkipCredits < 1 then return data, false end
	data.SkipCredits -= 1
	data.PendingSkip = token
	return data, true
end

function Rules.resolveSkip(raw: any, token: string, delivered: boolean): Profile
	local data = Rules.normalize(raw)
	if data.PendingSkip ~= token then return data end
	if not delivered then data.SkipCredits += 1 end
	data.PendingSkip = nil
	return data
end

function Rules.flush(raw: any, delta: {Coins: number?, Wins: number?, Best: number?}): Profile
	local data = Rules.normalize(raw)
	data.Coins += math.max(0, delta.Coins or 0)
	data.Wins += math.max(0, delta.Wins or 0)
	data.Best = math.max(data.Best, math.min(100, delta.Best or 0))
	return data
end

function Rules.buySkin(raw: any, id: string, cost: number): (Profile, boolean)
	local data = Rules.normalize(raw)
	if data.Skins[id] then data.Skin = id; return data, true end
	if not Rules.finite(cost) or cost < 0 or cost % 1 ~= 0 or data.Coins < cost then return data, false end
	data.Coins -= cost
	data.Skins[id] = true
	data.Skin = id
	return data, true
end

return Rules
