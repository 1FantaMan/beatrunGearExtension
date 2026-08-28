-- client-only; centralizes disabling cl/Fall.lua's native "FallLock" hook (which zeroes mouse
-- input entirely during fast falls) so multiple gears (wingsuit, fglove) can each ask for it to be
-- disabled without fighting over the same cached hook function -- stays off as long as anything
-- wants it off, restored only once everyone releases it
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
