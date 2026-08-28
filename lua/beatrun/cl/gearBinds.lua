local gearSlots = include("beatrun/sh/gearSlots.lua")
local keybinds = include("beatrun/sh/modules.lua").Get("gearKeybinds")

local keyStates = {}

local function OnThink()
  for slotName, slotInfo in pairs(gearSlots.SLOTS) do
    if not slotInfo.active then continue end

    local isDown = input.IsButtonDown(keybinds.Get(slotName, slotInfo.defaultKey))
    local pressed = isDown and not keyStates[slotName]
    local released = keyStates[slotName] and not isDown
    keyStates[slotName] = isDown

    if pressed then
      net.Start("BeatrunGearsKeyPress")
        net.WriteString(slotName)
      net.SendToServer()
    end

    if released then
      net.Start("BeatrunGearsKeyRelease")
        net.WriteString(slotName)
      net.SendToServer()
    end
  end
end

hook.Add("Think", "BeatrunGearsThink", OnThink)