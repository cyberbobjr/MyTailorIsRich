-- ============================================================================
-- My Tailor Is Rich — machine à coudre électrique inscrite auprès de Live Wire
--
-- Facultatif : sans Live Wire (ou avec une version sans l'API des consommateurs,
-- révision < 6), rien n'est inscrit et rien ne change. Aucun require= dans mod.info.
-- API publique de Live Wire (ADR-002, LiveWire.API.registerConsumer) : la machine
-- consomme MTIR.LiveWire.WATTS pendant qu'elle coud (MTIR_MachineSound.isRunning),
-- 0 à l'arrêt ; Live Wire la facture à son onduleur, la liste dans « Afficher les
-- consommateurs » et ses circuits peuvent la couper (MTIR.hasSewingPower interroge
-- alors LiveWire.API.consumerPowered). Inscrite des deux côtés (shared), à
-- OnInitWorld, avant que Live Wire ferme les inscriptions (OnInitGlobalModData).
-- ============================================================================

require "MyTailorIsRich/MTIR_SewingMachine"
require "MyTailorIsRich/MTIR_MachineSound"

MTIR.LiveWire = {}
local LW = MTIR.LiveWire

LW.CONSUMER_ID = "MTIRSewingMachine"
--- Puissance d'une machine à coudre domestique en marche, en W (avant les réglages
--- sandbox de Live Wire). Même valeur que l'ancien adaptateur de LiveWire Extended.
LW.WATTS = 100
--- Tuiles : une par orientation, une seule case chacune (MTIR_entities.txt).
LW.FACINGS = 4

--- API de Live Wire si elle accepte les consommateurs, sinon nil.
function LW.api()
    local api = LiveWire and LiveWire.API
    if api and (api.revision or 0) >= 6 and api.registerConsumer then
        return api
    end
    return nil
end

function LW.sprites()
    local prefix = MTIR.MACHINE_KINDS.electric.prefix
    local sprites = {}
    for i = 0, LW.FACINGS - 1 do
        sprites[#sprites + 1] = prefix .. i
    end
    return sprites
end

--- Appelée par Live Wire sur l'autorité : W pendant le travail, 0 au repos.
function LW.powerConsumption(machine)
    return MTIR.MachineSound.isRunning(machine) and LW.WATTS or 0
end

--- Nom affiché dans le logiciel de gestion de Live Wire (traduit par le client).
function LW.display(machine)
    return { name = MTIR.MACHINE_KINDS.electric.titleKey }
end

function LW.register()
    local api = LW.api()
    if not api then
        return
    end
    local ok, why = api.registerConsumer(LW.CONSUMER_ID, {
        sprites = LW.sprites(),
        powerConsumption = LW.powerConsumption,
        category = "other",
        circuit = "equipment",
        display = LW.display,
    })
    if not ok and why ~= "duplicate_consumer" then
        print("MyTailorIsRich: Live Wire refused the electric sewing machine: " .. tostring(why))
    end
end

Events.OnInitWorld.Add(LW.register)

return LW
