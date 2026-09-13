local modules = include("beatrun/sh/modules.lua")

-- lazy so include()ing this never re-enters a module that's still mid-load (gearAdmin -> gearsHandler -> here -> gearAdmin looped and crashed)
local util = setmetatable({}, {
	__index = function(t, name)
		local value = modules.Get(name)
		rawset(t, name, value)
		return value
	end,
})

-- these globals only exist in the fork's cl/*.lua
if CLIENT then
	-- global so this survives util.lua being include()d fresh by every gear (include() doesn't cache) - otherwise each
	-- gear's RegisterSafeAnim call would populate a throwaway table and only the last-loaded gear's hooks would stick
	BeatrunGearsAnimSafety = BeatrunGearsAnimSafety or {
		-- slide/wallrun grab BodyAnim directly assuming a climbanim model, corrupting a custom one mid-anim
		CONFLICTING_TRICK_EVENTS = {
			slide = true,
			slide45 = true,
			wallrunv = true,
			wallrunh = true,
		},
		SAFE_ANIM_EVENTS = {},
		ANIM_HIDE_BODY = {},
		ANIM_FALLBACK_EVENT = {},
	}

	local CONFLICTING_TRICK_EVENTS = BeatrunGearsAnimSafety.CONFLICTING_TRICK_EVENTS
	local SAFE_ANIM_EVENTS = BeatrunGearsAnimSafety.SAFE_ANIM_EVENTS
	local ANIM_HIDE_BODY = BeatrunGearsAnimSafety.ANIM_HIDE_BODY
	local ANIM_FALLBACK_EVENT = BeatrunGearsAnimSafety.ANIM_FALLBACK_EVENT

	-- fallbackEvent=false means go idle (RemoveBodyAnim) instead of another trick pose - "jumpstill" floats, wrong once grounded
	local function RunFallback(event)
		local fallback = ANIM_FALLBACK_EVENT[event]

		if fallback then
			ParkourEvent(fallback, LocalPlayer(), true)
		else
			RemoveBodyAnim()
		end
	end

	-- data: model, fallbackEvent="jumpstill"|false, transitioncheck(ply)->bool, conflictsWith={event,...}, hideBody=true, onStart(ply), deleteonend
	function util.RegisterSafeAnim(event, data)
		SAFE_ANIM_EVENTS[event] = true
		ANIM_FALLBACK_EVENT[event] = data.fallbackEvent == nil and "jumpstill" or data.fallbackEvent
		ANIM_HIDE_BODY[event] = data.hideBody ~= false

		if data.conflictsWith then
			for _, conflictEvent in ipairs(data.conflictsWith) do
				CONFLICTING_TRICK_EVENTS[conflictEvent] = true
			end
		end

		local userOnStart = data.onStart
		local userCheck = data.transitioncheck

		return RegisterCustomAnim(event, {
			model = data.model,
			deleteonend = data.deleteonend,
			transitionanim = false, -- the fork's generic auto-transition SetSequence()s a stock name onto our custom model
			onStart = function(ply)
				camjoint = "eyes" -- a preceding slide (or similar) can leave this pointed at an attachment our model doesn't have
				if userOnStart then userOnStart(ply) end
			end,
			transitioncheck = userCheck and function(ply)
				if userCheck(ply) then
					RunFallback(event)
				end

				return false
			end or nil,
		})
	end

	hook.Add("OnParkour", "BeatrunUtilPreemptConflictingTrick", function(event, ply)
		if CONFLICTING_TRICK_EVENTS[event] and SAFE_ANIM_EVENTS[BodyAnimString] then
			RunFallback(BodyAnimString)
		end
	end)

	hook.Add("PreDrawOpaqueRenderables", "BeatrunUtilHideBodyDuringAnim", function()
		local ply = LocalPlayer()

		if ANIM_HIDE_BODY[BodyAnimString] and not ply:ShouldDrawLocalPlayer() then
			ply:SetNoDraw(true)

			if IsValid(BodyAnimArmCopy) then
				BodyAnimArmCopy:SetNoDraw(true)
			end
		end
	end)
end

return util
