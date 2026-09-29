-- ============================================================================
-- My Tailor Is Rich — machines à coudre (électrique et à pédale)
--
-- Tuiles : mtir_sewing_01_0..3 (électrique, posée sur une table, courant requis)
--          mtir_treadle_01_0..3 (à pédale, meuble au sol, sans courant).
-- Sur une machine, la couture d'après patron, la retouche et la remise en état
-- sont plus rapides et plus sûres (bonus réglés par MachineBonusMultiplier).
-- Entretien (EnableMachineMaintenance) : la machine s'use à chaque travail,
-- casse parfois l'aiguille tenue en main et se bloque à 0 % ; on la répare
-- avec un tournevis et de l'huile du jeu (végétale, d'olive…).
-- L'état est rangé dans modData.movableData, que le vanilla recopie quand on
-- ramasse puis repose le meuble (ISMoveableSpriteProps.lua:1403, 2423).
-- La position voyage dans les paramètres réseau sous forme "x,y,z" ("" = à la
-- main) : l'autorité retrouve la machine et revérifie tout.
-- ============================================================================

require "MyTailorIsRich/MTIR_Patterns"

MTIR.MACHINE_KINDS = {
    electric = {
        prefix = "mtir_sewing_01_",
        item = "Base.Mov_MTIR_SewingMachine",
        needsPower = true,
        repairPerk = "Electricity",
        -- Bonus de base (MachineBonusMultiplier = 1).
        durationFactor = 0.5, levelBonus = 2, precisionBonus = 4, threadFactor = 0.7,
        noiseRadius = 12, noiseVolume = 12,
        wearMin = 2, wearMax = 4,
        sound = "MTIR_SewingMachineElectric",
        titleKey = "IGUI_MTIR_Machine_Title",
    },
    treadle = {
        prefix = "mtir_treadle_01_",
        item = "Base.Mov_MTIR_TreadleMachine",
        needsPower = false,
        repairPerk = "Mechanics",
        durationFactor = 0.75, levelBonus = 1, precisionBonus = 2, threadFactor = 0.85,
        noiseRadius = 5, noiseVolume = 6,
        wearMin = 1, wearMax = 3,
        sound = "MTIR_SewingMachineTreadle",
        titleKey = "IGUI_MTIR_Treadle_Title",
    },
}

--- Huile alimentaire du jeu (tag base:oil : végétale, olive…) : utilisations par entretien.
MTIR.MAINTENANCE_OIL_USES = 3

local CONDITION_MAX = 100
-- Sous ce seuil, la réussite baisse (jusqu'à -50 % à 0 %).
local CONDITION_WARN = 50
local NEEDLE_BREAK_BASE = 0.04
local MAINTENANCE_BASE_GAIN = 20
local MAINTENANCE_GAIN_PER_LEVEL = 8
-- Distance maximale (en cases, par axe) entre le personnage et la machine.
local MAX_REACH = 1.6

-- ----------------------------------------------------------------------------
-- Détection
-- ----------------------------------------------------------------------------

local function spriteName(object)
    local sprite = object and object.getSprite and object:getSprite()
    return sprite and sprite:getName() or nil
end

--- "electric", "treadle" ou nil.
function MTIR.getMachineKindName(object)
    local name = spriteName(object)
    if not name then
        return nil
    end
    for kindName, kind in pairs(MTIR.MACHINE_KINDS) do
        if string.sub(name, 1, #kind.prefix) == kind.prefix then
            return kindName
        end
    end
    return nil
end

function MTIR.getMachineKind(object)
    local kindName = MTIR.getMachineKindName(object)
    return kindName and MTIR.MACHINE_KINDS[kindName] or nil
end

function MTIR.isSewingMachine(object)
    return MTIR.getMachineKindName(object) ~= nil
end

function MTIR.findSewingMachine(square)
    if not square then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if MTIR.isSewingMachine(object) then
            return object
        end
    end
    return nil
end

--- Courant : groupe électrogène, ou réseau public tant qu'il existe, à l'intérieur.
function MTIR.hasSewingPower(square)
    if not square then
        return false
    end
    if square:haveElectricity() then
        return true
    end
    return square:hasGridPower() and square:getRoom() ~= nil
end

-- ----------------------------------------------------------------------------
-- Position réseau
-- ----------------------------------------------------------------------------

function MTIR.encodeMachinePos(object)
    local square = object and object:getSquare()
    if not square then
        return ""
    end
    return square:getX() .. "," .. square:getY() .. "," .. square:getZ()
end

--- Case désignée par "x,y,z" (encodeMachinePos, valable pour tout objet), ou nil.
function MTIR.squareFromPos(pos)
    if type(pos) ~= "string" or pos == "" then
        return nil
    end
    local parts = luautils.split(pos, ",")
    local x, y, z = tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3])
    if not x or not y or not z then
        return nil
    end
    return getCell():getGridSquare(x, y, z)
