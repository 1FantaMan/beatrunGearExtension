local shared = include("beatrun/gears/thruster/shared.lua")

local mod = {}

function mod.init(ply)
  return shared.GetStates(mod.config)
end

function mod.destroy(ply, state)
end

return mod
