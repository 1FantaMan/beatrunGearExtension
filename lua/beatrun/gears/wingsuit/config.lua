return {
  name = "wingsuit",
  displayname = "Wingsuit",
  level = 1,
  type = "back",

  endlag = 0.75, -- delay after toggling off before you can glide again

  -- power (duration resource)
  glide_power_max = 100,        -- size of the glide bar
  glide_drain_rate = 10,        -- flat power cost per second just for gliding
  glide_drain_speedscale = 0.02, -- extra power cost per second, scaled by current speed

  -- movement (steering + speed trade)
  glide_turn_rate = 10,  -- how fast your direction turns to follow your look angle
  glide_thrust = 400,    -- speed gained per second diving straight down (or lost looking straight up)

  -- gravity (floatiness, scales with speed)
  glide_gravity_scale = 0.15, -- gravity multiplier at full glide speed (lower = floatier)
  glide_gravity_speed = 600,  -- speed needed to reach full floatiness; below this, gravity ramps toward normal

  -- cancel condition
  glide_cancel_pitch = 90, -- looking up past this angle (degrees from level) force-cancels the glide

  glide_sound = "beatrun/gears/fins/Wingsuit_SE.wav",
}
