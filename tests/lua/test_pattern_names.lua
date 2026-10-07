-- Noms des patrons : jamais de clé brute (serveur MP sans traductions du mod),
-- recalcul des noms déjà enregistrés en clé brute (objets et entrées de classeur),
-- et repli d'affichage chez le client.

local T = {}

local PATTERN_ITEM = "Base.MTIR_TailorPattern"
local PRINTED_ITEM = "Base.MTIR_PrintedPattern"
local BINDER_ITEM = "Base.MTIR_PatternBinder"

local TEXTS = {
    IGUI_MTIR_PatternName = "Pattern: %1",
    IGUI_MTIR_PatternCopyName = "Pattern copy: %1",
    IGUI_MTIR_PrintedPatternName = "Store-bought pattern: %1",
}

local function newItem(fullType, name, modData)
    local item = { fullType = fullType, name = name, modData = modData or {} }
    function item:getFullType() return self.fullType end
    function item:getName() return self.name end
    function item:setName(value) self.name = value end
    function item:setCustomName(value) self.customName = value end
    function item:getModData() return self.modData end
    function item:hasModData() return true end
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
    OPTS = { PatternMaxUses = 5, PatternCopyPrecisionLoss = 1, PatternBinderCapacity = 20 }
    LOADED = true
    MTIR = { opt = function(name) return OPTS[name] end }
    -- getTextOrNull : nil si la clé manque (serveur MP sans traductions du mod).
    getTextOrNull = function(key, arg)
        local text = LOADED and TEXTS[key] or nil
        if text == nil then
            return nil
        end
        return (string.gsub(text, "%%1", tostring(arg)))
    end
    getText = function(key, arg)
        return getTextOrNull(key, arg) or key
    end
    getItemNameFromFullType = function(fullType)
        return fullType == "Base.Tshirt_White" and "White T-shirt" or fullType
    end
    instanceItem = function(fullType) return newItem(fullType, fullType, {}) end
    sendAddItemToContainer = function() end
    added = {}
    character = {
        getInventory = function() return { AddItem = function(_, item) table.insert(added, item) end } end,
        getPerkLevel = function() return 4 end,
    }
    Perks = { Tailoring = "Tailoring" }
    loadMod("shared/MyTailorIsRich/MTIR_Patterns.lua")
    MTIR.syncItem = function() end
    MTIR.removeItem = function() end
    loadMod("shared/MyTailorIsRich/MTIR_PatternBinder.lua")
    loadMod("shared/MyTailorIsRich/MTIR_PatternCopy.lua")
end

T["nom composé dans la langue de l'autorité"] = function()
    assertEq(MTIR.composePatternName("IGUI_MTIR_PatternName", "Base.Tshirt_White"), "Pattern: White T-shirt",
        "traduction présente")
end

T["traduction absente : nom du vêtement, jamais la clé brute"] = function()
    LOADED = false
    assertEq(MTIR.composePatternName("IGUI_MTIR_PatternName", "Base.Tshirt_White"), "White T-shirt", "repli")
end

T["création (tracé, copie) sans traduction : pas de clé brute"] = function()
    LOADED = false
    local garment = newItem("Base.Tshirt_White", "White T-shirt")
    local traced = MTIR.createPattern(character, garment, { kind = "clothes", fabric = "Cotton", difficulty = 1 })
    assertEq(traced.name, "White T-shirt", "patron tracé")
    assertEq(traced.customName, true, "nom personnalisé")
    local copy = MTIR.createPatternCopy(character, patternData())
    assertEq(copy.name, "White T-shirt", "copie")
    LOADED = true
    copy = MTIR.createPatternCopy(character, patternData())
    assertEq(copy.name, "Pattern copy: White T-shirt", "copie traduite")
end

T["patron du commerce (OnCreate) sans traduction : pas de clé brute"] = function()
    loadMod("shared/MyTailorIsRich/MTIR_PrintedPatterns.lua")
    MTIR.getPrintableGarments = function()
        return { { fullType = "Base.Tshirt_White", kind = "clothes", fabric = "Cotton", difficulty = 1 } }
    end
    ZombRand = function(a, b) return b and a or 0 end
    instanceof = function() return false end
    LOADED = false
    local item = newItem(PRINTED_ITEM, "Store-bought Sewing Pattern")
    MTIR.onCreatePrintedPattern(item)
    assertEq(item.name, "White T-shirt", "repli sur le nom du vêtement")
    LOADED = true
    item = newItem(PRINTED_ITEM, "Store-bought Sewing Pattern")
    MTIR.onCreatePrintedPattern(item)
    assertEq(item.name, "Store-bought pattern: White T-shirt", "traduit")
end

T["clé du nom selon le type et la génération"] = function()
    assertEq(MTIR.getPatternNameKey(PRINTED_ITEM, patternData()), "IGUI_MTIR_PrintedPatternName", "commerce")
    assertEq(MTIR.getPatternNameKey(PATTERN_ITEM, patternData({ copies = 2 })), "IGUI_MTIR_PatternCopyName",
        "copie")
    assertEq(MTIR.getPatternNameKey(PATTERN_ITEM, patternData()), "IGUI_MTIR_PatternName", "tracé")
