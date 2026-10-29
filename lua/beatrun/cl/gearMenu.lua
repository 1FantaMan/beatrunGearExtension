local modules = include("beatrun/sh/modules.lua")
local gearsHandler = modules.Get("gearsHandler")
local gearAdmin = modules.Get("gearAdmin")

local SLOTS_ORDERED = {
	{ slot = "right", label = "RIGHT ARM" },
	{ slot = "left",  label = "LEFT ARM" },
	{ slot = "back",  label = "BACK" },
	{ slot = "leg",   label = "LEG" },
}

local AUTOEQUIP_FILE = "beatrun_gearmenu_autoequip.txt"
local starMat = Material("beatrun/CMenu/Star.png")

local function LoadAutoEquip()
	local data = file.Read(AUTOEQUIP_FILE, "DATA")
	return (data and util.JSONToTable(data)) or {}
end

local function SaveAutoEquip(tbl)
	file.Write(AUTOEQUIP_FILE, util.TableToJSON(tbl))
end

local autoEquip = LoadAutoEquip() -- { [slot] = gearName }

local function RunAutoEquip()
	for slot, name in pairs(autoEquip) do
		local gear = gearsHandler.GetClientGear(name)
		if gear and LocalPlayer():GetLevel() >= gearAdmin.GetLevel(gear) then
			RunConsoleCommand("brgears_equip", slot, name)
		end
	end
end

-- net messages sent from PlayerInitialSpawn can arrive before the client is ready, so the client asks for
-- admin state itself; auto-equip waits for it because level overrides decide what's locked
hook.Add("InitPostEntity", "BeatrunGearMenu_AutoEquip", function()
	hook.Add("BeatrunGearsAdminStateUpdated", "BeatrunGearMenu_AutoEquip", function()
		hook.Remove("BeatrunGearsAdminStateUpdated", "BeatrunGearMenu_AutoEquip")
		RunAutoEquip()
	end)

	RunConsoleCommand("brgears_admin_refresh")
end)

local function main(icon, window)
	local S = BeatrunUI.S

	-- DesktopWindows sizes are fixed at file load, before Beatrun's UI exists, so rescale here
	window:SetSize(S(500), S(600))
	window:Center()
	window:SetTitle("")
	window:ShowCloseButton(false)
	window.Paint = function(self, w, h)
		surface.SetDrawColor(20, 20, 20, 240)
		surface.DrawRect(0, 0, w, h)

		surface.SetDrawColor(255, 255, 255, 200)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end

	local title = vgui.Create("DLabel", window)
	title:SetText("GEAR")
	title:SetFont("BeatrunUILarge")
	title:SetTextColor(color_white)
	title:SetContentAlignment(5) -- centered
	title:Dock(TOP)
	title:SetTall(S(50))

	local closeBtn = vgui.Create("DButton", window)
	closeBtn:SetText("X")
	closeBtn:SetFont("BeatrunUI")
	closeBtn:SetTextColor(color_white)
	closeBtn:SetSize(S(24), S(24))
	closeBtn:SetPos(window:GetWide() - S(30), S(10))
	closeBtn.Paint = function() end -- no button background, just the X text
	closeBtn.DoClick = function()
		window:Close()
	end

	local listPanel = vgui.Create("DScrollPanel", window)
	listPanel:Dock(FILL)
	listPanel:DockMargin(S(10), 0, S(10), S(10))

	local function AddSectionHeader(label)
		local header = vgui.Create("DLabel", listPanel)
		header:SetText(label)
		header:SetFont("BeatrunUI")
		header:SetTextColor(Color(180, 180, 180))
		header:Dock(TOP)
		header:SetTall(S(28))
		header:DockMargin(0, S(10), 0, S(2))
	end

	local FAVORITE_ICON_SIZE = S(22)
	local FAVORITE_ICON_PADDING = S(4)

	local function AddGearRow(slot, gear)
		local isEquipped = LocalPlayer():GetNW2String("brgear_" .. slot, "") == gear.name
		local requiredLevel = gearAdmin.GetLevel(gear)
		local isLocked = LocalPlayer():GetLevel() < requiredLevel

		local row = vgui.Create("DButton", listPanel)
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(S(30))
		row:DockMargin(0, 0, 0, 1)

		local textColor = isEquipped and color_white or Color(180, 180, 180)

		local nameLabel = vgui.Create("DLabel", row)
		nameLabel:SetFont("BeatrunUI")
		nameLabel:SetTextColor(textColor)
		nameLabel:SetText(gear.config.displayname)
		nameLabel:SizeToContents()

		local levelLabel = vgui.Create("DLabel", row)
		levelLabel:SetFont("BeatrunUI")
		levelLabel:SetTextColor(textColor)
		levelLabel:SetText("LEVEL " .. requiredLevel)
		levelLabel:SizeToContents()

		row.PerformLayout = function(self, w, h)
			local y = (h - nameLabel:GetTall()) / 2
			local half = w / 2

			nameLabel:SetPos((half - nameLabel:GetWide()) / 2, y)
			levelLabel:SetPos(half + (half - levelLabel:GetWide()) / 2, y)
		end

		row.Paint = function(self, w, h)
			surface.SetDrawColor(isEquipped and Color(255, 255, 255, 40) or Color(0, 0, 0, 120))
			surface.DrawRect(0, 0, w, h)

			-- thin divider at the same x on every row - reads as one continuous line down the whole table
			surface.SetDrawColor(255, 255, 255, 60)
			surface.DrawRect(w / 2, 0, 1, h)

			if autoEquip[slot] == gear.name then
				surface.SetDrawColor(255, 255, 255)
				surface.SetMaterial(starMat)
				surface.DrawTexturedRect(FAVORITE_ICON_PADDING, (h - FAVORITE_ICON_SIZE) / 2, FAVORITE_ICON_SIZE,
					FAVORITE_ICON_SIZE)
			end
		end

		row.PaintOver = function(self, w, h)
			if not isLocked then return end

			surface.SetDrawColor(0, 0, 0, 235)
			surface.DrawRect(0, 0, w, h)

			surface.SetFont("BeatrunUI")
			surface.SetTextColor(Color(220, 40, 40))
			local tw, th = surface.GetTextSize("LOCKED")
			surface.SetTextPos((w - tw) / 2, (h - th) / 2)
			surface.DrawText("LOCKED")
		end

		row.DoClick = function()
			if isLocked then return end

			if isEquipped then
				RunConsoleCommand("brgears_unequip", slot)
			else
				RunConsoleCommand("brgears_equip", slot, gear.name)
			end

			timer.Simple(0.05, RefreshGearList)
		end

		row.DoRightClick = function()
			if isLocked then return end

			if autoEquip[slot] == gear.name then
				autoEquip[slot] = nil
			else
				autoEquip[slot] = gear.name
			end

			SaveAutoEquip(autoEquip)
			RefreshGearList()
		end
	end

	function RefreshGearList()
		listPanel:Clear()

		local _, folders = file.Find("beatrun/gears/*", "LUA")

		for _, entry in ipairs(SLOTS_ORDERED) do
			AddSectionHeader(entry.label)

			for _, folder in ipairs(folders) do
				if folder == "template" then continue end

				local gear = gearsHandler.GetClientGear(folder)
				if not gear or gear.config.type ~= entry.slot then continue end

				AddGearRow(entry.slot, gear)
			end
		end
	end

	RefreshGearList()
end

list.Set("DesktopWindows", "BeatrunGearMenu", {
	title = "Gears",
	icon = "beatrun/CMenu/Star.png",

	width = 500,
	height = 600,
	onewindow = true,

	init = main
})
