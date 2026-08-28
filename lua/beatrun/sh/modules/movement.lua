local mod = {}

-- stop wallrun/climb/dive so they don't keep fighting a gear's own velocity change
function mod.CancelAbilities(ply)
  ply:SetWallrun(0)
  ply:SetWallrunTime(0)
  ply:SetClimbing(0)
  ply:SetDive(false)
end

return mod
