-- shared "spin 180 degrees, optionally fade out" animation; each caller owns its own state via New()
local mod = {}

local SPIN_DURATION = 0.35

function mod.New()
  return { startTime = nil, withFade = false }
end

function mod.Trigger(anim, withFade)
  anim.startTime = CurTime()
  anim.withFade = withFade
end

function mod.Cancel(anim)
  anim.startTime = nil
end

-- returns rotation (0-180) and alpha (0-255), holding at the end value once finished
function mod.Update(anim)
  if not anim.startTime then return 0, 255 end

  local t = math.Clamp((CurTime() - anim.startTime) / SPIN_DURATION, 0, 1)
  local rotation = Lerp(t, 0, 180)
  local alpha = anim.withFade and Lerp(t, 255, 0) or 255

  return rotation, alpha
end

return mod
