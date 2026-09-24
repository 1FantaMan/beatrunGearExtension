return {
	name = "thruster",
	displayname = "Thruster Capacity",
	level = 1,
	type = "leg",

	max_uses = 1,

	endlag = 0.5,
	start_endlag = 0.45,

	jump_power = 170,
	jump_power_scale = 0.1, -- extra vertical boost applied above dash_max_speed

	dash_speed = 200,
	dash_max_speed = 1200,

	fall_damage_threshold = 600,
	fall_boost_penalty_scale = 0.5,
	min_fall_boost_penalty = 0.3,

	thrust_sound = "beatrun/gears/thruster/thrust.wav",
}
