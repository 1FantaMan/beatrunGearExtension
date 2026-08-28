return {
  name = "thruster",
  displayname = "Thruster Capacity",
  level = 1,
  type = "leg",

  max_uses = 2,

  endlag = 0.5,
  start_endlag = 0.45,

  jump_power = 270,
  jump_power_scale = 0.1, -- extra vertical boost per unit of current speed, only applied above dash_max_speed

  dash_speed = 1.05,
  dash_max_speed = 590,
  dive_dash_multiplier = 1.15,

  thrust_sound = "beatrun/gears/thruster/thrust.wav",
}
