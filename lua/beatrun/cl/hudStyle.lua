local mod = {}

surface.CreateFont("BeatrunHUDFont", {
  font = "x14y24pxHeadUpDaisy",
  shadow = true,
  scanlines = 2,
  weight = 500,
  antialias = false,
  size = 28,
})

local blur = Material("pp/blurscreen")

-- only safe to call from HUDPaint (absolute screen coords) -- do not use from a nested VGUI panel's .Paint
function mod.DrawBlurRect(x, y, w, h, a)
  surface.SetDrawColor(255, 255, 255, a or 255)
  surface.SetMaterial(blur)

  for i = 1, 2 do
    blur:SetFloat("$blur", i / 3 * 5)
    blur:Recompute()

    render.UpdateScreenEffectTexture()
    render.SetScissorRect(x, y, x + w, y + h, true)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    render.SetScissorRect(0, 0, 0, 0, false)
  end
end

function mod.DrawPanel(x, y, w, h, borderColor)
  mod.DrawBlurRect(x, y, w, h)
  surface.SetDrawColor(20, 20, 20, 50)
  surface.DrawRect(x, y, w, h)
  surface.SetDrawColor(borderColor or Color(255, 255, 255, 150))
  surface.DrawOutlinedRect(x, y, w, h, 1)
end

return mod
