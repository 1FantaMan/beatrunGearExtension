local modules = include("beatrun/sh/modules.lua")
local groundCheck = modules.Get("groundCheck")
local sound = modules.Get("sound")

local mod = {}

function mod.init(ply)
    return {
        phase = "idle",
        uses = mod.config.max_uses,

        lastUsed = CurTime(),
        airStartTime = 0,

        shared = {}
    }
end

function mod.activate(ply, state)
    if (CurTime() - state.airStartTime) < mod.config.start_endlag then
        return false
    end

    if (CurTime() - state.lastUsed) < mod.config.endlag then
        return false
    end

    if ply:IsOnGround() then
        return false
    end

    if state.uses == 1 then
        ply:SetDive(true)
        state.shared.isDiving = true
    else
        state.shared.isDiving = false
    end

    if state.uses <= 0 then
        return false
    end

    sound.Play(ply, mod.config.thrust_sound)

    state.phase = "thrust"
    state.lastUsed = CurTime()
    state.uses = math.max(0, state.uses - 1)
end

function mod.onSetupMove(ply, mv, state)
    if state.phase ~= "thrust" then
        return
    end

    if state.shared.isDiving then
        ply:ViewPunch(Angle(-10, 0, 0))
    end

    local vel = ply:GetVelocity()
    local look = ply:EyeAngles():Forward()
    look.z = 0
    look:Normalize()

    local dashSpeed = vel:Length() * mod.config.dash_speed

    if ply:GetDive() then
        dashSpeed = dashSpeed * mod.config.dive_dash_multiplier
    end

    vel.z = math.max(vel.z, mod.config.jump_power)

    if vel:Length() <= mod.config.dash_max_speed then
        local dash = look * dashSpeed
        vel.x = dash.x
        vel.y = dash.y
    end

    mv:SetVelocity(vel)

    state.phase = "idle"
end

function mod.onParkour(ply, state, action)
    if action ~= "land" then
        return
    end

    if not groundCheck.IsRealGround(ply) then
        return
    end

    state.uses = mod.config.max_uses
end

function mod.onTick(ply, state)
    if not ply:IsOnGround() and ply:GetWasOnGround() then
        state.airStartTime = CurTime()
    end
end

return mod
