include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
include("beatrun/gears/grappler/visuals/cooldownTimer.lua")

-- meleeairstill = stationary air kick, meleeair = moving/dropkick variant
local throwAnim = CreateClientConVar("bg_grappler_throw_anim", "meleeairstill", true, false, "Grappler throw animation: meleeairstill or meleeair")

local mod = {}

function mod.init(ply)
    return {}
end

function mod.activate(ply, state)
    ParkourEvent(throwAnim:GetString(), ply, true)
end

function mod.destroy(ply, state)
end

return mod
