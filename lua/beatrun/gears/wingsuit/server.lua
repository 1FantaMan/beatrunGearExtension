local modules = include("beatrun/sh/modules.lua")
local sound = modules.Get("sound")

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

local function canGlide(ply, state, mode)
	state.isGliding = mode
	ply:SetGravity(0)
	state.shared.isDiving = mode
end

local function playAction(ply, mode)
	ParkourEvent((mode and "wingsuit_glidestart") or "wingsuit_glideend", ply, true)
end

function mod.init(ply)
	return {
		isGliding = false,
		glidePower = mod.config.glide_power_max,

		lastUsed = 0,

		shared = {
			isDiving = false
		}
	}
end

function mod.activate(ply, state)
	if state.isGliding then
		canGlide(ply, state, false)
		return
	end

	if ply:IsOnGround() then
		return false
	end

	if state.glidePower <= 0 then
		return false
	end

	if (CurTime() - state.lastUsed) <= mod.config.endlag then
		return false
	end

	sound.Play(ply, mod.config.glide_sound)

	state.lastUsed = CurTime()
	canGlide(ply, state, true)
	playAction(ply, true)
end

function mod.onSetupMove(ply, mv, state)
	if not state.isGliding then
		return
	end

	local look = ply:EyeAngles()

	if look.pitch <= -mod.config.glide_cancel_pitch then
		canGlide(ply, state, false)
		playAction(ply, false)
		return
	end

	local vel = mv:GetVelocity()
	local speed = vel:Length()

	local speedFrac = math.Clamp(speed / mod.config.glide_gravity_speed, 0, 1) -- 600 = speed for "full glide" gravity
	local gravityScale = Lerp(speedFrac, 1, mod.config.glide_gravity_scale)  -- low speed -> normal gravity, high speed -> floaty
	ply:SetGravity(gravityScale)

	if speed > 0 then
		local currentDir = vel / speed
		local lookDir = look:Forward()
		local newDir = LerpVector(mod.config.glide_turn_rate * FrameTime(), currentDir, lookDir)
		vel = newDir * speed
	end

	local pitchFactor = look.pitch / 90
	vel = vel + look:Forward() * pitchFactor * mod.config.glide_thrust * FrameTime()

	local drainRate = mod.config.glide_drain_rate + vel:Length() * mod.config.glide_drain_speedscale
	state.glidePower = state.glidePower - drainRate * FrameTime()

	if state.glidePower <= 0 then
		state.glidePower = 0
		canGlide(ply, state, false)
		playAction(ply, false)
		return
	end

	mv:SetVelocity(vel)
end

function mod.onParkour(ply, state, action)
	if table.HasValue(mod.parkourevents_flags.cancel, action) then
		canGlide(ply, state, false)
	end

	if table.HasValue(mod.parkourevents_flags.glidepower_reset, action) then
		state.glidePower = mod.config.glide_power_max
	end
end

function mod.onTick(ply, state)
	if not state.isGliding and ply:IsOnGround() then
		state.glidePower = mod.config.glide_power_max
	end

	ply:SetNW2Float("brgear_fins_glidepower", state.glidePower)
	ply:SetNW2Bool("brgear_fins_gliding", state.isGliding)
end

function mod.destroy(ply, state)
	state.glidePower = mod.config.glide_power_max
	canGlide(ply, state, false)
end

function mod.onPlayerSpawn(ply)
	local state = GetState(ply, "back")
	if not state then return end

	state.glidePower = mod.config.glide_power_max
	state.lastUsed = CurTime()
	canGlide(ply, state, false)
end

hook.Add("PlayerSpawn", "BeatrunGears_fins", mod.onPlayerSpawn)

return mod
