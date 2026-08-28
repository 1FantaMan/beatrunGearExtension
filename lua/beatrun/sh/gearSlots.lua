local mod = {}
mod.SLOTS = {
  right = { active = false },
  left = {
    active = true,
    defaultKey = KEY_E
  },
  back = {
    active = true,
    defaultKey = KEY_X
  },
  leg = {
    active = true,
    defaultKey = KEY_G
  }
}

function mod.IsValidSlot(slot)
  return mod.SLOTS[slot] ~= nil
end

return mod
