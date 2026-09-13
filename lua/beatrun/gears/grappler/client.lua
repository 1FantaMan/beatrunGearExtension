include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
local crosshairProjected = include("beatrun/gears/grappler/visuals/crosshairProjected.lua")
local util = include("beatrun/sh/util.lua")

local shared = include("beatrun/gears/grappler/shared.lua")

local mod = {}

function mod.GetHookPosition(ply)
	local startPos = ply:EyePos()
	local dir = ply:EyeAngles():Forward()

	local trace = shared.ComputeGrapplerRaycast(ply, startPos, dir, mod.config)

	if trace then
		return trace.HitPos, true
	end

	return startPos + dir * mod.config.max_range, false
end

crosshairProjected.Init(mod)

util.RegisterSafeAnim("grapple_throw", {
	model = "beatrun/gears/grappler/anims/grappler_arms",
})

-- fraction of the pull sequence's full length to play before cutting back to idle; tune by feel
local PULL_TRANSITION_CYCLE = 0.25

local pullData = {
	model = "beatrun/gears/grappler/anims/grappler_arms",
	fallbackEvent = false, -- "jumpstill" is a floating pose; go straight back to normal idle/walk instead
	transitioncheck = function(ply)
		return BodyAnimCycle >= PULL_TRANSITION_CYCLE
	end,
}

-- grounded pull keeps the old arms-only anim; the fullbody one's leg motion looks like floating while grounded
util.RegisterSafeAnim("grapple_pull", pullData)
util.RegisterSafeAnim("grapple_pull_air", pullData)

function mod.init(ply)
	return shared.GetStates(mod.config)
end

function mod.destroy(ply, state)
end

return mod
