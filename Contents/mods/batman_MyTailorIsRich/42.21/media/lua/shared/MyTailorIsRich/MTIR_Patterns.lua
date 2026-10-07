-- ============================================================================
-- My Tailor Is Rich — patrons de couture
--
-- Tracer : un vêtement ou une paire de chaussures sert de modèle ; on obtient
-- un objet « Patron tracé » (Base.MTIR_TailorPattern) qui mémorise le modèle.
-- Coudre : le patron donne un exemplaire neuf dans la taille choisie.
--   * précision : écart d'une taille (±1) possible, moins fréquent si le traceur
--     et la couturière sont doués ;
--   * usure : PatternMaxUses coutures (réussies ou non), puis le patron est perdu ;
--   * garde-fous : pas de protection balistique, tissu cousable (coton, jean,
--     cuir) ; chaussures : tissu ou cuir selon le modèle (MTIR.getShoeMaterial),
--     jamais en caoutchouc ou en plastique ; elles demandent plus de Couture,
--     une aiguille ET une alêne, et de la colle.
-- Le patron système vanilla (SewingPattern) apprend des recettes figées : il
-- n'est pas utilisé ici.
-- ============================================================================

require "MyTailorIsRich/MTIR_Sizing"
require "MyTailorIsRich/MTIR_Effects"

MTIR.PATTERN_ITEM = "Base.MTIR_TailorPattern"
--- Patron du commerce trouvé dans le butin (données posées par MTIR_PrintedPatterns.lua).
MTIR.PRINTED_PATTERN_ITEM = "Base.MTIR_PrintedPattern"
MTIR.PATTERN_DATA_KEY = "MTIR_Pattern"

local PAPER_TYPE = "Base.SheetPaper2"
local SHOE_PAPER = 2
local SHOE_MATERIAL_UNITS = 6
local SHOE_THREAD = 5
--- Difficulté d'un patron de chaussures (partagée avec MTIR_PrintedPatterns.lua).
MTIR.SHOE_PATTERN_DIFFICULTY = 3
--- Colle consommée par une paire de chaussures (utilisations d'un objet base:glue).
MTIR.SHOE_GLUE_USES = 1
local MAX_OFF_CHANCE = 0.5
local OFF_CHANCE_PER_LEVEL = 0.05
local MIN_TRACE_CONDITION = 0.5

-- Matériaux par tissu : unités apportées par objet (rouleau : une par utilisation).
-- L'ordre est celui du prélèvement : chutes d'abord, grandes peaux en dernier.
local MATERIALS = {
    Cotton = { { type = "Base.RippedSheets", units = 1 }, { type = "Base.FabricRoll_Cotton", roll = true } },
    Denim = {
        { type = "Base.DenimStrips", units = 1 },
        { type = "Base.FabricRoll_DenimBlue", roll = true },
        { type = "Base.FabricRoll_DenimDarkBlue", roll = true },
        { type = "Base.FabricRoll_DenimBlack", roll = true },
    },
    Leather = {
        { type = "Base.LeatherStrips", units = 1 },
        { type = "Base.Leather_Crude_Small_Tan", units = 3 },
        { type = "Base.Leather_Crude_Medium_Tan", units = 6 },
        { type = "Base.Leather_Crude_Large_Tan", units = 10 },
    },
}

-- Chaussures sans FabricType reconnu : mots-clés cherchés dans le type, le
-- ClothingItem et l'icône du script (jamais dans le nom affiché, traduit : le
-- serveur et le client doivent conclure pareil).
-- Caoutchouc ou plastique : pas de patron possible.
local SHOE_RUBBER_KEYS = {
    "wellie", "welly", "wellington", "rubber", "gumboot", "rainboot", "galosh",
    "flipflop", "flip_flop", "flip-flop", "crocs", "tiresandal", "tire_sandal", "plastic", "jelly",
}
-- Toile ou tissu (coton) ; tout le reste est en cuir.
local SHOE_FABRIC_KEYS = {
    "trainer", "sneaker", "slipper", "canvas", "espadrille", "tennis", "running", "plimsoll", "converse",
}

-- Tissu en plus ou en moins selon la taille cousue.
local SIZE_MATERIAL_DELTA = { XS = -2, S = -1, M = 0, L = 0, XL = 1, XXL = 2 }

