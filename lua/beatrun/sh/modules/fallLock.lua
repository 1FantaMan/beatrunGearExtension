-- client-only; ref-counted disable of native FallLock (zeroes mouse input on fast falls) so multiple gears can share it without fighting
local mod = {}

local cachedFn
local disableCount = 0

local function Capture()
  if cachedFn then return end

  local hooks = hook.GetTable().InputMouseApply
  cachedFn = hooks and hooks.FallLock
end

function mod.Disable()
  Capture()

  disableCount = disableCount + 1
  hook.Remove("InputMouseApply", "FallLock")
end

function mod.Enable()
  disableCount = math.max(0, disableCount - 1)

  if disableCount == 0 and cachedFn then
    hook.Add("InputMouseApply", "FallLock", cachedFn)
  end
end

return mod
