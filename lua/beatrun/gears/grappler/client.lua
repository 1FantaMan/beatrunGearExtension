include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
local crosshairProjected = include("beatrun/gears/grappler/visuals/crosshairProjected.lua")
local movement = include("beatrun/sh/modules.lua").Get("movement")

local shared = include("beatrun/gears/grappler/shared.lua")

local mod = {}

crosshairProjected.Init(mod)

function mod.init(ply)
	return {}
end

function mod.GetHookPosition(ply)
	local startPos = ply:EyePos()
	local dir = ply:EyeAngles():Forward()

	local trace = util.TraceLine({
		start = startPos,
		endpos = startPos + dir * mod.config.max_range,
		filter = ply
	})

	if trace.Hit then
		return trace.HitPos, true
	end

	return startPos + dir * mod.config.max_range, false
end

function mod.canActivate(ply, state)
	if ply:GetNW2Int("brgear_left_uses", mod.config.max_uses) <= 0 then return false end
	if ply:GetNW2Bool("brgear_grapple_active", false) then return false end

	local _, reachable = mod.GetHookPosition(ply)
	return reachable
end

function mod.activate(ply, state)
	movement.CancelAbilities(ply)
	ParkourEvent("meleeairstill", ply, true)
end

function mod.onSetupMove(ply, mv, state)
	if not ply:GetNW2Bool("brgear_grapple_active", false) then
		state.appliedThisFire = nil
		return
	end

	local fireTime = ply:GetNW2Float("brgear_grapple_fire_time", 0)
	if state.lastSeenFireTime ~= fireTime then
		state.lastSeenFireTime = fireTime
		state.appliedThisFire = false
	end

	if state.appliedThisFire then return end

	local arrivalTime = ply:GetNW2Float("brgear_grapple_arrival_time", 0)
	local pullDelay = ply:GetNW2Float("brgear_grapple_pull_delay", 0)
	if CurTime() < arrivalTime + pullDelay then return end

	local fallSpeed = -mv:GetVelocity().z
	local direction = (ply:GetNW2Vector("brgear_grapple_target", Vector()) - ply:EyePos()):GetNormalized()
	local vel = mv:GetVelocity():Length()
	mv:SetVelocity(shared.ComputePushVelocity(direction, vel, fallSpeed, mod.config))
end

function mod.destroy(ply, state)
end

return mod
