local gearUtil = include("beatrun/sh/util.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")
local movement = gearUtil.movement
local sound = gearUtil.sound
local groundCheck = gearUtil.groundCheck
include("beatrun/gears/grappler/visuals/screenShake.lua")

local mod = {}

local usesRefill = gearUtil.usesRefill.New(mod, "usesRemaining")

local DOOR_CLASSES = {
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
}
local DOOR_BLOCK_RADIUS = 80 -- matches the stock door-bash interaction range

function mod.IsNearDoor(ply, radius)
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), radius)) do
		if DOOR_CLASSES[ent:GetClass()] then
			return true
		end
	end

	return false
end

function mod.GetStates(config)
	local state = {
		phase = "idle",
		targetPos = nil,
		arrivalTime = 0,
		pullDelay = 0,
		boostTime = 0,
		waitingForLanding = false,
		usesRemaining = config.max_uses,
	}

	return state
end

function mod.ApplyActivateState(state, startPos, trace, config)
	local distance = startPos:Distance(trace.HitPos)
	local travelTime = math.min(config.max_travel_time, distance / config.travel_speed)

	state.phase = "traveling"
	state.targetPos = trace.HitPos
	state.arrivalTime = CurTime() + travelTime
	state.pullDelay = math.min(config.max_pull_delay, distance / config.pull_delay_speed)
end

function mod.ComputeGrapplerRaycast(ply, startPos, direction, config)
	local endPos = startPos + direction * config.max_range

	local trace = util.TraceLine({
		start = startPos,
		endpos = endPos,
		filter = ply
	})

	if not trace.Hit then
		return nil
	end

	return trace
end

function mod.ComputePushVelocity(direction, currentSpeed, fallSpeed, config)
	local boostSpeed = math.min(config.push_max_speed,
		math.max(config.push_speed, currentSpeed * config.push_speed_multiplier))

	if fallSpeed > config.fall_damage_threshold then
		local excess = fallSpeed - config.fall_damage_threshold
		local penalty = math.max(config.min_fall_push_penalty, 1 - excess * config.fall_push_penalty_scale)
		boostSpeed = boostSpeed * penalty
	end

	return direction * boostSpeed
end

function mod.onSetupMove(ply, mv, state)
	local config = mod.config

	usesRefill.OnTick(ply, state)

	if state.phase == "done" and CurTime() - state.boostTime >= config.rope_visible_time then
		state.phase = "idle"

		if SERVER then
			ply:SetNW2Bool("brgear_grapple_active", false)
		end
	end

	if state.phase == "idle" and mv:KeyPressed(gearSlots.SLOTS.left.bit) and state.usesRemaining > 0
		and not mod.IsNearDoor(ply, DOOR_BLOCK_RADIUS) then
		local startPos = ply:EyePos()
		local direction = ply:EyeAngles():Forward()
		local trace = mod.ComputeGrapplerRaycast(ply, startPos, direction, config)

		if trace then
			movement.CancelAbilities(ply)

			state.usesRemaining = state.usesRemaining - 1
			mod.ApplyActivateState(state, startPos, trace, config)

			if SERVER then
				usesRefill.Broadcast(ply, state)
				sound.Play(ply, config.fire_sound, 90, 100)

				ply:SetNW2Bool("brgear_grapple_active", true)
				ply:SetNW2Vector("brgear_grapple_target", trace.HitPos)
				ply:SetNW2Float("brgear_grapple_fire_time", CurTime())
				ply:SetNW2Float("brgear_grapple_arrival_time", state.arrivalTime)
				ply:SetNW2Float("brgear_grapple_pull_delay", state.pullDelay)
			end

			-- unconditional call so the fork's SP-only net relay reaches the client (SetupMove never runs client-side in true SP)
			ParkourEvent("grapple_throw", ply, true)

			local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
			local kick = Angle(1 * shakeScale, 2 * shakeScale, 0)
			ply:SetViewPunchAngles(ply:GetViewPunchAngles() + kick)
		end
	end

	if state.phase == "traveling" and CurTime() >= state.arrivalTime + state.pullDelay then
		local fallSpeed = -mv:GetVelocity().z

		if SERVER and fallSpeed > config.fall_damage_threshold then
			local damage = (fallSpeed - config.fall_damage_threshold) * config.fall_damage_scale
			ply:TakeDamage(damage, ply, ply)

			if not ply:Alive() then
				state.phase = "idle"
				return
			end
		end

		local direction = (state.targetPos - ply:EyePos()):GetNormalized()
		local speed = mv:GetVelocity():Length()
		mv:SetVelocity(mod.ComputePushVelocity(direction, speed, fallSpeed, config))

		state.phase = "done"
		state.boostTime = CurTime()

		usesRefill.StartWaiting(state)

		local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
		local kick = Angle(-1 * shakeScale, -5 * shakeScale, 0)
		ply:SetViewPunchAngles(ply:GetViewPunchAngles() + kick)

		-- the fullbody pull anim's leg motion looks like floating while actually standing on ground; only use it airborne
		local pullAnim = groundCheck.IsRealGround(ply) and "grapple_pull" or "grapple_pull_air"
		ParkourEvent(pullAnim, ply, true)
		ParkourEvent("grappler_hooked", ply, true)
	end
end

return mod
