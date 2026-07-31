local mod = {}
mod.plys = {}

local function OnParkour(action, ply)
    if action ~= "wallrunv" then return end
    if ply:GetNW2String("brgear_armRight", "") ~= "gloves" then return end

    ply:SetWallrunTime(ply:GetWallrunTime() + mod.config.wallclimb_power)
end

function mod.init(ply)
    return {}
end

function mod.destroy(ply)

end

hook.Add("OnParkour", "GlovesWallrunBoost", OnParkour)
return mod
