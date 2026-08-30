local modules = include("beatrun/sh/modules.lua")
local sound = modules.Get("sound")
local movement = modules.Get("movement")

local mod = {}

local usesRefill = modules.Get("usesRefill").New(mod, "usesRemaining")

local function PlayFireSound(ply)
  sound.Play(ply, mod.config.fire_sound, 90, 100)
end

local function BroadcastRopeVisual(ply, targetPos, arrivalTime)
  ply:SetNW2Bool("brgear_grapple_active", true)
  ply:SetNW2Vector("brgear_grapple_target", targetPos)
  ply:SetNW2Float("brgear_grapple_fire_time", CurTime())
  ply:SetNW2Float("brgear_grapple_arrival_time", arrivalTime)
end

function mod.init(ply)
  local state = {
    phase = "idle",
    targetPos = nil,
    arrivalTime = 0,
    pullDelay = 0,
    boostTime = 0,
    waitingForLanding = false,
    usesRemaining = mod.config.max_uses,
  }

  usesRefill.Broadcast(ply, state)

  return state
end

function mod.activate(ply, state)
  if state.phase ~= "idle" then
    return false
  end

  if state.usesRemaining <= 0 then
    return false
  end

  local startPos = ply:EyePos()
  local direction = ply:EyeAngles():Forward()
  local endPos = startPos + direction * mod.config.max_range

  local trace = util.TraceLine({
    start = startPos,
    endpos = endPos,
    filter = ply
  })

  if not trace.Hit then
    return false
  end

  movement.CancelAbilities(ply)

  state.usesRemaining = state.usesRemaining - 1
  usesRefill.Broadcast(ply, state)

  PlayFireSound(ply)

  ply:ViewPunch(Angle(2, 5, 0))

  local distance = startPos:Distance(trace.HitPos)
  local travelTime = math.min(mod.config.max_travel_time, distance / mod.config.travel_speed)

  state.phase = "traveling"
  state.targetPos = trace.HitPos
  state.arrivalTime = CurTime() + travelTime
  state.pullDelay = math.min(mod.config.max_pull_delay, distance / mod.config.pull_delay_speed)

  BroadcastRopeVisual(ply, trace.HitPos, state.arrivalTime)
  ParkourEvent("grappler_sling", ply, true)
end

function mod.onSetupMove(ply, mv, state)
  if state.phase ~= "traveling" then
    return
  end

  if CurTime() < state.arrivalTime + state.pullDelay then
    return
  end

  local fallSpeed = -mv:GetVelocity().z
  if fallSpeed > mod.config.fall_damage_threshold then
    local damage = (fallSpeed - mod.config.fall_damage_threshold) * mod.config.fall_damage_scale
    ply:TakeDamage(damage, ply, ply)

    if not ply:Alive() then
      return
    end
  end

  local direction = (state.targetPos - ply:EyePos()):GetNormalized()
  local currentSpeed = mv:GetVelocity():Length()
  local boostSpeed = math.min(mod.config.push_max_speed, math.max(mod.config.push_speed, currentSpeed * mod.config.push_speed_multiplier))

  if fallSpeed > mod.config.fall_damage_threshold then
    local excess = fallSpeed - mod.config.fall_damage_threshold
    local penalty = math.max(mod.config.min_fall_push_penalty, 1 - excess * mod.config.fall_push_penalty_scale)
    boostSpeed = boostSpeed * penalty
  end

  mv:SetVelocity(direction * boostSpeed)

  state.phase = "done"
  state.boostTime = CurTime()
  usesRefill.StartWaiting(state)
  ParkourEvent("grappler_hooked", ply, true)
end

function mod.onParkour(ply, state, action)
  usesRefill.OnParkour(ply, state, action)
end

function mod.onTick(ply, state)
  if state.phase == "done" and CurTime() - state.boostTime >= mod.config.rope_visible_time then
    state.phase = "idle"
    ply:SetNW2Bool("brgear_grapple_active", false)
  end

  usesRefill.OnTick(ply, state)
end

function mod.destroy(ply, state)
  state.phase = "idle"
  ply:SetNW2Bool("brgear_grapple_active", false)
end

return mod
