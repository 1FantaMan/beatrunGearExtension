local disableOverdrive = CreateConVar("beatrun_disable_overdrive", "0", { FCVAR_REPLICATED, FCVAR_ARCHIVE }, "If 1, holding E on runnerhands does nothing instead of triggering Beatrun's Overdrive.")

hook.Add("Initialize", "BeatrunGearsDisableOverdrive", function()
    local stored = weapons.GetStored("runnerhands")
    if not stored then return end

    local basePrimaryAttack = stored.PrimaryAttack

    function stored:PrimaryAttack()
        local ply = self:GetOwner()

        if IsValid(ply) and ply:KeyDown(IN_USE) and disableOverdrive:GetBool() then
            return
        end

        return basePrimaryAttack(self)
    end
end)
