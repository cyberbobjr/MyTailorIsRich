-- ============================================================================
-- My Tailor Is Rich — classeur à patrons (Base.MTIR_PatternBinder)
--
-- Le classeur range des patrons du mod SANS les garder comme objets : chaque
-- patron rangé devient une entrée de la ModData "MTIR_Binder" du classeur,
-- qui conserve son type d'objet, son nom et TOUTE sa ModData (modèle,
-- utilisations, précision, génération de copie, données d'autres mods…).
-- Le sortir recrée un objet du même type avec ces données.
--
-- Données : { nextId = n, entries = { { id, type, name, modData }, ... } }.
-- `id` ne change jamais : le client désigne une entrée par son id (paramètre
-- réseau `entryId`), jamais par sa place dans la liste.
--
-- Écritures réservées à l'autorité (solo, serveur) : actions chronométrées
-- MTIR_BinderStoreAction, MTIR_BinderTakeAction et MTIR_SewPatternAction,
-- puis MTIR.syncItem (syncItemFields : ModData remplacée entièrement, poids).
-- Les fonctions « pures » (tables Lua seulement) sont testées hors jeu.
-- ============================================================================

require "MyTailorIsRich/MTIR_Patterns"

MTIR.BINDER_ITEM = "Base.MTIR_PatternBinder"
MTIR.BINDER_DATA_KEY = "MTIR_Binder"

-- Poids du classeur vide (Weight du script) et d'un patron rangé (feuilles sans pochette).
local BINDER_WEIGHT = 0.3
local WEIGHT_PER_PATTERN = 0.1
local DEFAULT_CAPACITY = 20

-- ----------------------------------------------------------------------------
-- Données pures (tables Lua)
-- ----------------------------------------------------------------------------

