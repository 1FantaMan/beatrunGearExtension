-- same override, client realm: needed so sliding prediction matches the server's result (see server.lua)
local util = include("beatrun/sh/util.lua")
local slideOverride = util.slideOverride

local mod = {}

function mod.init(ply)
  return {}
end

function mod.destroy(ply, state)
end

return mod
