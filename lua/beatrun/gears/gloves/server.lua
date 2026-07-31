local mod = {}
mod.plys = {}

local function OnParkour(action, ply)
    if not table.HasValue({ "wallrunh", "wallrunv" }, action) then return end
    if ply:GetNW2String("brgear_armRight", "") ~= "gloves" then return end

    if action == "wallrunv" then
        ply:SetWallrunTime(ply:GetWallrunTime() + mod.config.wallclimb_power)
    elseif action == "wallrunh" then
        ply:SetWallrunTime(ply:GetWallrunTime() + mod.config.wallrun_power)

        local ovel = ply:GetWallrunOrigVel()
        ovel:Mul(1 + (mod.config.wallrun_power / 1.5))
        if ovel:Length() > mod.config.wallrun_speed_cap then
            ovel:Mul(mod.config.wallrun_speed_cap / ovel:Length())
        end
        ply:SetWallrunOrigVel(ovel)
    end
end

function mod.init(ply)
    return {}
end

function mod.destroy(ply)

end

hook.Add("OnParkour", "GlovesWallrunBoost", OnParkour)
return mod