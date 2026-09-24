local util = include("beatrun/sh/util.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")
local isParkouring = util.isParkouring
local sound = util.sound

local mod = {}

local usesRefill = util.usesRefill.New(mod, "uses")

-- EXPERIMENT (ease-in dash velocity): tune/remove this if it doesn't feel right; REVERT by deleting this constant too
local DASH_EASE_DURATION = 0.08

function mod.GetStates(config)
	return {
		uses = config.max_uses,
		lastUsed = CurTime(),
		airStartTime = 0,
		wasOnGround = true,
		dashing = false,
		shared = {},
	}
end

function mod.ComputeDashVelocity(ply, vel, look, config)
	local speed = vel:Length()
	local dashSpeed = speed + config.dash_speed
	local fallSpeed = -vel.z

	-- how much of the upward boost applies - falls off at high fall speed so dashing can't cancel real fall damage
	local boostPenalty = 1
	if fallSpeed > config.fall_damage_threshold then
		local excess = fallSpeed - config.fall_damage_threshold
		boostPenalty = math.max(config.min_fall_boost_penalty, 1 - excess * config.fall_boost_penalty_scale)
	end

	if speed > config.dash_max_speed then
		local boostedZ = math.max(vel.z, config.jump_power + speed * config.jump_power_scale)
		vel.z = Lerp(boostPenalty, vel.z, boostedZ)
	else
		local dash = look * dashSpeed
		vel.x = dash.x
		vel.y = dash.y

		local boostedZ = math.max(vel.z, config.jump_power)
		vel.z = Lerp(boostPenalty, vel.z, boostedZ)
	end

	return vel
end

function mod.onSetupMove(ply, mv, state)
	local config = mod.config

	usesRefill.OnTick(ply, state)

	if state.dashing then
		local elapsed = CurTime() - state.dashStartTime

		if elapsed >= DASH_EASE_DURATION then
			mv:SetVelocity(state.dashTargetVelocity)
			state.dashing = false
		else
			local chaseT = math.Clamp(FrameTime() / DASH_EASE_DURATION, 0, 1)
			mv:SetVelocity(LerpVector(chaseT, mv:GetVelocity(), state.dashTargetVelocity))
		end
	end

	local onGround = ply:IsOnGround()
	if not onGround and state.wasOnGround then
		state.airStartTime = CurTime()
	end
	state.wasOnGround = onGround

	if not mv:KeyPressed(gearSlots.SLOTS.leg.bit) then return end
	if isParkouring(ply) then return end
	if (CurTime() - state.airStartTime) < config.start_endlag then return end
	if (CurTime() - state.lastUsed) < config.endlag then return end
	if onGround then return end
	if state.uses <= 0 then return end

	state.lastUsed = CurTime()
	state.uses = math.max(0, state.uses - 1)

	if SERVER then
		sound.Play(ply, config.thrust_sound)
		usesRefill.Broadcast(ply, state)
	end

	if game.SinglePlayer() then
		ply:SendLua("LocalPlayer():CLViewPunch(Angle(6 * LocalPlayer():GetInfoNum('brgears_screenshake_scale', 1), 0, 0))")
	elseif CLIENT and IsFirstTimePredicted() then
		local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
		ply:CLViewPunch(Angle(6 * shakeScale, 0, 0))
	end

	usesRefill.StartWaiting(state)

	ParkourEvent("jumpfar", ply, true)

	local look = ply:EyeAngles():Forward()
	look.z = 0
	look:Normalize()

	state.dashing = true
	state.dashStartTime = CurTime()
	state.dashTargetVelocity = mod.ComputeDashVelocity(ply, mv:GetVelocity(), look, config)
end

return mod
