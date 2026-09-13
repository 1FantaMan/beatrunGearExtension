local util = include("beatrun/sh/util.lua")
local shared = include("beatrun/gears/thruster/shared.lua")

local mod = {}

local usesRefill = util.usesRefill.New(mod, "uses")

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
end

function mod.OnPlayerSpawn(ply)
	local state = GetState(ply, "leg")
	if not state then return end

	state.uses = mod.config.max_uses
	state.lastUsed = CurTime()
	state.airStartTime = 0
	state.wasOnGround = true
	usesRefill.Broadcast(ply, state)
end

hook.Add("PlayerSpawn", "BeatrunGears_Thruster", mod.OnPlayerSpawn)

return mod
