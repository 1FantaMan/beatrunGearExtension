-- shared by both rope files; include() doesn't cache, so GetConVar() guards against double-registering
local mod = {}

local function EnsureConVar(name, default, help, min, max)
  return CreateClientConVar(name, default, true, false, help, min, max)
end

local r = EnsureConVar("brgears_grappler_rope_r", "0", "Grappler rope color - red (0-255)", 0, 255)
local g = EnsureConVar("brgears_grappler_rope_g", "0", "Grappler rope color - green (0-255)", 0, 255)
local b = EnsureConVar("brgears_grappler_rope_b", "15", "Grappler rope color - blue (0-255)", 0, 255)

-- Global so every include() shares the same Color object, same reason as above
BeatrunGrapplerRopeColor = BeatrunGrapplerRopeColor or Color(r:GetInt(), g:GetInt(), b:GetInt())
mod.color = BeatrunGrapplerRopeColor

local function UpdateColor()
  mod.color.r = r:GetInt()
  mod.color.g = g:GetInt()
  mod.color.b = b:GetInt()
end

cvars.AddChangeCallback("brgears_grappler_rope_r", UpdateColor, "BeatrunGearsRopeColorR")
cvars.AddChangeCallback("brgears_grappler_rope_g", UpdateColor, "BeatrunGearsRopeColorG")
cvars.AddChangeCallback("brgears_grappler_rope_b", UpdateColor, "BeatrunGearsRopeColorB")

concommand.Add("brgears_grappler_rope_color", function(ply, cmd, args)
  if #args ~= 3 then
    print("Usage: brgears_grappler_rope_color <r> <g> <b>  (each 0-255)")
    return
  end

  RunConsoleCommand("brgears_grappler_rope_r", args[1])
  RunConsoleCommand("brgears_grappler_rope_g", args[2])
  RunConsoleCommand("brgears_grappler_rope_b", args[3])
end, nil, "Set the grappler rope color in one go: brgears_grappler_rope_color <r> <g> <b>")

return mod