end

--- Machine désignée par "x,y,z", ou nil (case non chargée, machine retirée).
function MTIR.machineFromPos(pos)
    return MTIR.findSewingMachine(MTIR.squareFromPos(pos))
end

--- Personnage à portée de main d'un objet posé (même étage, case voisine).
function MTIR.isWithinReach(character, object)
    local square = object and object:getSquare()
    if not square or math.floor(character:getZ()) ~= square:getZ() then
        return false
    end
    return math.abs(character:getX() - (square:getX() + 0.5)) <= MAX_REACH
        and math.abs(character:getY() - (square:getY() + 0.5)) <= MAX_REACH
end

function MTIR.isNearSewingMachine(character, machine)
    return MTIR.isWithinReach(character, machine)
end

-- ----------------------------------------------------------------------------
-- État et entretien
-- ----------------------------------------------------------------------------

function MTIR.isMaintenanceEnabled()
    return MTIR.opt("EnableMachineMaintenance") == true
end

--- État de 0 à 100 (100 si l'entretien est désactivé ou jamais utilisée).
function MTIR.getMachineCondition(machine)
    if not MTIR.isMaintenanceEnabled() or not machine or not machine:hasModData() then
        return CONDITION_MAX
    end
    local movable = machine:getModData().movableData
    local value = type(movable) == "table" and tonumber(movable.mtirCondition) or nil
    return value and math.max(0, math.min(CONDITION_MAX, value)) or CONDITION_MAX
end

--- Autorité : fixe l'état et le transmet aux clients.
function MTIR.setMachineCondition(machine, value)
    local modData = machine:getModData()
    if type(modData.movableData) ~= "table" then
        modData.movableData = {}
    end
    modData.movableData.mtirCondition = math.max(0, math.min(CONDITION_MAX, math.floor(value + 0.5)))
    if isServer() then
        machine:transmitModData()
    end
end

function MTIR.isMachineJammed(machine)
    return MTIR.isMaintenanceEnabled() and MTIR.getMachineCondition(machine) <= 0
end

--- Malus de réussite (0 à 0,5) d'une machine usée sous 50 %.
function MTIR.getMachineConditionMalus(machine)
    local condition = MTIR.getMachineCondition(machine)
    if condition >= CONDITION_WARN then
        return 0
    end
    return (CONDITION_WARN - condition) / 100
end

--- Risque de casser l'aiguille à chaque travail (plus élevé sur une machine usée).
function MTIR.getNeedleBreakChance(machine)
    if not MTIR.isMaintenanceEnabled() then
        return 0
    end
    return NEEDLE_BREAK_BASE + (CONDITION_MAX - MTIR.getMachineCondition(machine)) / 1000
end

--- Tirage (sans effet) : l'aiguille casse-t-elle pendant ce travail ?
--- Tiré avant l'issue du travail, appliqué ensuite par MTIR.wearMachine.
function MTIR.rollNeedleBreak(machine)
    if not MTIR.isMaintenanceEnabled() or not MTIR.getMachineKind(machine) then
        return false
    end
    return ZombRandFloat(0, 1) < MTIR.getNeedleBreakChance(machine)
end

--- Autorité : usure de la machine après un travail mené à terme.
function MTIR.wearMachine(machine)
    local kind = MTIR.getMachineKind(machine)
    if not MTIR.isMaintenanceEnabled() or not kind then
        return
    end
    MTIR.setMachineCondition(machine, MTIR.getMachineCondition(machine) - ZombRand(kind.wearMin, kind.wearMax + 1))
end

function MTIR.getMaintenancePerk(machine)
    local kind = MTIR.getMachineKind(machine)
    return Perks[kind and kind.repairPerk or "Maintenance"]
end

--- État regagné par un entretien selon la compétence de réparation.
function MTIR.getMaintenanceGain(character, machine)
    return MAINTENANCE_BASE_GAIN + MAINTENANCE_GAIN_PER_LEVEL * character:getPerkLevel(MTIR.getMaintenancePerk(machine))
end

function MTIR.getMaintenanceDuration()
    return math.max(1, 300 * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.predicateScrewdriver(item)
    return not item:isBroken() and item:hasTag(ItemTag.SCREWDRIVER)
end

--- Huile utilisable pour l'entretien : tag base:oil et assez d'utilisations
--- (pour un aliment, une utilisation = 1 % de sa faim, Food.getCurrentUses).
function MTIR.predicateMaintenanceOil(item)
    return item:hasTag(ItemTag.OIL) and item:getCurrentUses() >= MTIR.MAINTENANCE_OIL_USES
end

-- ----------------------------------------------------------------------------
-- Bonus
-- ----------------------------------------------------------------------------

--- Bonus effectifs d'une machine (options sandbox et usure comprises).
--- Mêmes champs que MTIR.SEW_BY_HAND, plus successMalus et machine.
function MTIR.getMachineMods(machine)
    local kind = MTIR.getMachineKind(machine)
    if not kind then
        return MTIR.SEW_BY_HAND
    end
    local scale = MTIR.opt("MachineBonusMultiplier")
    return {
        durationFactor = math.max(0.1, 1 - (1 - kind.durationFactor) * scale),
        levelBonus = math.floor(kind.levelBonus * scale + 0.5),
        precisionBonus = math.floor(kind.precisionBonus * scale + 0.5),
        threadFactor = math.max(0.1, 1 - (1 - kind.threadFactor) * scale),
        successMalus = MTIR.getMachineConditionMalus(machine),
        machine = machine,
    }
end

--- Motif d'indisponibilité (clé de traduction), ou nil si la machine est utilisable.
--- data : données de patron (les chaussures se cousent à la main), ou nil.
function MTIR.getSewingMachineProblem(character, machine, data)
    local kind = MTIR.getMachineKind(machine)
    -- Une machine ramassée garde sa case (IsoObject.removeFromSquare ne l'efface
    -- pas) : seul son index dans la case (-1) révèle qu'elle n'y est plus.
    if not kind or not machine:getSquare() or machine:getObjectIndex() == -1 then
        return "IGUI_MTIR_Machine_Missing"
    end
    if kind.needsPower and not MTIR.hasSewingPower(machine:getSquare()) then
        return "IGUI_MTIR_Machine_NoPower"
    end
    if MTIR.isMachineJammed(machine) then
        return "IGUI_MTIR_Machine_Jammed"
    end
    if data and data.kind == "shoe" then
        return "IGUI_MTIR_Machine_NoShoes"
    end
    if character and not MTIR.isNearSewingMachine(character, machine) then
        return "IGUI_MTIR_Machine_TooFar"
    end
    return nil
end

--- Bonus d'une action : machine utilisable, ou main ; nil si la machine demandée ne l'est plus.
function MTIR.resolveWorkMods(character, machinePos, data)
    if machinePos == nil or machinePos == "" then
        return MTIR.SEW_BY_HAND
    end
    local machine = MTIR.machineFromPos(machinePos)
    if MTIR.getSewingMachineProblem(character, machine, data) then
        return nil
    end
    return MTIR.getMachineMods(machine)
end

-- ----------------------------------------------------------------------------
-- Bruit et son (client : l'action tourne là ; addSound est relayé au serveur)
-- ----------------------------------------------------------------------------

--- Bruit qui attire les zombies, à appeler régulièrement pendant le travail.
function MTIR.emitMachineNoise(character, machine)
    local kind = MTIR.getMachineKind(machine)
    local scale = MTIR.opt("MachineNoiseMultiplier")
    if not kind or scale <= 0 then
        return
    end
    local radius = math.floor(kind.noiseRadius * scale + 0.5)
    if radius > 0 then
        addSound(character, machine:getSquare():getX(), machine:getSquare():getY(), machine:getSquare():getZ(),
            radius, kind.noiseVolume)
    end
end

function MTIR.getMachineSound(machine)
    local kind = MTIR.getMachineKind(machine)
    return kind and kind.sound or nil
end

-- ----------------------------------------------------------------------------
-- Dé à coudre (couture à la main)
-- ----------------------------------------------------------------------------

function MTIR.needsThimble(mods)
    return MTIR.opt("RequireThimble") == true and (mods == nil or mods.machine == nil)
end

function MTIR.predicateThimble(item)
    return item:hasTag(ItemTag.THIMBLE)
end

--- Dé à coudre de l'inventaire (sacs compris), ou nil.
function MTIR.findThimble(character)
    return character:getInventory():getFirstEvalRecurse(MTIR.predicateThimble)
end

--- Vrai si la couture à la main est permise (dé présent, ou option désactivée).
function MTIR.hasThimbleFor(character, mods)
    return not MTIR.needsThimble(mods) or MTIR.findThimble(character) ~= nil
end

return MTIR
