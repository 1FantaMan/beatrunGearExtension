-- unlike include(), which re-executes every call, this includes each module once and shares the result
-- across every file that calls Get() -- the cache has to be a true global, not a local upvalue, since
-- this file itself gets re-executed by include() each time something calls
-- include("beatrun/sh/modules.lua"), which would otherwise silently create a fresh, disconnected
-- cache every time and defeat the point for any module with real shared state
BeatrunGearsModuleCache = BeatrunGearsModuleCache or {}

local mod = {}

function mod.Get(name)
  if BeatrunGearsModuleCache[name] then
    return BeatrunGearsModuleCache[name]
  end

  local path = "beatrun/sh/modules/" .. name .. ".lua"
  if not file.Exists(path, "LUA") then
    error("[BeatrunGears] no such module: " .. name)
  end

  BeatrunGearsModuleCache[name] = include(path)
  return BeatrunGearsModuleCache[name]
end

return mod
