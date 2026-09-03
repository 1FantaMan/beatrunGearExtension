local mod = {}

function mod.ComputePushVelocity(direction, currentSpeed, fallSpeed, config)
	local boostSpeed = math.min(config.push_max_speed,
		math.max(config.push_speed, currentSpeed * config.push_speed_multiplier))

	if fallSpeed > config.fall_damage_threshold then
		local excess = fallSpeed - config.fall_damage_threshold
		local penalty = math.max(config.min_fall_push_penalty, 1 - excess * config.fall_push_penalty_scale)
		boostSpeed = boostSpeed * penalty
	end

	return direction * boostSpeed
end

return mod
