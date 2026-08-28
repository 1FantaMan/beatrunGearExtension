local gearEquip = include("beatrun/sh/modules.lua").Get("gearEquip")

local mod = {}

function mod.init(ply)
  return { fallSpeed = 0 }
end

function mod.destroy(ply, state)
end

-- GetFallDamage's return isn't respected here; track peak fall speed ourselves for EntityTakeDamage below
function mod.onSetupMove(ply, mv, state)
  local velz = mv:GetVelocity().z

  if velz < 0 then
    state.fallSpeed = math.max(state.fallSpeed, -velz)
  end

  if ply:OnGround() then
    state.fallSpeed = 0
  end
end

hook.Add("EntityTakeDamage", "BeatrunGears_FallGloveExtendedSurvival", function(target, dmginfo)
  if not target:IsPlayer() then return end
  if bit.band(dmginfo:GetDamageType(), DMG_FALL) == 0 then return end
  if not gearEquip.IsEquipped(target, "right", "fglove") then return end

  local state = GetState(target, "right")
  if not state then return end

  if state.fallSpeed < mod.config.max_survivable_speed then
    dmginfo:SetDamage(0)
  end
end, HOOK_HIGH)

return mod
