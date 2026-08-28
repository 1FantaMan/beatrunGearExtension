local mod = {}

-- param order matches Entity:EmitSound itself (soundLevel, pitch, volume)
function mod.Play(ply, soundPath, soundLevel, pitch, volume)
  util.PrecacheSound(soundPath)
  ply:EmitSound(soundPath, soundLevel or 75, pitch or 100, volume or 1)
end

return mod
