local hookRun = hook.Run

-- Config Variables --
--
-- Time in seconds after moving for the first time that the player will lose spawn protection
local spawnProtectionMoveDelay = 2

-- Time in seconds before spawn protection wears off if no action is taken
local spawnProtectionDecayTime = 10

-- How long players are allowed to hold weapons after spawning ( in seconds )
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
    ["gmod_tool"]         = true,
    ["gmod_camera"]       = true,
    ["weapon_medkit"]     = true,
    ["none"]              = true,
    ["laserpointer"]      = true,
    ["remotecontroller"]  = true
}

-- Helpers / Wrappers --

local function isValidPlayer( ply )
    local isValid = IsValid( ply ) and ply:IsPlayer()

    return isValid
end
-- Makes a given player transparent
local function setPlayerTransparent( ply )
    ply:SetRenderMode( RENDERMODE_TRANSALPHA )
    ply:Fire( "alpha", 175, 0 )
end

-- Returns a given player to visible state
local function setPlayerVisible( ply )
    if not isValidPlayer( ply ) then return end

    ply:SetRenderMode( RENDERMODE_NORMAL )
    ply:Fire( "alpha", 255, 0 )
end

local function setPlayerNoCollide( ply )
    ply:SetCollisionGroup( COLLISION_GROUP_WORLD )
end

local function setPlayerCollide( ply )
    if not isValidPlayer( ply ) then return end

    ply:SetCollisionGroup( COLLISION_GROUP_NONE )
end

-- Creates a unique name for the Spawn Protection Decay timer
local function playerDecayTimerIdentifier( ply )
    return spawnDecayPrefix .. ply:SteamID64()
end

-- Creates a unique name for the Delayed Removal Timer
local function playerDelayedRemovalTimerIdentifier( ply )
    return delayedRemovalPrefix .. ply:SteamID64()
end

-- Set Spawn Protection
local function setSpawnProtection( ply )
    ply:SetNWBool( "hasSpawnProtection", true )
end

local function setLastSpawnTime( ply )
    ply:SetNWInt( "lastSpawnTime", CurTime() )
end

-- Remove Decay Timer
local function removeDecayTimer( ply )
    -- Timer might exist after player has left
    if not isValidPlayer( ply ) then return end

    local playerIdentifer = playerDecayTimerIdentifier( ply )
    timer.Remove( playerIdentifer )
end

-- Remove Delayed Removal Timer
local function removeDelayedRemoveTimer( ply )
    -- Timer might exist after player has left
    if not isValidPlayer( ply ) then return end

    local playerIdentifer = playerDelayedRemovalTimerIdentifier( ply )
    timer.Remove( playerIdentifer )
end

-- Revoke spawn protection for a player
local function removeSpawnProtection( ply )
    if not isValidPlayer( ply ) then return end

    ply:ChatPrint( "You've lost spawn protection" )
    ply:SetNWBool( "hasSpawnProtection", false )
end

-- Creates a decay timer which will expire after spawnProtectionDecayTime
local function createDecayTimer( ply )
    local playerIdentifer = playerDecayTimerIdentifier( ply )
    timer.Create( playerIdentifer, spawnProtectionDecayTime, 1, function()
        removeSpawnProtection( ply )
        setPlayerVisible( ply )
        setPlayerCollide( ply )
        removeDelayedRemoveTimer( ply )
    end )
end

-- Creates a delayed removal time which will expire after spawnProtectionMoveDelay
local function createDelayedRemoveTimer( ply )
    local playerIdentifer = playerDelayedRemovalTimerIdentifier( ply )
    timer.Create( playerIdentifer, spawnProtectionMoveDelay, 1, function()
        ply:SetNWBool( "disablingSpawnProtection", false )
        removeSpawnProtection( ply )
        setPlayerVisible( ply )
        setPlayerCollide( ply )
        removeDecayTimer( ply )
    end )
end

-- Used to delay the removal of spawn protection
local function delayRemoveSpawnProtection( ply )
    ply:SetNWBool( "disablingSpawnProtection", true )
    createDelayedRemoveTimer( ply )
end

local function playerSpawnedAtEnemySpawnPoint( ply )
    local spawnPoint = ply.LinkedSpawnPoint
    if not spawnPoint or not IsValid( spawnPoint ) then return false end

    local spawnPointOwner = spawnPoint:CPPIGetOwner()
    if spawnPointOwner == ply then return false end

    return true
