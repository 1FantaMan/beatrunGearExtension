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
		-- lifecycle
		phase = "idle", -- idle -> traveling -> done
		usesRemaining = config.max_uses,
		waitingForLanding = false,

		-- active grapple
		targetPos = nil,
		targetEntity = nil, -- NPC/ragdoll being pulled to the player
		targetPhysBone = nil, -- which physics object to grab (only used when targetEntity is a ragdoll)
		arrivalTime = 0,
		pullDelay = 0,
		boostTime = 0,

		-- aim tracking (only updated while idle)
		trackedHitPos = nil,
		trackedEntity = nil,
		trackedPhysBone = nil,
		trackedReachable = false,
	}

	return state
end

function mod.ApplyActivateState(state, startPos, hitPos, config, targetEntity, targetPhysBone)
	local distance = startPos:Distance(hitPos)
	local travelTime = math.min(config.max_travel_time, distance / config.travel_speed)

	state.phase = "traveling"
	state.targetPos = hitPos
	state.targetEntity = targetEntity
	state.targetPhysBone = targetPhysBone
	state.arrivalTime = CurTime() + travelTime
	state.pullDelay = math.min(config.max_pull_delay, distance / config.pull_delay_speed)
end

function mod.IsBlockedTrace(trace)
	return trace ~= nil and DOOR_CLASSES[trace.Entity:GetClass()] == true
end

local function UpdateHookTracking(ply, state, config)
	local startPos = ply:EyePos()
	local direction = ply:EyeAngles():Forward()
	local trace = mod.ComputeGrapplerRaycast(ply, startPos, direction, config)

	if mod.IsBlockedTrace(trace) then
		trace = nil -- blocked surface, treat exactly like a miss
	end

	if trace then
		state.trackedHitPos = trace.HitPos
		state.trackedEntity = (IsValid(trace.Entity) and (trace.Entity:IsNPC() or trace.Entity:IsRagdoll()))
			and trace.Entity or nil
		state.trackedPhysBone = trace.PhysicsBone
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
	state.trackedEntity = nil
	state.trackedPhysBone = nil
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
			mod.ApplyActivateState(state, startPos, state.trackedHitPos, config, state.trackedEntity, state.trackedPhysBone)

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

	-- pulling an NPC/ragdoll instead of pulling ourselves to a surface: continuously push the target toward us
	-- for the whole travel window instead of a single velocity application at arrival, since most NPCs run
	-- their own navigation every tick and would otherwise instantly override a one-shot SetVelocity - NOT YET
	-- CONFIRMED IN-GAME whether this is enough to actually beat that navigation for every NPC type
	if state.phase == "traveling" and IsValid(state.targetEntity) then
		if SERVER then
			local target = state.targetEntity

			if target:IsRagdoll() then
				-- ragdolls are pure physics objects (one per bone) - moving the base entity does nothing.
				-- only grab the specific limb the hook actually traced onto, not the whole ragdoll, and pull
				-- from that limb's own position rather than the ragdoll's root
				local phys = target:GetPhysicsObjectNum(state.targetPhysBone or 0)

				if IsValid(phys) then
					local direction = (ply:GetPos() - phys:GetPos()):GetNormalized()
					phys:SetVelocity(direction * config.entity_pull_speed)
				end
			else
				local direction = (ply:GetPos() - target:GetPos()):GetNormalized()
				target:SetLocalVelocity(direction * config.entity_pull_speed)
			end
		end

		if CurTime() >= state.arrivalTime + state.pullDelay then
			state.phase = "done"
			state.boostTime = CurTime()
			state.targetEntity = nil

			usesRefill.StartWaiting(state)

			local shakeScale = ply:GetInfoNum("brgears_screenshake_scale", 1)
			clViewPunch(ply, Angle(-1 * shakeScale, -5 * shakeScale, 0))

			local pullAnim = groundCheck.IsRealGround(ply) and "grapple_pull" or "grapple_pull_air"
			ParkourEvent(pullAnim, ply, true)
			ParkourEvent("grappler_hooked", ply, true)
		end

		return
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
