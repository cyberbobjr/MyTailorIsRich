-- MTIR_PatternCopy : précision des copies (perte par génération, plancher à 0),
-- utilisations neuves, original intact, option de désactivation.

local T = {}

local PATTERN_ITEM = "Base.MTIR_TailorPattern"

local function original(overrides)
    local data = { fullType = "Base.Jacket_Denim", kind = "clothes", fabric = "Denim", difficulty = 2,
        precision = 6, uses = 2, extra = { note = "x" } }
    for key, value in pairs(overrides or {}) do
        data[key] = value
    end
    return data
end

function T.setup()
    OPTS = { PatternMaxUses = 5, PatternCopyPrecisionLoss = 1, EnablePatternCopy = true,
        ActionTimeMultiplier = 1, TailoringXpMultiplier = 1, NeedTailoringLevel = true }
    MTIR = {
        PATTERN_DATA_KEY = "MTIR_Pattern",
        PATTERN_ITEM = PATTERN_ITEM,
        opt = function(name) return OPTS[name] end,
        getRequiredLevelToTrace = function(data) return data.difficulty end,
        getRequiredPaper = function(data) return 1 + data.difficulty end,
        getTraceXp = function() return 10 end,
    }
    getText = function(key, arg) return key .. ":" .. tostring(arg) end
    getItemNameFromFullType = function(fullType) return fullType end
    local function newItem(fullType)
        local item = { fullType = fullType, modData = {} }
        function item:getFullType() return self.fullType end
        function item:getModData() return self.modData end
        function item:setName(value) self.name = value end
        function item:setCustomName(value) self.customName = value end
        return item
    end
    instanceItem = function(fullType) return newItem(fullType) end
    sendAddItemToContainer = function() end
    added = {}
    character = { getInventory = function()
        return { AddItem = function(_, item) table.insert(added, item) end }
    end }
    loadMod("shared/MyTailorIsRich/MTIR_PatternBinder.lua")
    loadMod("shared/MyTailorIsRich/MTIR_PatternCopy.lua")
end

T["copie : précision moins la perte, utilisations neuves, génération 1"] = function()
    local copy = MTIR.makePatternCopyData(original(), 1, 5)
    assertEq(copy.precision, 5, "précision")
    assertEq(copy.uses, 5, "utilisations neuves")
    assertEq(copy.copies, 1, "copie de l'original")
    assertEq(copy.fullType, "Base.Jacket_Denim", "modèle")
    assertEq(copy.fabric, "Denim", "tissu")
    assertEq(copy.difficulty, 2, "difficulté")
    assertEq(copy.extra.note, "x", "autres données gardées")
end

T["copie de copie : la précision baisse encore"] = function()
    local first = MTIR.makePatternCopyData(original(), 2, 5)
    local second = MTIR.makePatternCopyData(first, 2, 5)
    assertEq(first.precision, 4, "première génération")
    assertEq(second.precision, 2, "deuxième génération")
    assertEq(second.copies, 2, "génération comptée")
end

T["précision jamais négative ; perte nulle : copie parfaite"] = function()
    assertEq(MTIR.makePatternCopyData(original({ precision = 1 }), 3, 5).precision, 0, "plancher à 0")
    local noPrecision = original()
    noPrecision.precision = nil
    assertEq(MTIR.makePatternCopyData(noPrecision, 1, 5).precision, 0, "précision absente")
    assertEq(MTIR.makePatternCopyData(original(), 0, 5).precision, 6, "perte nulle")
end

T["l'original n'est pas modifié"] = function()
    local data = original()
    local copy = MTIR.makePatternCopyData(data, 1, 5)
    copy.extra.note = "y"
    assertEq(data.precision, 6, "précision de l'original")
    assertEq(data.uses, 2, "utilisations de l'original")
    assertEq(data.copies, nil, "pas de génération sur l'original")
    assertEq(data.extra.note, "x", "table de l'original")
end

T["options : perte et activation"] = function()
    assertEq(MTIR.getCopyPrecision(original()), 5, "perte par défaut")
    OPTS.PatternCopyPrecisionLoss = 4
    assertEq(MTIR.getCopyPrecision(original()), 2, "perte de 4")
    assertTrue(MTIR.isPatternCopyEnabled(), "activée")
    OPTS.EnablePatternCopy = false
    assertEq(MTIR.isPatternCopyEnabled(), false, "désactivée")
end

T["exigences : niveau et feuilles du tracé, durée plus courte"] = function()
    local data = original()
    assertEq(MTIR.getRequiredLevelToCopy(data), 2, "niveau du tracé")
    assertEq(MTIR.getRequiredPaperToCopy(data), 3, "feuilles du tracé")
    assertEq(MTIR.getCopyDuration(data), 160, "80 + 2 × 40")
    assertEq(MTIR.getCopyXp(data), 5, "moitié de l'XP du tracé")
end

T["autorité : patron tracé créé avec les données de la copie"] = function()
    local item = MTIR.createPatternCopy(character, original())
    assertEq(#added, 1, "ajouté à l'inventaire")
    assertEq(item:getFullType(), PATTERN_ITEM, "patron tracé")
    local data = item:getModData().MTIR_Pattern
    assertEq(data.precision, 5, "précision réduite")
    assertEq(data.uses, 5, "utilisations neuves")
    assertEq(item.name, "IGUI_MTIR_PatternCopyName:Base.Jacket_Denim", "nom de la copie")
    assertEq(item.customName, true, "nom personnalisé")
end

return T
