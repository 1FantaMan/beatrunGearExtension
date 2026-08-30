local modules = include("beatrun/sh/modules.lua")
local sound = modules.Get("sound")

local mod = {}

local usesRefill = modules.Get("usesRefill").New(mod, "uses")

function mod.init(ply)
  local state = {
    phase = "idle",
    uses = mod.config.max_uses,

    lastUsed = CurTime(),
    airStartTime = 0,

    shared = {}
  }

  usesRefill.Broadcast(ply, state)

  return state
end

function mod.activate(ply, state)
  if (CurTime() - state.airStartTime) < mod.config.start_endlag then
    return false
  end

  if (CurTime() - state.lastUsed) < mod.config.endlag then
    return false
  end

  if ply:IsOnGround() then
    return false
  end

  if state.uses == 1 then
    ply:SetDive(true)
    state.shared.isDiving = true
  else
    state.shared.isDiving = false
  end

  if state.uses <= 0 then
    return false
  end

  sound.Play(ply, mod.config.thrust_sound)

  state.phase = "thrust"
  state.lastUsed = CurTime()
  state.uses = math.max(0, state.uses - 1)
  usesRefill.Broadcast(ply, state)
  usesRefill.StartWaiting(state)
end

function mod.onSetupMove(ply, mv, state)
  if state.phase ~= "thrust" then
    return
  end

  if state.shared.isDiving then
    ply:ViewPunch(Angle(-10, 0, 0))
  end

  local vel = ply:GetVelocity()
  local look = ply:EyeAngles():Forward()
  look.z = 0
  look:Normalize()

  local speed = vel:Length()
  local dashSpeed = speed * mod.config.dash_speed

  if ply:GetDive() then
    dashSpeed = dashSpeed * mod.config.dive_dash_multiplier
  end

  if speed > mod.config.dash_max_speed then
    -- already faster than the dash would redirect to; floor the vertical speed instead of adding on top
    vel.z = math.max(vel.z, mod.config.jump_power + speed * mod.config.jump_power_scale)
  else
    local dash = look * dashSpeed
    vel.x = dash.x
    vel.y = dash.y
    vel.z = math.max(vel.z, mod.config.jump_power)
  end

  mv:SetVelocity(vel)

  ParkourEvent("thruster_thrusted", ply, true)

  state.phase = "idle"
end

function mod.onParkour(ply, state, action)
  usesRefill.OnParkour(ply, state, action)
end

function mod.onTick(ply, state)
  if not ply:IsOnGround() and ply:GetWasOnGround() then
    state.airStartTime = CurTime()
  end

  usesRefill.OnTick(ply, state)
end

function mod.destroy(ply, state)
  state.phase = "idle"
end

function mod.OnPlayerSpawn(ply)
  local state = GetState(ply, "leg")
  if not state then return end

  state.phase = "idle"
  state.uses = mod.config.max_uses
  state.lastUsed = CurTime()
  state.airStartTime = 0
  usesRefill.Broadcast(ply, state)
end

hook.Add("PlayerSpawn", "BeatrunGears_Thruster", mod.OnPlayerSpawn)

return mod
