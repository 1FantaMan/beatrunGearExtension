local util = include("beatrun/sh/util.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")
local sound = util.sound
local isParkouring = util.isParkouring

local mod = {}

mod.parkourevents_flags = {
	glidepower_reset = {
		"land",
		"hangfoldedstart",
		"slide", "slide45", "diveslideend", "jumpslide",
		"landcoil",
		"ziplinestart",
	},
	cancel = {
		"land",
		"hangfoldedstart",
		"jump", "jumpfar", "jumpstill",
		"slide", "slide45", "diveslideend", "jumpslide",
		"wallrunv", "wallrunh",
		"vault", "vaulthigh", "vaultkong", "springboard", "stepup",
		"swingbar",
		"coil", "landcoil",
		"ziplinestart",
	},
}

function mod.GetStates(config)
	return {
		isGliding = false,
		glidePower = config.glide_power_max,
		lastUsed = 0,
	}
end

function mod.SetGliding(ply, state, mode)
	state.isGliding = mode
	ply:SetGravity(0)
end

local function playAction(ply, mode)
	ParkourEvent((mode and "wingsuit_glidestart") or "wingsuit_glideend", ply, true)

	if mode then
		ParkourEvent("divestart", ply, true)
	end
end

function mod.onSetupMove(ply, mv, state)
	local config = mod.config

	if CLIENT and state.isGliding and not ply:GetNW2Bool("brgear_wingsuit_gliding", false) then
		mod.SetGliding(ply, state, false)
	end

	if mv:KeyPressed(gearSlots.SLOTS.back.bit) then
		if isParkouring(ply) then return end

		if state.isGliding then
			mod.SetGliding(ply, state, false)
			playAction(ply, false)
		elseif not ply:IsOnGround() and state.glidePower > 0 and (CurTime() - state.lastUsed) > config.endlag then
			if SERVER then
				sound.Play(ply, config.glide_sound)
			end

			state.lastUsed = CurTime()
			mod.SetGliding(ply, state, true)
			playAction(ply, true)
		end
	end

	if not state.isGliding then return end

	local look = ply:EyeAngles()

	if look.pitch <= -config.glide_cancel_pitch then
		mod.SetGliding(ply, state, false)
		playAction(ply, false)
		return
	end

	local vel = mv:GetVelocity()
	local speed = vel:Length()

	local speedFrac = math.Clamp(speed / config.glide_gravity_speed, 0, 1)
	local gravityScale = Lerp(speedFrac, 1, config.glide_gravity_scale) -- low speed -> normal gravity, high speed -> floaty
	ply:SetGravity(gravityScale)

	if speed > 0 then
		local currentDir = vel / speed
		local lookDir = look:Forward()
		local newDir = LerpVector(config.glide_turn_rate * FrameTime(), currentDir, lookDir)
		vel = newDir * speed
	end

	local pitchFactor = look.pitch / 90
	vel = vel + look:Forward() * pitchFactor * config.glide_thrust * FrameTime()

	local drainRate = config.glide_drain_rate + vel:Length() * config.glide_drain_speedscale
	state.glidePower = state.glidePower - drainRate * FrameTime()

	if state.glidePower <= 0 then
		state.glidePower = 0
		mod.SetGliding(ply, state, false)
		playAction(ply, false)
		return
	end

	mv:SetVelocity(vel)
end

function mod.onParkour(ply, state, action)
	if table.HasValue(mod.parkourevents_flags.cancel, action) then
		mod.SetGliding(ply, state, false)
	end

	if table.HasValue(mod.parkourevents_flags.glidepower_reset, action) then
		state.glidePower = mod.config.glide_power_max
	end
end

return mod
