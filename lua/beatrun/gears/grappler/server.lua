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

function mod.OnPlayerSpawn(ply)
	local state = GetState(ply, "left")
	if not state then return end

	-- respawning (e.g. via a dev "kill/respawn" bind) doesn't tear down the gear like unequip does,
	-- so a mid-grapple respawn otherwise leaves brgear_grapple_active stuck true on the new life
	state.phase = "idle"
	state.usesRemaining = mod.config.max_uses
	state.targetPos = nil
	state.arrivalTime = 0
	state.pullDelay = 0
	state.boostTime = 0
	state.waitingForLanding = false

	ply:SetNW2Bool("brgear_grapple_active", false)
	usesRefill.Broadcast(ply, state)
end

hook.Add("PlayerSpawn", "BeatrunGears_Grappler", mod.OnPlayerSpawn)

return mod
