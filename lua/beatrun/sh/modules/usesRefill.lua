-- shared "refill uses on landing" handler so gears with a uses count don't each reimplement the landing-detection dance
local modules = include("beatrun/sh/modules.lua")
local groundCheck = modules.Get("groundCheck")

local mod = {}

-- gearMod: the gear's own module table (for gearMod.config.type/max_uses)
-- usesField: the state field name holding the uses count (e.g. "usesRemaining" or "uses")
function mod.New(gearMod, usesField)
  local refiller = {}

  function refiller.Broadcast(ply, state)
    ply:SetNW2Int("brgear_" .. gearMod.config.type .. "_uses", state[usesField])
  end

  local function refill(ply, state)
    state.waitingForLanding = false
    state[usesField] = gearMod.config.max_uses
    refiller.Broadcast(ply, state)
  end

  -- call once right after a use, so landing (real ground) refills it
  function refiller.StartWaiting(state)
    state.waitingForLanding = true
  end

  -- call from the gear's onParkour(ply, state, action)
  function refiller.OnParkour(ply, state, action)
    if action ~= "land" or not state.waitingForLanding then return end
    if not groundCheck.IsRealGround(ply) then return end
    refill(ply, state)
  end

  -- call from the gear's onTick(ply, state) as a fallback (e.g. already grounded, no "land" event fires)
  function refiller.OnTick(ply, state)
    if state.waitingForLanding and groundCheck.IsRealGround(ply) then
      refill(ply, state)
    end
  end

  return refiller
end

return mod
