-- stacked "uses remaining" HUD, mirrored on the opposite side of the native corner box, one box per equipped gear with config.max_uses set
local gearsHandler = include("beatrun/sh/gearsHandler.lua")
local hudStyle = include("beatrun/cl/hudStyle.lua")

surface.CreateFont("BeatrunGearUsesFont", {
  font = "x14y24pxHeadUpDaisy",
  shadow = true,
  scanlines = 2,
  weight = 500,
  antialias = false,
  size = 34,
})

surface.CreateFont("BeatrunGearUsesFontSmall", {
  font = "x14y24pxHeadUpDaisy",
  shadow = true,
  scanlines = 2,
  weight = 500,
  antialias = false,
  size = 20,
})

surface.CreateFont("BeatrunGearUsesLabelFont", {
  font = "x14y24pxHeadUpDaisy",
  shadow = true,
  scanlines = 2,
  weight = 500,
  antialias = false,
  size = 24,
})

local SLOT_ORDER = { "left", "right", "leg", "back" }
local SLOT_LABELS = { left = "LEFT", right = "RIGHT", leg = "LEG", back = "BACK" }
local BOX_WIDTH = 150 -- widened to fit the slot label alongside the number
local BOX_HEIGHT = 56 -- shorter than the native box's 85
local BOX_GAP = 8
local MARGIN_X = 20
local LABEL_PADDING = 16

-- matches native HUD.lua's corner-gap fill (cl/HUD.lua:205): a corner-color rect straddling the screen edge
local function DrawEdgeFill(y, h, cornerColor, vpZ)
  local fillColor = Color(cornerColor.r, cornerColor.g, cornerColor.b, math.Clamp(cornerColor.a + 50, 0, 255))
  surface.SetDrawColor(fillColor)
  surface.DrawRect(ScrW() - MARGIN_X + vpZ, y, MARGIN_X * 2, h)
end

hook.Add("HUDPaint", "BeatrunGearsUsesHud", function()
  local ply = LocalPlayer()
  if not IsValid(ply) then return end

  local vp = GetConVar("Beatrun_HUDSway"):GetBool() and ply:GetViewPunchAngles() or Angle(0, 0, 0)
  local cornerColor = string.ToColor(ply:GetInfo("Beatrun_HUDCornerColor"))
  local textColor = string.ToColor(ply:GetInfo("Beatrun_HUDTextColor"))

  local w, h = SScaleX(BOX_WIDTH), SScaleY(BOX_HEIGHT)
  local x = ScrW() - MARGIN_X - w + vp.z
  local nextBottom = ScrH() * 0.895 + SScaleY(85) + vp.x

  for _, slot in ipairs(SLOT_ORDER) do
    local gearName = ply:GetNW2String("brgear_" .. slot, "")
    if gearName == "" then continue end

    local gear = gearsHandler.GetClientGear(gearName)
    if gear == nil or gear.config.max_uses == nil then continue end

    local usesRemaining = ply:GetNW2Int("brgear_" .. slot .. "_uses", gear.config.max_uses)
    local numberColor = usesRemaining <= 0 and Color(220, 50, 50) or textColor

    local top = nextBottom - h
    DrawEdgeFill(top, h, cornerColor, vp.z)
    hudStyle.DrawPanel(x, top, w, h, cornerColor)

    local mainText = tostring(usesRemaining)
    local smallText = "/" .. gear.config.max_uses
    local textY = top + h / 2

    draw.SimpleText(SLOT_LABELS[slot], "BeatrunGearUsesLabelFont", x + LABEL_PADDING, textY, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    surface.SetFont("BeatrunGearUsesFont")
    local mainW = surface.GetTextSize(mainText)
    surface.SetFont("BeatrunGearUsesFontSmall")
    local smallW = surface.GetTextSize(smallText)

    local numberX = x + w - LABEL_PADDING - mainW - smallW
    draw.SimpleText(mainText, "BeatrunGearUsesFont", numberX, textY, numberColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(smallText, "BeatrunGearUsesFontSmall", numberX + mainW, textY + 4, numberColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    nextBottom = top - BOX_GAP
  end
end)
