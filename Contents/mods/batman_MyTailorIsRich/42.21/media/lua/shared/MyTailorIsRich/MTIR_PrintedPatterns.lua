-- ============================================================================
-- My Tailor Is Rich — patrons du commerce (Base.MTIR_PrintedPattern)
--
-- Trouvés dans le butin, ils portent les mêmes données qu'un patron tracé
-- (ModData "MTIR_Pattern") : le vêtement est tiré au hasard parmi TOUS les
-- vêtements chargés, mods compris, qui pourraient être tracés par ce mod.
--
-- Appel : OnCreate du script (InventoryItem.initialiseItem, 42.21). Le moteur
-- l'appelle à chaque instanciation sur le fil du jeu, du chargement ou du
-- serveur, y compris AVANT la relecture d'un objet sauvegardé ou reçu du
-- réseau : InventoryItem.load() efface ensuite ModData et nom, puis les relit.
-- Le tirage fait sur l'autorité (solo, ou serveur qui remplit les conteneurs)
-- est donc celui qui reste ; les tirages faits avant une relecture sont perdus.
-- ============================================================================

require "MyTailorIsRich/MTIR_Patterns"
require "MyTailorIsRich/MTIR_Shoes"

-- Précision d'un patron imprimé : celle d'un bon traceur (niveaux 5 à 8).
local MIN_PRECISION = 5
local MAX_PRECISION = 8

-- ----------------------------------------------------------------------------
-- Description d'un script Item (sans instance)
-- ----------------------------------------------------------------------------

local function isBulletLocation(scriptItem)
    local key = MTIR.locKey(scriptItem)
    return key ~= nil and string.find(key, "bullet", 1, true) ~= nil
end

--- Modèle { kind, fabric, difficulty } d'un script Item, ou nil s'il ne peut pas
--- servir de patron. Mêmes règles que MTIR.getTraceKind / MTIR.describeModel
--- (matière des chaussures : MTIR.getShoeMaterial),
--- sauf la protection balistique (valeur du script non exposée : voir isBallistic).
function MTIR.describeScriptModel(scriptItem)
    if not scriptItem or scriptItem:isHidden() or scriptItem:getObsolete() then
        return nil
    end
    local sizing = MTIR.getSizing(scriptItem)
    if not sizing or isBulletLocation(scriptItem) then
        return nil
    end
    if sizing.kind == "shoe" then
        if not MTIR.opt("EnableShoeSizes") or MTIR.UNSIZED_SHOES[scriptItem:getFullName()] then
            return nil
        end
        -- Caoutchouc ou plastique (bottes de pluie, tongs…) : pas de patron.
        local fabric = MTIR.getShoeMaterial(scriptItem)
        if not fabric then
            return nil
        end
        return { kind = "shoe", fabric = fabric, difficulty = MTIR.SHOE_PATTERN_DIFFICULTY }
    end
    local fabric = scriptItem:getFabricType()
    if not fabric or MTIR.FABRIC_DIFFICULTY[fabric] == nil then
        return nil
    end
    local difficulty = sizing.slot and sizing.slot.difficulty or 1
    return { kind = "clothes", fabric = fabric, difficulty = difficulty }
end

-- ----------------------------------------------------------------------------
-- Liste des vêtements imprimables (construite une fois, tous modules)
-- ----------------------------------------------------------------------------

local garments = nil
local garmentsKey = nil
-- fullType -> true : protection balistique constatée sur une instance.
local ballistic = {}

--- Les options qui changent le résultat de MTIR.describeScriptModel.
local function optionsKey()
    return tostring(MTIR.opt("ListCustomClothes")) .. "|" .. tostring(MTIR.opt("ListExcludedClothes"))
        .. "|" .. tostring(MTIR.opt("ExtraSizedLocations")) .. "|" .. tostring(MTIR.opt("EnableShoeSizes"))
end

local function buildGarments()
    local list = {}
    local items = ScriptManager.instance:getAllItems()
    for i = 0, items:size() - 1 do
        local scriptItem = items:get(i)
        local model = MTIR.describeScriptModel(scriptItem)
        local fullType = scriptItem:getFullName()
        if model and not ballistic[fullType] then
            model.fullType = fullType
            table.insert(list, model)
        end
    end
    return list
end

--- Liste courante ; reconstruite si une option de taille a changé.
function MTIR.getPrintableGarments()
    local key = optionsKey()
    if garments == nil or garmentsKey ~= key then
        garments = buildGarments()
        garmentsKey = key
        print("[MTIR] patrons du commerce : " .. tostring(#garments) .. " vetements possibles")
    end
    return garments
end

--- La valeur BulletDefense n'est lisible que sur une instance (Clothing) :
--- vérifiée au premier tirage de chaque vêtement, puis mémorisée.
local function isBallistic(fullType)
    if ballistic[fullType] ~= nil then
        return ballistic[fullType]
    end
    local sample = instanceItem(fullType)
    local result = sample ~= nil and instanceof(sample, "Clothing") and sample:getBulletDefense() > 0
    ballistic[fullType] = result
    return result
end

--- Tire un vêtement au hasard ; un vêtement balistique est retiré de la liste.
local function pickGarment()
    local list = MTIR.getPrintableGarments()
    while #list > 0 do
        local index = ZombRand(#list) + 1
        local garment = list[index]
        if not isBallistic(garment.fullType) then
            return garment
        end
        table.remove(list, index)
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- OnCreate
-- ----------------------------------------------------------------------------

--- Pose les données de patron sur `item` (sans effet s'il en a déjà).
function MTIR.onCreatePrintedPattern(item)
    if not item then
        return
    end
    local modData = item:getModData()
    if modData[MTIR.PATTERN_DATA_KEY] then
        return
    end
    local garment = pickGarment()
    if not garment then
        print("[MTIR] patron du commerce : aucun vetement imprimable")
        return
    end
    modData[MTIR.PATTERN_DATA_KEY] = {
        fullType = garment.fullType,
        kind = garment.kind,
        fabric = garment.fabric,
        difficulty = garment.difficulty,
        precision = ZombRand(MIN_PRECISION, MAX_PRECISION + 1),
        uses = MTIR.opt("PatternMaxUses"),
    }
    -- Nom enregistré dans l'objet (langue de l'autorité, comme MTIR.createPattern).
    item:setName(getText("IGUI_MTIR_PrintedPatternName", getItemNameFromFullType(garment.fullType)))
    item:setCustomName(true)
end

return MTIR
