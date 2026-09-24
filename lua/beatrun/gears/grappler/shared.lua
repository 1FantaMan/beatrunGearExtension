local gearUtil = include("beatrun/sh/util.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")
local movement = gearUtil.movement
local sound = gearUtil.sound
local groundCheck = gearUtil.groundCheck
local isParkouring = gearUtil.isParkouring
include("beatrun/gears/grappler/visuals/screenShake.lua")

local mod = {}

local usesRefill = gearUtil.usesRefill.New(mod, "usesRemaining")

local DOOR_CLASSES = {
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
}

function mod.GetStates(config)
	local state = {
		phase = "idle",
		targetPos = nil,
		arrivalTime = 0,
		pullDelay = 0,
		boostTime = 0,
		waitingForLanding = false,
		usesRemaining = config.max_uses,
		trackedHitPos = nil,
		trackedReachable = false,
	}

	return state
end

function mod.ApplyActivateState(state, startPos, hitPos, config)
	local distance = startPos:Distance(hitPos)
	local travelTime = math.min(config.max_travel_time, distance / config.travel_speed)

	state.phase = "traveling"
	state.targetPos = hitPos
	state.arrivalTime = CurTime() + travelTime
	state.pullDelay = math.min(config.max_pull_delay, distance / config.pull_delay_speed)
end

-- keeps the aim point "stuck" to the last surface it hit through brief gaps in the trace (model seams,
-- doorways, etc) instead of flickering unreachable every frame the ray happens to miss. Only truly lets
-- go once the current aim ray has drifted far from where that surface actually was.
function mod.IsBlockedTrace(trace)
	return trace ~= nil and DOOR_CLASSES[trace.Entity:GetClass()] == true
end

-- NOTE: this only ever actually runs server-side in true singleplayer (SetupMove is never invoked
-- client-side there), so it's the real gate for firing but can't be relied on for client-only visuals
-- like the crosshair - see crosshairProjected.lua's own independent copy of this same logic
local function UpdateHookTracking(ply, state, config)
	local startPos = ply:EyePos()
	local direction = ply:EyeAngles():Forward()
	local trace = mod.ComputeGrapplerRaycast(ply, startPos, direction, config)

	if mod.IsBlockedTrace(trace) then
		trace = nil -- blocked surface, treat exactly like a miss
	end

	if trace then
		state.trackedHitPos = trace.HitPos
		state.trackedReachable = true
		return
	end

	if state.trackedHitPos then
		local endPos = startPos + direction * config.max_range
		local dist = select(1, util.DistanceToLine(startPos, endPos, state.trackedHitPos))

		if dist <= config.reacquire_tolerance then
			state.trackedReachable = true -- still close enough to the old surface, keep it frozen
			return
		end
	end

	state.trackedHitPos = nil
	state.trackedReachable = false
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

local function clViewPunch(ply, kick)
	if game.SinglePlayer() then
		ply:SendLua(string.format("LocalPlayer():CLViewPunch(Angle(%f, %f, %f))",
			kick.p, kick.y, kick.r
		))
	elseif CLIENT and IsFirstTimePredicted() then
		ply:CLViewPunch(kick)
	end
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

	if state.phase == "idle" then
		UpdateHookTracking(ply, state, config)
	end

	if state.phase == "idle" and mv:KeyPressed(gearSlots.SLOTS.left.bit) and state.usesRemaining > 0
		and not isParkouring(ply) then

		local startPos = ply:EyePos()

		if state.trackedReachable then
			movement.CancelAbilities(ply)

			state.usesRemaining = state.usesRemaining - 1
			mod.ApplyActivateState(state, startPos, state.trackedHitPos, config)

			if SERVER then
				usesRefill.Broadcast(ply, state)
				sound.Play(ply, config.fire_sound, 90, 100)

				ply:SetNW2Bool("brgear_grapple_active", true)
				ply:SetNW2Vector("brgear_grapple_target", state.targetPos)
				ply:SetNW2Float("brgear_grapple_fire_time", CurTime())
				ply:SetNW2Float("brgear_grapple_arrival_time", state.arrivalTime)
				ply:SetNW2Float("brgear_grapple_pull_delay", state.pullDelay)
			end

			ParkourEvent("grapple_throw", ply, true)

			local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
			clViewPunch(ply, Angle(1 * shakeScale, 2 * shakeScale, 0))
		end
	end

	if state.phase == "traveling" and CurTime() >= state.arrivalTime + state.pullDelay then
		local fallSpeed = -mv:GetVelocity().z

		-- apply the catch push BEFORE dealing fall damage - TakeDamageInfo creates a ragdoll synchronously
		-- on a fatal hit, which snapshots whatever velocity exists at that moment, so setting it after the
		-- kill is already too late (the ragdoll is a separate entity by then)
		local direction = (state.targetPos - ply:EyePos()):GetNormalized()
		local speed = mv:GetVelocity():Length()
		mv:SetVelocity(mod.ComputePushVelocity(direction, speed, fallSpeed, config))

		if SERVER and fallSpeed > config.fall_damage_threshold then
			local damage = (fallSpeed - config.fall_damage_threshold) * config.fall_damage_scale

			-- plain TakeDamage() doesn't tag DMG_FALL, so Beatrun's own fatal-fall handling (HitSoundsME.lua's
			-- DeathStopSound/DeathFall sound/ScreenFade) never recognized this as fall damage - use a real
			-- DamageInfo instead so a fatal grapple landing plays identically to a fatal natural fall
			local dmg = DamageInfo()
			dmg:SetDamage(damage)
			dmg:SetDamageType(DMG_FALL)
			dmg:SetAttacker(ply)
			dmg:SetInflictor(ply)
			ply:TakeDamageInfo(dmg)

			if not ply:Alive() then
				state.phase = "idle"
				ply:SetNW2Bool("brgear_grapple_active", false)
				return
			end
		end

		state.phase = "done"
		state.boostTime = CurTime()

		usesRefill.StartWaiting(state)

		local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
		clViewPunch(ply, Angle(-1 * shakeScale, -5 * shakeScale, 0))

		local pullAnim = groundCheck.IsRealGround(ply) and "grapple_pull" or "grapple_pull_air"
		ParkourEvent(pullAnim, ply, true)
		ParkourEvent("grappler_hooked", ply, true)
	end
end

return mod
