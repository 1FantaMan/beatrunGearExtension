local gearSlots = include("beatrun/sh/gearSlots.lua")
local keybinds = include("beatrun/sh/modules.lua").Get("gearKeybinds")
local gearsHandler = include("beatrun/sh/modules.lua").Get("gearsHandler")

local keyStates = {}

local function OnThink()
	for slotName, slotInfo in pairs(gearSlots.SLOTS) do
		if not slotInfo.active then continue end

		local isDown = input.IsButtonDown(keybinds.Get(slotName, slotInfo.defaultKey))
		local pressed = isDown and not keyStates[slotName]
		local released = keyStates[slotName] and not isDown
		keyStates[slotName] = isDown

		if pressed then
			net.Start("BeatrunGearsKeyPress")
			net.WriteString(slotName)
			net.SendToServer()

			local entry = BeatrunGearsClientGears[slotName]
			if entry and entry ~= "" then
				local gear = gearsHandler.GetClientGear(entry.name)

				if gear and gear.activate then
					local cooldown = gear.config.cooldown or 0
					local offCooldown = (CurTime() - (entry.lastActivateTime or 0)) >= cooldown
					local allowed = offCooldown and
						(not gear.canActivate or gear.canActivate(LocalPlayer(), entry.state))

					if allowed then
						if gear.PreparePredictedShared then
							gear.PreparePredictedShared(LocalPlayer(), entry.state)
						end

						gear.activate(LocalPlayer(), entry.state)
						entry.lastActivateTime = CurTime()
						entry.lastPredictedActivate = CurTime()
					end
				end
			end
		end

		if released then
			net.Start("BeatrunGearsKeyRelease")
			net.WriteString(slotName)
			net.SendToServer()
		end
	end
end

hook.Add("Think", "BeatrunGearsThink", OnThink)
