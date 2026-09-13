local mod = {}

-- bits 25-27 are free (unused by any native IN_* flag), read via mv:KeyPressed in each gear's onSetupMove
mod.SLOTS = {
	right = { active = false },
	left = {
		active = true,
		bit = bit.lshift(1, 25),
		defaultKey = KEY_E
	},
	back = {
		active = true,
		bit = bit.lshift(1, 26),
		defaultKey = KEY_X
	},
	leg = {
		active = true,
		bit = bit.lshift(1, 27),
		defaultKey = KEY_G
	}
}

function mod.IsValidSlot(slot)
	return mod.SLOTS[slot] ~= nil
end

return mod
