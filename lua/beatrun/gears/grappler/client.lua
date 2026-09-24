include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
local crosshairProjected = include("beatrun/gears/grappler/visuals/crosshairProjected.lua")
local util = include("beatrun/sh/util.lua")

local shared = include("beatrun/gears/grappler/shared.lua")

local mod = {}

-- own copy of shared.lua's UpdateHookTracking freeze/reacquire logic, kept independent and driven by
-- HUDPaint instead of onSetupMove - onSetupMove never runs client-side in true singleplayer, so a version
-- that depended on it would never update the crosshair when testing solo
local trackedHitPos

function mod.GetHookPosition(ply)
	local startPos = ply:EyePos()
	local direction = ply:EyeAngles():Forward()
	local trace = shared.ComputeGrapplerRaycast(ply, startPos, direction, mod.config)

	if shared.IsBlockedTrace(trace) then
		trace = nil
	end

	if trace then
		trackedHitPos = trace.HitPos
		return trackedHitPos, true
	end

	if trackedHitPos then
		local endPos = startPos + direction * mod.config.max_range
		local dist = select(1, _G.util.DistanceToLine(startPos, endPos, trackedHitPos))

		if dist <= mod.config.reacquire_tolerance then
			return trackedHitPos, true
		end
	end

	trackedHitPos = nil

	return startPos + direction * mod.config.max_range, false
end

crosshairProjected.Init(mod)

util.RegisterSafeAnim("grapple_throw", {
	model = "beatrun/gears/grappler/anims/grappler_arms",
})

local pullData = {
	model = "beatrun/gears/grappler/anims/grappler_arms",
	fallbackEvent = false,
	transitioncheck = function(ply)
		return BodyAnimCycle >= 0.25 -- goes around frame 17-19 of the anim
	end,
}

util.RegisterSafeAnim("grapple_pull", pullData)
util.RegisterSafeAnim("grapple_pull_air", pullData) -- this is the fullbody anim, just only works for air :)

function mod.init(ply)
	return shared.GetStates(mod.config)
end

function mod.destroy(ply, state)
end

return mod
