-- ============================================================================
-- My Tailor Is Rich — autorité (solo et serveur MP)
--
-- * Chaque minute : tailles de la tenue de départ, chute, retrait, stats.
-- * Chaque heure  : usure des vêtements portés.
-- * OnTick        : raideur musculaire (OnPlayerUpdate ne se déclenche pas
--                   côté serveur en 42.21, et le corps y fait autorité).
-- * OnZombieDead  : une taille cohérente pour toute la tenue du zombie, fixée
--                   avant la création et l'envoi du cadavre.
-- * Commandes     : taille d'artisanat choisie, escalade (déchirures).
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_ShoeEffects"
require "MyTailorIsRich/MTIR_VanillaHooks"
require "MyTailorIsRich/MTIR_MachineSound"

if isClient() then
    return
end

local STIFFNESS_TICKS = 30
local DISCOMFORT_SYNC_TICKS = 300
local CLIMB_COOLDOWN_MS = 500
local FALL_COOLDOWN_MS = 1500
--- Au plus un relais de son de machine par joueur et par intervalle.
local MACHINE_SOUND_COOLDOWN_MS = 500

local function forEachAuthorityPlayer(callback)
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player and not player:isDead() then
                callback(player)
            end
        end
        return
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and not player:isDead() then
            callback(player)
        end
    end
end

local function updatePlayerClothes(player)
    MTIR.applyAuthorityWornEffects(player)
    MTIR.applyDerivedStats(player)
end

local function onEveryOneMinute()
    forEachAuthorityPlayer(updatePlayerClothes)
end

local function onEveryHours()
    MTIR.DegradingChance = {}
    forEachAuthorityPlayer(MTIR.degradeWornClothes)
end

local tickCount = 0
local elapsedFactor = 0
local lastWorldHours = nil

--- Minutes de jeu écoulées depuis le dernier passage (0 au premier).
local function elapsedGameMinutes()
    local hours = getGameTime():getWorldAgeHours()
    local minutes = lastWorldHours and math.max(0, (hours - lastWorldHours) * 60) or 0
    lastWorldHours = hours
    return minutes
end

local syncTickCount = 0

local function onTick()
    -- Plancher d'inconfort maintenu à chaque tick (le moteur le fait redescendre à chaque mise à jour).
    forEachAuthorityPlayer(MTIR.enforceDiscomfortFloor)

    syncTickCount = syncTickCount + 1
    if syncTickCount >= DISCOMFORT_SYNC_TICKS then
        syncTickCount = 0
        forEachAuthorityPlayer(MTIR.syncDiscomfortIfCorrected)
    end

    elapsedFactor = elapsedFactor + getGameTime():getMultiplier()
    tickCount = tickCount + 1
    if tickCount < STIFFNESS_TICKS then
        return
    end
    local factor = elapsedFactor
    local minutes = elapsedGameMinutes()
    tickCount = 0
    elapsedFactor = 0
    forEachAuthorityPlayer(function(player)
        MTIR.applyStiffness(player, factor)
        MTIR.refreshDiscomfortFloor(player)
        MTIR.applyShoeTick(player, factor, minutes)
    end)
end

--- Solo : tailles de la tenue de départ dès l'apparition du personnage.
local function onCreatePlayer(_, player)
    if isServer() or not player then
        return
    end
    updatePlayerClothes(player)
end

local function onZombieDead(zombie)
    if not zombie or not instanceof(zombie, "IsoZombie") then
        return
    end
    local sizeName = MTIR.getRandomClothesSize().name
    local shoeSize = MTIR.randomShoeSize(zombie:isFemale())
    local worn = zombie:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item and MTIR.canClothesHaveSize(item) and not MTIR.getData(item) then
                MTIR.createData(item, sizeName)
            elseif item and MTIR.canShoeHaveSize(item) and not MTIR.getShoeData(item) then
                MTIR.createShoeData(item, shoeSize)
            end
        end
    end
    local inventory = zombie:getInventory()
    if inventory then
        MTIR.sizeClothingCollection(inventory:getItems(), sizeName)
        MTIR.sizeShoesInCollection(inventory:getItems(), shoeSize)
    end
end

-- ----------------------------------------------------------------------------
-- Commandes client (en solo aussi : sendClientCommand passe par ici)
-- ----------------------------------------------------------------------------

local lastClimb = {}
local lastFall = {}
local Commands = {}

function Commands.setCraftSize(player, args)
    MTIR.setCraftSizeFor(player, args.fullType, args.size)
end

function Commands.climb(player, args)
    if type(args.kind) ~= "string" then
        return
    end
    local key = MTIR.playerKey(player)
    local now = getTimestampMs()
    if lastClimb[key] and now - lastClimb[key] < CLIMB_COOLDOWN_MS then
        return
    end
    lastClimb[key] = now
    MTIR.rollClimbRips(player, args.kind)
    -- Chute pendant l'escalade (clôture ratée, grillage lâché) : elle reste dans l'état
    -- d'escalade, sans état de chute ; le client la signale avec fell = true.
    if args.fell == true then
        lastFall[key] = now
        MTIR.rollShoeLossEvent(player, "fall")
    else
        MTIR.rollShoeLossEvent(player, args.kind)
    end
end

--- Chute hors escalade. Une chute déjà comptée à l'escalade n'est pas retirée.
function Commands.fall(player)
    local key = MTIR.playerKey(player)
    local now = getTimestampMs()
    if lastFall[key] and now - lastFall[key] < FALL_COOLDOWN_MS then
        return
    end
    lastFall[key] = now
    MTIR.rollShoeLossEvent(player, "fall")
end

--- Son de la machine (MTIR_MachineSound) : relayé aux autres joueurs proches.
--- Marche : son connu, machine présente et à portée du joueur. Arrêt : toujours
--- relayé (la machine a pu être ramassée entre-temps).
local lastMachineSound = {}

function Commands.machineSound(player, args)
    local x, y, z = args.x, args.y, args.z
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return
    end
    local relay = { x = x, y = y, z = z, on = args.on == true }
    if relay.on then
        local key = MTIR.playerKey(player)
        local now = getTimestampMs()
        if lastMachineSound[key] and now - lastMachineSound[key] < MACHINE_SOUND_COOLDOWN_MS then
            return
        end
        local machine = MTIR.findSewingMachine(getCell():getGridSquare(x, y, z))
        if not machine or MTIR.getMachineSound(machine) ~= args.sound
            or not MTIR.isWithinReach(player, machine) then
            return
        end
        lastMachineSound[key] = now
        relay.sound = args.sound
    end
    local players = getOnlinePlayers()
    local range = MTIR.MachineSound.RELAY_RANGE
    for i = 0, (players and players:size() or 0) - 1 do
        local other = players:get(i)
        if other ~= player and math.abs(other:getX() - x) <= range and math.abs(other:getY() - y) <= range then
            sendServerCommand(other, MTIR.NET_MODULE, "machineSound", relay)
        end
    end
end

local function onClientCommand(module, command, player, args)
    if module ~= MTIR.NET_MODULE or not player or type(args) ~= "table" then
        return
    end
    local handler = Commands[command]
    if handler then
        handler(player, args)
    end
end

Events.EveryOneMinute.Add(onEveryOneMinute)
Events.EveryHours.Add(onEveryHours)
Events.OnTick.Add(onTick)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnZombieDead.Add(onZombieDead)
Events.OnClientCommand.Add(onClientCommand)
