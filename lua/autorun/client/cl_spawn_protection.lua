spawnProtectionHaloColor = Color( 100, 100, 100)

hook.Remove( "PreDrawHalos", "PVPHalos" )  
hook.Add( "PreDrawHalos", "PVPHalos", function()
    local lookent = LocalPlayer():GetEyeTrace().Entity
    if ( IsValid(lookent) and lookent:IsPlayer() ) then
        local target = lookent
        local targetHasSpawnProtection = target:GetNWBool("hasSpawnProtection", false)

        if ( targetHasSpawnProtection ) then
            halo.Add( {target}, spawnProtectionHaloColor, 2, 1, 1 )
        end
    end
end )
