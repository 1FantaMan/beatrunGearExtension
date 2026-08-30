-- global (not local) since this file itself gets re-include()'d, which would otherwise reset the cache
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
