-- MTIR_LiveWire : machine à coudre électrique inscrite comme consommateur de Live Wire
-- (ADR-002 de Live Wire, API révision 6). Facultatif : sans Live Wire ou avec une
-- révision plus ancienne, rien n'est inscrit. Consommation pendant le travail
-- seulement (MTIR_MachineSound.isRunning) ; coupure lue par MTIR.hasSewingPower.

local T = {}

local SOUND = "MTIR_SewingMachineElectric"

local function square(x, y, z)
    local sq = {}
    function sq:getX() return x end
    function sq:getY() return y end
    function sq:getZ() return z end
    function sq:haveElectricity() return true end
    function sq:hasGridPower() return false end
    function sq:getRoom() return nil end
    return sq
end

local function liveWire(revision)
    registered = {}
    LiveWire = { API = { revision = revision } }
    function LiveWire.API.registerConsumer(id, definition)
        registered[#registered + 1] = { id = id, definition = definition }
        return true
    end
end

function T.setup()
    NOW = 0
    getTimestampMs = function() return NOW end
    isClient = function() return false end
    isServer = function() return false end
    SandboxVars = { MyTailorIsRich = {} }
    MTIR = nil
    LiveWire = nil
    registered = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")
    getWorld = function()
        return { getFreeEmitter = function()
            return { playSoundImpl = function() return 1 end, isPlaying = function() return false end }
        end }
    end
    loadMod("shared/MyTailorIsRich/MTIR_MachineSound.lua")
    MTIR.getMachineSound = function() return SOUND end
    MACHINE = { getSquare = function() return square(10, 20, 0) end }
    loadMod("shared/MyTailorIsRich/MTIR_LiveWire.lua")
end

T["sans Live Wire : rien n'est inscrit"] = function()
    triggerEvent("OnInitWorld")
    assertEq(registered, nil, "aucune inscription")
end

T["Live Wire sans API des consommateurs : rien n'est inscrit"] = function()
    liveWire(5)
    triggerEvent("OnInitWorld")
    assertEq(#registered, 0, "révision 5")
end

T["Live Wire révision 6 : quatre orientations inscrites"] = function()
    liveWire(6)
    triggerEvent("OnInitWorld")
    assertEq(#registered, 1, "une inscription")
    local d = registered[1].definition
    assertEq(registered[1].id, "MTIRSewingMachine", "id")
    assertEq(#d.sprites, 4, "orientations")
    assertEq(d.sprites[1], "mtir_sewing_01_0", "première tuile")
    assertEq(d.sprites[4], "mtir_sewing_01_3", "dernière tuile")
    assertEq(d.category, "other", "famille")
    assertEq(d.display(MACHINE).name, "IGUI_MTIR_Machine_Title", "nom affiché")
end

T["consommation pendant le travail seulement (solo)"] = function()
    local W = MTIR.LiveWire.powerConsumption
    assertEq(W(MACHINE), 0, "au repos")
    local state = MTIR.MachineSound.start("me", MACHINE)
    assertEq(W(MACHINE), MTIR.LiveWire.WATTS, "en marche")
    NOW = 5000
    MTIR.MachineSound.keepAlive(state)
    NOW = 14000
    assertEq(W(MACHINE), MTIR.LiveWire.WATTS, "maintenue")
    MTIR.MachineSound.stop(state)
    assertEq(W(MACHINE), 0, "arrêtée")
end

T["machine sans nouvelles : plus facturée"] = function()
    MTIR.MachineSound.start("me", MACHINE)
    NOW = 10001
    assertEq(MTIR.LiveWire.powerConsumption(MACHINE), 0, "délai dépassé")
end

T["client MP : le serveur seul note la marche"] = function()
    isClient = function() return true end
    sendClientCommand = function() end
    MTIR.MachineSound.start("me", MACHINE)
    assertEq(MTIR.MachineSound.isRunning(MACHINE), false, "client")
    MTIR.MachineSound.setRunning({ x = 10, y = 20, z = 0 }, true)
    assertTrue(MTIR.MachineSound.isRunning(MACHINE), "noté par l'autorité")
end

T["circuit coupé : machine sans courant"] = function()
    liveWire(6)
    local cut = true
    LiveWire.API.consumer = function(o) return o == MACHINE and "MTIRSewingMachine" or nil end
    LiveWire.API.consumerPowered = function() return not cut end
    assertEq(MTIR.hasSewingPower(MACHINE:getSquare(), MACHINE), false, "coupée")
    cut = false
    assertTrue(MTIR.hasSewingPower(MACHINE:getSquare(), MACHINE), "rétablie")
    assertTrue(MTIR.hasSewingPower(MACHINE:getSquare(), {}), "objet non inscrit")
end

return T
