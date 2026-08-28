-- the actual slide-speed override lives here; loading it registers the SetupMove/PlayerFootstep/
-- StartCommand hooks (gated per-player on this gear being equipped) once, the first time anyone equips it
include("beatrun/sh/modules.lua").Get("slideOverride")

local mod = {}

function mod.init(ply)
  return {}
end

function mod.destroy(ply, state)
end

return mod
