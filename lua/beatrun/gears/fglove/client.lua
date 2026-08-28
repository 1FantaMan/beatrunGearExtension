-- disables the native fall-panic camera lock for as long as this gear is equipped, not just during
-- wingsuit gliding (see wingsuit/client.lua, which shares the same refcounted fallLock module)
local fallLock = include("beatrun/sh/modules.lua").Get("fallLock")

local mod = {}

function mod.init(ply)
  fallLock.Disable()
  return {}
end

function mod.destroy(ply, state)
  fallLock.Enable()
end

return mod
