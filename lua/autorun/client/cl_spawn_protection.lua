spawnProtectionHaloColor = Color( 100, 100, 100 )

hook.Remove( "PreDrawHalos", "spawnProtectionHalos" )
hook.Add( "PreDrawHalos", "spawnProtectionHalos", function()
    local lookent = LocalPlayer():GetEyeTrace().Entity
    if ( IsValid( lookent ) and lookent:IsPlayer() ) then
        local target = lookent
        local targetHasSpawnProtection = target:GetNWBool( "hasSpawnProtection", false )

        if ( targetHasSpawnProtection ) then
            halo.Add( {target}, spawnProtectionHaloColor, 2, 1, 1 )
        end
    end
end )
