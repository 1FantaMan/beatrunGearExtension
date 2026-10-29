local shared = include("beatrun/gears/template/shared.lua")

local mod = {}

function mod.init(ply)
  return shared.GetStates(mod.config)
end

function mod.activate(ply, state)
end

function mod.destroy(ply, state)
end

return mod
