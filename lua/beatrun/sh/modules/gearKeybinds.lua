-- client-only; persists per-slot key overrides so the settings menu and gearBinds.lua share the same live table
local mod = {}

local FILE_NAME = "beatrun_gear_keybinds.txt"

local function Load()
  local data = file.Read(FILE_NAME, "DATA")
  return (data and util.JSONToTable(data)) or {}
end

local overrides = Load()

function mod.Get(slot, defaultKey)
  return overrides[slot] or defaultKey
end

function mod.Set(slot, key)
  overrides[slot] = key
  file.Write(FILE_NAME, util.TableToJSON(overrides))
end

function mod.Reset(slot)
  overrides[slot] = nil
  file.Write(FILE_NAME, util.TableToJSON(overrides))
end

return mod
