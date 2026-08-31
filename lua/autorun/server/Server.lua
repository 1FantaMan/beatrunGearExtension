if engine.ActiveGamemode() ~= "beatrun" then
  print("current gamemode is not beatrun, mod will not run.")
  return
end

util.AddNetworkString("BeatrunGearsClientLevel")
util.AddNetworkString("BeatrunGearsClientGearChanged")
util.AddNetworkString("BeatrunGearsClientActivate")
util.AddNetworkString("BeatrunGearsKeyPress")
util.AddNetworkString("BeatrunGearsKeyRelease")
util.AddNetworkString("BeatrunGearsAdminState")

local playerHandler = include("beatrun/sv/playerHandler.lua")
local gearAdmin = include("beatrun/sh/modules.lua").Get("gearAdmin")

local lastClientLevelTime = 0

local ACTIVATE_NET_INTERVAL = 0.2
local ACTIVATE_FLOOD_LIMIT = 5
local ACTIVATE_FLOOD_BLOCK_DURATION = 5

local function conCmdEquipGear(ply, cmd, args)
  if not IsValid(ply) then
    return
  end

  if args[1] == nil or args[2] == nil then
    print("Usage: brgears_equip <slot> <gear>")
    return
  end

  local _, msg = playerHandler.EquipGear(ply, args[1], args[2])
  ply:ChatPrint(msg)
end

local function conCmdUnequipGear(ply, cmd, args)
  if not IsValid(ply) then
    return
  end

  if args[1] == nil then
    print("Usage: brgears_unequip <slot>")
    return
  end

  local _, msg = playerHandler.UnequipGear(ply, args[1])
  ply:ChatPrint(msg)
end

local function OnClientLevel(_, ply)
  if game.IsDedicated() then return end

  if CurTime() - lastClientLevelTime < 5 then return end
  lastClientLevelTime = CurTime()

  local data = playerHandler.plys[ply:SteamID64()]
  if data == nil then return end

  local newLevel = net.ReadInt(16)
  data.beatrunlevel = newLevel
end

local function OnClientKeyPress(_, ply)
  local data = playerHandler.plys[ply:SteamID64()]
  if data == nil then return end

  if data.floodBlockedUntil and CurTime() < data.floodBlockedUntil then
    return
  end

  if CurTime() - (data.lastActivateNetTime or 0) < ACTIVATE_NET_INTERVAL then
    data.floodViolations = (data.floodViolations or 0) + 1

    if data.floodViolations >= ACTIVATE_FLOOD_LIMIT then
      data.floodBlockedUntil = CurTime() + ACTIVATE_FLOOD_BLOCK_DURATION
      data.floodViolations = 0
      print("[BeatrunGears] Sending activations too fast, blocked for " .. ACTIVATE_FLOOD_BLOCK_DURATION .. "s.")
    end

    return
  end

  data.floodViolations = 0
  data.lastActivateNetTime = CurTime()

  local slot = net.ReadString()
  playerHandler.OnGearKeyPress(ply, slot)
end

local function OnClientKeyRelease(_, ply)
  local slot = net.ReadString()
  playerHandler.OnGearKeyRelease(ply, slot)
end

