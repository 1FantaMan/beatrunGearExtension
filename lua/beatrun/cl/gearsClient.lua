local gearsHandler = include("beatrun/sh/modules.lua").Get("gearsHandler")

local RECONCILE_WINDOW = 0.5

clientGears = {}

local function OnGearChange()
	local slot = net.ReadString()
	local newName = net.ReadString()

	if clientGears[slot] and clientGears[slot] ~= "" then
		gearsHandler.GetClientGear(clientGears[slot].name).destroy(LocalPlayer(), clientGears[slot].state)
	end

	if newName ~= "" then
		local gear = gearsHandler.GetClientGear(newName)
		if gear == nil then
			return
		end

		clientGears[slot] = { name = newName, state = gear.init(LocalPlayer()) }
	else
		clientGears[slot] = ""
	end
end

local function OnGearActivate()
  local slot = net.ReadString()
  local name = net.ReadString()
  local serverShared = net.ReadTable()

  local entry = clientGears[slot]
  if entry == nil or entry == "" then return end

  entry.state.shared = entry.state.shared or {}
  table.Merge(entry.state.shared, serverShared)

  local alreadyPredicted = entry.lastPredictedActivate and (CurTime() - entry.lastPredictedActivate) < RECONCILE_WINDOW
  entry.lastPredictedActivate = nil

  if not alreadyPredicted then
    gearsHandler.GetClientGear(entry.name).activate(LocalPlayer(), entry.state)
  end

  entry.lastActivateTime = CurTime()
end

local function OnSetupMoveClient(ply, mv, cmd)
	if ply ~= LocalPlayer() then return end

	for slot, entry in pairs(clientGears) do
		if entry == "" then continue end

		local gear = gearsHandler.GetClientGear(entry.name)
		if gear and gear.onSetupMove then
			gear.onSetupMove(ply, mv, entry.state)
		end
	end
end

hook.Add("SetupMove", "BeatrunGearsSetupMoveClient", OnSetupMoveClient)
net.Receive("BeatrunGearsClientGearChanged", OnGearChange)
net.Receive("BeatrunGearsClientActivate", OnGearActivate)