--- Copie profonde des valeurs sauvegardables : textes, nombres, booléens et
--- tables. Les objets Java sont ignorés (perdus à la sauvegarde de toute façon).
function MTIR.copyPlainData(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for key, value in pairs(source) do
        local keyType, valueType = type(key), type(value)
        if keyType == "string" or keyType == "number" then
            if valueType == "table" then
                copy[key] = MTIR.copyPlainData(value)
            elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
                copy[key] = value
            end
        end
    end
    return copy
end

function MTIR.binderNewData()
    return { nextId = 1, entries = {} }
end

--- Nombre d'entrées (table absente : 0).
function MTIR.binderCount(binderData)
    if type(binderData) ~= "table" or type(binderData.entries) ~= "table" then
        return 0
    end
    return #binderData.entries
end

--- Données de patron d'une entrée (mêmes champs que MTIR.getPatternData), ou nil.
function MTIR.binderEntryPattern(entry)
    local modData = type(entry) == "table" and entry.modData or nil
    local data = type(modData) == "table" and modData[MTIR.PATTERN_DATA_KEY] or nil
    if type(data) ~= "table" or not data.fullType or not data.kind then
        return nil
    end
    return data
end

--- Entrée d'id `id` et sa place, ou nil.
function MTIR.binderFindEntry(binderData, id)
    local number = tonumber(id)
    if number == nil or type(binderData) ~= "table" or type(binderData.entries) ~= "table" then
        return nil, nil
    end
    for index, entry in ipairs(binderData.entries) do
        if entry.id == number then
            return entry, index
        end
    end
    return nil, nil
end

--- Ajoute une entrée { type, name, modData } ; rend son id, ou nil si le
--- classeur est plein ou l'entrée n'est pas un patron.
function MTIR.binderAddEntry(binderData, entry, capacity)
    if MTIR.binderEntryPattern(entry) == nil or MTIR.binderCount(binderData) >= capacity then
        return nil
    end
    binderData.entries = binderData.entries or {}
    -- nextId ne redescend jamais, même si des entrées ont été retirées.
    local id = math.max(1, math.floor(tonumber(binderData.nextId) or 1))
    for _, existing in ipairs(binderData.entries) do
        if type(existing.id) == "number" and existing.id >= id then
            id = existing.id + 1
        end
    end
    binderData.nextId = id + 1
    table.insert(binderData.entries, {
        id = id,
        type = tostring(entry.type),
        name = tostring(entry.name or ""),
        modData = MTIR.copyPlainData(entry.modData),
    })
    return id
end

--- Retire l'entrée d'id `id` ; rend l'entrée retirée, ou nil.
function MTIR.binderRemoveEntry(binderData, id)
    local entry, index = MTIR.binderFindEntry(binderData, id)
    if not entry then
        return nil
    end
    table.remove(binderData.entries, index)
    return entry
end

--- Une couture d'après une entrée : une utilisation de moins. Rend
--- "worn" (entrée retirée, patron usé), "used", ou nil (entrée absente).
function MTIR.binderWearEntry(binderData, id)
    local entry = MTIR.binderFindEntry(binderData, id)
    local data = MTIR.binderEntryPattern(entry)
    if not data then
        return nil
    end
    data.uses = (tonumber(data.uses) or 1) - 1
    if data.uses <= 0 then
        MTIR.binderRemoveEntry(binderData, id)
        return "worn"
    end
    return "used"
end

-- ----------------------------------------------------------------------------
-- Objet classeur
-- ----------------------------------------------------------------------------

function MTIR.isBinder(item)
    return item ~= nil and item:getFullType() == MTIR.BINDER_ITEM
end

function MTIR.getBinderCapacity()
    return math.max(1, math.floor(tonumber(MTIR.opt("PatternBinderCapacity")) or DEFAULT_CAPACITY))
end

--- Données du classeur en lecture (nil s'il n'a jamais rien contenu). Aucune écriture.
function MTIR.getBinderData(binder)
    if not MTIR.isBinder(binder) or not binder:hasModData() then
        return nil
    end
    local data = binder:getModData()[MTIR.BINDER_DATA_KEY]
    return type(data) == "table" and data or nil
end

--- Entrées du classeur (table vide s'il n'en a pas), dans l'ordre de rangement.
function MTIR.getBinderEntries(binder)
    local data = MTIR.getBinderData(binder)
    return data and data.entries or {}
end

function MTIR.getBinderCount(binder)
    return MTIR.binderCount(MTIR.getBinderData(binder))
end

function MTIR.isBinderFull(binder)
    return MTIR.getBinderCount(binder) >= MTIR.getBinderCapacity()
end

--- Données du patron rangé sous `entryId`, ou nil.
function MTIR.getBinderEntryData(binder, entryId)
    local entry = MTIR.binderFindEntry(MTIR.getBinderData(binder), entryId)
    return MTIR.binderEntryPattern(entry), entry
end

--- Source d'un patron : un patron (entryId nil) ou une entrée d'un classeur.
--- Rend les données du patron (comme MTIR.getPatternData), ou nil.
function MTIR.getSourcePatternData(item, entryId)
    if entryId ~= nil then
        if not MTIR.isBinder(item) then
            return nil
        end
        return (MTIR.getBinderEntryData(item, entryId))
    end
    return MTIR.getPatternData(item)
end

--- Nom affiché d'une source de patron (nom enregistré dans l'entrée ou l'objet).
function MTIR.getSourcePatternName(item, entryId)
    if entryId ~= nil then
        local _, entry = MTIR.getBinderEntryData(item, entryId)
        if entry and entry.name and entry.name ~= "" then
            return entry.name
        end
        local data = entry and MTIR.binderEntryPattern(entry)
        return data and getText("IGUI_MTIR_PatternName", getItemNameFromFullType(data.fullType)) or ""
    end
    return item and item:getName() or ""
end

--- Patron encore utilisable (utilisations restantes, modèle chargé).
function MTIR.isUsablePatternData(data)
    return data ~= nil and (tonumber(data.uses) or 0) > 0 and MTIR.patternModelExists(data)
end

-- ----------------------------------------------------------------------------
-- Autorité
-- ----------------------------------------------------------------------------

--- Données du classeur, créées au besoin (autorité seulement).
local function ensureBinderData(binder)
    local modData = binder:getModData()
    local data = modData[MTIR.BINDER_DATA_KEY]
    if type(data) ~= "table" then
        data = MTIR.binderNewData()
        modData[MTIR.BINDER_DATA_KEY] = data
    end
    data.entries = data.entries or {}
    return data
end

--- Poids d'après le contenu : classeur vide + feuilles rangées. setCustomWeight :
--- sauvegardé (InventoryItem.save, drapeau 128) et relu dans weight et actualWeight.
--- syncItemFields ne transmet pas actualWeight (SyncItemFieldsPacket, sauf aliments) :
--- un client MP le recalcule lui-même (MTIR_PatternBinderMenu.lua). Sans effet réseau.
function MTIR.applyBinderWeight(binder)
    local weight = BINDER_WEIGHT + WEIGHT_PER_PATTERN * MTIR.getBinderCount(binder)
    if binder:isCustomWeight() and math.abs(binder:getActualWeight() - weight) < 0.001 then
        return
    end
    binder:setActualWeight(weight)
    binder:setWeight(weight)
    binder:setCustomWeight(true)
end

--- Autorité : range `pattern` dans `binder` (le patron disparaît). Vrai si fait.
function MTIR.storePatternInBinder(character, binder, pattern)
    if not MTIR.getPatternData(pattern) or MTIR.isBinderFull(binder) then
        return false
    end
    local data = ensureBinderData(binder)
    local id = MTIR.binderAddEntry(data, {
        type = pattern:getFullType(),
        name = pattern:getName(),
        modData = pattern:getModData(),
    }, MTIR.getBinderCapacity())
    if not id then
        return false
    end
    MTIR.removeItem(pattern)
    MTIR.applyBinderWeight(binder)
    MTIR.syncItem(character, binder)
    return true
end

--- Recrée l'objet d'une entrée : même type (repli : patron tracé), même nom,
--- même ModData. Un patron du commerce passe par son OnCreate, dont le tirage
--- est aussitôt remplacé par les données rangées.
local function instancePattern(entry)
    local item = instanceItem(entry.type) or instanceItem(MTIR.PATTERN_ITEM)
    if not item then
        return nil
    end
    local modData = item:getModData()
    for key, value in pairs(MTIR.copyPlainData(entry.modData)) do
        modData[key] = value
    end
    if entry.name and entry.name ~= "" then
        item:setName(entry.name)
        item:setCustomName(true)
    end
    return item
end

--- Autorité : sort l'entrée `entryId` du classeur dans l'inventaire. Rend l'objet ou nil.
function MTIR.takePatternFromBinder(character, binder, entryId)
    local data = MTIR.getBinderData(binder)
    local entry = MTIR.binderFindEntry(data, entryId)
    if not MTIR.binderEntryPattern(entry) then
        return nil
    end
    local item = instancePattern(entry)
    if not item then
        return nil
    end
    MTIR.binderRemoveEntry(data, entryId)
    MTIR.applyBinderWeight(binder)
    local inventory = character:getInventory()
    inventory:AddItem(item)
    sendAddItemToContainer(inventory, item)
    MTIR.syncItem(character, binder)
    return item
end

--- Autorité : une couture d'après l'entrée `entryId`. Vrai si le patron est usé (retiré).
function MTIR.wearBinderPattern(character, binder, entryId)
    local result = MTIR.binderWearEntry(MTIR.getBinderData(binder), entryId)
    if result == "worn" then
        MTIR.applyBinderWeight(binder)
    end
    MTIR.syncItem(character, binder)
    return result == "worn"
end

return MTIR
