-- Config Variables --
--
-- Time in seconds after moving for the first time that the player will lose spawn protection
local spawnProtectionMoveDelay = 1

-- Time in seconds before spawn protection wears off if no action is taken
local spawnProtectionDecayTime = 10

-- Prefix for the internal timer names - used to avoid timer collision
local spawnDecayPrefix = "cfc_spawn_decay_timer-"

local delayedRemovalPrefix = "cfc_spawn_removal_timer-"

-- Table of key enums which are disallowed in spawn protection
local spawnProtectionMovementKeys = {}
spawnProtectionMovementKeys[IN_MOVELEFT]  = true
spawnProtectionMovementKeys[IN_MOVERIGHT] = true
spawnProtectionMovementKeys[IN_FORWARD]   = true
spawnProtectionMovementKeys[IN_BACK]      = true


-- Weapons allowed to the player which won't break spawn protection
local allowedSpawnWeapons = {
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

-- Helpers / Wrappers --

-- Makes a given player transparent
local function setPlayerTransparent( player )
    player:SetRenderMode( RENDERMODE_TRANSALPHA )
    player:Fire( "alpha", 175, 0 )
end

-- Returns a given player to visible state
local function setPlayerVisible( player )
    player:SetRenderMode( RENDERMODE_NORMAL )
    player:Fire( "alpha", 255, 0 )
end

-- Creates a unique name for the Spawn Protection Decay timer
local function playerDecayTimerIdentifier( player )
    return spawnDecayPrefix .. player:SteamID64()
end

-- Creates a unique name for the Delayed Removal Timer
local function playerDelayedRemovalTimerIdentifier( player )
    return delayedRemovalPrefix .. player:SteamID64()
end

-- Set Spawn Protection
local function setSpawnProtection( player )
    player:SetNWBool("hasSpawnProtection", true)
end

-- Remove Decay Timer
local function removeDecayTimer( player )
    local playerIdentifer = playerDecayTimerIdentifier( player )
    timer.Remove( playerIdentifer )
end

-- Remove Delayed Removal Timer
local function removeDelayedRemoveTimer( player )
    local playerIdentifer = playerDelayedRemovalTimerIdentifier( player )
    timer.Remove( playerIdentifer )
end

-- Revoke spawn protection for a player
local function removeSpawnProtection( player )
    player:ChatPrint("You've lost spawn protection")
    player:SetNWBool("hasSpawnProtection", false)
end

-- Creates a decay timer which will expire after spawnProtectionDecayTime
local function createDecayTimer( player )
    local playerIdentifer = playerDecayTimerIdentifier( player )
    timer.Create( playerIdentifer, spawnProtectionDecayTime, 1, function()
        removeSpawnProtection( player )
        setPlayerVisible( player )
        removeDelayedRemoveTimer( player )
    end)
end

-- Creates a delayed removal time which will expire after spawnProtectionMoveDelay
local function createDelayedRemoveTimer( player )
    local playerIdentifer = playerDelayedRemovalTimerIdentifier( player )
    timer.Create( playerIdentifer, spawnProtectionMoveDelay, 1, function()
        player:SetNWBool("disablingSpawnProtection", false)
        removeSpawnProtection( player )
        setPlayerVisible( player )
        removeDecayTimer( player )
    end)
end

-- Used to delay the removal of spawn protection
local function delayRemoveSpawnProtection( player, _delay )
    local delay = _delay or spawnProtectionMoveDelay
    player:SetNWBool("disablingSpawnProtection", true)
    createDelayedRemoveTimer( player )
end

local function playerSpawnedAtEnemySpawnPoint( player )
    local spawnPoint = player.LinkedSpawnPoint
    if ( spawnPoint and IsValid(spawnPoint) ) then
        local spawnPointOwner = spawnPoint:CPPIGetOwner()
        if ( spawnPointOwner != player ) then
            return true
        end
    end
	
    return false
end

local function playerIsInPvP( player )
    return player:GetNWBool("PVPMode", false)
end

local function playerHasSpawnProtection( player )
    return player:GetNWBool("hasSpawnProtection", false)
end

local function playerIsDisablingSpawnProtection( player )
    return player:GetNWBool("disablingSpawnProtection", false)
end

local function weaponIsAllowed( weapon )
    return allowedSpawnWeapons[weapon:GetClass()]
end

local function keyVoidsSpawnProtection( keyCode )
    return spawnProtectionMovementKeys[keyCode]
end


-- Hook functions --

-- Function called on player spawn to grant spawn protection
local function setSpawnProtectionForPvPSpawn( player )
    if ( playerIsInPvP( player ) ) then
		if( !playerSpawnedAtEnemySpawnPoint( player ) ) then
			setSpawnProtection( player )
			setPlayerTransparent( player )
			createDecayTimer( player )
		end
    end
end

-- Called on weapon change to check if the weapon is allowed,
-- and remove spawn protection if it's not
local function spawnProtectionWeaponChangeCheck( player, oldWeapon, newWeapon)
    if ( playerIsInPvP( player ) ) then

        if ( playerHasSpawnProtection( player ) ) then

            if ( !weaponIsAllowed( newWeapon ) ) then
                removeSpawnProtection( player )
                setPlayerVisible( player )
                removeDecayTimer( player )
                removeDelayedRemoveTimer( player )
            end
        end
    end
end

-- Called on player keyDown events to check if a movement key was pressed
-- and remove spawn protection if so
local function spawnProtectionMoveCheck( player, keyCode )
    if ( !playerIsDisablingSpawnProtection( player ) ) then

        if ( playerHasSpawnProtection( player ) ) then
            local playerIsMovingThemselves = keyVoidsSpawnProtection( keyCode )

            if ( playerIsMovingThemselves ) then
                delayRemoveSpawnProtection( player )
            end
        end
    end
end

-- Prevents damage if a player has spawn protection
local function preventDamageDuringSpawnProtection( player, damageInfo )
    if playerHasSpawnProtection( player ) then return true end
end

-- Hooks --

-- Remove spawn protection when a weapon is drawn
hook.Remove("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange")
hook.Add("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck)

-- Remove spawn protection when leaving PvP (just cleanup)
hook.Remove("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP")
hook.Add("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP", function(player)
	if( playerHasSpawnProtection( player ) ) then
		removeSpawnProtection(player)
		setPlayerVisible( player )
		removeDecayTimer( player )
		removeDelayedRemoveTimer( player )
	end
end)

-- Remove spawn protection when player enters vehicle
hook.Remove("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle")
hook.Add("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle", function(player)
	if( playerHasSpawnProtection( player ) ) then
		removeSpawnProtection(player)
		setPlayerVisible( player )
		removeDecayTimer( player )
		removeDelayedRemoveTimer( player )
	end
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
