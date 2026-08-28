local mod = {}

-- kickglitch mode 2 (sh/Melee.lua) spawns this exact invisible prop as a throwaway jump platform
local FAKE_GROUND_MODELS = {
  ["models/hunter/plates/plate1x1.mdl"] = true,
}

function mod.IsRealGround(ply)
  if not ply:IsOnGround() then return false end

  local ground = ply:GetGroundEntity()
  if IsValid(ground) and FAKE_GROUND_MODELS[ground:GetModel()] then
    return false
  end

  return true
end

return mod
