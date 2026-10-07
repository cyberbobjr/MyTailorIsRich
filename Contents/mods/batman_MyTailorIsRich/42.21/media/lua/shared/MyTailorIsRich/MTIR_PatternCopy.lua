-- ============================================================================
-- My Tailor Is Rich — copier un patron
--
-- On reporte les pièces d'un patron sur des feuilles neuves, à une table, avec
-- des ciseaux et un crayon ou un stylo (comme le tracé). L'original est gardé
-- intact (aucune utilisation retirée). La copie est un « Patron tracé » :
--   * précision = celle de l'original moins PatternCopyPrecisionLoss (au moins 0) :
--     une copie de copie perd encore en précision ;
--   * utilisations neuves (PatternMaxUses) ;
--   * `copies` compte les générations (1 = copie de l'original).
-- Option EnablePatternCopy : la copie peut être désactivée.
-- ============================================================================

require "MyTailorIsRich/MTIR_Patterns"
require "MyTailorIsRich/MTIR_PatternBinder"

-- Durée : pas de décousage, seulement le report des pièces.
local COPY_BASE_TIME = 80
local COPY_TIME_PER_DIFFICULTY = 40
local COPY_XP_FACTOR = 0.5

function MTIR.isPatternCopyEnabled()
    return MTIR.opt("EnablePatternCopy") ~= false
end

function MTIR.getPatternCopyLoss()
    return math.max(0, math.floor(tonumber(MTIR.opt("PatternCopyPrecisionLoss")) or 0))
end

--- Données de la copie (pures) : précision réduite de `loss` (au moins 0),
--- `maxUses` utilisations, une génération de plus. Toutes les autres données
--- de l'original (modèle, tissu, difficulté, champs d'autres mods) sont gardées.
function MTIR.makePatternCopyData(data, loss, maxUses)
    local copy = MTIR.copyPlainData(data)
    copy.precision = math.max(0, (tonumber(data.precision) or 0) - math.max(0, loss or 0))
    copy.uses = maxUses
    copy.copies = (tonumber(data.copies) or 0) + 1
    return copy
end

--- Précision qu'aura une copie de `data` avec les options courantes.
function MTIR.getCopyPrecision(data)
    return math.max(0, (tonumber(data.precision) or 0) - MTIR.getPatternCopyLoss())
end

--- Niveau de Couture pour copier : celui du tracé (un niveau de moins que la couture).
function MTIR.getRequiredLevelToCopy(data)
    return MTIR.getRequiredLevelToTrace(data)
end

function MTIR.getRequiredPaperToCopy(data)
    return MTIR.getRequiredPaper(data)
end

function MTIR.getCopyDuration(data)
    return math.max(1, (COPY_BASE_TIME + (data.difficulty or 0) * COPY_TIME_PER_DIFFICULTY)
        * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getCopyXp(data)
    return MTIR.getTraceXp(data) * COPY_XP_FACTOR
end

--- Autorité : crée la copie dans l'inventaire du personnage.
function MTIR.createPatternCopy(character, data)
    local pattern = instanceItem(MTIR.PATTERN_ITEM)
    if not pattern then
        return nil
    end
    pattern:getModData()[MTIR.PATTERN_DATA_KEY] = MTIR.makePatternCopyData(data, MTIR.getPatternCopyLoss(),
        MTIR.opt("PatternMaxUses"))
    -- Nom enregistré dans l'objet (langue de l'autorité, comme MTIR.createPattern).
    pattern:setName(MTIR.composePatternName("IGUI_MTIR_PatternCopyName", data.fullType))
    pattern:setCustomName(true)
    local inventory = character:getInventory()
    inventory:AddItem(pattern)
    sendAddItemToContainer(inventory, pattern)
    return pattern
end

return MTIR
