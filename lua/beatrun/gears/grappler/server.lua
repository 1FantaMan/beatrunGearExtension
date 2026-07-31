local mod = {}

hook.Add("OnParkour", "GrapplerLandEvent", function(action, ply)
    if action ~= "land" then return end
    ply:SetNW2Float("brgear_grappler_land_time", CurTime())
end)

function mod.init(ply)
    return {
        phase = "idle",
        targetPos = nil,
        arrivalTime = 0,
        pullDelay = 0,
        boostTime = 0,
        waitingForLanding = false,
        landBaseline = 0,
        landedTime = nil,
        usesRemaining = mod.config.max_uses,
    }
end

function mod.activate(ply, state)
    if state.phase ~= "idle" then
        ply:ChatPrint("[Grappler] Still finishing the last grapple.")
        return false
    end

    if state.usesRemaining <= 0 then
        ply:ChatPrint("[Grappler] Out of uses — land to recharge.")
        return false
    end

    local startPos = ply:EyePos()
    local direction = ply:EyeAngles():Forward()
    local endPos = startPos + direction * mod.config.max_range

    local trace = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = ply
    })

    if not trace.Hit then
        ply:ChatPrint("[Grappler] Nothing in range to grapple onto.")
        return false
    end

    state.usesRemaining = state.usesRemaining - 1
    ply:SetNW2Int("brgear_grapple_uses_remaining", state.usesRemaining)

    util.PrecacheSound(mod.config.fire_sound)
    ply:EmitSound(mod.config.fire_sound, 90, 100, 1)

    debugoverlay.Line(startPos, trace.HitPos, 2, Color(0, 255, 0))
    debugoverlay.Cross(trace.HitPos, 10, 2, Color(255, 0, 0))

    local distance = startPos:Distance(trace.HitPos)
    local travelTime = math.min(mod.config.max_travel_time, distance / mod.config.travel_speed)

    state.phase = "traveling"
    state.targetPos = trace.HitPos
    state.arrivalTime = CurTime() + travelTime
    state.pullDelay = math.min(mod.config.max_pull_delay, distance / mod.config.pull_delay_speed)

    ply:SetNW2Bool("brgear_grapple_active", true)
    ply:SetNW2Vector("brgear_grapple_target", trace.HitPos)
    ply:SetNW2Float("brgear_grapple_fire_time", CurTime())
    ply:SetNW2Float("brgear_grapple_arrival_time", state.arrivalTime)
end

function mod.onSetupMove(ply, mv, state)
    if state.phase ~= "traveling" then
        return
    end

    if CurTime() < state.arrivalTime + state.pullDelay then
        return
    end

    local direction = (state.targetPos - ply:EyePos()):GetNormalized()
    local currentSpeed = mv:GetVelocity():Length()
    local boostSpeed = math.min(mod.config.push_max_speed, math.max(mod.config.push_speed, currentSpeed * mod.config.push_speed_multiplier))

    mv:SetVelocity(direction * boostSpeed)

    state.phase = "done"
    state.boostTime = CurTime()
    state.waitingForLanding = true
    state.landBaseline = ply:GetNW2Float("brgear_grappler_land_time", 0)
end

function mod.onTick(ply, state)
    if state.phase == "done" and CurTime() - state.boostTime >= mod.config.rope_visible_time then
        state.phase = "idle"
        ply:SetNW2Bool("brgear_grapple_active", false)
    end

    local landedViaEvent = ply:GetNW2Float("brgear_grappler_land_time", 0) > state.landBaseline
    if state.waitingForLanding and (ply:IsOnGround() or landedViaEvent) then
        state.waitingForLanding = false
        state.landedTime = CurTime()
    end

    if state.landedTime and CurTime() - state.landedTime >= mod.config.uses_refill_delay then
        state.usesRemaining = mod.config.max_uses
        state.landedTime = nil
        ply:SetNW2Int("brgear_grapple_uses_remaining", state.usesRemaining)
    end
end

function mod.destroy(ply, state)
    state.phase = "idle"
    ply:SetNW2Bool("brgear_grapple_active", false)
end

return mod
