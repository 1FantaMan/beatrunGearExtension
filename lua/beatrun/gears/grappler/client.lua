include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
local cooldownTimer = include("beatrun/gears/grappler/visuals/cooldownTimer.lua")
local crosshair = include("beatrun/gears/grappler/visuals/crosshair.lua")

-- meleeairstill = stationary air kick, meleeair = moving/dropkick variant
local throwAnim = CreateClientConVar("bg_grappler_throw_anim", "meleeairstill", true, false, "Grappler throw animation: meleeairstill or meleeair")

local mod = {}

-- hand these visuals a direct reference to this gear's own module table (gearsHandler attaches
-- .config onto this exact table after this file's include() returns) instead of them calling
-- gearsHandler.GetClientGear("grappler") themselves -- include() never caches, so that would
-- re-include this very file every frame (see crosshair.lua's comment for the full story)
cooldownTimer.Init(mod)
crosshair.Init(mod)

function mod.init(ply)
  return {}
end

function mod.activate(ply, state)
  ParkourEvent(throwAnim:GetString(), ply, true)
  crosshair.TriggerOpen()
end

function mod.destroy(ply, state)
end

return mod
