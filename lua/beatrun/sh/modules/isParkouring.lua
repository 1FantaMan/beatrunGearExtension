local specials = {
	["mantle"] = true,
	["wallrun"] = true,
	["climbing"] = true
}

local checkActions = {
	["dive"] = "GetDive",
	["mantle"] = "GetMantle",
	["climbing"] = "GetClimbing",
	["sliding"] = "GetSliding",
	["wallrun"] = "GetWallrun",
}

return function(ply, exclude)
	local actions = table.Copy(checkActions)

	if exclude then
		for _, k in pairs(exclude) do
			actions[string.lower(k)] = nil
		end
	end

	for action, method in pairs(actions) do
		if specials[string.lower(action)] then
			if ply[method](ply) ~= 0 then
				return true, action
			end
		else
			if ply[method](ply) then
				return true, action
			end
		end
	end

	return false, nil
end
