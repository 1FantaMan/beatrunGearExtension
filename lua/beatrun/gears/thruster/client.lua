local mod = {}

function mod.init()
  return {}
end

function mod.activate(ply, state)
  if state.shared.isDiving then
    ParkourEvent("jumpfar", ply, true)
    ParkourEvent("divestart", ply, true)
    state.shared.isDiving = false
  else
    ParkourEvent("jumpfar", ply, true)
  end

end

function mod.onParkour()
end

function mod.onTick()
end

function mod.destroy()
end

return mod
