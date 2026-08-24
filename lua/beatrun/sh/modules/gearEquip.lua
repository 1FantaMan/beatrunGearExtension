local mod = {}

-- mirrors the NW2 var playerHandler.lua sets on equip/unequip ("brgear_" .. slot)
function mod.IsEquipped(ply, slot, name)
    return ply:GetNW2String("brgear_" .. slot, "") == name
end

return mod
