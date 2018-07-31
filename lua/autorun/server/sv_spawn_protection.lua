-- Config Variables --
--
-- Time in seconds after moving for the first time that the player will lose spawn protection
local spawnProtectionMoveDelay = 2

-- Time in seconds before spawn protection wears off if no action is taken
local spawnProtectionDecayTime = 10

-- How long players are allowed to hold weapons after spawning (in seconds)
local spawnProtectionWeaponGracePeriod = 0.001

-- Prefix for the internal timer names - used to avoid timer collision
local spawnDecayPrefix = "cfc_spawn_decay_timer-"

local delayedRemovalPrefix = "cfc_spawn_removal_timer-"

-- Table of key enums which are disallowed in spawn protection
local keyVoidsSpawnProtection = {}
keyVoidsSpawnProtection[IN_MOVELEFT]  = true
keyVoidsSpawnProtection[IN_MOVERIGHT] = true
keyVoidsSpawnProtection[IN_FORWARD]   = true
keyVoidsSpawnProtection[IN_BACK]      = true


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

local function setPlayerNoCollide( player )
    player:SetCollisionGroup( COLLISION_GROUP_WORLD )
end

local function setPlayerCollide( player )
    player:SetCollisionGroup( COLLISION_GROUP_NONE )
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

local function setLastSpawnTime( player )
    player:SetNWInt("lastSpawnTime", CurTime())
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
    if not spawnPoint or not IsValid( spawnPoint ) then return false end

    local spawnPointOwner = spawnPoint:CPPIGetOwner()
    if spawnPointOwner == player then return false end

    return true
end

local function playerIsInPvp( player )
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

-- Hook functions --

-- Function called on player spawn to grant spawn protection
local function setSpawnProtectionForPvpSpawn( player )
    if not playerIsInPvp( player ) then return end
    if playerSpawnedAtEnemySpawnPoint( player ) then return end

    setLastSpawnTime( player )
    setSpawnProtection( player )
    setPlayerTransparent( player )
    setPlayerNoCollide( player )
    createDecayTimer( player )
end

-- Called on weapon change to check if the weapon is allowed,
-- and remove spawn protection if it's not
local function spawnProtectionWeaponChangeCheck( player, oldWeapon, newWeapon)
    if not playerIsInPvp( player ) then return end
    if not playerHasSpawnProtection( player ) then return end
    if weaponIsAllowed( newWeapon ) then return end

    local lastSpawnTime = player:GetNWInt( "lastSpawnTime", CurTime() - spawnProtectionWeaponGracePeriod )
    if lastSpawnTime >= CurTime() - spawnProtectionWeaponGracePeriod then return end

    removeSpawnProtection( player )
    setPlayerVisible( player )
    setPlayerCollide( player )
    removeDecayTimer( player )
    removeDelayedRemoveTimer( player )
end

-- Called on player keyDown events to check if a movement key was pressed
-- and remove spawn protection if so
local function spawnProtectionMoveCheck( player, keyCode )
    if playerIsDisablingSpawnProtection( player ) then return end
    if not playerHasSpawnProtection( player ) then return end
    if keyVoidsSpawnProtection[ keyCode ] then delayRemoveSpawnProtection( player ) end
end

-- Prevents damage if a player has spawn protection
local function preventDamageDuringSpawnProtection( player, damageInfo )
    if playerHasSpawnProtection( player ) then return true end
end

-- Hooks --

-- Remove spawn protection when a weapon is drawn
hook.Remove("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange")
hook.Add("PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck, HOOK_LOW)

-- Remove spawn protection when leaving Pvp (just cleanup)
hook.Remove("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP")
hook.Add("PlayerExitPvP", "CFCremoveSpawnProtectionOnExitPvP", function(player)
    if not playerHasSpawnProtection( player ) then return end
    removeSpawnProtection(player)
    setPlayerVisible( player )
    setPlayerCollide( player )
    removeDecayTimer( player )
    removeDelayedRemoveTimer( player )
end)

-- Remove spawn protection when player enters vehicle
hook.Remove("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle")
hook.Add("PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle", function(player)
    if not playerHasSpawnProtection( player ) then return end
    removeSpawnProtection(player)
    setPlayerVisible( player )
    setPlayerCollide( player )
    removeDecayTimer( player )
    removeDelayedRemoveTimer( player )
end)

-- Enable spawn protection when spawning in PvP
hook.Remove("PlayerSpawn", "CFCsetSpawnProtection")
hook.Add("PlayerSpawn", "CFCsetSpawnProtection", setSpawnProtectionForPvpSpawn)

-- Trigger spawn protection removal on player move
hook.Remove("KeyPress", "CFCspawnProtectionMoveCheck")
hook.Add("KeyPress", "CFCspawnProtectionMoveCheck", spawnProtectionMoveCheck)

-- Prevent entity damage while in spawn protection
hook.Remove("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection")
hook.Add("EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection", preventDamageDuringSpawnProtection, HOOK_HIGH)
