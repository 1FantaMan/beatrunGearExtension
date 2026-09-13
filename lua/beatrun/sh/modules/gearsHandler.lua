local GEARS_DIR = "beatrun/gears/"
local serverCache = {}
local clientCache = {}
local sharedCache = {}

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
	gear.defaultConfig = table.Copy(gear.config) -- pristine snapshot, so admin tuning can revert cleanly

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
	gear.defaultConfig = table.Copy(gear.config) -- pristine snapshot, so admin tuning can revert cleanly

	gear.name = name
	clientCache[name] = gear

	return gear
end

-- onSetupMove lives here instead of duplicated in server.lua/client.lua, so both realms run the same code
function mod.GetSharedGear(name)
	if sharedCache[name] then
		return sharedCache[name]
	end

	local folder = GEARS_DIR .. name .. "/"
	local path = folder .. "shared.lua"

	if not file.Exists(path, "LUA") then
		return nil
	end

	local gear = include(path)

	local configPath = folder .. "config.lua"
	gear.config = file.Exists(configPath, "LUA") and include(configPath) or {}

	gear.name = name
	sharedCache[name] = gear

	return gear
end

return mod
