local util = include("beatrun/sh/util.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")
local isParkouring = util.isParkouring
local sound = util.sound

local mod = {}

local usesRefill = util.usesRefill.New(mod, "uses")

function mod.GetStates(config)
	return {
		uses = config.max_uses,
		lastUsed = CurTime(),
		airStartTime = 0,
		wasOnGround = true,
		shared = {},
	}
end

function mod.ComputeDashVelocity(ply, vel, look, config)
	local speed = vel:Length()
	local dashSpeed = speed * config.dash_speed
	local fallSpeed = -vel.z

	if ply:GetDive() then
		dashSpeed = dashSpeed * config.dive_dash_multiplier
	end

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
	local isDiving = state.uses == 1
	state.uses = math.max(0, state.uses - 1)

	if isDiving then
		ply:SetDive(true)
		ParkourEvent("divestart", ply, true)

		if CLIENT and IsFirstTimePredicted() then
			ply:ViewPunch(Angle(-10, 0, 0))
		end
	end

	if SERVER then
		sound.Play(ply, config.thrust_sound)
		usesRefill.Broadcast(ply, state)
	end

	usesRefill.StartWaiting(state)

	if not isDiving then
		ParkourEvent("jumpfar", ply, true)
	end

	local look = ply:EyeAngles():Forward()
	look.z = 0
	look:Normalize()

	-- EXPERIMENT (ease-in dash velocity): REPLACES the old instant `mv:SetVelocity(mod.ComputeDashVelocity(ply,
	-- mv:GetVelocity(), look, config))` call. REVERT by deleting these 3 lines and putting that call back here.
	state.dashing = true
	state.dashStartTime = CurTime()
	state.dashTargetVelocity = mod.ComputeDashVelocity(ply, mv:GetVelocity(), look, config)
end

return mod
