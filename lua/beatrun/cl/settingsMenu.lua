local gearSlots = include("beatrun/sh/gearSlots.lua")
local keybinds = include("beatrun/sh/modules.lua").Get("gearKeybinds")

local KEYBIND_ROWS = {
  { slot = "left", label = "LEFT ARM" },
  { slot = "back", label = "BACK" },
  { slot = "leg", label = "LEG" },
}

-- VGUI focus inside the context menu's DesktopWindows frames isn't reliable enough for
-- OnKeyCodePressed capture, so key capture is done via a plain key-scan Think hook instead
local listeningSlot = nil
local listenStartTime = 0
local LISTEN_DELAY = 0.25 -- ignore input for a moment so the MOUSE1 click that started listening isn't captured as the bind

local function ScanForKeyPress()
  for key = KEY_FIRST, KEY_LAST do
    if key == KEY_C then continue end -- the context menu's own open keybind; still held/re-triggering while this menu is up

    if input.IsButtonDown(key) then return key end
  end

  for key = MOUSE_FIRST, MOUSE_LAST do
    if input.IsButtonDown(key) then return key end
  end

  return nil
end

hook.Add("Think", "BeatrunGears_SettingsKeyCapture", function()
  if not listeningSlot then return end
  if CurTime() - listenStartTime < LISTEN_DELAY then return end

  local key = ScanForKeyPress()
  if not key then return end

  if key ~= KEY_ESCAPE then
    keybinds.Set(listeningSlot, key)
  end

  listeningSlot = nil
end)

local function main(icon, window)
  window:SetTitle("")
  window:ShowCloseButton(false)
  window.Paint = function(self, w, h)
    surface.SetDrawColor(20, 20, 20, 240)
    surface.DrawRect(0, 0, w, h)

    surface.SetDrawColor(255, 255, 255, 200)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
  end

  local title = vgui.Create("DLabel", window)
  title:SetText("SETTINGS")
  title:SetFont("BeatrunGearMenuTitleFont")
  title:SetTextColor(color_white)
  title:SetContentAlignment(5) -- centered
  title:Dock(TOP)
  title:SetTall(50)

  local closeBtn = vgui.Create("DButton", window)
  closeBtn:SetText("X")
  closeBtn:SetFont("BeatrunGearMenuFont")
  closeBtn:SetTextColor(color_white)
  closeBtn:SetSize(24, 24)
  closeBtn:SetPos(window:GetWide() - 30, 10)
  closeBtn.Paint = function() end
  closeBtn.DoClick = function()
    window:Close()
  end

  local listPanel = vgui.Create("DScrollPanel", window)
  listPanel:Dock(FILL)
  listPanel:DockMargin(10, 0, 10, 10)

  local function AddSectionHeader(label)
    local header = vgui.Create("DLabel", listPanel)
    header:SetText(label)
    header:SetFont("BeatrunGearMenuFont")
    header:SetTextColor(Color(180, 180, 180))
    header:Dock(TOP)
    header:SetTall(28)
    header:DockMargin(0, 10, 0, 2)
  end

  local function AddKeybindRow(slotName, label)
    local defaultKey = gearSlots.SLOTS[slotName].defaultKey

    local row = vgui.Create("DButton", listPanel)
    row:SetText("")
    row:Dock(TOP)
    row:SetTall(30)
    row:DockMargin(0, 0, 0, 1)

    row.Paint = function(self, w, h)
      local listening = listeningSlot == slotName

      surface.SetDrawColor(0, 0, 0, 120)
      surface.DrawRect(0, 0, w, h)

      surface.SetFont("BeatrunGearMenuFont")
      surface.SetTextColor(color_white)
      surface.SetTextPos(10, 6)
      surface.DrawText(label)

      local rightText = listening and "PRESS A KEY..." or (input.GetKeyName(keybinds.Get(slotName, defaultKey)) or "UNBOUND")
      local tw = surface.GetTextSize(rightText)
      surface.SetTextColor(listening and Color(255, 210, 90) or Color(180, 180, 180))
      surface.SetTextPos(w - tw - 10, 6)
      surface.DrawText(rightText)
    end

    row.DoClick = function()
      listeningSlot = slotName
      listenStartTime = CurTime()
    end
  end

  AddSectionHeader("KEYBINDS")

  for _, entry in ipairs(KEYBIND_ROWS) do
    AddKeybindRow(entry.slot, entry.label)
  end
end

list.Set("DesktopWindows", "BeatrunSettingsMenu", {
  title = "Settings",
  icon = "icon16/cog.png", -- placeholder, swap later

  width = 400,
  height = 400,
  onewindow = true,

  init = main
})
