local shared = include("beatrun/gears/wingsuit/shared.lua")

local mod = {}

function mod.init(ply)
	return shared.GetStates(mod.config)
end

function mod.onTick(ply, state)
	if not state.isGliding and ply:IsOnGround() then
		state.glidePower = mod.config.glide_power_max
	end

	ply:SetNW2Float("brgear_wingsuit_glidepower", state.glidePower)
	ply:SetNW2Bool("brgear_wingsuit_gliding", state.isGliding)
end

function mod.destroy(ply, state)
	state.glidePower = mod.config.glide_power_max
	shared.SetGliding(ply, state, false)
end

function mod.onPlayerSpawn(ply)
	local state = GetState(ply, "back")
	if not state then return end

	state.glidePower = mod.config.glide_power_max
	state.lastUsed = CurTime()
	shared.SetGliding(ply, state, false)
end

hook.Add("PlayerSpawn", "BeatrunGears_wingsuit", mod.onPlayerSpawn)

return mod
