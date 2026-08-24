return {
    name = "grappler",
    displayname = "Grappler",
    level = 1,
    type = "left",
    cooldown = 0,
    broadcastActivation = false,

    max_uses = 2,
    max_range = 1300,
    travel_speed = 1900,
    max_travel_time = 0.15,
    pull_delay_speed = 5000,
    max_pull_delay = 0.3,

    push_speed = 700,
    push_speed_multiplier = 1.25,
    push_max_speed = 1200,

    fall_damage_threshold = 700,
    fall_damage_scale = 0.15,
    fall_push_penalty_scale = 0.001,
    min_fall_push_penalty = 0.3,

    rope_visible_time = 0.3,
    uses_refill_delay = 0.3,
    door_open_delay = 0.15,
    door_melee_range = 50, -- matches Beatrun's own melee door-bash reach (sh/Melee.lua)

    fire_sound = "beatrun/gears/grappler/Grappler_SE.wav",
}