-- ----------------------------------------------------------------------------
-- Données du patron
-- ----------------------------------------------------------------------------

function MTIR.isPattern(item)
    if item == nil then
        return false
    end
    local fullType = item:getFullType()
    return fullType == MTIR.PATTERN_ITEM or fullType == MTIR.PRINTED_PATTERN_ITEM
end

--- { fullType, kind, fabric, difficulty, precision, uses } ou nil.
function MTIR.getPatternData(item)
    if not MTIR.isPattern(item) or not item:hasModData() then
        return nil
    end
    local data = item:getModData()[MTIR.PATTERN_DATA_KEY]
    if not data or not data.fullType or not data.kind then
        return nil
    end
    return data
end

-- ----------------------------------------------------------------------------
-- Nom d'un patron
--
-- Le nom est enregistré dans l'objet, dans la langue de l'autorité (celle du
-- serveur en MP). Un serveur MP ne charge les traductions des mods qu'après
-- MTIR_ServerTranslations.lua ; avant la 0.4.5, getText y rendait la clé
-- brute (« IGUI_MTIR_PatternName »), enregistrée telle quelle : ces noms sont
-- recalculés par MTIR.repairPatternNames.
-- ----------------------------------------------------------------------------

local RAW_NAME_PREFIX = "IGUI_MTIR_"

--- Nom composé avec `key` ; sans traduction du mod, le nom du vêtement plutôt
--- qu'une clé brute.
function MTIR.composePatternName(key, fullType)
    local garment = getItemNameFromFullType(fullType) or tostring(fullType)
    return getTextOrNull(key, garment) or garment
end

--- Clé du nom d'un patron selon son type d'objet et ses données.
function MTIR.getPatternNameKey(itemType, data)
    if itemType == MTIR.PRINTED_PATTERN_ITEM then
        return "IGUI_MTIR_PrintedPatternName"
    end
    if type(data) == "table" and (tonumber(data.copies) or 0) > 0 then
        return "IGUI_MTIR_PatternCopyName"
    end
    return "IGUI_MTIR_PatternName"
end

--- Nom d'un patron d'après son type d'objet et ses données (ModData "MTIR_Pattern").
function MTIR.getPatternNameFor(itemType, data)
    return MTIR.composePatternName(MTIR.getPatternNameKey(itemType, data), data.fullType)
end

