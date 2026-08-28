-- client-only, but lives alongside the other shared modules since beatrun/sh/modules/* is already
-- synced to clients; persists per-slot key overrides so the settings menu and gearBinds.lua's
-- Think poller both read/write the same live table via modules.lua's cache
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
