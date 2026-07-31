local gearsHandler = include("beatrun/sh/gearsHandler.lua")

local MARGIN = 100

hook.Add("HUDPaint", "BeatrunGrapplerCooldownTimer", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetNW2String("brgear_armLeft", "") ~= "grappler" then
        return
    end

    local gear = gearsHandler.GetClientGear("grappler")
    if gear == nil then return end

    local usesRemaining = ply:GetNW2Int("brgear_grapple_uses_remaining", gear.config.max_uses)

    local x = ScrW() - MARGIN
    local y = ScrH() / 2

    draw.SimpleText(usesRemaining .. "/" .. gear.config.max_uses, "DermaLarge", x, y, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
