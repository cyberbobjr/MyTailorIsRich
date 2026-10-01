-- MTIR_PatternBinder : entrées à id stable, capacité, usure, copie profonde
-- des données, et aller-retour ranger / sortir sans perte (type, nom, ModData).

local T = {}

local PATTERN_ITEM = "Base.MTIR_TailorPattern"
local PRINTED_ITEM = "Base.MTIR_PrintedPattern"

--- Objet simulé : type, nom, ModData, poids ; conteneur facultatif.
local function newItem(fullType, name, modData)
    local item = { fullType = fullType, name = name, modData = modData or {}, weight = nil, custom = false }
    function item:getFullType() return self.fullType end
    function item:getName() return self.name end
    function item:setName(value) self.name = value end
    function item:setCustomName(value) self.customName = value end
    function item:getModData() return self.modData end
    function item:hasModData() return true end
    function item:setActualWeight(value) self.weight = value end
    function item:getActualWeight() return self.weight or 0 end
    function item:setWeight(value) self.scriptWeight = value end
    function item:setCustomWeight(value) self.custom = value end
    function item:isCustomWeight() return self.custom end
    function item:getContainer() return self.container end
    return item
end

local function patternData(overrides)
    local data = { fullType = "Base.Tshirt_White", kind = "clothes", fabric = "Cotton", difficulty = 1,
        precision = 6, uses = 5 }
    for key, value in pairs(overrides or {}) do
        data[key] = value
    end
    return data
end

function T.setup()
    OPTS = { PatternBinderCapacity = 3, PatternMaxUses = 5 }
    synced = 0
    MTIR = {
        PATTERN_DATA_KEY = "MTIR_Pattern",
        PATTERN_ITEM = PATTERN_ITEM,
        opt = function(name) return OPTS[name] end,
        patternModelExists = function(data) return data ~= nil and data.fullType ~= "Base.Removed" end,
        syncItem = function() synced = synced + 1 end,
    }
    function MTIR.isPattern(item)
        return item ~= nil and (item:getFullType() == PATTERN_ITEM or item:getFullType() == PRINTED_ITEM)
    end
    function MTIR.getPatternData(item)
        if not MTIR.isPattern(item) then return nil end
        local data = item:getModData()[MTIR.PATTERN_DATA_KEY]
        return data and data.fullType and data.kind and data or nil
    end
    function MTIR.removeItem(item)
        local container = item.container
        if container then
            container.items[item] = nil
            item.container = nil
        end
    end
    getText = function(key, arg) return key .. ":" .. tostring(arg) end
    getItemNameFromFullType = function(fullType) return fullType end
    instanceItem = function(fullType) return newItem(fullType, fullType, {}) end
    sendAddItemToContainer = function() end
    inventory = { items = {} }
    function inventory:AddItem(item)
        self.items[item] = true
        item.container = self
    end
    character = { getInventory = function() return inventory end }
    loadMod("shared/MyTailorIsRich/MTIR_PatternBinder.lua")
end

local function entry(name, overrides)
    return { type = PATTERN_ITEM, name = name, modData = { MTIR_Pattern = patternData(overrides) } }
end

T["copie profonde : valeurs simples et tables, sans fonctions, indépendante"] = function()
    local source = { a = 1, b = "x", c = true, d = { e = 2, f = { g = "h" } }, fn = function() end }
    local copy = MTIR.copyPlainData(source)
    assertEq(copy.a, 1, "nombre")
    assertEq(copy.b, "x", "texte")
    assertEq(copy.c, true, "booléen")
    assertEq(copy.d.f.g, "h", "table imbriquée")
    assertEq(copy.fn, nil, "fonction ignorée")
    copy.d.e = 99
    assertEq(source.d.e, 2, "la source n'est pas modifiée")
end

T["ajout jusqu'à la capacité, ids croissants"] = function()
    local data = MTIR.binderNewData()
    assertEq(MTIR.binderAddEntry(data, entry("A"), 3), 1, "premier id")
    assertEq(MTIR.binderAddEntry(data, entry("B"), 3), 2, "deuxième id")
    assertEq(MTIR.binderAddEntry(data, entry("C"), 3), 3, "troisième id")
    assertEq(MTIR.binderAddEntry(data, entry("D"), 3), nil, "classeur plein")
    assertEq(MTIR.binderCount(data), 3, "trois entrées")
end

T["entrée sans données de patron refusée"] = function()
    local data = MTIR.binderNewData()
    assertEq(MTIR.binderAddEntry(data, { type = PATTERN_ITEM, name = "x", modData = {} }, 3), nil, "refusée")
    assertEq(MTIR.binderAddEntry(data, nil, 3), nil, "nil refusé")
    assertEq(MTIR.binderCount(data), 0, "vide")
end

T["ids stables : jamais réutilisés après un retrait"] = function()
    local data = MTIR.binderNewData()
    MTIR.binderAddEntry(data, entry("A"), 3)
    MTIR.binderAddEntry(data, entry("B"), 3)
    local removed = MTIR.binderRemoveEntry(data, 1)
    assertEq(removed.name, "A", "entrée retirée")
    assertEq(MTIR.binderFindEntry(data, 2).name, "B", "B garde son id")
    assertEq(MTIR.binderAddEntry(data, entry("C"), 3), 3, "nouvel id après retrait")
    assertEq(MTIR.binderRemoveEntry(data, 1), nil, "id retiré introuvable")
    assertEq(MTIR.binderFindEntry(data, "3").name, "C", "id reçu en texte")
end

