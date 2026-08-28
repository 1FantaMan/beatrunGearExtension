local GEARS_DIR = "beatrun/gears/"
local serverCache = {}
local clientCache = {}

local mod = {}

function mod.GetServerGear(name)
  if not SERVER then return end

  if serverCache[name] then
    return serverCache[name]
  end

  local folder = GEARS_DIR .. name .. "/"
  local initPath = folder .. "server.lua"

  if not file.Exists(initPath, "LUA") then
    return nil
  end

  local gear = include(initPath)

  local configPath = folder .. "config.lua"
  gear.config = file.Exists(configPath, "LUA") and include(configPath) or {}

  gear.name = name
  serverCache[name] = gear

  return gear
end

function mod.GetClientGear(name)
  if not CLIENT then return end

  if clientCache[name] then
    return clientCache[name]
  end

  local folder = GEARS_DIR .. name .. "/"
  local initPath = folder .. "client.lua"

  if not file.Exists(initPath, "LUA") then
    return nil
  end

  local gear = include(initPath)

  local configPath = folder .. "config.lua"
  gear.config = file.Exists(configPath, "LUA") and include(configPath) or {}

  gear.name = name
  clientCache[name] = gear

  return gear
end

return mod