local function conCmdAdminToggle(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil then
    print("Usage: brgears_admin_toggle <gear>")
    return
  end

  gearAdmin.SetDisabled(args[1], not gearAdmin.IsDisabled(args[1]))
  gearAdmin.Broadcast()
end

local function conCmdAdminSetLevel(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil or args[2] == nil then
    print("Usage: brgears_admin_setlevel <gear> <level|default>")
    return
  end

  gearAdmin.SetLevelOverride(args[1], args[2] == "default" and nil or tonumber(args[2]))
  gearAdmin.Broadcast()
end

local function conCmdAdminSetTuning(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil or args[2] == nil or args[3] == nil then
    print("Usage: brgears_admin_settuning <gear> <field> <value|default>")
    return
  end

  if args[3] == "default" then
    gearAdmin.ClearTuning(args[1], args[2])
  else
    gearAdmin.SetTuning(args[1], args[2], tonumber(args[3]))
  end

  gearAdmin.Broadcast()
end

local function conCmdAdminSavePreset(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil then
    print("Usage: brgears_admin_savepreset <name>")
    return
  end

  gearAdmin.SavePreset(args[1])
  gearAdmin.Broadcast()
end

local function conCmdAdminLoadPreset(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil then
    print("Usage: brgears_admin_loadpreset <name>")
    return
  end

  gearAdmin.LoadPreset(args[1])
  gearAdmin.Broadcast()
end

local function conCmdAdminDeletePreset(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end
  if args[1] == nil then
    print("Usage: brgears_admin_deletepreset <name>")
    return
  end

  gearAdmin.DeletePreset(args[1])
  gearAdmin.Broadcast()
end

local function conCmdAdminResetDefault(ply, cmd, args)
  if not gearAdmin.CanManage(ply) then return end

  gearAdmin.ResetToDefault()
  gearAdmin.Broadcast()
end

for _, fileName in ipairs(file.Find("beatrun/cl/*.lua", "LUA")) do
  AddCSLuaFile("beatrun/cl/" .. fileName)
end

for _, fileName in ipairs(file.Find("beatrun/sh/*.lua", "LUA")) do
  AddCSLuaFile("beatrun/sh/" .. fileName)
end

for _, fileName in ipairs(file.Find("beatrun/sh/modules/*.lua", "LUA")) do
  AddCSLuaFile("beatrun/sh/modules/" .. fileName)
end

local _, folders = file.Find("beatrun/gears/*", "LUA")
for _, folderName in ipairs(folders) do
  if folderName == "template" then continue end

  AddCSLuaFile("beatrun/gears/" .. folderName .. "/client.lua")
  AddCSLuaFile("beatrun/gears/" .. folderName .. "/config.lua")

  local visualFiles = file.Find("beatrun/gears/" .. folderName .. "/visuals/*.lua", "LUA")
  for _, fileName in ipairs(visualFiles) do
    AddCSLuaFile("beatrun/gears/" .. folderName .. "/visuals/" .. fileName)
  end

  for _, ext in ipairs({ "wav", "mp3" }) do
    local soundFiles = file.Find("sound/beatrun/gears/" .. folderName .. "/*." .. ext, "GAME")
    for _, fileName in ipairs(soundFiles) do
      resource.AddSingleFile("sound/beatrun/gears/" .. folderName .. "/" .. fileName)
    end
  end

  for _, ext in ipairs({ "png", "vmt" }) do
    local materialFiles = file.Find("materials/beatrun/gears/" .. folderName .. "/*." .. ext, "GAME")
    for _, fileName in ipairs(materialFiles) do
      resource.AddSingleFile("materials/beatrun/gears/" .. folderName .. "/" .. fileName)
    end
  end
end

hook.Add("PlayerInitialSpawn", "BeatrunGearsSpawn", playerHandler.OnPlayerSpawn)
hook.Add("PlayerInitialSpawn", "BeatrunGearsAdminStateSync", gearAdmin.SendTo)
net.Receive("BeatrunGearsClientLevel", OnClientLevel)
net.Receive("BeatrunGearsKeyPress", OnClientKeyPress)
net.Receive("BeatrunGearsKeyRelease", OnClientKeyRelease)
concommand.Add("brgears_equip", conCmdEquipGear)
concommand.Add("brgears_unequip", conCmdUnequipGear)
concommand.Add("brgears_admin_toggle", conCmdAdminToggle)
concommand.Add("brgears_admin_setlevel", conCmdAdminSetLevel)
concommand.Add("brgears_admin_settuning", conCmdAdminSetTuning)
concommand.Add("brgears_admin_savepreset", conCmdAdminSavePreset)
concommand.Add("brgears_admin_loadpreset", conCmdAdminLoadPreset)
concommand.Add("brgears_admin_deletepreset", conCmdAdminDeletePreset)
concommand.Add("brgears_admin_resetdefault", conCmdAdminResetDefault)
