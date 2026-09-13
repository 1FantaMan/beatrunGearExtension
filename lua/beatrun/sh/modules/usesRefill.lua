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

    -- SetNW2Int is server-only; client-side callers just skip the broadcast and keep their own local count
    if SERVER then
      refiller.Broadcast(ply, state)
    end
  end

  local MIN_STATIONARY_REFILL_DELAY = 0.5 -- anti-spam floor so a use that never leaves the ground can't refill instantly

  function refiller.StartWaiting(state)
    state.waitingForLanding = true
    state.waitStartTime = CurTime()
  end

  function refiller.OnParkour(ply, state, action)
    if action ~= "land" or not state.waitingForLanding then return end
    if not groundCheck.IsRealGround(ply) then return end
    refill(ply, state)
  end

  -- fallback for onTick, covering cases already grounded when waiting started (no "land" event will ever fire)
  function refiller.OnTick(ply, state)
    if not state.waitingForLanding then return end
    if not groundCheck.IsRealGround(ply) then return end
    if CurTime() - state.waitStartTime < MIN_STATIONARY_REFILL_DELAY then return end
    refill(ply, state)
  end

  return refiller
end

return mod
