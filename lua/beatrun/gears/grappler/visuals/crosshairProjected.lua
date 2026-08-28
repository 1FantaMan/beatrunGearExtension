-- world-projected aim reticle - draws at Vector:ToScreen() of the aim point instead of screen
-- center. Idle: live raycast. Grappling: locked to brgear_grapple_target, stays visible.
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
local MIN_RADIUS_PX = 19
local MAX_RADIUS_PX = 24 -- kept close to MIN_RADIUS_PX for a subtle range-size effect

local RANGE_FADE_START = 0.7 -- start fading once this far (0-1) toward max_range
local RANGE_FADE_MIN_ALPHA = 90 -- alpha floor from proximity fade alone

local DISTANCE_ROTATION_DEG = 15 -- extra rotation added as aim distance approaches max_range

local MISS_DEBOUNCE = 0.1 -- how long with zero hits before counting as unreachable
local HIT_DEBOUNCE = 0.1 -- how long with continuous hits before cancelling a miss-streak

local unreachableAnim = spinAnimation.New()
local activationAnim = spinAnimation.New()

-- debounce timers so a single stray hit/miss frame doesn't flip the state
local hitStreak = 0
local missStreak = 0
local isUnreachable = false

-- called on every fire; only fades if hasUsesLeft is false
function mod.PlayActivationSpin(hasUsesLeft)
  spinAnimation.Trigger(activationAnim, not hasUsesLeft)
end

hook.Add("HUDPaint", "BeatrunGrapplerCrosshairProjected", function()
  local ply = LocalPlayer()
  if not IsValid(ply) or ply:GetNW2String("brgear_left", "") ~= "grappler" then
    hitStreak = 0
    missStreak = 0
    isUnreachable = false
    spinAnimation.Cancel(unreachableAnim)
    spinAnimation.Cancel(activationAnim)
    return
  end

  if gearMod == nil or gearMod.config == nil then return end

  local isActive = ply:GetNW2Bool("brgear_grapple_active", false)

  local hitPos, reachable
  if isActive then
    -- mid-grapple: show where you're hooked to, not wherever you're currently looking
    hitPos = ply:GetNW2Vector("brgear_grapple_target")
    reachable = true
  else
    hitPos, reachable = gearMod.GetHookPosition(ply)
  end

  local screenPos = hitPos:ToScreen()
  if not screenPos.visible then return end -- behind the camera or otherwise unprojectable this frame

  local distance = math.Clamp(ply:EyePos():Distance(hitPos), gearMod.config.min_range, gearMod.config.max_range)

  if isActive then
    hitStreak = 0
    missStreak = 0
    if isUnreachable then
      isUnreachable = false
      spinAnimation.Cancel(unreachableAnim)
    end
  else
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
    elseif missStreak >= MISS_DEBOUNCE and not isUnreachable then
      isUnreachable = true
      spinAnimation.Trigger(unreachableAnim, true)
    end
  end

  local usesRemaining = ply:GetNW2Int("brgear_grapple_uses_remaining", gearMod.config.max_uses)
  if usesRemaining > 0 then
    spinAnimation.Cancel(activationAnim)
  end

  local t = (distance - gearMod.config.min_range) / (gearMod.config.max_range - gearMod.config.min_range)
  local radius = Lerp(t, MIN_RADIUS_PX, MAX_RADIUS_PX)

  local unreachableRotation, unreachableAlpha = spinAnimation.Update(unreachableAnim)
  local activationRotation, activationAlpha = spinAnimation.Update(activationAnim)
  local rotationOffset = unreachableRotation + activationRotation + t * DISTANCE_ROTATION_DEG

  -- proximity fade: warns before it's actually confirmed unreachable
  local rangeAlpha = 255
  if t > RANGE_FADE_START then
    local fadeT = (t - RANGE_FADE_START) / (1 - RANGE_FADE_START)
    rangeAlpha = Lerp(fadeT, 255, RANGE_FADE_MIN_ALPHA)
  end

  local alpha = math.min(unreachableAlpha, activationAlpha, rangeAlpha)
  local drawSize = (radius / TEXTURE_RADIUS_FRACTION) * 2

  surface.SetMaterial(crosshairMat)
  surface.SetDrawColor(255, 255, 255, alpha)

  for _, pivotDeg in ipairs(PIVOTS_DEG) do
    surface.DrawTexturedRectRotated(screenPos.x, screenPos.y, drawSize, drawSize, pivotDeg + rotationOffset)
  end
end)

return mod
