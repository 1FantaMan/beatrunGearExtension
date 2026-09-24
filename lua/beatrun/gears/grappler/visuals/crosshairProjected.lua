-- world-projected aim reticle: draws at Vector:ToScreen() of the live aim point, or the grapple target while active
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

local POSITION_SMOOTH_SPEED = 20 -- how fast the drawn position chases the target position

local APPEAR_DURATION = 0.3 -- fade+spin-in duration when the crosshair (re)appears
local APPEAR_SPIN_DEG = 195 -- extra rotation at the start of the appear animation, decaying to 0

local DISAPPEAR_DURATION = 0.25 -- fade-out duration when the tracked surface is truly lost
local DISAPPEAR_SPIN_DEG = 120 -- extra rotation added over the course of the disappear animation

local activeSpinRotation = 0
local displayX, displayY -- smoothed drawn position; nil until first valid frame
local wasReachable -- last frame's reachable state; nil until first valid frame
local appearStartTime -- set when the crosshair transitions from unreachable to reachable; nil once consumed
local disappearStartTime -- set when the crosshair transitions from reachable to unreachable; nil once consumed
local lastAlpha = 0 -- alpha drawn last frame; the disappear animation fades down from this, not from 0

hook.Add("HUDPaint", "BeatrunGrapplerCrosshairProjected", function()
  local ply = LocalPlayer()
  if not IsValid(ply) or not ply:Alive() or ply:GetNW2String("brgear_left", "") ~= "grappler" then
    activeSpinRotation = 0
    displayX, displayY = nil, nil
    wasReachable = nil
    appearStartTime = nil
    disappearStartTime = nil
    lastAlpha = 0
    return
  end

  if gearMod == nil or gearMod.config == nil then return end

  local isActive = ply:GetNW2Bool("brgear_grapple_active", false)

  -- reflects live aim even mid-grapple, so sizing/fade keep updating while position eases back after a pull.
  -- hitPos/reachable come straight from the same tracked-surface state shared.lua's onSetupMove maintains,
  -- so this can never show a position the fire logic wouldn't also accept
  local hitPos, reachable = gearMod.GetHookPosition(ply)
  local usesRemaining = ply:GetNW2Int("brgear_" .. gearMod.config.type .. "_uses", gearMod.config.max_uses)
  reachable = reachable and usesRemaining > 0

  if wasReachable == nil then wasReachable = reachable end

  if not isActive then
    if reachable and not wasReachable then
      appearStartTime = CurTime() -- fade+spin back in when the surface is (re)acquired
      disappearStartTime = nil
    elseif not reachable and wasReachable then
      disappearStartTime = CurTime() -- fade out and drift to center when the surface is truly lost
      appearStartTime = nil
    end
  end

  wasReachable = reachable

  -- once lost, aim the reticle at screen center instead of the stale/unprojectable aim point - the
  -- existing position smoothing below then naturally drifts it there instead of snapping
  local targetPos
  if isActive then
    targetPos = ply:GetNW2Vector("brgear_grapple_target")
  elseif reachable then
    targetPos = hitPos
  end

  local screenX, screenY
  if targetPos then
    local screenPos = targetPos:ToScreen()
    if screenPos.visible then
      screenX, screenY = screenPos.x, screenPos.y
    end
  end

  if not screenX then
    screenX, screenY = ScrW() / 2, ScrH() / 2
  end

  if displayX == nil then
    displayX, displayY = screenX, screenY
  else
    local smoothT = math.Clamp(FrameTime() * POSITION_SMOOTH_SPEED, 0, 1)
    displayX = Lerp(smoothT, displayX, screenX)
    displayY = Lerp(smoothT, displayY, screenY)
  end

  local distance = math.Clamp(ply:EyePos():Distance(hitPos), gearMod.config.min_range, gearMod.config.max_range)
  local t = (distance - gearMod.config.min_range) / (gearMod.config.max_range - gearMod.config.min_range)
  local radius = Lerp(t, MIN_RADIUS_PX, MAX_RADIUS_PX)

  local rotationOffset, alpha

  if isActive then
    activeSpinRotation = (activeSpinRotation + FrameTime() * ACTIVE_SPIN_SPEED_DPS) % 360
    rotationOffset = activeSpinRotation
    alpha = 255
  else
    activeSpinRotation = 0
    rotationOffset = t * DISTANCE_ROTATION_DEG

    -- proximity fade: warns before it's actually confirmed unreachable
    local rangeAlpha = 255
    if t > RANGE_FADE_START then
      local fadeT = (t - RANGE_FADE_START) / (1 - RANGE_FADE_START)
      rangeAlpha = Lerp(fadeT, 255, RANGE_FADE_MIN_ALPHA)
    end

    if reachable then
      alpha = rangeAlpha
    elseif disappearStartTime then
      alpha = lastAlpha -- fade animation below takes it from here; not yet forced to 0
    else
      alpha = 0 -- already fully faded out (or was never reachable to begin with)
    end
  end

  if appearStartTime then
    local appearT = math.Clamp((CurTime() - appearStartTime) / APPEAR_DURATION, 0, 1)
    alpha = alpha * appearT
    rotationOffset = rotationOffset + Lerp(appearT, APPEAR_SPIN_DEG, 0)
    if appearT >= 1 then appearStartTime = nil end
  elseif disappearStartTime then
    local disappearT = math.Clamp((CurTime() - disappearStartTime) / DISAPPEAR_DURATION, 0, 1)
    alpha = alpha * (1 - disappearT) -- fades from the alpha it had the moment the surface was lost, not from 0
    rotationOffset = rotationOffset + Lerp(disappearT, 0, DISAPPEAR_SPIN_DEG)
    if disappearT >= 1 then disappearStartTime = nil end
  end

  lastAlpha = alpha

  if alpha <= 0 then return end -- fully faded out, nothing left to draw

  local drawSize = (radius / TEXTURE_RADIUS_FRACTION) * 2

  surface.SetMaterial(crosshairMat)
  surface.SetDrawColor(255, 255, 255, alpha)

  for _, pivotDeg in ipairs(PIVOTS_DEG) do
    surface.DrawTexturedRectRotated(displayX, displayY, drawSize, drawSize, pivotDeg + rotationOffset)
  end
end)

return mod
