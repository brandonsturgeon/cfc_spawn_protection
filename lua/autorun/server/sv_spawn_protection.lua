
-- Time in seconds after moving for the first time that the player will lose spawn protection
spawnProtectionMoveDelay = 1

-- Table of key enums which are disallowed in spawn protection
spawnProtectionMovementKeys = {}
spawnProtectionMovementKeys[IN_JUMP] = true
spawnProtectionMovementKeys[IN_MOVELEFT] = true
spawnProtectionMovementKeys[IN_MOVERIGHT] = true
spawnProtectionMovementKeys[IN_FORWARD] = true
spawnProtectionMovementKeys[IN_BACK] = true


allowedSpawnWeapons = {
    ["Physics Gun"]       = true,
    ["weapon_physgun"]    = true,
    ["weapon_physcannon"] = true,
    ["gmod_tool"]         = true,
    ["gmod_camera"]       = true,
    ["weapon_medkit"]     = true,
    ["none"]              = true,
    ["laserpointer"]      = true,
    ["remotecontroller"]  = true
}

-- Helpers / Wrappers

function setSpawnProtection( player )
    player:SetNWBool("hasSpawnProtection", true)
end

function removeSpawnProtection( player )
    player:ChatPrint("You've left spawn protection")
    player:SetNWBool("hasSpawnProtection", false)
end

function delayRemoveSpawnProtection( player, _delay )
    local delay = _delay or spawnProtectionMoveDelay
    player:SetNWBool("disablingSpawnProtection", true)

    timer.Simple(spawnProtectionMoveDelay, function ()
        player:SetNWBool("disablingSpawnProtection", false)
        removeSpawnProtection( player )
    end)
end

function playerIsInPvP( player )
    return player:GetNWBool("PVPMode", false)
end

function playerHasSpawnProtection( player )
    return player:GetNWBool("playerHasSpawnProtection", false)
end

function playerIsDisablingSpawnProtection( player )
    return player:GetNWBool("disablingSpawnProtection", false)
end

function weaponIsAllowed( weapon )
    return allowedSpawnWeapons[weapon:GetClass()] or false
end

function keyVoidsSpawnProtection( keyCode )
    return spawnProtectionMovementKeys[keyCode] or false
end


-- Hook functions --

function setSpawnProtectionForPvPSpawn( player )
    if ( playerIsInPvP( player ) ) then
        setSpawnProtection( player )
    end
end

function spawnProtectionWeaponChangeCheck( player, oldWeapon, newWeapon)
    if (playerIsInPvP( player )) then

        if ( !playerHasSpawnProtection( player ) ) then

            if ( !weaponIsAllowed( newWeapon ) ) then
                removeSpawnProtection( player )
            end
        end
    end
end

function spawnProtectionMoveCheck( player, keyCode )
    if ( !playerIsDisablingSpawnProtection( player ) ) then

        if ( playerHasSpawnProtection( player ) ) then

            local playerIsMovingThemselves = keyVoidsSpawnProtection( keyCode )

            if ( playerIsMovingThemselves ) then
                delayRemoveSpawnProtection( player )
            end
        end
    end
end

function preventDamageDuringSpawnProtection( player, damageInfo )
    local playerHasSpawnProtection = player:GetNWBool("hasSpawnProtection", false)

    if ( playerHasSpawnProtection ) then
        player:ChatPrint("You have spawn protection")
        damageInfo:SetDamage( 0 )
        return false
    end

end

-- Hooks --

-- Remove spawn protection when a weapon is drawn
hook.Remove("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange")
hook.Add("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck)

-- Remove spawn protection when leaving PvP (just cleanup)
hook.Remove("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP")
hook.Add("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP", function(player)
    removeSpawnProtection(player)
end)

-- Remove spawn protection when player enters vehicle
hook.Remove("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle")
hook.Add("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle", function(player)
    removeSpawnProtection(player)
end)

-- Enable spawn protection when spawning in PvP
hook.Remove("PlayerSpawn", "CFCsetSpawnProtection")
hook.Add("PlayerSpawn", "CFCsetSpawnProtection", setSpawnProtectionForPvPSpawn)

-- Trigger spawn protection removal on player move
hook.Remove("KeyPress", "CFCspawnProtectionMoveCheck")
hook.Add("KeyPress", "CFCspawnProtectionMoveCheck", spawnProtectionMoveCheck)

-- Prevent entity damage while in spawn protection
hook.Remove("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection")
hook.Add("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection", preventDamageDuringSpawnProtection, HOOK_HIGH)
