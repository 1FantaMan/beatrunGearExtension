-- referencing util.slideOverride forces its lazy load, registering its hooks once, the first time anyone equips this gear
local util = include("beatrun/sh/util.lua")
local slideOverride = util.slideOverride

local mod = {}

function mod.init(ply)
  return {}
end

function mod.destroy(ply, state)
end

return mod
