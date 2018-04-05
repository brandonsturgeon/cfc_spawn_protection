
-- Time in seconds after moving for the first time that the player will lose spawn protection
spawnProtectionMoveDelay = 1

allowedSpawnWeapons = {
        ["weapon_physgun"]    = true,
        ["weapon_physcannon"] = true,
        ["gmod_tool"]         = true,
        ["gmod_camera"]       = true,
        ["weapon_medkit"]     = true
        ["none"]              = true,
        ["laserpointer"]      = true,
        ["remotecontroller"]  = true
}

function setSpawnProtection( player )
    player:SetNWBool("hasSpawnProtection", true)
    player:GodEnable()
end
hook.Remove("PlayerSpawn", "CFCsetSpawnProtection")
hook.Add("PlayerSpawn", "CFCsetSpawnProtection", setSpawnProtection)

function removeSpawnProtection( player )
    player:SetNWBool("hasSpawnProtection", false)
    player:GodDisable()
end

function spawnProtectionWeaponChangeCheck( player, oldWeapon, newWeapon)
    local playerInPvP = player:GetNWBool("PVPMode", false)

    if (playerInPvP) then 
          local playerLacksSpawnProtection = !player:GetNWBool("hasSpawnProtection", true)

          if (playerLacksSpawnProtection) then
              local weaponIsDisallowed = !allowedSpawnWeapons[newWeapon]

              if ( weaponIsDisallowed ) then
                  removeSpawnProtection( player )
              end
          end
    end
end
hook.Remove("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange")
hook.Add("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck)

function spawnProtectionMoveCheck( player, _ )
    local playerHasSpawnProtection = player:GetNWBool("hasSpawnProtection", false)
  
    if ( playerHasSpawnProtection ) then
        timer.Simple(spawnProtectionMoveDelay, function ()
            removeSpawnProtection( player )
        end)
    end
end
hook.Remove("Move", "CFCspawnProtectionMoveCheck")
hook.Add("Move", "CFCspawnProtectionMoveCheck", spawnProtectionMoveCheck)
