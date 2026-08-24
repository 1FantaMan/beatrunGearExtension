-- generic cached loader for beatrun/sh/modules/*.lua - unlike include(), which
-- re-executes the file every call, this includes each module exactly once and
-- hands back the same table on every later Get(), so any state a module keeps
-- (e.g. a cached list) is actually shared across every gear that uses it.
local mod = {}

local cache = {}

function mod.Get(name)
    if cache[name] then
        return cache[name]
    end

    local path = "beatrun/sh/modules/" .. name .. ".lua"
    if not file.Exists(path, "LUA") then
        error("[BeatrunGears] no such module: " .. name)
    end

    cache[name] = include(path)
    return cache[name]
end

return mod