--- Nom enregistré qui n'est qu'une clé de traduction du mod.
function MTIR.isRawPatternName(name)
    return type(name) == "string" and string.sub(name, 1, #RAW_NAME_PREFIX) == RAW_NAME_PREFIX
end

--- Le nom ne se recalcule que si la traduction est disponible : sinon, garder la
--- clé (repli d'affichage chez le client, MTIR.getSourcePatternName) plutôt que
--- d'enregistrer pour toujours un nom sans « Patron : ».
local function canRepairName(itemType, data)
    return getTextOrNull(MTIR.getPatternNameKey(itemType, data), "") ~= nil
end

--- Autorité : recalcule le nom d'un patron (objet) ou des entrées d'un classeur
--- dont le nom enregistré est une clé brute. Vrai si quelque chose a changé
--- (à synchroniser par l'appelant).
function MTIR.repairPatternNames(item)
    if item == nil then
        return false
    end
    local changed = false
    local data = MTIR.getPatternData(item)
    if data and MTIR.isRawPatternName(item:getName()) and canRepairName(item:getFullType(), data) then
        item:setName(MTIR.getPatternNameFor(item:getFullType(), data))
        item:setCustomName(true)
        changed = true
    end
    if MTIR.isBinder and MTIR.isBinder(item) then
        for _, entry in ipairs(MTIR.getBinderEntries(item)) do
            local entryData = MTIR.binderEntryPattern(entry)
            if entryData and MTIR.isRawPatternName(entry.name) and canRepairName(entry.type, entryData) then
                entry.name = MTIR.getPatternNameFor(entry.type, entryData)
                changed = true
            end
        end
    end
    return changed
end

--- L'objet a-t-il un nom de patron à recalculer (objet ou entrée de classeur) ?
function MTIR.hasRawPatternName(item)
    if item == nil then
        return false
    end
    if MTIR.getPatternData(item) and MTIR.isRawPatternName(item:getName()) then
        return true
    end
    if MTIR.isBinder and MTIR.isBinder(item) then
        for _, entry in ipairs(MTIR.getBinderEntries(item)) do
            if MTIR.isRawPatternName(entry.name) then
                return true
            end
        end
    end
    return false
end

--- Le modèle existe-t-il encore (mod désinstallé depuis le tracé) ?
function MTIR.patternModelExists(data)
    return data ~= nil and ScriptManager.instance:getItem(data.fullType) ~= nil
end

-- ----------------------------------------------------------------------------
-- Tracer
-- ----------------------------------------------------------------------------

local function containsAny(text, keys)
    for _, key in ipairs(keys) do
        if string.find(text, key, 1, true) then
            return true
        end
    end
    return false
end

--- Matière d'une paire (script Item) : FabricType du script s'il est cousable,
--- sinon "Cotton" (baskets, pantoufles, toile…) ou "Leather" ; nil pour le
--- caoutchouc ou le plastique (bottes de pluie, tongs, sabots en plastique…).
--- Partagé par le tracé (MTIR.describeModel) et les patrons du commerce.
function MTIR.getShoeMaterial(scriptItem)
    if not scriptItem then
        return nil
    end
    local fabric = scriptItem:getFabricType()
    if fabric and MTIR.FABRIC_DIFFICULTY[fabric] ~= nil then
        return fabric
    end
    local text = string.lower(tostring(scriptItem:getFullName()) .. "|" .. tostring(scriptItem:getClothingItem())
        .. "|" .. tostring(scriptItem:getIcon()))
    if containsAny(text, SHOE_RUBBER_KEYS) then
        return nil
    end
    return containsAny(text, SHOE_FABRIC_KEYS) and "Cotton" or "Leather"
end

--- Genre du modèle traçable, ou nil et une clé de raison (nil si pas de taille du tout).
function MTIR.getTraceKind(item)
    if not item or not instanceof(item, "Clothing") then
        return nil, nil
    end
    local kind = MTIR.canShoeHaveSize(item) and "shoe" or (MTIR.canClothesHaveSize(item) and "clothes" or nil)
    if not kind then
        return nil, nil
    end
    if item:getBulletDefense() > 0 then
        return nil, "IGUI_MTIR_Pattern_NoBallistic"
    end
    if kind == "clothes" and not MTIR.getClothesFabricType(item) then
        return nil, "IGUI_MTIR_Pattern_NoFabric"
    end
    if kind == "shoe" and not MTIR.getShoeMaterial(item:getScriptItem()) then
        return nil, "IGUI_MTIR_Pattern_NoShoeFabric"
    end
    return kind, nil
end

--- Description du modèle au moment du tracé.
function MTIR.describeModel(item)
    local kind = MTIR.getTraceKind(item)
    if not kind then
        return nil
    end
    if kind == "shoe" then
        local fabric = MTIR.getShoeMaterial(item:getScriptItem())
        return { kind = "shoe", fabric = fabric, difficulty = MTIR.SHOE_PATTERN_DIFFICULTY }
    end
    return { kind = "clothes", fabric = MTIR.getClothesFabricType(item), difficulty = MTIR.getClothesDifficulty(item) }
end

--- Niveau de Couture du modèle : difficulté + tissu ; option dédiée pour les chaussures.
local function patternLevel(model)
    if model.kind == "shoe" then
        return MTIR.opt("ShoePatternLevel")
    end
    return model.difficulty + (MTIR.FABRIC_DIFFICULTY[model.fabric] or 0)
end

function MTIR.getRequiredLevelToTrace(model)
    if not MTIR.opt("NeedTailoringLevel") then return 0 end
    return math.max(0, patternLevel(model) - 1)
end

function MTIR.getRequiredLevelToSew(model)
    if not MTIR.opt("NeedTailoringLevel") then return 0 end
    return patternLevel(model)
end

function MTIR.getRequiredPaper(model)
    if model.kind == "shoe" then
        return SHOE_PAPER
    end
    return 1 + model.difficulty
end

function MTIR.canTraceCondition(item)
    return not item:isBroken() and item:getCondition() >= item:getConditionMax() * MIN_TRACE_CONDITION
end

function MTIR.getTraceDuration(model)
    return math.max(1, (100 + model.difficulty * 50) * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getTraceXp(model)
    return patternLevel(model) * 2 * MTIR.opt("TailoringXpMultiplier")
end

function MTIR.predicatePaper(item)
    return item:getFullType() == PAPER_TYPE
end

function MTIR.getPaperType()
    return PAPER_TYPE
end

--- Même liste que l'édition de carte vanilla (ISInventoryPaneContextMenu).
function MTIR.predicatePen(item)
    return item:hasTag(ItemTag.WRITE) or item:hasTag(ItemTag.PEN) or item:hasTag(ItemTag.PENCIL)
        or item:hasTag(ItemTag.BLUE_PEN) or item:hasTag(ItemTag.RED_PEN) or item:hasTag(ItemTag.GREEN_PEN)
end

--- Autorité : crée le patron dans l'inventaire du personnage.
function MTIR.createPattern(character, item, model)
    local pattern = instanceItem(MTIR.PATTERN_ITEM)
    if not pattern then
        return nil
    end
    pattern:getModData()[MTIR.PATTERN_DATA_KEY] = {
        fullType = item:getFullType(),
        kind = model.kind,
        fabric = model.fabric,
        difficulty = model.difficulty,
        precision = character:getPerkLevel(Perks.Tailoring),
        uses = MTIR.opt("PatternMaxUses"),
    }
    -- Nom enregistré dans l'objet (langue de l'autorité : celle du serveur en MP).
    pattern:setName(MTIR.composePatternName("IGUI_MTIR_PatternName", item:getFullType()))
    pattern:setCustomName(true)
    local inventory = character:getInventory()
    inventory:AddItem(pattern)
    sendAddItemToContainer(inventory, pattern)
    return pattern
end

-- ----------------------------------------------------------------------------
-- Coudre
-- ----------------------------------------------------------------------------

--- Tailles proposées : noms XS..XXL ou pointures (texte, comme les paramètres réseau).
function MTIR.getPatternSizes(data)
    local sizes = {}
    if data.kind == "shoe" then
        for size = MTIR.SHOE_MIN, MTIR.SHOE_MAX do
            table.insert(sizes, tostring(size))
        end
    else
        for _, size in ipairs(MTIR.SIZE_LIST) do
            table.insert(sizes, size.name)
        end
    end
    return sizes
end

function MTIR.isValidPatternSize(data, size)
    if data.kind == "shoe" then
        local number = tonumber(size)
        return number ~= nil and number >= MTIR.SHOE_MIN and number <= MTIR.SHOE_MAX
    end
    return MTIR.SIZES[size] ~= nil
end

function MTIR.getPatternMaterialUnits(data, size)
    if data.kind == "shoe" then
        return SHOE_MATERIAL_UNITS
    end
    return math.max(2, 2 + data.difficulty * 3 + (SIZE_MATERIAL_DELTA[size] or 0))
end

--- Couture à la main : aucun bonus (sur machine : MTIR.getMachineMods, MTIR_SewingMachine.lua).
MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }

function MTIR.getPatternThread(data, mods)
    local base = data.kind == "shoe" and SHOE_THREAD or (data.difficulty * 2 + 1)
    return math.max(1, math.ceil(base * (mods or MTIR.SEW_BY_HAND).threadFactor))
end

function MTIR.getSewDuration(data, mods)
    local base = data.kind == "shoe" and 750 or (300 + data.difficulty * 150)
    return math.max(1, base * (mods or MTIR.SEW_BY_HAND).durationFactor * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getSewXp(data, isSuccess)
    return patternLevel(data) * 8 * MTIR.opt("TailoringXpMultiplier") * (isSuccess and 1 or 0.2)
end

--- Risque d'un écart d'une taille : 50 % sans compétence, nul à 10 niveaux cumulés.
function MTIR.getPatternOffChance(data, tailoring)
    local chance = MAX_OFF_CHANCE - OFF_CHANCE_PER_LEVEL * ((data.precision or 0) + tailoring)
    return math.max(0, math.min(MAX_OFF_CHANCE, chance))
end

--- Taille réellement obtenue (écart ±1 éventuel, borné à la gamme).
function MTIR.rollPatternSize(data, size, tailoring)
    if ZombRandFloat(0, 1) >= MTIR.getPatternOffChance(data, tailoring) then
        return size
    end
    local sizes = MTIR.getPatternSizes(data)
    local index = 1
    for i, name in ipairs(sizes) do
        if name == size then
            index = i
        end
    end
    local offset = ZombRand(2) == 0 and -1 or 1
    if index + offset < 1 or index + offset > #sizes then
        offset = -offset
    end
    return sizes[index + offset] or size
end

--- Chaussures : alêne (en plus de l'aiguille) et colle (MTIR.SHOE_GLUE_USES utilisations).
local function addShoeTools(ctx, inventory, data)
    ctx.needsAwl = MTIR.patternNeedsAwl(data)
    ctx.needsGlue = MTIR.patternNeedsGlue(data)
    ctx.requiredGlue = ctx.needsGlue and MTIR.SHOE_GLUE_USES or 0
    ctx.awl = ctx.needsAwl and inventory:getFirstEvalRecurse(MTIR.predicateAwl) or nil
    ctx.glue = ctx.needsGlue and inventory:getFirstEvalRecurse(MTIR.predicateGlue) or nil
end

--- Tout ce qu'il faut pour coudre `size` d'après un patron : outils, fil, tissu,
--- niveau, chances et durée. Partagé par le menu contextuel et le panneau de la machine.
--- Champs des chaussures : needsAwl, awl (alêne ou nil), needsGlue, glue (objet
--- base:glue ou nil), requiredGlue (utilisations) ; `ready` les exige.
function MTIR.getSewRequirements(player, data, size, mods)
    mods = mods or MTIR.SEW_BY_HAND
    local inventory = player:getInventory()
    local allThreads = inventory:getItemsFromType("Thread", true)
    local requiredThread = MTIR.getPatternThread(data, mods)
    local requiredUnits = MTIR.getPatternMaterialUnits(data, size)
    local available, materials = MTIR.pickPatternMaterials(inventory, data.fabric, requiredUnits)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToSew(data)
    local effective = tailoring + mods.levelBonus
    local ctx = {
        needle = inventory:getFirstEvalRecurse(MTIR.predicatePatternNeedle(data.fabric, data.kind)),
        scissors = inventory:getFirstEvalRecurse(MTIR.predicatePatternCutter(data.fabric, data.kind)),
        requiredThread = requiredThread,
        remainingThread = MTIR.getRemainingThread(allThreads),
        threads = MTIR.pickThreads(allThreads, requiredThread),
        requiredUnits = requiredUnits,
        availableUnits = available,
        materials = materials,
        tailoring = tailoring,
        effectiveLevel = effective,
        requiredLevel = requiredLevel,
        thimble = MTIR.needsThimble(mods) and MTIR.findThimble(player) or nil,
        needsThimble = MTIR.needsThimble(mods),
        success = effective >= requiredLevel
            and math.max(0, math.min(1, MTIR.getSuccessChanceForChange(effective, requiredLevel) - (mods.successMalus or 0)))
            or 0,
        offChance = MTIR.getPatternOffChance(data, tailoring + mods.precisionBonus),
        duration = MTIR.getSewDuration(data, mods),
    }
    addShoeTools(ctx, inventory, data)
    ctx.ready = ctx.needle ~= nil and ctx.scissors ~= nil and ctx.threads ~= nil and ctx.materials ~= nil
        and effective >= requiredLevel and (not ctx.needsThimble or ctx.thimble ~= nil)
        and (not ctx.needsAwl or ctx.awl ~= nil) and (not ctx.needsGlue or ctx.glue ~= nil)
    return ctx
end

-- ----------------------------------------------------------------------------
-- Matériaux (ArrayList pour les paramètres réseau)
-- ----------------------------------------------------------------------------

local function materialEntry(fabric, item)
    for _, entry in ipairs(MATERIALS[fabric] or {}) do
        if item:getFullType() == entry.type then
            return entry
        end
    end
    return nil
end

--- Types acceptés pour un tissu (affichage).
function MTIR.getPatternMaterialTypes(fabric)
    local types = {}
    for _, entry in ipairs(MATERIALS[fabric] or {}) do
        table.insert(types, entry.type)
    end
    return types
end

local function unitsOf(fabric, item)
    local entry = materialEntry(fabric, item)
    if not entry then
        return 0
    end
    if entry.roll then
        return item:getCurrentUses()
    end
    return entry.units
end

function MTIR.countMaterialUnits(fabric, items)
    local total = 0
    for i = 0, items:size() - 1 do
        total = total + unitsOf(fabric, items:get(i))
    end
    return total
end

--- Matériaux de l'inventaire : total disponible et liste suffisante (ou nil).
function MTIR.pickPatternMaterials(inventory, fabric, required)
    local picked = ArrayList.new()
    local pickedUnits = 0
    local available = 0
    for _, entry in ipairs(MATERIALS[fabric] or {}) do
        local items = inventory:getItemsFromFullType(entry.type, true)
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            local units = unitsOf(fabric, item)
            available = available + units
            if pickedUnits < required and units > 0 then
                picked:add(item)
                pickedUnits = pickedUnits + units
            end
        end
    end
    return available, pickedUnits >= required and picked or nil
end

--- Autorité : consomme `units` unités (une peau entamée est consommée entière).
function MTIR.consumeMaterials(fabric, items, units)
    for i = 0, items:size() - 1 do
        if units <= 0 then
            return
        end
        local item = items:get(i)
        local entry = materialEntry(fabric, item)
        if entry and entry.roll then
            while units > 0 and item:getCurrentUses() > 0 do
                item:UseAndSync()
                units = units - 1
            end
        elseif entry then
            MTIR.removeItem(item)
            units = units - entry.units
        end
    end
end

--- Aiguille, ou alêne pour un vêtement en cuir. Chaussures (kind "shoe") :
--- aiguille seulement, l'alêne est exigée en plus (MTIR.predicateAwl).
function MTIR.predicatePatternNeedle(fabric, kind)
    return function(item)
        if kind ~= "shoe" and fabric == "Leather" and MTIR.predicateAwl(item) then
            return true
        end
        return MTIR.predicateNeedle(item)
    end
end

--- Ciseaux, ou couteau aiguisé pour le cuir et pour toutes les chaussures.
function MTIR.predicatePatternCutter(fabric, kind)
    return function(item)
        if (kind == "shoe" or fabric == "Leather") and not item:isBroken() and item:hasTag(ItemTag.SHARP_KNIFE) then
            return true
        end
        return MTIR.predicateScissors(item)
    end
end

--- Alêne (tag base:awl : alênes, jeu de poinçons, couteau suisse, multitool…).
function MTIR.predicateAwl(item)
    return not item:isBroken() and item:hasTag(ItemTag.AWL)
end

--- Colle (tag base:glue : colle, colle à bois) avec assez d'utilisations.
function MTIR.predicateGlue(item)
    return item:hasTag(ItemTag.GLUE) and instanceof(item, "DrainableComboItem")
        and item:getCurrentUses() >= MTIR.SHOE_GLUE_USES
end

function MTIR.patternNeedsAwl(data)
    return data ~= nil and data.kind == "shoe"
end

function MTIR.patternNeedsGlue(data)
    return data ~= nil and data.kind == "shoe"
end

--- Autorité : consomme la colle (UseAndSync retire l'objet vide et synchronise).
function MTIR.consumeGlue(glue, uses)
    for _ = 1, uses do
        if glue:getCurrentUses() <= 0 then
            return
        end
        glue:UseAndSync()
    end
end

--- Autorité : crée l'exemplaire cousu, taille connue, état selon la marge de Couture.
function MTIR.createFromPattern(character, data, size, margin)
    local item = instanceItem(data.fullType)
    if not item then
        return nil
    end
    if data.kind == "shoe" then
        item:getModData()[MTIR.SHOE_DATA_KEY] = { size = tonumber(size), reveal = true, hint = true }
    else
        item:getModData()[MTIR.DATA_KEY] = { size = size, reveal = true, hint = true, resized = 0 }
    end
    local ratio = math.min(1, 0.7 + 0.1 * math.max(0, margin))
    item:setCondition(math.max(1, math.floor(item:getConditionMax() * ratio + 0.5)))
    if instanceof(item, "Clothing") then
        item:synchWithVisual()
    end
    local inventory = character:getInventory()
    inventory:AddItem(item)
    sendAddItemToContainer(inventory, item)
    return item
end

return MTIR
