-- disables fall-panic camera lock while equipped; shares the refcounted fallLock module with wingsuit/client.lua
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
