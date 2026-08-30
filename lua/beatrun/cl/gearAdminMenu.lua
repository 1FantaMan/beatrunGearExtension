-- admin-only gear config panel, its own "Beatrun" tab (Server category) in the spawnmenu; server re-validates IsAdmin() regardless
local gearAdmin = include("beatrun/sh/modules.lua").Get("gearAdmin")

local EXCLUDED_TUNING_FIELDS = { name = true, displayname = true, level = true, type = true }

local function DefaultConfig(folder)
  return include("beatrun/gears/" .. folder .. "/config.lua")
end

local function TunableFields(defaults)
  local fields = {}
  for field, value in pairs(defaults) do
    if not EXCLUDED_TUNING_FIELDS[field] and type(value) == "number" then
      fields[#fields + 1] = field
    end
  end
  table.sort(fields)
  return fields
end

local function BuildPanel(panel)
  panel:Clear()

  panel:Help("Presets")

  local presetRow = vgui.Create("DPanel", panel)
  presetRow:SetTall(26)
  presetRow.Paint = function() end
  panel:AddItem(presetRow)

  local presetCombo = vgui.Create("DComboBox", presetRow)
  presetCombo:Dock(LEFT)
  presetCombo:SetWide(150)
  for _, name in ipairs(gearAdmin.presetNames) do
    presetCombo:AddChoice(name)
  end

  local function RefreshLater()
    timer.Simple(0.1, function()
      if IsValid(panel) then BuildPanel(panel) end
    end)
  end

  local loadBtn = vgui.Create("DButton", presetRow)
  loadBtn:SetText("Load")
  loadBtn:Dock(LEFT)
  loadBtn:DockMargin(4, 0, 0, 0)
  loadBtn:SetWide(50)
  loadBtn.DoClick = function()
    local _, name = presetCombo:GetSelected()
    if not name or name == "" then return end
    RunConsoleCommand("brgears_admin_loadpreset", name)
    RefreshLater()
  end

  local deleteBtn = vgui.Create("DButton", presetRow)
  deleteBtn:SetText("Delete")
  deleteBtn:Dock(LEFT)
  deleteBtn:DockMargin(4, 0, 0, 0)
  deleteBtn:SetWide(50)
  deleteBtn.DoClick = function()
    local _, name = presetCombo:GetSelected()
    if not name or name == "" then return end
    RunConsoleCommand("brgears_admin_deletepreset", name)
    RefreshLater()
  end

  local saveRow = vgui.Create("DPanel", panel)
  saveRow:SetTall(26)
  saveRow.Paint = function() end
  panel:AddItem(saveRow)

  local presetNameEntry = vgui.Create("DTextEntry", saveRow)
  presetNameEntry:Dock(LEFT)
  presetNameEntry:SetWide(150)
  presetNameEntry:SetPlaceholderText("new preset name")

  local saveBtn = vgui.Create("DButton", saveRow)
  saveBtn:SetText("Save")
  saveBtn:Dock(LEFT)
  saveBtn:DockMargin(4, 0, 0, 0)
  saveBtn:SetWide(50)
  saveBtn.DoClick = function()
    local name = presetNameEntry:GetValue()
    if name == "" then return end
    RunConsoleCommand("brgears_admin_savepreset", name)
    RefreshLater()
  end

  panel:Help(" ")

  local _, folders = file.Find("beatrun/gears/*", "LUA")

  for _, folder in ipairs(folders) do
    if folder == "template" then continue end

    local defaults = DefaultConfig(folder)

    local category = vgui.Create("DCollapsibleCategory")
    category:SetLabel(defaults.displayname or folder)
    category:SetExpanded(false)

    local body = vgui.Create("DPanel", category)
    body:SetTall(64)
    body.Paint = function() end
    category:SetContents(body)
    panel:AddItem(category)

    local function AddRow()
      local row = vgui.Create("DPanel", body)
      row:Dock(TOP)
      row:SetTall(24)
      row:DockMargin(4, 2, 4, 0)
      row.Paint = function() end
      return row
    end

    local disabledRow = AddRow()
    local disabledBox = vgui.Create("DCheckBox", disabledRow)
    disabledBox:SetPos(0, 4)
    disabledBox:SetValue(gearAdmin.state.disabled[folder] == true)
    disabledBox.OnChange = function()
      RunConsoleCommand("brgears_admin_toggle", folder)
    end

    local disabledLabel = vgui.Create("DLabel", disabledRow)
    disabledLabel:SetText("Disabled (not equippable)")
    disabledLabel:SetPos(20, 4)
    disabledLabel:SizeToContents()

    local levelRow = AddRow()
    local levelLabel = vgui.Create("DLabel", levelRow)
    levelLabel:SetText("Level requirement")
    levelLabel:Dock(LEFT)
    levelLabel:SetWide(140)

    local levelWang = vgui.Create("DNumberWang", levelRow)
    levelWang:Dock(LEFT)
    levelWang:SetWide(60)
    levelWang:SetMin(1)
    levelWang:SetMax(999)
    levelWang:SetDecimals(0)
    levelWang:SetValue(gearAdmin.state.levelOverride[folder] or defaults.level or 1)
    levelWang.OnValueChanged = function(_, value)
      RunConsoleCommand("brgears_admin_setlevel", folder, math.Round(value))
    end

    local levelResetBtn = vgui.Create("DButton", levelRow)
    levelResetBtn:SetText("reset")
    levelResetBtn:Dock(LEFT)
    levelResetBtn:DockMargin(4, 0, 0, 0)
    levelResetBtn:SetWide(45)
    levelResetBtn.DoClick = function()
      RunConsoleCommand("brgears_admin_setlevel", folder, "default")
      RefreshLater()
    end

    local tuningRowCount = 2
    for _, field in ipairs(TunableFields(defaults)) do
      tuningRowCount = tuningRowCount + 1
      local row = AddRow()

      local label = vgui.Create("DLabel", row)
      label:SetText(field)
      label:Dock(LEFT)
      label:SetWide(140)

      local overrides = gearAdmin.state.tuning[folder]
      local current = (overrides and overrides[field] ~= nil) and overrides[field] or defaults[field]

      local wang = vgui.Create("DNumberWang", row)
      wang:Dock(LEFT)
      wang:SetWide(90)
      wang:SetMin(-999999)
      wang:SetMax(999999)
      wang:SetDecimals(2)
      wang:SetValue(current)
      wang.OnValueChanged = function(_, value)
        RunConsoleCommand("brgears_admin_settuning", folder, field, value)
      end

      local resetBtn = vgui.Create("DButton", row)
      resetBtn:SetText("reset")
      resetBtn:Dock(LEFT)
      resetBtn:DockMargin(4, 0, 0, 0)
      resetBtn:SetWide(45)
      resetBtn.DoClick = function()
        RunConsoleCommand("brgears_admin_settuning", folder, field, "default")
        RefreshLater()
      end
    end

    body:SetTall(tuningRowCount * 26)
  end
end

hook.Add("AddToolMenuTabs", "BeatrunGears_AdminTab", function()
  spawnmenu.AddToolTab("Beatrun", "Beatrun", "icon16/wrench.png")
end)

hook.Add("AddToolMenuCategories", "BeatrunGears_AdminCategory", function()
  spawnmenu.AddToolCategory("Beatrun", "Server", "Server")
end)

hook.Add("PopulateToolMenu", "BeatrunGears_AdminPanel", function()
  spawnmenu.AddToolMenuOption("Beatrun", "Server", "GearAdmin", "Gear Admin", "", "", BuildPanel)
end)
