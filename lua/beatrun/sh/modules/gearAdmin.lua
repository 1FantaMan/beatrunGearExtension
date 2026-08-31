-- server-authoritative gear admin config (disabled gears, level overrides, tuning, presets); only the server mutates it, then broadcasts to clients
local gearsHandler = include("beatrun/sh/modules.lua").Get("gearsHandler")

local STATE_FILE = "beatrun_gear_admin_state.txt"
local PRESETS_FILE = "beatrun_gear_admin_presets.txt"

local mod = {}

local function NewState()
  return { disabled = {}, levelOverride = {}, tuning = {} }
end

local function ReadJSON(path)
  local data = file.Exists(path, "DATA") and file.Read(path, "DATA")
  return data and util.JSONToTable(data) or nil
end

local function DeepCopy(tbl)
  return util.JSONToTable(util.TableToJSON(tbl))
end

mod.state = (SERVER and ReadJSON(STATE_FILE)) or NewState()
mod.presets = (SERVER and ReadJSON(PRESETS_FILE)) or {}

local function SaveState()
  file.Write(STATE_FILE, util.TableToJSON(mod.state))
end

local function SavePresets()
  file.Write(PRESETS_FILE, util.TableToJSON(mod.presets))
end

local function GetGear(name)
  return SERVER and gearsHandler.GetServerGear(name) or gearsHandler.GetClientGear(name)
end

-- always resets to the pristine defaultConfig first, then layers current overrides on top - so
-- clearing an override (or switching to a state that no longer has one) actually reverts it,
-- instead of leaving the field stuck at whatever it was last tuned to
local function ApplyTuning(name)
  local gear = GetGear(name)
  if not gear then return end

  for field, value in pairs(gear.defaultConfig) do
    gear.config[field] = value
  end

  local overrides = mod.state.tuning[name]
  if overrides then
    for field, value in pairs(overrides) do
      gear.config[field] = value
    end
  end
end

local function ApplyAllTuning()
  for name in pairs(mod.state.tuning) do
    ApplyTuning(name)
  end
end

ApplyAllTuning()

local PRIVILEGE_NAME = "BeatrunGears - Manage Admin Settings"

-- CAMI is the shared privilege interface ULX/SAM/serverguard implement; falls back to vanilla IsAdmin() if none are running
if SERVER and CAMI then
  CAMI.RegisterPrivilege({
    Name = PRIVILEGE_NAME,
    MinAccess = "admin",
    Description = "Manage Beatrun Gears admin settings (disable gears, level overrides, tuning, presets).",
  })
end

function mod.CanManage(ply)
  if not IsValid(ply) then return true end -- server console

  if CAMI then
    local access = CAMI.PlayerHasAccess(ply, PRIVILEGE_NAME, nil)
    if access ~= nil then return access end
  end

  return ply:IsAdmin()
end

function mod.IsDisabled(name)
  return mod.state.disabled[name] == true
end

function mod.GetLevel(gear)
  return mod.state.levelOverride[gear.name] or gear.config.level
end

function mod.SetDisabled(name, disabled)
  mod.state.disabled[name] = disabled and true or nil
  SaveState()
end

function mod.SetLevelOverride(name, level)
  mod.state.levelOverride[name] = level
  SaveState()
end

function mod.SetTuning(name, field, value)
  mod.state.tuning[name] = mod.state.tuning[name] or {}
  mod.state.tuning[name][field] = value
  ApplyTuning(name)
  SaveState()
end

function mod.ClearTuning(name, field)
  if mod.state.tuning[name] then
    mod.state.tuning[name][field] = nil
  end
  SaveState()
end

function mod.SavePreset(presetName)
  mod.presets[presetName] = DeepCopy(mod.state)
  SavePresets()
end

-- reapplies every gear tuned by either the old or new state, not just the new one, so a gear
-- that had an override before but doesn't in the loaded preset actually reverts to default
local function ApplyTuningDiff(previousTuning)
  local names = {}
  for name in pairs(previousTuning) do names[name] = true end
  for name in pairs(mod.state.tuning) do names[name] = true end
  for name in pairs(names) do ApplyTuning(name) end
end

function mod.LoadPreset(presetName)
  local preset = mod.presets[presetName]
  if not preset then return false end

  local previousTuning = mod.state.tuning
  mod.state = DeepCopy(preset)
  SaveState()
  ApplyTuningDiff(previousTuning)

  return true
end

function mod.ResetToDefault()
  local previousTuning = mod.state.tuning
  mod.state = NewState()
  SaveState()
  ApplyTuningDiff(previousTuning)
end

function mod.DeletePreset(presetName)
  mod.presets[presetName] = nil
  SavePresets()
end

local function PresetNames()
  local names = {}
  for name in pairs(mod.presets) do
    names[#names + 1] = name
  end
  return names
end

if SERVER then
  local function Payload()
    return util.TableToJSON({ state = mod.state, presetNames = PresetNames() })
  end

  function mod.SendTo(ply)
    net.Start("BeatrunGearsAdminState")
      net.WriteString(Payload())
    net.Send(ply)
  end

  function mod.Broadcast()
    net.Start("BeatrunGearsAdminState")
      net.WriteString(Payload())
    net.Send(player.GetAll())
  end
else
  mod.presetNames = {}

  -- gearAdminMenu.lua sets this to rebuild itself whenever fresh state actually arrives, instead
  -- of guessing a fixed delay after sending a concommand
  mod.OnStateUpdated = nil

  net.Receive("BeatrunGearsAdminState", function()
    local payload = util.JSONToTable(net.ReadString())
    mod.state = payload.state
    mod.presetNames = payload.presetNames
    ApplyAllTuning()

    if mod.OnStateUpdated then mod.OnStateUpdated() end
  end)
end

return mod
