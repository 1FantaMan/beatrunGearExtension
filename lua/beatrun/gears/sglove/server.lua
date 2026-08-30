-- slide-speed override lives here; loading it registers its hooks once, the first time anyone equips this gear
include("beatrun/sh/modules.lua").Get("slideOverride")

local mod = {}

function mod.init(ply)
  return {}
end

function mod.destroy(ply, state)
end

return mod
