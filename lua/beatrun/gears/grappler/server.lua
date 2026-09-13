local util = include("beatrun/sh/util.lua")
local shared = include("beatrun/gears/grappler/shared.lua")

local mod = {}
local usesRefill = util.usesRefill.New(mod, "usesRemaining")

function mod.init(ply)
	local state = shared.GetStates(mod.config)
	usesRefill.Broadcast(ply, state)
	return state
end

function mod.onParkour(ply, state, action)
	usesRefill.OnParkour(ply, state, action)
end

function mod.onTick(ply, state)
	usesRefill.OnTick(ply, state)
end

function mod.destroy(ply, state)
	state.phase = "idle"
	ply:SetNW2Bool("brgear_grapple_active", false)
end

return mod
