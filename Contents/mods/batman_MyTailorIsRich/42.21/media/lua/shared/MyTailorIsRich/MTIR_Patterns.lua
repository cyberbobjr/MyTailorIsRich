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
--     cuir) ; les chaussures sont en cuir et demandent plus de Couture.
-- Le patron système vanilla (SewingPattern) apprend des recettes figées : il
-- n'est pas utilisé ici.
-- ============================================================================

require "MyTailorIsRich/MTIR_Sizing"
require "MyTailorIsRich/MTIR_Effects"

MTIR.PATTERN_ITEM = "Base.MTIR_TailorPattern"
MTIR.PATTERN_DATA_KEY = "MTIR_Pattern"

local PAPER_TYPE = "Base.SheetPaper2"
local SHOE_PAPER = 2
local SHOE_MATERIAL_UNITS = 6
local SHOE_THREAD = 5
local SHOE_DIFFICULTY = 3
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

-- Tissu en plus ou en moins selon la taille cousue.
local SIZE_MATERIAL_DELTA = { XS = -2, S = -1, M = 0, L = 0, XL = 1, XXL = 2 }

-- ----------------------------------------------------------------------------
-- Données du patron
-- ----------------------------------------------------------------------------

function MTIR.isPattern(item)
    return item ~= nil and item:getFullType() == MTIR.PATTERN_ITEM
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

--- Le modèle existe-t-il encore (mod désinstallé depuis le tracé) ?
function MTIR.patternModelExists(data)
    return data ~= nil and ScriptManager.instance:getItem(data.fullType) ~= nil
end

-- ----------------------------------------------------------------------------
-- Tracer
-- ----------------------------------------------------------------------------

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
    return kind, nil
end

--- Description du modèle au moment du tracé.
function MTIR.describeModel(item)
    local kind = MTIR.getTraceKind(item)
    if not kind then
        return nil
    end
    if kind == "shoe" then
        return { kind = "shoe", fabric = "Leather", difficulty = SHOE_DIFFICULTY }
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
    pattern:setName(getText("IGUI_MTIR_PatternName", getItemNameFromFullType(item:getFullType())))
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

function MTIR.getPatternThread(data)
    if data.kind == "shoe" then
        return SHOE_THREAD
    end
    return data.difficulty * 2 + 1
end

function MTIR.getSewDuration(data)
    local base = data.kind == "shoe" and 750 or (300 + data.difficulty * 150)
    return math.max(1, base * MTIR.opt("ActionTimeMultiplier"))
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

--- Aiguille (ou alêne pour le cuir) et outil de coupe (ou couteau pour le cuir).
function MTIR.predicatePatternNeedle(fabric)
    return function(item)
        if fabric == "Leather" and not item:isBroken() and item:hasTag(ItemTag.AWL) then
            return true
        end
        return MTIR.predicateNeedle(item)
    end
end

function MTIR.predicatePatternCutter(fabric)
    return function(item)
        if fabric == "Leather" and not item:isBroken() and item:hasTag(ItemTag.SHARP_KNIFE) then
            return true
        end
        return MTIR.predicateScissors(item)
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
