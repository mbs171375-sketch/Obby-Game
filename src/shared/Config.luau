--!strict
-- Public catalogue IDs supplied by the experience creator. Prices come from Roblox.
return {
	Title = "BRAINROT ORBIT",
	StageCount = 100,
	PromotionInterval = 50,
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
	SpeedCoilSpeed = 32,
	GravityCoilJump = 80,
	DataStoreName = "BrainrotOrbit_v1",
	Products = {
		Speed = { Id = 2038121195, Kind = "Pass", Name = "Speed Coil", Benefit = "Double your running speed; works with Jump Boot", Color = {255, 208, 68} },
		Gravity = { Id = 2041634630, Kind = "Pass", Name = "Jump Boot", Benefit = "Higher jumps; works with Speed Coil", Color = {157, 117, 255} },
		Skip = { Id = 3720254856, Kind = "Product", Credits = 10, Name = "10 Stage Skips", Benefit = "Move forward up to 10 stages at once", Color = {63, 237, 213} },
	},
	Skins = {
		{ Id = "Classic", Name = "Orbit Explorer", Cost = 0, Color = {100, 211, 255} },
		{ Id = "Toast", Name = "Toast Goblin", Cost = 30, Color = {255, 190, 102} },
		{ Id = "Frog", Name = "Froggy Frequency", Cost = 60, Color = {125, 255, 146} },
		{ Id = "Goose", Name = "Galaxy Goose", Cost = 100, Color = {238, 235, 255} },
		{ Id = "Cosmic", Name = "Cosmic Dumpling", Cost = 160, Color = {255, 118, 224} },
	},
	-- Requested Brainrot Rap audio. The Roblox experience must have permission to play it.
	MusicTracks = {134764779929866},
	MusicBPM = 132,
	-- Reference identifying the requested recording; this URL is not used for playback.
	RequestedMusicReference = "https://www.youtube.com/watch?v=T_NKi5KHUdI",
}
