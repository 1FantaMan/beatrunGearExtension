local gearsHandler = include("beatrun/sh/gearsHandler.lua")

local clientGears = {}

local function OnGearChange()
    local slot = net.ReadString()
    local newName = net.ReadString()

    if clientGears[slot] and clientGears[slot] ~= "" then
        gearsHandler.GetClientGear(clientGears[slot].name).destroy(LocalPlayer(), clientGears[slot].state)
    end

    if newName ~= "" then
        local gear = gearsHandler.GetClientGear(newName)
        if gear == nil then
            return
        end

        clientGears[slot] = { name = newName, state = gear.init(LocalPlayer()) }
    else
        clientGears[slot] = ""
    end
end

local function OnGearActivate()
    local slot = net.ReadString()

    if clientGears[slot] == nil or clientGears[slot] == "" then
        return
    end

    gearsHandler.GetClientGear(clientGears[slot].name).activate(LocalPlayer(), clientGears[slot].state)
end

net.Receive("BeatrunGearsClientGearChanged", OnGearChange)
net.Receive("BeatrunGearsClientActivate", OnGearActivate)