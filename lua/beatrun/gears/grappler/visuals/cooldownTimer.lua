-- receives the grappler's own client.lua module table via mod.Init() instead of calling
-- gearsHandler.GetClientGear("grappler") itself every frame -- include() never caches, so a
-- fresh gearsHandler.GetClientGear call from here would re-include client.lua (which includes
-- this very file), re-registering this hook with zeroed state every single frame forever
local MARGIN = 100

local mod = {}

local gearMod

function mod.Init(theGearMod)
  gearMod = theGearMod
end

hook.Add("HUDPaint", "BeatrunGrapplerCooldownTimer", function()
  local ply = LocalPlayer()
  if not IsValid(ply) or ply:GetNW2String("brgear_left", "") ~= "grappler" then
    return
  end

  if gearMod == nil or gearMod.config == nil then return end

  local usesRemaining = ply:GetNW2Int("brgear_grapple_uses_remaining", gearMod.config.max_uses)

  local x = ScrW() - MARGIN
  local y = ScrH() / 2

  draw.SimpleText(usesRemaining .. "/" .. gearMod.config.max_uses, "DermaLarge", x, y, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

return mod
