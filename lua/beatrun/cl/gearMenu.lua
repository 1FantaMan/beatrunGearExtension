local gearsHandler = include("beatrun/sh/modules.lua").Get("gearsHandler")

surface.CreateFont("BeatrunGearMenuFont", {
	font = "x14y24pxHeadUpDaisy",
	shadow = true,
	scanlines = 2,
	weight = 500,
	antialias = false,
	size = 22,
})

surface.CreateFont("BeatrunGearMenuTitleFont", {
	font = "x14y24pxHeadUpDaisy",
	shadow = true,
	scanlines = 2,
	weight = 500,
	antialias = false,
	size = 36,
})

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
		RunConsoleCommand("brgears_equip", slot, name)
	end
end

hook.Add("InitPostEntity", "BeatrunGearMenu_AutoEquip", function()
	local done = false

	net.Receive("BeatrunGearsLevelSynced", function()
		if done then return end
		done = true
		RunAutoEquip()
	end)

	timer.Simple(5, function()
		if done then return end
		done = true
		RunAutoEquip()
	end)
end)

local function main(icon, window)
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
	title:SetFont("BeatrunGearMenuTitleFont")
	title:SetTextColor(color_white)
	title:SetContentAlignment(5) -- centered
	title:Dock(TOP)
	title:SetTall(50)

	local closeBtn = vgui.Create("DButton", window)
	closeBtn:SetText("X")
	closeBtn:SetFont("BeatrunGearMenuFont")
	closeBtn:SetTextColor(color_white)
	closeBtn:SetSize(24, 24)
	closeBtn:SetPos(window:GetWide() - 30, 10)
	closeBtn.Paint = function() end -- no button background, just the X text
	closeBtn.DoClick = function()
		window:Close()
	end

	local listPanel = vgui.Create("DScrollPanel", window)
	listPanel:Dock(FILL)
	listPanel:DockMargin(10, 0, 10, 10)

	local function AddSectionHeader(label)
		local header = vgui.Create("DLabel", listPanel)
		header:SetText(label)
		header:SetFont("BeatrunGearMenuFont")
		header:SetTextColor(Color(180, 180, 180))
		header:Dock(TOP)
		header:SetTall(28)
		header:DockMargin(0, 10, 0, 2)
	end

	local FAVORITE_ICON_SIZE = 22
	local FAVORITE_ICON_PADDING = 4

	local function AddGearRow(slot, gear)
		local isEquipped = LocalPlayer():GetNW2String("brgear_" .. slot, "") == gear.name
		local isLocked = LocalPlayer():GetLevel() < gear.config.level

		local row = vgui.Create("DButton", listPanel)
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(30)
		row:DockMargin(0, 0, 0, 1)

		local textColor = isEquipped and color_white or Color(180, 180, 180)

		local nameLabel = vgui.Create("DLabel", row)
		nameLabel:SetFont("BeatrunGearMenuFont")
		nameLabel:SetTextColor(textColor)
		nameLabel:SetText(gear.config.displayname)
		nameLabel:SizeToContents()

		local levelLabel = vgui.Create("DLabel", row)
		levelLabel:SetFont("BeatrunGearMenuFont")
		levelLabel:SetTextColor(textColor)
		levelLabel:SetText("LEVEL " .. gear.config.level)
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

			surface.SetFont("BeatrunGearMenuFont")
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
