include("beatrun/gears/grappler/visuals/firstPersonRope.lua")
local crosshairProjected = include("beatrun/gears/grappler/visuals/crosshairProjected.lua")

-- meleeairstill = stationary air kick, meleeair = moving/dropkick variant
local throwAnim = CreateClientConVar("bg_grappler_throw_anim", "meleeairstill", true, false, "Grappler throw animation: meleeairstill or meleeair")

local mod = {}

-- pass a reference instead of GetClientGear("grappler") calling itself, which would re-include() this file every frame
crosshairProjected.Init(mod)

function mod.init(ply)
  return {}
end

-- returns (hitPos, reachable) - the real hit, or the point at max_range if nothing's there
function mod.GetHookPosition(ply)
  local startPos = ply:EyePos()
  local dir = ply:EyeAngles():Forward()

  local trace = util.TraceLine({
    start = startPos,
    endpos = startPos + dir * mod.config.max_range,
    filter = ply
  })

  if trace.Hit then
    return trace.HitPos, true
  end

  return startPos + dir * mod.config.max_range, false
end

function mod.activate(ply, state)
  ParkourEvent(throwAnim:GetString(), ply, true)
end

function mod.destroy(ply, state)
end

return mod
