-- MTIR_MachineSound : boucle locale, relais MP, arrêt et délai d'expiration,
-- inscription à OnTick seulement tant qu'une boucle distante joue.

local T = {}

local SOUND = "MTIR_SewingMachineElectric"

function T.setup()
    NOW = 0
    getTimestampMs = function() return NOW end
    CLIENT = true
    isClient = function() return CLIENT end
    isServer = function() return false end

    playing = {}
    played = 0
    local nextId = 0
    local function newEmitter()
        local emitter = {}
        function emitter:playSoundImpl(name, square)
            nextId = nextId + 1
            playing[nextId] = name
            played = played + 1
            return nextId
        end
        function emitter:isPlaying(id) return playing[id] ~= nil end
        function emitter:stopSound(id) playing[id] = nil end
        return emitter
    end
    getWorld = function() return { getFreeEmitter = function() return newEmitter() end } end

    local function square(x, y, z)
        return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
    end
    getCell = function() return { getGridSquare = function(_, x, y, z) return square(x, y, z) end } end

    sent = {}
    sendClientCommand = function(_, module, command, args)
        sent[#sent + 1] = { module = module, command = command, args = args }
    end

    MTIR = { NET_MODULE = "MTIR", MACHINE_KINDS = { electric = { sound = SOUND } } }
    MACHINE = { getSquare = function() return square(10, 20, 0) end }
    MTIR.getMachineSound = function(machine) return machine == MACHINE and SOUND or nil end

    loadMod("shared/MyTailorIsRich/MTIR_MachineSound.lua")
end

local function activeCount()
    local n = 0
    for _ in pairs(playing) do
        n = n + 1
    end
    return n
end

local function runTicks(n)
    for _ = 1, n do
        triggerEvent("OnTick")
    end
end

local function remote(args)
    triggerEvent("OnServerCommand", "MTIR", "machineSound", args)
end

local function on(x, sound)
    return { x = x, y = 2, z = 0, on = true, sound = sound or SOUND }
end

T["le joueur qui coud joue localement et prévient le serveur"] = function()
    local state = MTIR.MachineSound.start("me", MACHINE)
    assertEq(activeCount(), 1, "boucle locale")
    assertEq(#sent, 1, "commande de début")
    assertEq(sent[1].args.on, true, "on")
    assertEq(sent[1].args.sound, SOUND, "son")
    MTIR.MachineSound.keepAlive(state)
    assertEq(#sent, 2, "maintien")
    MTIR.MachineSound.stop(state)
    assertEq(activeCount(), 0, "boucle arrêtée")
    assertEq(sent[3].args.on, false, "commande de fin")
end

T["en solo, aucune commande réseau"] = function()
    CLIENT = false
    local state = MTIR.MachineSound.start("me", MACHINE)
    MTIR.MachineSound.keepAlive(state)
    MTIR.MachineSound.stop(state)
    assertEq(#sent, 0, "commandes envoyées")
end

T["aucun abonné OnTick au repos"] = function()
    assertEq(listenerCount("OnTick"), 0, "abonnés au chargement")
    runTicks(120)
    assertEq(listenerCount("OnTick"), 0, "abonnés après 120 ticks")
end

T["boucle distante : maintien sans relecture, arrêt, décrochage"] = function()
    remote(on(1))
    assertEq(activeCount(), 1, "boucle distante")
    assertEq(listenerCount("OnTick"), 1, "abonné pendant la lecture")
    remote(on(1))
    assertEq(played, 1, "le maintien ne relance pas le son")
    remote({ x = 1, y = 2, z = 0, on = false })
    assertEq(activeCount(), 0, "arrêt reçu")
    runTicks(60)
    assertEq(listenerCount("OnTick"), 0, "décroché quand plus rien ne joue")
end

T["boucle distante sans nouvelles : expire puis décroche"] = function()
    remote(on(7))
    runTicks(60)
    assertEq(activeCount(), 1, "pas encore expirée")
    NOW = 20000
    runTicks(60)
    assertEq(activeCount(), 0, "expirée")
    assertEq(listenerCount("OnTick"), 0, "décrochée")
end

T["une seule inscription pour plusieurs machines"] = function()
    remote(on(1))
    remote(on(2))
    assertEq(activeCount(), 2, "deux boucles")
    assertEq(listenerCount("OnTick"), 1, "un seul abonné")
end

T["commandes invalides ignorées"] = function()
    remote(on(5, "Evil"))
    remote({ x = "1", y = 2, z = 0, on = true, sound = SOUND })
    remote({ on = true, sound = SOUND })
    assertEq(activeCount(), 0, "rien ne joue")
    assertEq(listenerCount("OnTick"), 0, "aucun abonné")
end

return T
