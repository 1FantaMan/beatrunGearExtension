local lastLevel = 1

if not game.IsDedicated() then

	local function SendLevel()
		local level = LocalPlayer():GetLevel()
		if level == lastLevel then return end
		lastLevel = level

		net.Start("BeatrunGearsClientLevel")
		net.WriteInt(level, 16)
		net.SendToServer()
	end

	hook.Add("InitPostEntity", "BeatrunGearsOnPlayerSpawn", function()
		-- lastLevel starts at 1, so this sends immediately if the real level differs - otherwise the server
		-- stays on the default 1 until the timer's first tick (4s later), racing any level-gated action in between
		SendLevel()
		timer.Create("BeatrunGearsLevelChangeLoop", 4, 0, SendLevel)
	end)

end
