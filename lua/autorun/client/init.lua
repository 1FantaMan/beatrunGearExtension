if engine.ActiveGamemode() ~= "beatrun" then
  print("current gamemode is not beatrun, mod will not run.")
  return
end

for _, fileName in ipairs(file.Find("beatrun/cl/*.lua", "LUA")) do
  include("beatrun/cl/" .. fileName)
end

-- unconditional so bystanders see other players' ropes too
include("beatrun/gears/grappler/visuals/thirdPersonRope.lua")
