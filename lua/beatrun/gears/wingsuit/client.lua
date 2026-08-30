local hudStyle = include("beatrun/cl/hudStyle.lua")
local fallLock = include("beatrun/sh/modules.lua").Get("fallLock")

local mod = {}

local wasGliding = false

-- native "fall"/"falluncontrolled" events would hijack JumpAnim's state machine away from the dive pose while gliding; intercept at HOOK_HIGH (before JumpAnim's own OnParkour hook) and redirect to "divestart" instead
local FALL_EVENTS_TO_REDIRECT = {
  fall = true,
  falluncontrolled = true,
}

hook.Add("OnParkour", "BeatrunGears_WingsuitDiveOverride", function(event, ply)
  if not FALL_EVENTS_TO_REDIRECT[event] then return end
  if not IsValid(ply) or ply ~= LocalPlayer() then return end
  if not ply:GetNW2Bool("brgear_wingsuit_gliding", false) then return end

  ParkourEvent("divestart", ply, true)

  return true
end, HOOK_HIGH)

function mod.init(ply)
  return {}
end

function mod.activate(ply, state)
  if state.shared.isDiving then
    ParkourEvent("divestart", ply, true)
  end
end

function mod.destroy(ply, state)
end

hook.Add("HUDPaint", "BeatrunGears_WingsuitHUD", function()
  local ply = LocalPlayer()
  if not IsValid(ply) then return end
  if ply:GetNW2String("brgear_back", "") ~= "wingsuit" then return end

  local power = ply:GetNW2Float("brgear_wingsuit_glidepower", 0)
  local frac = math.Clamp(power / mod.config.glide_power_max, 0, 1)

  -- replicate Beatrun's own bgpadding calc (cl/HUD.lua) so our box matches the native one's actual width, not just its minimum
  local nicktext = GetConVar("Beatrun_HUDXP"):GetBool() and (ply:Nick() .. " | " .. ply:GetXP() .. "XP") or ply:Nick()
  surface.SetFont("BeatrunHUDSmall")
  local nickw = surface.GetTextSize(nicktext)
  local bgpadw = nickw
  local bgpadding = bgpadw > 200 and bgpadw + 40 or 200

  local w = SScaleX(bgpadding) + 10 -- extend past the native box's width to the left
  local h = 15

  local vp = GetConVar("Beatrun_HUDSway"):GetBool() and ply:GetViewPunchAngles() or Angle(0, 0, 0)
  local x = 20 - 15 + vp.z
  local y = ScrH() * 0.895 + SScaleY(85) + 10 + vp.x -- sits just below the native corner box

  local cornerColor = string.ToColor(ply:GetInfo("Beatrun_HUDCornerColor"))
  local textColor = string.ToColor(ply:GetInfo("Beatrun_HUDTextColor"))

  hudStyle.DrawPanel(x, y, w, h, cornerColor)

  local barX, barY, barW, barH = x + 8, y + 3, w - 16, 8
  surface.SetDrawColor(60, 60, 60, 200)
  surface.DrawRect(barX, barY, barW, barH)
  surface.SetDrawColor(textColor)
  surface.DrawRect(barX, barY, barW * frac, barH)
end)

hook.Add("Think", "BeatrunGears_FinsGlideWatch", function()
  local ply = LocalPlayer()
  if not IsValid(ply) then return end

  local isGliding = ply:GetNW2Bool("brgear_wingsuit_gliding", false)

  if isGliding and not wasGliding then
    fallLock.Disable()
  elseif wasGliding and not isGliding then
    ParkourEvent("diveslideend", ply, true)
    fallLock.Enable()
  end

  wasGliding = isGliding
end)

return mod
