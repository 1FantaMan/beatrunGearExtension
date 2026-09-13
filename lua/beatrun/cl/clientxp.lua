local lastLevel = 1

-- on SP/listen servers Beatrun's own GetLevel() only exists client-side, so poll it and mirror to the server
if not game.IsDedicated() then

  hook.Add("InitPostEntity", "BeatrunGearsOnPlayerSpawn", function()
    timer.Create("BeatrunGearsLevelChangeLoop", 4, 0, function()
      local level = LocalPlayer():GetLevel()
      if level == lastLevel then return end
      lastLevel = level

      net.Start("BeatrunGearsClientLevel")
        net.WriteInt(level, 16)
      net.SendToServer()
    end)
  end)

end