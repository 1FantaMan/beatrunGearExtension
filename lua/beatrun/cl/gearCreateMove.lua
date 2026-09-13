local gearSlots = include("beatrun/sh/gearSlots.lua")
local keybinds = include("beatrun/sh/modules.lua").Get("gearKeybinds")

local isTyping = false
hook.Add("StartChat", "BeatrunGearsCreateMoveChatDetect", function() isTyping = true end)
hook.Add("FinishChat", "BeatrunGearsCreateMoveChatDetect", function() isTyping = false end)

hook.Add("CreateMove", "BeatrunGearsCreateMove", function(cmd)
	if isTyping or gui.IsConsoleVisible() then return end

	for slotName, slotInfo in pairs(gearSlots.SLOTS) do
		if not slotInfo.active then continue end

		if input.IsButtonDown(keybinds.Get(slotName, slotInfo.defaultKey)) then
			cmd:SetButtons(bit.bor(cmd:GetButtons(), slotInfo.bit))
		end
	end
end)
