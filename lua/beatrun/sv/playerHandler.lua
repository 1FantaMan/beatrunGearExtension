local gearsHandler = include("beatrun/sh/gearsHandler.lua")
local gearSlots = include("beatrun/sh/gearSlots.lua")

local mod = {}
mod.plys = {}

local function OnTick()
    for steamid, data in pairs(mod.plys) do
        local ply = player.GetBySteamID64(steamid)
        if not ply then continue end

        for slot, gearData in pairs(data.gears) do
            if gearData == "" then
                continue
            end

            local gear = gearsHandler.GetServerGear(gearData.name)
            if gear and gear.onTick then
                gear.onTick(ply, gearData.state)
            end
        end
    end
end

local function OnParkour(action, ply)
    if not IsValid(ply) then return end

    local data = mod.plys[ply:SteamID64()]
    if data == nil then return end

    for slot, gearData in pairs(data.gears) do
        if gearData == "" then continue end

        local gear = gearsHandler.GetServerGear(gearData.name)
        if gear and gear.onParkour then
            gear.onParkour(ply, gearData.state, action)
        end
    end
end

local function OnSetupMove(ply, mv, cmd)
    local data = mod.plys[ply:SteamID64()]
    if data == nil then return end

    for slot, gearData in pairs(data.gears) do
        if gearData == "" then continue end

        local gear = gearsHandler.GetServerGear(gearData.name)
        if gear and gear.onSetupMove then
            gear.onSetupMove(ply, mv, gearData.state)
        end
    end
end

function mod.GetLevel(ply)
    if not game.IsDedicated() then
        local data = mod.plys[ply:SteamID64()]
        if data == nil then return end

        return data.beatrunlevel
    else
        return ply:GetLevel()
    end
end

function mod.OnPlayerSpawn(ply)
    local newData = {}

    newData.beatrunlevel = 1 --> this will be changed if the server is not dedicated
    newData.gears = {}

    for gearType, _ in pairs(gearSlots.SLOTS) do
        newData.gears[gearType] = ""
    end

    mod.plys[ply:SteamID64()] = newData
end

function mod.EquipGear(ply, slot, name)
    if not gearSlots.IsValidSlot(slot) then
        return false, "'" .. slot .. "' is not a valid slot."
    end

    local data = mod.plys[ply:SteamID64()]
    if data == nil then
        return false, "Data doesnt exist for '" .. ply:Nick() .. "'."
    end

    local gear = gearsHandler.GetServerGear(name)
    if gear == nil then
        return false, "'" .. name .. "' is not a valid gear."
    end

    if data.gears[slot].name == name then
        return false, "the gear '" .. name .. "' is already equipped."
    end

    if data.gears[slot] ~= "" then
        local oldGear = gearsHandler.GetServerGear(data.gears[slot].name)
        if oldGear and oldGear.destroy then
            oldGear.destroy(ply, data.gears[slot].state)
        end
    end


    if gear.config.type ~= slot then
        return false, "'" .. name .. "' gear isnt indentical to the slot: '" .. slot .. "'"
    end

    if mod.GetLevel(ply) < gear.config.level then
        return false, "'" .. name .. "' gear's level is higher than the player."
    end

    local state = gear.init(ply)
    mod.plys[ply:SteamID64()].gears[slot] = { name = name, state = state, lastActivateTime = 0 }
    ply:SetNW2String("brgear_" .. slot, name)

    net.Start("BeatrunGearsClientGearChanged")
        net.WriteString(slot)
        net.WriteString(name)
    net.Send(ply)

    return true, "successfully equipped '" .. name .. "' gear for '" .. slot .. "'."
end

function mod.UnequipGear(ply, slot)
    if not gearSlots.IsValidSlot(slot) then
        return false, "'" .. slot .. "' is not a valid slot."
    end

    local data = mod.plys[ply:SteamID64()]
    if data == nil then
        return false, "Data doesnt exist for '" .. ply:Nick() .. "'."
    end

    if data.gears[slot] == "" then
        return false, "'" .. slot .. "' doesnt have a gear."
    end

    local gear = gearsHandler.GetServerGear(data.gears[slot].name)
    if gear == nil then
        return false, "'" .. data.gears[slot].name .. "' is not a valid gear."
    end

    if gear.destroy then
        gear.destroy(ply, data.gears[slot].state)
    end
    data.gears[slot] = ""
    ply:SetNW2String("brgear_" .. slot, "")

    net.Start("BeatrunGearsClientGearChanged")
        net.WriteString(slot)
        net.WriteString("")
    net.Send(ply)

    return true, "successfully unequipped '" .. slot .. "'."
end

function mod.OnGearKeyPress(ply, slot)
    if not gearSlots.IsValidSlot(slot) or not gearSlots.SLOTS[slot].active then
        return false, "'" .. slot .. "' is not a valid slot or not active."
    end

    local data = mod.plys[ply:SteamID64()]
    if data == nil then
        return false, "Data doesnt exist for '" .. ply:Nick() .. "'."
    end

    if data.gears[slot] == "" then
        return false, "'" .. slot .. "' doesnt have a gear."
    end

    local gear = gearsHandler.GetServerGear(data.gears[slot].name)
    if gear == nil then
        return false, "'" .. data.gears[slot].name .. "' is not a valid gear."
    end

    if data.gears[slot].state.resetCooldown then
        data.gears[slot].lastActivateTime = 0
        data.gears[slot].state.resetCooldown = false
    end

    if CurTime() - data.gears[slot].lastActivateTime < (gear.config.cooldown or 0) then
        return false, "'" .. data.gears[slot].name .. "' is still on cooldown '" .. CurTime() - data.gears[slot].lastActivateTime .. "'"
    end

    local activated = true
    if gear.activate then
        activated = gear.activate(ply, data.gears[slot].state)
        if activated == nil then activated = true end
    end

    if not activated then
        return false, "'" .. data.gears[slot].name .. "' did not activate."
    end

    data.gears[slot].lastActivateTime = CurTime()

    net.Start("BeatrunGearsClientActivate")
        net.WriteString(slot)
        net.WriteString(data.gears[slot].name)
        net.WriteTable(data.gears[slot].state.shared or {})
    net.Send(ply)

    return true, "successfully activated '" .. slot .. "'."
end

function mod.OnGearKeyRelease(ply, slot)
    if not gearSlots.IsValidSlot(slot) or not gearSlots.SLOTS[slot].active then
        return
    end

    local data = mod.plys[ply:SteamID64()]
    if data == nil then return end

    if data.gears[slot] == "" then return end

    local gear = gearsHandler.GetServerGear(data.gears[slot].name)
    if gear == nil then return end

    if gear.onRelease then
        gear.onRelease(ply, data.gears[slot].state)
    end
end

hook.Add("Tick", "BeatrunGearsGearTick", OnTick)
hook.Add("SetupMove", "BeatrunGearsSetupMove", OnSetupMove)
hook.Add("OnParkour", "BeatrunGearsOnParkour", OnParkour)
return mod