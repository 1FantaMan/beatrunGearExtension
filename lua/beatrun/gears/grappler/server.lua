local modules = include("beatrun/sh/modules.lua")
local groundCheck = modules.Get("groundCheck")
local sound = modules.Get("sound")
local movement = modules.Get("movement")

local mod = {}

-- same door classes Beatrun's own melee door-bash (sh/Melee.lua) checks for
local DOOR_CLASSES = {
    prop_door_rotating = true,
    func_door_rotating = true,
}

local function PlayFireSound(ply)
    sound.Play(ply, mod.config.fire_sound, 90, 100)
end

-- targetEnt/targetLocalOffset let the rope track a moving entity (e.g. a
-- swinging door) instead of a fixed world point - omit them to clear any
-- previous tracked entity and just use the static targetPos.
local function BroadcastRopeVisual(ply, targetPos, arrivalTime, targetEnt, targetLocalOffset)
    ply:SetNW2Bool("brgear_grapple_active", true)
    ply:SetNW2Vector("brgear_grapple_target", targetPos)
    ply:SetNW2Float("brgear_grapple_fire_time", CurTime())
    ply:SetNW2Float("brgear_grapple_arrival_time", arrivalTime)
    ply:SetNW2Entity("brgear_grapple_target_ent", targetEnt or NULL)
    ply:SetNW2Vector("brgear_grapple_target_offset", targetLocalOffset or vector_origin)
end

function mod.init(ply)
    return {
        phase = "idle",
        targetPos = nil,
        arrivalTime = 0,
        pullDelay = 0,
        boostTime = 0,
        waitingForLanding = false,
        landedTime = nil,
        usesRemaining = mod.config.max_uses,
    }
end

function mod.activate(ply, state)
    if state.phase ~= "idle" then
        return false
    end

    if state.usesRemaining <= 0 then
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
        return false
    end

    if IsValid(trace.Entity) and DOOR_CLASSES[trace.Entity:GetClass()] then
        local door = trace.Entity

        -- close enough to just melee-bash it instead - don't fire the grapple
        if startPos:Distance(trace.HitPos) < mod.config.door_melee_range then
            return false
        end

        if door:GetInternalVariable("m_bLocked") then
            return false
        end

        PlayFireSound(ply)

        -- rope shows instantly (no travel delay) - only the actual door
        -- open is delayed. targetLocalOffset is the hit point expressed
        -- relative to the door's own pos/angles at fire time, so the rope
        -- can track it live as the door swings open
        local targetLocalOffset = WorldToLocal(trace.HitPos, angle_zero, door:GetPos(), door:GetAngles())

        state.targetPos = trace.HitPos
        state.arrivalTime = CurTime()
        state.phase = "done"
        state.boostTime = CurTime()

        BroadcastRopeVisual(ply, trace.HitPos, state.arrivalTime, door, targetLocalOffset)

        timer.Simple(mod.config.door_open_delay, function()
            if not IsValid(door) then return end

            -- prop_door_rotating/func_door_rotating have a real "Open
            -- Direction" keyvalue (opendir: 0=both/default away-from-user,
            -- 1=forward only, 2=backward only) that forces a fixed swing
            -- direction regardless of the activator's position - deterministic,
            -- unlike Use()'s default "away from whoever opened it" behavior.
            -- Pick whichever forces it toward the player via a dot product
            -- against the door's own forward vector.
            local towardPlayer = (ply:GetPos() - door:GetPos()):GetNormalized()
            local openForward = door:GetForward():Dot(towardPlayer) > 0

            door:SetKeyValue("opendir", openForward and "1" or "2")

            local speed = door:GetInternalVariable("speed")
            door.grapplerOldSpeed = door.grapplerOldSpeed or speed

            door:SetSaveValue("speed", door.grapplerOldSpeed * 4)
            door:Use(ply)
            door:Fire("Lock")
            door:EmitSound("Door.Barge")
            ply:ViewPunch(Angle(15, 10, 0))

            timer.Simple(1, function()
                if IsValid(door) then
                    door:SetSaveValue("speed", door.grapplerOldSpeed)
                    door:SetKeyValue("opendir", "0")
                    door:Fire("Unlock")
                end
            end)
        end)

        return
    end

    movement.CancelAbilities(ply)

    state.usesRemaining = state.usesRemaining - 1
    ply:SetNW2Int("brgear_grapple_uses_remaining", state.usesRemaining)

    PlayFireSound(ply)

    debugoverlay.Line(startPos, trace.HitPos, 2, Color(0, 255, 0))
    debugoverlay.Cross(trace.HitPos, 10, 2, Color(255, 0, 0))

    ply:ViewPunch(Angle(2, 5, 0))

    local distance = startPos:Distance(trace.HitPos)
    local travelTime = math.min(mod.config.max_travel_time, distance / mod.config.travel_speed)

    state.phase = "traveling"
    state.targetPos = trace.HitPos
    state.arrivalTime = CurTime() + travelTime
    state.pullDelay = math.min(mod.config.max_pull_delay, distance / mod.config.pull_delay_speed)

    BroadcastRopeVisual(ply, trace.HitPos, state.arrivalTime)
end

function mod.onSetupMove(ply, mv, state)
    if state.phase ~= "traveling" then
        return
    end

    if CurTime() < state.arrivalTime + state.pullDelay then
        return
    end

    local fallSpeed = -mv:GetVelocity().z
    if fallSpeed > mod.config.fall_damage_threshold then
        local damage = (fallSpeed - mod.config.fall_damage_threshold) * mod.config.fall_damage_scale
        ply:TakeDamage(damage, ply, ply)

        if not ply:Alive() then
            return
        end
    end

    local direction = (state.targetPos - ply:EyePos()):GetNormalized()
    local currentSpeed = mv:GetVelocity():Length()
    local boostSpeed = math.min(mod.config.push_max_speed, math.max(mod.config.push_speed, currentSpeed * mod.config.push_speed_multiplier))

    if fallSpeed > mod.config.fall_damage_threshold then
        local excess = fallSpeed - mod.config.fall_damage_threshold
        local penalty = math.max(mod.config.min_fall_push_penalty, 1 - excess * mod.config.fall_push_penalty_scale)
        boostSpeed = boostSpeed * penalty
    end

    mv:SetVelocity(direction * boostSpeed)

    state.phase = "done"
    state.boostTime = CurTime()
    state.waitingForLanding = true
end

function mod.onParkour(ply, state, action)
    if action ~= "land" or not state.waitingForLanding then return end
    if not groundCheck.IsRealGround(ply) then return end
    state.waitingForLanding = false
    state.landedTime = CurTime()
end

function mod.onTick(ply, state)
    if state.phase == "done" and CurTime() - state.boostTime >= mod.config.rope_visible_time then
        state.phase = "idle"
        ply:SetNW2Bool("brgear_grapple_active", false)
    end

    if state.waitingForLanding and groundCheck.IsRealGround(ply) then
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
