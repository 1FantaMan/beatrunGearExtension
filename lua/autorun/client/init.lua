if engine.ActiveGamemode() ~= "beatrun" then
    print("current gamemode is not beatrun, mod will not run.")
    return
end

for _, fileName in ipairs(file.Find("beatrun/cl/*.lua", "LUA")) do
    include("beatrun/cl/" .. fileName)
end