end

T["clé brute reconnue, nom ordinaire non"] = function()
    assertTrue(MTIR.isRawPatternName("IGUI_MTIR_PatternName"), "clé brute")
    assertEq(MTIR.isRawPatternName("Pattern: White T-shirt"), false, "nom traduit")
    assertEq(MTIR.isRawPatternName(nil), false, "nil")
end

T["migration : patron en clé brute renommé d'après ses données"] = function()
    local printed = newItem(PRINTED_ITEM, "IGUI_MTIR_PrintedPatternName", { MTIR_Pattern = patternData() })
    assertTrue(MTIR.hasRawPatternName(printed), "à corriger")
    assertTrue(MTIR.repairPatternNames(printed), "corrigé")
    assertEq(printed.name, "Store-bought pattern: White T-shirt", "nom recalculé")
    assertEq(printed.customName, true, "nom personnalisé")
    assertEq(MTIR.hasRawPatternName(printed), false, "plus rien à corriger")
    assertEq(MTIR.repairPatternNames(printed), false, "idempotent")
end

T["migration : nom ordinaire ou objet sans données intacts"] = function()
    local named = newItem(PATTERN_ITEM, "Pattern: Jeans", { MTIR_Pattern = patternData() })
    assertEq(MTIR.repairPatternNames(named), false, "nom ordinaire")
    assertEq(named.name, "Pattern: Jeans", "inchangé")
    local empty = newItem(PATTERN_ITEM, "IGUI_MTIR_PatternName", {})
    assertEq(MTIR.repairPatternNames(empty), false, "sans données de patron")
    assertEq(MTIR.repairPatternNames(nil), false, "nil")
end

T["migration différée tant que la traduction manque"] = function()
    LOADED = false
    local pattern = newItem(PATTERN_ITEM, "IGUI_MTIR_PatternName", { MTIR_Pattern = patternData() })
    assertEq(MTIR.repairPatternNames(pattern), false, "pas de nom sans « Pattern: » enregistré")
    assertEq(pattern.name, "IGUI_MTIR_PatternName", "clé gardée pour plus tard")
end

T["migration : entrées de classeur en clé brute"] = function()
    local binder = newItem(BINDER_ITEM, "Binder", { MTIR_Binder = { nextId = 3, entries = {
        { id = 1, type = PATTERN_ITEM, name = "IGUI_MTIR_PatternCopyName",
            modData = { MTIR_Pattern = patternData({ copies = 1 }) } },
        { id = 2, type = PATTERN_ITEM, name = "Pattern: Jeans", modData = { MTIR_Pattern = patternData() } },
    } } })
    assertTrue(MTIR.hasRawPatternName(binder), "à corriger")
    assertTrue(MTIR.repairPatternNames(binder), "corrigé")
    local entries = MTIR.getBinderEntries(binder)
    assertEq(entries[1].name, "Pattern copy: White T-shirt", "entrée recalculée")
    assertEq(entries[2].name, "Pattern: Jeans", "entrée ordinaire intacte")
    assertEq(MTIR.hasRawPatternName(binder), false, "plus rien à corriger")
end

T["affichage client : clé brute remplacée sans écriture"] = function()
    local binder = newItem(BINDER_ITEM, "Binder", { MTIR_Binder = { nextId = 2, entries = {
        { id = 1, type = PRINTED_ITEM, name = "IGUI_MTIR_PrintedPatternName",
            modData = { MTIR_Pattern = patternData() } },
    } } })
    assertEq(MTIR.getSourcePatternName(binder, 1), "Store-bought pattern: White T-shirt", "entrée")
    assertEq(MTIR.getBinderEntries(binder)[1].name, "IGUI_MTIR_PrintedPatternName", "aucune écriture")
    local pattern = newItem(PATTERN_ITEM, "IGUI_MTIR_PatternName", { MTIR_Pattern = patternData() })
    assertEq(MTIR.getSourcePatternName(pattern, nil), "Pattern: White T-shirt", "patron seul")
    assertEq(pattern.name, "IGUI_MTIR_PatternName", "objet non renommé")
end

T["sortir du classeur : nom en clé brute recalculé sur l'objet recréé"] = function()
    local binder = newItem(BINDER_ITEM, "Binder", { MTIR_Binder = { nextId = 2, entries = {
        { id = 1, type = PATTERN_ITEM, name = "IGUI_MTIR_PatternName", modData = { MTIR_Pattern = patternData() } },
    } } })
    binder.isCustomWeight = function() return false end
    binder.setActualWeight = function() end
    binder.setWeight = function() end
    binder.setCustomWeight = function() end
    local item = MTIR.takePatternFromBinder(character, binder, 1)
    assertEq(item.name, "Pattern: White T-shirt", "nom recalculé")
    assertEq(item.customName, true, "nom personnalisé")
end

return T
