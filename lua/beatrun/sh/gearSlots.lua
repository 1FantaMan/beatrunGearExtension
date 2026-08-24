local mod = {}
mod.SLOTS = {
    right = { active = false },
    left = {
        active = true,
        concmd = "brg_activate_left",
        defaultKey = KEY_E
    },
    back = {
        active = true,
        concmd = "brg_activate_back",
        defaultKey = KEY_X
    },
    leg = {
        active = true,
        concmd = "brg_activate_leg",
        defaultKey = KEY_G
    }
}

function mod.IsValidSlot(slot)
    return mod.SLOTS[slot] ~= nil
end

return mod
