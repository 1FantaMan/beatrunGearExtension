local ropeMaterial = CreateMaterial("BeatrunGrappleRopeFP", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})
local ropeColor = include("beatrun/gears/grappler/visuals/ropeColor.lua").color

local MAX_COIL_RADIUS = 4
local MAX_ROTATIONS = 6
local TIGHTEN_DURATION = 0.15
local TUBE_RADIUS = 0.8
local TUBE_SIDES = 6

-- manual fine-tune on top of the detected hand bone, local to the eye (forward, right, up)
local ANCHOR_OFFSET = Vector(4, 3, -4)

-- tried fingertip-to-shoulder; not every playermodel rig has finger bones, so walk up until one exists
local HAND_BONE_CANDIDATES = {
	"ValveBiped.Bip01_L_Finger2",
	"ValveBiped.Bip01_L_Finger1",
	"ValveBiped.Bip01_L_Finger0",
	"ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_L_Wrist",
	"ValveBiped.Bip01_L_Forearm",
	"ValveBiped.Bip01_L_UpperArm",
	"ValveBiped.Bip01_L_Clavicle",
}

local function FindHandBone(ent)
	for _, boneName in ipairs(HAND_BONE_CANDIDATES) do
		local boneID = ent:LookupBone(boneName)
		if boneID then return boneID end
	end
	return nil
end

local function buildRing(center, tangent)
	local ang = tangent:Angle()
	local right = ang:Right()
	local up = ang:Up()

	local ring = {}
	for s = 1, TUBE_SIDES do
		local a = (s / TUBE_SIDES) * math.pi * 2
		ring[s] = center + (right * math.cos(a) + up * math.sin(a)) * TUBE_RADIUS
	end
	return ring
end

hook.Add("PreDrawEffects", "BeatrunGearsRopeDrawFirstPerson", function()
	-- water/reflection passes re-run this hook against their own render target; skip anything but the real backbuffer
	if render.GetRenderTarget() then return end

	local ply = LocalPlayer()
	if not IsValid(ply) or ply:ShouldDrawLocalPlayer() then return end
	if not ply:GetNW2Bool("brgear_grapple_active", false) then return end

	local anchorPos

	-- Beatrun's real first-person hands are BodyAnimMDLarm, not ply:GetViewModel() (that one shows the wrong/unused model)
	if IsValid(BodyAnimMDLarm) and IsValid(BodyAnimArmCopy) then
		BodyAnimMDLarm:InvalidateBoneCache()
		BodyAnimMDLarm:SetupBones()

		local attachID = BodyAnimArmCopy:LookupAttachment("eyes")
		local eyesAttach = attachID ~= 0 and BodyAnimArmCopy:GetAttachment(attachID)
		local boneID = eyesAttach and FindHandBone(BodyAnimMDLarm)
		local boneMatrix = boneID and BodyAnimMDLarm:GetBoneMatrix(boneID)

		if boneMatrix then
			local rawHandPos = boneMatrix:GetTranslation()

			-- BodyAnimMDLarm's own entity angles are never set (always identity) - only the camera rotates it
			local localOffset = WorldToLocal(rawHandPos, angle_zero, eyesAttach.Pos, angle_zero)
			anchorPos = LocalToWorld(localOffset, angle_zero, ply:EyePos(), ply:EyeAngles())
		end
	end

	-- last resort: no matching bone on the hand companion model, read it straight off the player entity instead
	if not anchorPos then
		ply:SetupBones()

		local boneID = FindHandBone(ply)
		local boneMatrix = boneID and ply:GetBoneMatrix(boneID)

		if not boneMatrix then return end

		anchorPos = boneMatrix:GetTranslation()
	end

	anchorPos = anchorPos + LocalToWorld(ANCHOR_OFFSET, angle_zero, vector_origin, ply:EyeAngles())

	local targetPos = ply:GetNW2Vector("brgear_grapple_target")
	local fireTime = ply:GetNW2Float("brgear_grapple_fire_time", 0)
	local arrivalTime = ply:GetNW2Float("brgear_grapple_arrival_time", 0)

	local hookPos = targetPos
	local tightenProgress = 0

	if CurTime() < arrivalTime then
		local totalTravelTime = math.max(arrivalTime - fireTime, 0.0001)
		local travelProgress = math.Clamp((CurTime() - fireTime) / totalTravelTime, 0, 1)
		hookPos = LerpVector(travelProgress, anchorPos, targetPos)
	else
		tightenProgress = math.Clamp((CurTime() - arrivalTime) / TIGHTEN_DURATION, 0, 1)
	end

	local coilRadius = Lerp(tightenProgress, MAX_COIL_RADIUS, 0)
	local totalRotations = Lerp(tightenProgress, MAX_ROTATIONS, 0)

	local mainAxis = (hookPos - anchorPos):GetNormalized()
	local axisAngle = mainAxis:Angle()
	local rightVec = axisAngle:Right()
	local upVec = axisAngle:Up()

	local segments = 120
	local tightnessPower = 2

	local pathPoints = { anchorPos }
	for i = 1, segments do
		local t = i / segments
		local axisPoint = LerpVector(t, anchorPos, hookPos)

		local tightness = (1 - t) ^ tightnessPower
		local angle = tightness * totalRotations * math.pi * 2
		local offset = (rightVec * math.cos(angle) + upVec * math.sin(angle)) * coilRadius

		pathPoints[i + 1] = axisPoint + offset
	end

	local rings = {}
	for i = 1, #pathPoints do
		local tangent
		if i == 1 then
			tangent = (pathPoints[2] - pathPoints[1]):GetNormalized()
		elseif i == #pathPoints then
			tangent = (pathPoints[i] - pathPoints[i - 1]):GetNormalized()
		else
			tangent = (pathPoints[i + 1] - pathPoints[i - 1]):GetNormalized()
		end

		rings[i] = buildRing(pathPoints[i], tangent)
	end

	render.SetMaterial(ropeMaterial)
	mesh.Begin(MATERIAL_TRIANGLES, (#pathPoints - 1) * TUBE_SIDES * 2)

	for i = 1, #pathPoints - 1 do
		local ringA = rings[i]
		local ringB = rings[i + 1]

		for s = 1, TUBE_SIDES do
			local sNext = (s % TUBE_SIDES) + 1

			local a1, a2 = ringA[s], ringA[sNext]
			local b1, b2 = ringB[s], ringB[sNext]

			mesh.Position(a1)
			mesh.Normal((a1 - pathPoints[i]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()

			mesh.Position(b1)
			mesh.Normal((b1 - pathPoints[i + 1]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()

			mesh.Position(b2)
			mesh.Normal((b2 - pathPoints[i + 1]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()

			mesh.Position(a1)
			mesh.Normal((a1 - pathPoints[i]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()

			mesh.Position(b2)
			mesh.Normal((b2 - pathPoints[i + 1]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()

			mesh.Position(a2)
			mesh.Normal((a2 - pathPoints[i]):GetNormalized())
			mesh.Color(ropeColor.r, ropeColor.g, ropeColor.b, ropeColor.a)
			mesh.AdvanceVertex()
		end
	end

	mesh.End()
end)
