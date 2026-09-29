-- ============================================================================
-- My Tailor Is Rich — son de la machine à coudre, entendu par tous les joueurs
--
-- Joué sur un émetteur libre posé sur la machine, et non sur le personnage :
-- l'émetteur du personnage se tait quand il est invisible (admin, debug).
-- La lecture locale passe par playSoundImpl, sans paquet réseau : un simple
-- playSound sur un émetteur libre envoie un PlayWorldSound aux autres clients,
-- qui rejoueraient la boucle sans jamais recevoir d'arrêt (FMODSoundEmitter,
-- StopSound réservé aux personnages et véhicules).
--
-- En MP, le client qui coud prévient le serveur (commande "machineSound") au
-- début, toutes les ~2 s (en même temps que le bruit pour les zombies) et à la
-- fin. Le serveur vérifie la demande et la relaie aux joueurs proches
-- (MTIR_Server). Chez eux, la boucle s'arrête à la fin, ou d'elle-même sans
-- nouvelles depuis REMOTE_TIMEOUT_MS (déconnexion, plantage). Le contrôle de ce
-- délai n'est accroché à OnTick que tant qu'une boucle distante joue : coût nul
-- au repos.
-- ============================================================================

require "MyTailorIsRich/MTIR_SewingMachine"

MTIR.MachineSound = {}
local MachineSound = MTIR.MachineSound

--- Portée du relais serveur, en cases (au-delà de distanceMax des deux sons).
MachineSound.RELAY_RANGE = 30
local REMOTE_TIMEOUT_MS = 10000
local EXPIRY_CHECK_TICKS = 60

--- Sons de machine autorisés dans une commande réseau.
function MachineSound.isKnownSound(name)
    for _, kind in pairs(MTIR.MACHINE_KINDS) do
        if kind.sound == name then
            return true
        end
    end
    return false
end

local function positionOf(square)
    return { x = square:getX(), y = square:getY(), z = square:getZ() }
end

local function playLocal(square, soundName)
    local emitter = getWorld():getFreeEmitter()
    local id = emitter:playSoundImpl(soundName, square)
    return { emitter = emitter, id = id }
end

local function stopLocal(playing)
    if playing and playing.emitter:isPlaying(playing.id) then
        playing.emitter:stopSound(playing.id)
    end
end

local function notify(character, args)
    if isClient() then
        sendClientCommand(character, MTIR.NET_MODULE, "machineSound", args)
    end
end

-- ----------------------------------------------------------------------------
-- Joueur qui coud (client)
-- ----------------------------------------------------------------------------

--- Lance la boucle de la machine ; renvoie un état à passer à keepAlive/stop.
function MachineSound.start(character, machine)
    local soundName = MTIR.getMachineSound(machine)
    local square = machine and machine:getSquare()
    if not soundName or not square then
        return nil
    end
    local state = playLocal(square, soundName)
    state.character = character
    state.args = positionOf(square)
    state.args.sound = soundName
    state.args.on = true
    notify(character, state.args)
    return state
end

function MachineSound.keepAlive(state)
    if state then
        notify(state.character, state.args)
    end
end

function MachineSound.stop(state)
    if not state then
        return
    end
    stopLocal(state)
    notify(state.character, { x = state.args.x, y = state.args.y, z = state.args.z, on = false })
end

-- ----------------------------------------------------------------------------
-- Autres joueurs (client MP) : boucles reçues du serveur
-- ----------------------------------------------------------------------------

local remote = {}
local remoteCount = 0
local ticks = 0
--- OnTick n'empêche pas les doublons (Event.Add) : on suit l'inscription.
local watching = false
local onTick

local function remoteKey(args)
    return args.x .. "," .. args.y .. "," .. args.z
end

local function onRemote(args)
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then
        return
    end
    local key = remoteKey(args)
    local playing = remote[key]
    if args.on ~= true then
        if playing then
            stopLocal(playing)
            remote[key] = nil
            remoteCount = remoteCount - 1
        end
        return
    end
    local now = getTimestampMs()
    if playing and playing.emitter:isPlaying(playing.id) then
        playing.expires = now + REMOTE_TIMEOUT_MS
        return
    end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square or not MachineSound.isKnownSound(args.sound) then
        return
    end
    if not playing then
        remoteCount = remoteCount + 1
    else
        stopLocal(playing)
    end
    playing = playLocal(square, args.sound)
    playing.expires = now + REMOTE_TIMEOUT_MS
    remote[key] = playing
    if not watching then
        watching = true
        ticks = 0
        Events.OnTick.Add(onTick)
    end
end

local function onServerCommand(module, command, args)
    if module == MTIR.NET_MODULE and command == "machineSound" and type(args) == "table" then
        onRemote(args)
    end
end

--- Coupe les boucles distantes restées sans nouvelles ; se décroche d'OnTick
--- quand il n'en reste plus (le retrait en cours d'événement est prévu par
--- Event.trigger, qui corrige son index).
onTick = function()
    ticks = ticks + 1
    if ticks < EXPIRY_CHECK_TICKS then
        return
    end
    ticks = 0
    local now = getTimestampMs()
    for key, playing in pairs(remote) do
        if now > playing.expires then
            stopLocal(playing)
            remote[key] = nil
            remoteCount = remoteCount - 1
        end
    end
    if remoteCount <= 0 then
        remoteCount = 0
        watching = false
        Events.OnTick.Remove(onTick)
    end
end

-- Pas de son sur un serveur dédié ; en solo, rien n'arrive par le réseau.
if not isServer() then
    Events.OnServerCommand.Add(onServerCommand)
end
