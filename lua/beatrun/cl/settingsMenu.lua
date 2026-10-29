local gearSlots = include("beatrun/sh/gearSlots.lua")
local keybinds = include("beatrun/sh/modules.lua").Get("gearKeybinds")
include("beatrun/gears/grappler/visuals/ropeColor.lua")

local KEYBIND_ROWS = {
	{ slot = "left", label = "LEFT ARM" },
	{ slot = "back", label = "BACK" },
	{ slot = "leg",  label = "LEG" },
}

local SCROLLER_ROWS = {
	{
		convar = "brgears_screenshake_scale",
		label = "Screen Shake",
		min = 0,
		max = 5,
		decimals = 2,
		default = 1,
	},
}

local listeningSlot = nil
local listenStartTime = 0
local LISTEN_DELAY = 0.25

local function ScanForKeyPress()
	for key = KEY_FIRST, KEY_LAST do
		if key == KEY_C then continue end

		if input.IsButtonDown(key) then return key end
	end

	for key = MOUSE_FIRST, MOUSE_LAST do
		if input.IsButtonDown(key) then return key end
	end

	return nil
end

local function KeySlots(listPanel)
	local S = BeatrunUI.S

	local function AddKeybindRow(slotName, label)
		local defaultKey = gearSlots.SLOTS[slotName].defaultKey

		local row = vgui.Create("DButton", listPanel)
		row:SetText("")
		row:Dock(TOP)
		row:SetTall(S(30))
		row:DockMargin(0, 0, 0, 1)

		row.Paint = function(self, w, h)
			local listening = listeningSlot == slotName

			surface.SetDrawColor(0, 0, 0, 120)
			surface.DrawRect(0, 0, w, h)

			surface.SetFont("BeatrunUI")
			local _, th = surface.GetTextSize(label)
			local textY = (h - th) / 2

			surface.SetTextColor(color_white)
			surface.SetTextPos(S(10), textY)
			surface.DrawText(label)

			local rightText = listening and "PRESS A KEY..." or
				(input.GetKeyName(keybinds.Get(slotName, defaultKey)) or "UNBOUND")
			local tw = surface.GetTextSize(rightText)
			surface.SetTextColor(listening and Color(255, 210, 90) or Color(180, 180, 180))
			surface.SetTextPos(w - tw - S(10), textY)
			surface.DrawText(rightText)
		end

		row.DoClick = function()
			listeningSlot = slotName
			listenStartTime = CurTime()
		end
	end

	for _, entry in ipairs(KEYBIND_ROWS) do
		AddKeybindRow(entry.slot, entry.label)
	end
end

local function GrapplerRopeColorer(listPanel)
	local mixer = vgui.Create("DColorMixer", listPanel)
	mixer:Dock(TOP)
	mixer:SetTall(BeatrunUI.S(200))
	mixer:DockMargin(0, 0, 0, BeatrunUI.S(10))
	mixer:SetPalette(false)
	mixer:SetAlphaBar(false)
	mixer:SetWangs(true)
	mixer:SetColor(Color(
		GetConVar("brgears_grappler_rope_r"):GetInt(),
		GetConVar("brgears_grappler_rope_g"):GetInt(),
		GetConVar("brgears_grappler_rope_b"):GetInt()
	))
	mixer.ValueChanged = function(_, color)
		RunConsoleCommand("brgears_grappler_rope_r", math.Round(color.r))
		RunConsoleCommand("brgears_grappler_rope_g", math.Round(color.g))
		RunConsoleCommand("brgears_grappler_rope_b", math.Round(color.b))
	end
end

local function Sliders(listPanel)
	local function AddSliderRow(entry)
		local slider = vgui.Create("DNumSlider", listPanel)
		slider:Dock(TOP)
		slider:SetTall(BeatrunUI.S(30))
		slider:DockMargin(0, 0, 0, 1)
		slider:SetText(entry.label)
		slider:SetMin(entry.min)
		slider:SetMax(entry.max)
		slider:SetDecimals(entry.decimals)
		slider:SetValue(GetConVar(entry.convar):GetFloat())
		slider.OnValueChanged = function(_, value)
			RunConsoleCommand(entry.convar, value)
		end
	end

	for _, entry in ipairs(SCROLLER_ROWS) do
		AddSliderRow(entry)
	end
end

hook.Add("Think", "BeatrunGears_SettingsKeyCapture", function()
	if not listeningSlot then return end
	if CurTime() - listenStartTime < LISTEN_DELAY then return end

	local key = ScanForKeyPress()
	if not key then return end

	if key ~= KEY_ESCAPE then
		keybinds.Set(listeningSlot, key)
	end

	listeningSlot = nil
end)

local function main(icon, window)
	local S = BeatrunUI.S

	-- DesktopWindows sizes are fixed at file load, before Beatrun's UI exists, so rescale here
	window:SetSize(S(400), S(400))
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
	title:SetText("SETTINGS")
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
	closeBtn.Paint = function() end
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

	AddSectionHeader("KEYBINDS")
	KeySlots(listPanel)

	AddSectionHeader("SCROLLERS")
	Sliders(listPanel)

	AddSectionHeader("GRAPPLE ROPE COLOR")
	GrapplerRopeColorer(listPanel)
end

list.Set("DesktopWindows", "BeatrunSettingsMenu", {
	title = "Settings",
	icon = "icon16/cog.png", -- placeholder, swap later

	width = 400,
	height = 400,
	onewindow = true,

	init = main
})