T["ModData de l'entrée copiée, pas partagée avec l'objet"] = function()
    local data = MTIR.binderNewData()
    local source = entry("A")
    MTIR.binderAddEntry(data, source, 3)
    source.modData.MTIR_Pattern.uses = 1
    assertEq(MTIR.binderEntryPattern(MTIR.binderFindEntry(data, 1)).uses, 5, "copie indépendante")
end

T["usure : une utilisation de moins, retrait à zéro"] = function()
    local data = MTIR.binderNewData()
    MTIR.binderAddEntry(data, entry("A", { uses = 2 }), 3)
    assertEq(MTIR.binderWearEntry(data, 1), "used", "première couture")
    assertEq(MTIR.binderEntryPattern(MTIR.binderFindEntry(data, 1)).uses, 1, "une utilisation restante")
    assertEq(MTIR.binderWearEntry(data, 1), "worn", "patron usé")
    assertEq(MTIR.binderCount(data), 0, "entrée retirée")
    assertEq(MTIR.binderWearEntry(data, 1), nil, "entrée absente")
end

T["ranger puis sortir : type, nom et toutes les données conservés"] = function()
    local binder = newItem(MTIR.BINDER_ITEM, "Classeur", {})
    local modData = { MTIR_Pattern = patternData({ precision = 7, uses = 3, copies = 2 }),
        OtherMod = { tag = "abc" } }
    local pattern = newItem(PRINTED_ITEM, "Patron du commerce : T-shirt", modData)
    inventory:AddItem(pattern)

    assertTrue(MTIR.storePatternInBinder(character, binder, pattern), "rangé")
    assertEq(inventory.items[pattern], nil, "patron retiré de l'inventaire")
    assertEq(MTIR.getBinderCount(binder), 1, "une entrée")
    assertTrue(binder.custom, "poids personnalisé")
    assertTrue(math.abs(binder.weight - 0.4) < 1e-6, "poids 0,3 + 0,1")
    assertEq(synced, 1, "classeur synchronisé")

    local id = MTIR.getBinderEntries(binder)[1].id
    assertEq(MTIR.getSourcePatternData(binder, id).precision, 7, "données lues dans le classeur")
    assertEq(MTIR.getSourcePatternName(binder, id), "Patron du commerce : T-shirt", "nom de l'entrée")

    local item = MTIR.takePatternFromBinder(character, binder, id)
    assertTrue(item ~= nil, "patron recréé")
    assertEq(item:getFullType(), PRINTED_ITEM, "même type d'objet")
    assertEq(item:getName(), "Patron du commerce : T-shirt", "même nom")
    assertEq(item.customName, true, "nom personnalisé")
    local data = MTIR.getPatternData(item)
    assertEq(data.precision, 7, "précision")
    assertEq(data.uses, 3, "utilisations")
    assertEq(data.copies, 2, "génération de copie")
    assertEq(item:getModData().OtherMod.tag, "abc", "données d'un autre mod")
    assertTrue(inventory.items[item], "dans l'inventaire")
    assertEq(MTIR.getBinderCount(binder), 0, "classeur vide")
    assertTrue(math.abs(binder.weight - 0.3) < 1e-6, "poids du classeur vide")
end

T["classeur plein : rien n'est rangé"] = function()
    OPTS.PatternBinderCapacity = 1
    local binder = newItem(MTIR.BINDER_ITEM, "Classeur", {})
    local first = newItem(PATTERN_ITEM, "P1", { MTIR_Pattern = patternData() })
    local second = newItem(PATTERN_ITEM, "P2", { MTIR_Pattern = patternData() })
    inventory:AddItem(first)
    inventory:AddItem(second)
    assertTrue(MTIR.storePatternInBinder(character, binder, first), "premier rangé")
    assertTrue(MTIR.isBinderFull(binder), "plein")
    assertEq(MTIR.storePatternInBinder(character, binder, second), false, "second refusé")
    assertTrue(inventory.items[second], "second toujours dans l'inventaire")
end

T["couture d'après une entrée : usure synchronisée, retrait du patron usé"] = function()
    local binder = newItem(MTIR.BINDER_ITEM, "Classeur", {})
    local pattern = newItem(PATTERN_ITEM, "P", { MTIR_Pattern = patternData({ uses = 1 }) })
    inventory:AddItem(pattern)
    MTIR.storePatternInBinder(character, binder, pattern)
    local id = MTIR.getBinderEntries(binder)[1].id
    assertEq(MTIR.wearBinderPattern(character, binder, id), true, "usé")
    assertEq(MTIR.getBinderCount(binder), 0, "entrée retirée")
    assertEq(MTIR.getSourcePatternData(binder, id), nil, "plus de données")
end

T["source : patron seul ou entrée, jamais un autre objet"] = function()
    local pattern = newItem(PATTERN_ITEM, "P", { MTIR_Pattern = patternData() })
    assertEq(MTIR.getSourcePatternData(pattern, nil).precision, 6, "patron seul")
    assertEq(MTIR.getSourcePatternData(pattern, 1), nil, "entryId sur un patron")
    local binder = newItem(MTIR.BINDER_ITEM, "Classeur", {})
    assertEq(MTIR.getSourcePatternData(binder, 1), nil, "classeur vide")
    assertEq(MTIR.getSourcePatternData(binder, nil), nil, "classeur sans entryId")
end

T["patron utilisable : utilisations et modèle présents"] = function()
    assertTrue(MTIR.isUsablePatternData(patternData()), "utilisable")
    assertEq(MTIR.isUsablePatternData(patternData({ uses = 0 })), false, "usé")
    assertEq(MTIR.isUsablePatternData(patternData({ fullType = "Base.Removed" })), false, "modèle absent")
    assertEq(MTIR.isUsablePatternData(nil), false, "rien")
end

return T
