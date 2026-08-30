-- world-projected aim reticle: draws at Vector:ToScreen() of the live aim point, or the grapple target while active
local spinAnimation = include("beatrun/gears/grappler/visuals/spinAnimation.lua")

local mod = {}

local gearMod

function mod.Init(theGearMod)
  gearMod = theGearMod
end

local crosshairMat = Material("beatrun/gears/grappler/crosshair_corner.png", "noclamp smooth")

local TEXTURE_RADIUS_FRACTION = 0.5 -- must match crosshair_proto.py's RADIUS_FRACTION

local TWIST_DEG = -10 -- rotates the whole 4-piece formation off the cardinal directions
local PIVOTS_DEG = { 0 + TWIST_DEG, 90 + TWIST_DEG, 180 + TWIST_DEG, 270 + TWIST_DEG }
local MIN_RADIUS_PX = 22
local MAX_RADIUS_PX = 17 -- kept close to MIN_RADIUS_PX for a subtle range-size effect

local RANGE_FADE_START = 0.7 -- start fading once this far (0-1) toward max_range
local RANGE_FADE_MIN_ALPHA = 90 -- alpha floor from proximity fade alone

local DISTANCE_ROTATION_DEG = 90 -- extra rotation added as aim distance approaches max_range
local ACTIVE_SPIN_SPEED_DPS = 540 -- continuous spin speed while grappling, degrees/sec

local POSITION_SMOOTH_SPEED = 12 -- how fast the drawn position chases the target position

local MISS_DEBOUNCE = 0.1 -- how long with zero hits before counting as unreachable
local HIT_DEBOUNCE = 0.1 -- how long with continuous hits before cancelling a miss-streak

local APPEAR_DURATION = 0.3 -- fade+spin-in duration when the crosshair first appears
local APPEAR_SPIN_DEG = 195 -- extra rotation at the start of the appear animation, decaying to 0

local unreachableAnim = spinAnimation.New()

-- debounce timers so a single stray hit/miss frame doesn't flip the state
local hitStreak = 0
local missStreak = 0
local isUnreachable = false

local activeSpinRotation = 0
local displayX, displayY -- smoothed drawn position; nil until first valid frame
local appearStartTime -- set when the crosshair transitions from hidden to visible; nil once consumed

hook.Add("HUDPaint", "BeatrunGrapplerCrosshairProjected", function()
  local ply = LocalPlayer()
  if not IsValid(ply) or not ply:Alive() or ply:GetNW2String("brgear_left", "") ~= "grappler" then
    hitStreak = 0
    missStreak = 0
    isUnreachable = false
    spinAnimation.Cancel(unreachableAnim)
    activeSpinRotation = 0
    displayX, displayY = nil, nil
    appearStartTime = nil
    return
  end

  if gearMod == nil or gearMod.config == nil then return end

  local isActive = ply:GetNW2Bool("brgear_grapple_active", false)

  -- reflects live aim even mid-grapple, so sizing/fade keep updating while position eases back after a pull
  local hitPos, reachable = gearMod.GetHookPosition(ply)
  local usesRemaining = ply:GetNW2Int("brgear_" .. gearMod.config.type .. "_uses", gearMod.config.max_uses)
  reachable = reachable and usesRemaining > 0

  local targetPos = isActive and ply:GetNW2Vector("brgear_grapple_target") or hitPos
  local screenPos = targetPos:ToScreen()
  if not screenPos.visible then return end -- behind the camera or otherwise unprojectable this frame

  if displayX == nil then
    displayX, displayY = screenPos.x, screenPos.y
  else
    local smoothT = math.Clamp(FrameTime() * POSITION_SMOOTH_SPEED, 0, 1)
    displayX = Lerp(smoothT, displayX, screenPos.x)
    displayY = Lerp(smoothT, displayY, screenPos.y)
  end

  local distance = math.Clamp(ply:EyePos():Distance(hitPos), gearMod.config.min_range, gearMod.config.max_range)
  local t = (distance - gearMod.config.min_range) / (gearMod.config.max_range - gearMod.config.min_range)
  local radius = Lerp(t, MIN_RADIUS_PX, MAX_RADIUS_PX)

  local rotationOffset, alpha

  if isActive then
    activeSpinRotation = (activeSpinRotation + FrameTime() * ACTIVE_SPIN_SPEED_DPS) % 360
    rotationOffset = activeSpinRotation
    alpha = 255

    hitStreak = 0
    missStreak = 0
    if isUnreachable then
      isUnreachable = false
      spinAnimation.Cancel(unreachableAnim)
    end
  else
    activeSpinRotation = 0

    if reachable then
      hitStreak = hitStreak + FrameTime()
      missStreak = 0
    else
      missStreak = missStreak + FrameTime()
      hitStreak = 0
    end

    if hitStreak >= HIT_DEBOUNCE and isUnreachable then
      isUnreachable = false
      spinAnimation.Cancel(unreachableAnim)
      appearStartTime = CurTime() -- fade+spin back in when going from unreachable to reachable
    elseif missStreak >= MISS_DEBOUNCE and not isUnreachable then
      isUnreachable = true
      spinAnimation.Trigger(unreachableAnim, true)
    end

    local unreachableRotation, unreachableAlpha = spinAnimation.Update(unreachableAnim)
    rotationOffset = unreachableRotation + t * DISTANCE_ROTATION_DEG

    -- proximity fade: warns before it's actually confirmed unreachable
    local rangeAlpha = 255
    if t > RANGE_FADE_START then
      local fadeT = (t - RANGE_FADE_START) / (1 - RANGE_FADE_START)
      rangeAlpha = Lerp(fadeT, 255, RANGE_FADE_MIN_ALPHA)
    end

    alpha = math.min(unreachableAlpha, rangeAlpha)
  end

  if appearStartTime then
    local appearT = math.Clamp((CurTime() - appearStartTime) / APPEAR_DURATION, 0, 1)
    alpha = alpha * appearT
    rotationOffset = rotationOffset + Lerp(appearT, APPEAR_SPIN_DEG, 0)
    if appearT >= 1 then appearStartTime = nil end
  end

  local drawSize = (radius / TEXTURE_RADIUS_FRACTION) * 2

  surface.SetMaterial(crosshairMat)
  surface.SetDrawColor(255, 255, 255, alpha)

  for _, pivotDeg in ipairs(PIVOTS_DEG) do
    surface.DrawTexturedRectRotated(displayX, displayY, drawSize, drawSize, pivotDeg + rotationOffset)
  end
end)

return mod
