
-- Time in seconds after moving for the first time that the player will lose spawn protection
spawnProtectionMoveDelay = 1

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

function setSpawnProtection( player )
    player:SetNWBool("hasSpawnProtection", false)
end

function setSpawnProtectionForPvPSpawn( player )
	local playerIsInPvP = player:GetNWBool("PVPMode", false)
	if ( playerIsInPvP ) then
		setSpawnProtection( player )
	end
end
hook.Remove("PlayerSpawn", "CFCsetSpawnProtection")
hook.Add("PlayerSpawn", "CFCsetSpawnProtection", setSpawnProtectionForPvPSpawn)

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

function spawnProtectionWeaponChangeCheck( player, oldWeapon, newWeapon)
    local playerInPvP = player:GetNWBool("PVPMode", false)

    if (playerInPvP) then 
          local playerLacksSpawnProtection = !player:GetNWBool("hasSpawnProtection", true)

          if (playerLacksSpawnProtection) then
              local weaponIsDisallowed = !allowedSpawnWeapons[newWeapon:GetClass()]

              if ( weaponIsDisallowed ) then
                  removeSpawnProtection( player )
              end
          end
    end
end
hook.Remove("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange")
hook.Add("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck)

function spawnProtectionMoveCheck( player, keyPressed )
	local playerIsDisablingSpawnProtection = player:GetNWBool("disablingSpawnProtection", false)
	
	if ( !playerIsDisablingSpawnProtection ) then
		local playerHasSpawnProtection = player:GetNWBool("hasSpawnProtection", false)
	  
		if ( playerHasSpawnProtection ) then
			local playerIsMovingThemselves = spawnProtectionMovementKeys[keyPressed]

			if ( playerIsMovingThemselves ) then
				delayRemoveSpawnProtection( player )
			end
		end
	end
end
hook.Remove("KeyPress", "CFCspawnProtectionMoveCheck")
hook.Add("KeyPress", "CFCspawnProtectionMoveCheck", spawnProtectionMoveCheck)

function preventDamageDuringSpawnProtection( player, damageInfo )
	local playerHasSpawnProtection = player:GetNWBool("hasSpawnProtection", false)
	
	if ( playerHasSpawnProtection ) then
		player:ChatPrint("You have spawn protection")
		damageInfo:SetDamage( 0 )
		return false
	end
	
end
hook.Remove("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection")
hook.Add("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection", preventDamageDuringSpawnProtection)

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