end

local function playerHasSpawnProtection( ply )
    return ply:GetNWBool( "hasSpawnProtection", false )
end

local function playerIsDisablingSpawnProtection( ply )
    return ply:GetNWBool( "disablingSpawnProtection", false )
end

local function weaponIsAllowed( weapon )
    return allowedSpawnWeapons[weapon:GetClass()]
end

-- Hook functions --

-- Function called on player spawn to grant spawn protection
local function setProtectionOnSpawn( ply )
    if not isValidPlayer( ply ) then return end

    local shouldSet = hookRun( "CFC_SpawnProtection_ShouldSetSpawnProtection", ply )
    if shouldSet == false then return end

    if playerSpawnedAtEnemySpawnPoint( ply ) then return end

    ply:Give( "weapon_physgun" )
    ply:SelectWeapon( "weapon_physgun" )
    timer.Simple( 0, function()
       ply:Give( "weapon_physgun" )
       ply:SelectWeapon( "weapon_physgun" )
    end )

    setLastSpawnTime( ply )
    setSpawnProtection( ply )
    setPlayerTransparent( ply )
    setPlayerNoCollide( ply )
    createDecayTimer( ply )
end

-- Called on weapon change to check if the weapon is allowed,
-- and remove spawn protection if it's not
local function spawnProtectionWeaponChangeCheck( ply, oldWeapon, newWeapon )
    local shouldCheck = hookRun( "CFC_SpawnProtection_ShouldCheckWeaponChange", ply, oldWeapon, newWeapon )
    if shouldCheck == false then return end

    if not playerHasSpawnProtection( ply ) then return end
    if weaponIsAllowed( newWeapon ) then return end

    local lastSpawnTime = ply:GetNWInt( "lastSpawnTime", CurTime() - spawnProtectionWeaponGracePeriod )
    if lastSpawnTime >= CurTime() - spawnProtectionWeaponGracePeriod then return end

    removeSpawnProtection( ply )
    setPlayerVisible( ply )
    setPlayerCollide( ply )
    removeDecayTimer( ply )
    removeDelayedRemoveTimer( ply )
end

-- Called on player keyDown events to check if a movement key was pressed
-- and remove spawn protection if so
local function spawnProtectionMoveCheck( ply, keyCode )
    if playerIsDisablingSpawnProtection( ply ) then return end
    if not playerHasSpawnProtection( ply ) then return end
    if keyVoidsSpawnProtection[ keyCode ] then delayRemoveSpawnProtection( ply ) end
end

-- Prevents damage if a player has spawn protection
local function preventDamageDuringSpawnProtection( ply, damageInfo )
    if playerHasSpawnProtection( ply ) then return true end
end

CFCSpawnProtection = {}

function CFCSpawnProtection:cleanup( ply )
    if not playerHasSpawnProtection( ply ) then return end
    removeSpawnProtection( ply )
    setPlayerVisible( ply )
    setPlayerCollide( ply )
    removeDecayTimer( ply )
    removeDelayedRemoveTimer( ply )
end

-- Hooks --

-- Remove spawn protection when a weapon is drawn
hook.Remove( "PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange" )
hook.Add( "PlayerSwitchWeapon", "CFCspawnProtectionWeaponChange", spawnProtectionWeaponChangeCheck, HOOK_LOW )

-- Remove spawn protection when player enters vehicle
hook.Remove( "PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle" )
hook.Add( "PlayerEnteredVehicle", "CFCremoveSpawnProtectionOnEnterVehicle", function( ply )
    CFCSpawnProtection:cleanup( ply )
end )

-- Enable spawn protection when spawning in PvP
hook.Remove( "PlayerSpawn", "CFCsetSpawnProtection" )
hook.Add( "PlayerSpawn", "CFCsetSpawnProtection", setProtectionOnSpawn )

-- Trigger spawn protection removal on player move
hook.Remove( "KeyPress", "CFCspawnProtectionMoveCheck" )
hook.Add( "KeyPress", "CFCspawnProtectionMoveCheck", spawnProtectionMoveCheck )

-- Prevent entity damage while in spawn protection
hook.Remove( "EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection" )
hook.Add( "EntityTakeDamage", "CFCpreventDamageDuringSpawnProtection", preventDamageDuringSpawnProtection, HOOK_HIGH )
