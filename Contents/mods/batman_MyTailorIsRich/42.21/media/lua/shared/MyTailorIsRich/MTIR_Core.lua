-- ============================================================================
-- My Tailor Is Rich — cœur partagé (Build 42.21)
-- Fork local de Realistic Clothes (Workshop 3491510356).
--
-- Contenu : options, tailles, données d'objet, emplacements, formules pures.
-- Aucune écriture d'état de jeu ici, sauf MTIR.createData / MTIR.ensureData,
-- réservées à l'autorité (solo ou serveur).
--
-- Portage 42.21 :
--   * getBodyLocation() renvoie un ItemBodyLocation : on compare une clé texte
--     normalisée (MTIR.locKey), jamais l'objet à une chaîne ;
--   * script Item : getItemType() == ItemType.CLOTHING (plus de getType()) ;
--   * traits : hasTrait(CharacterTrait.X) ; Lucky/Unlucky n'existent plus.
-- ============================================================================

MTIR = MTIR or {}

MTIR.DATA_KEY = "MTIR"
MTIR.NET_MODULE = "MTIR"

-- BodyPartSyncPacket.BD_stiffness en 42.21.
MTIR.BD_STIFFNESS = 1099511627776

-- ----------------------------------------------------------------------------
-- Autorité et options
-- ----------------------------------------------------------------------------

--- Vrai en solo et sur le serveur : seuls ces contextes modifient l'état.
function MTIR.isAuthority()
    return not isClient()
end

local DEFAULTS = {
    NeedTailoringLevel = true,
    TailoringXpMultiplier = 1.0,
    ActionTimeMultiplier = 1.0,
    RipChanceMultiplier = 1.0,
    DropChanceMultiplier = 1.0,
    InsulationReduceMultiplier = 1.0,
    CombatSpeedReduceMultiplier = 1.0,
    IncreaseTripChanceMultiplier = 1.0,
    IncreaseStiffnessMultiplier = 1.0,
    EnableClothesDegrading = true,
    MinDaysToDegrade = 30,
    MaxDaysToDegrade = 360,
    ChanceToDegradeOnFailure = 0.5,
    ProtectionLossEachCondition = 2.5,
    ResistanceLossEachCondition = 5.0,
    ListCustomClothes = "",
    EnableShoeSizes = true,
    ShoeEffectMultiplier = 1.0,
    ShowPlayerSize = true,
    ExtraSizedLocations = "",
    ListExcludedClothes = "",
    PatternMaxUses = 5,
    ShoePatternLevel = 8,
    EnablePatternCopy = true,
    PatternCopyPrecisionLoss = 1,
    PatternBinderCapacity = 20,
    RequireThimble = true,
    MachineBonusMultiplier = 1.0,
    MachineNoiseMultiplier = 1.0,
    EnableMachineMaintenance = true,
    SewingLootMultiplier = 1.0,
}

--- Lecture directe des options sandbox : suit les changements faits par un admin.
function MTIR.opt(name)
    local vars = SandboxVars and SandboxVars.MyTailorIsRich
    local value = vars and vars[name]
    if value == nil then
        return DEFAULTS[name]
    end
    return value
end

local degradeCache = {}

--- Paramètres d'usure dérivés des jours min/max (formule d'origine).
function MTIR.getDegradeParams()
    local minDays = MTIR.opt("MinDaysToDegrade")
    local maxDays = MTIR.opt("MaxDaysToDegrade")
    if minDays > maxDays then
        minDays, maxDays = 30, 360
    end
    if degradeCache.minDays ~= minDays or degradeCache.maxDays ~= maxDays then
        local maxChance = 10 / (minDays * 24)
        local minChance = 10 / (maxDays * 24)
        local modifier = math.log(maxChance / minChance) / math.log(2.25 / 0.2)
        degradeCache = {
            minDays = minDays,
            maxDays = maxDays,
            modifier = modifier,
            baseChance = math.sqrt(minChance * maxChance / (0.2 * 2.25) ^ modifier),
        }
    end
    return degradeCache
end

local customCache = { raw = nil, list = {} }

--- Vêtements ajoutés par l'option ListCustomClothes : fullType -> difficulté.
function MTIR.getCustomClothes()
    local raw = MTIR.opt("ListCustomClothes") or ""
    if raw == customCache.raw then
        return customCache.list
    end

    local list = {}
    for _, pair in ipairs(luautils.split(raw, ",")) do
        local parts = luautils.split(luautils.trim(pair), ":")
        local name = luautils.trim(parts[1] or "")
        local difficulty = 1
        if #parts == 2 then
            local number = tonumber(luautils.trim(parts[2]))
            if number and number > 0 and math.floor(number) == number then
                difficulty = math.min(number, 3)
            end
        end
        if name ~= "" then
            local script = ScriptManager.instance:getItem(name)
            if script and script:getItemType() == ItemType.CLOTHING then
                list[name] = difficulty
            end
        end
    end

    customCache = { raw = raw, list = list }
    return list
end

-- ----------------------------------------------------------------------------
-- Tailles
-- ----------------------------------------------------------------------------

MTIR.SIZES = {
    XS = { name = "XS", chance = 5, includes = function(x) return x <= 50 end },
    S = { name = "S", chance = 10, includes = function(x) return x > 50 and x <= 65 end },
    M = { name = "M", chance = 25, includes = function(x) return x > 65 and x <= 75 end },
    L = { name = "L", chance = 35, includes = function(x) return x > 75 and x < 85 end },
    XL = { name = "XL", chance = 15, includes = function(x) return x >= 85 and x < 100 end },
    XXL = { name = "XXL", chance = 10, includes = function(x) return x >= 100 end },
}

MTIR.SIZE_LIST = {
    MTIR.SIZES.XS, MTIR.SIZES.S, MTIR.SIZES.M,
    MTIR.SIZES.L, MTIR.SIZES.XL, MTIR.SIZES.XXL,
}

function MTIR.getSizeIndex(name)
    for i, size in ipairs(MTIR.SIZE_LIST) do
        if size.name == name then
            return i
        end
    end
    return nil
end

function MTIR.getNextSize(name)
    local index = MTIR.getSizeIndex(name)
    if index and index < #MTIR.SIZE_LIST then
        return MTIR.SIZE_LIST[index + 1]
    end
    return nil
end

function MTIR.getPrevSize(name)
    local index = MTIR.getSizeIndex(name)
    if index and index > 1 then
        return MTIR.SIZE_LIST[index - 1]
    end
    return nil
end

function MTIR.getClothesSizeFromName(name)
    return MTIR.SIZES[name] or MTIR.SIZES.L
end

--- Taille du personnage déduite de son poids.
function MTIR.getPlayerSize(player)
    local weight = player:getNutrition():getWeight()
    for _, size in ipairs(MTIR.SIZE_LIST) do
        if size.includes(weight) then
            return size
        end
    end
    return MTIR.SIZES.L
end

--- Écart en crans : positif = trop grand, négatif = trop petit.
function MTIR.getSizeDiff(clothesSize, playerSize)
    local clothesIndex = MTIR.getSizeIndex(clothesSize and clothesSize.name)
    local playerIndex = MTIR.getSizeIndex(playerSize and playerSize.name)
    if not clothesIndex or not playerIndex then
        return nil
    end
    return clothesIndex - playerIndex
end

function MTIR.getRandomClothesSize()
    local total = 0
    for _, size in ipairs(MTIR.SIZE_LIST) do
        total = total + size.chance
    end
    local roll = ZombRand(total)
    local cumulative = 0
    for _, size in ipairs(MTIR.SIZE_LIST) do
        cumulative = cumulative + size.chance
        if roll < cumulative then
            return size
        end
    end
    return MTIR.SIZES.L
end

-- ----------------------------------------------------------------------------
-- Emplacements (clés texte normalisées, portage 42.21)
-- ----------------------------------------------------------------------------

--- "base:tshirt" -> "tshirt". Accepte un InventoryItem ou un script Item.
function MTIR.locKey(source)
    if not source then
        return nil
    end
    local location = source:getBodyLocation()
    if location == nil then
        return nil
    end
    local key = string.lower(tostring(location))
    local colon = string.find(key, ":", 1, true)
    if colon then
        key = string.sub(key, colon + 1)
    end
    if key == "" then
        return nil
    end
    return key
end

-- canDrop : un bas trop grand peut tomber (sans ceinture, mains prises).
-- insulationMod / combatMod : un vêtement trop grand isole moins / gêne le combat.
-- incTrip : un bas trop grand augmente le risque de chute en franchissant.
-- incStiffness : un vêtement trop petit raidit les muscles couverts.
local TOP = { canRip = true, canDrop = false, insulationMod = true, combatMod = true, incTrip = false, incStiffness = true }
local BOTTOM = { canRip = true, canDrop = true, insulationMod = true, combatMod = false, incTrip = true, incStiffness = true }
local FULL = { canRip = true, canDrop = false, insulationMod = true, combatMod = true, incTrip = true, incStiffness = true }

local function slot(base, difficulty)
    local result = { difficulty = difficulty }
    for key, value in pairs(base) do
        result[key] = value
    end
    return result
end

MTIR.CLOTHES_SLOTS = {
    tanktop = slot(TOP, 1), tshirt = slot(TOP, 1), shortsleeveshirt = slot(TOP, 1),
    shirt = slot(TOP, 1), sweater = slot(TOP, 2), sweaterhat = slot(TOP, 2),
    jacket = slot(TOP, 2), jacket_down = slot(TOP, 2), jacket_bulky = slot(TOP, 3),
    jackethat = slot(TOP, 2), jackethat_bulky = slot(TOP, 3), jacketsuit = slot(TOP, 2),
    torso1 = slot(TOP, 1), vesttexture = slot(TOP, 1), jersey = slot(TOP, 1),

    skirt = slot(BOTTOM, 1), pants = slot(BOTTOM, 1), legs1 = slot(BOTTOM, 1),
    shortsshort = slot(BOTTOM, 1), shortpants = slot(BOTTOM, 1), longskirt = slot(BOTTOM, 1),
    pants_skinny = slot(BOTTOM, 1),

    longdress = slot(FULL, 3), dress = slot(FULL, 3), boilersuit = slot(FULL, 3),
    torso1legs1 = slot(FULL, 2), pantsextra = slot(FULL, 2),
}

-- Emplacements qui s'usent et leur difficulté de remise en état.
MTIR.DEGRADE_LOCATIONS = {
    hands = 1, scarf = 1, socks = 1, tanktop = 1, tshirt = 1,
    torso1 = 2, legs1 = 2, shirt = 2, shortsleeveshirt = 2, torsoextra = 2, pants = 2,
    skirt = 2, shortsshort = 2, shortpants = 2, longskirt = 2, vesttexture = 2,
    jersey = 2, pants_skinny = 2,
    sweater = 3, sweaterhat = 3, jacket = 3, jacket_down = 3, jackethat = 3,
    torso1legs1 = 3, bathrobe = 3, pantsextra = 3, torsoextravest = 3,
    jacket_bulky = 4, jackethat_bulky = 4, jacketsuit = 4, dress = 4, longdress = 4,
    fullsuit = 5, boilersuit = 5, torsoextravestbullet = 5,
}

-- MTIR.getSlot, MTIR.canClothesHaveSize et MTIR.canOutputHaveSize sont dans
-- MTIR_Sizing.lua : ils déduisent aussi la taille des vêtements de mods.

function MTIR.getDegradeDifficulty(item)
    local key = MTIR.locKey(item)
    return key and MTIR.DEGRADE_LOCATIONS[key] or nil
end

function MTIR.canClothesDegrade(item)
    if not MTIR.opt("EnableClothesDegrading") then
        return false
    end
    return MTIR.getDegradeDifficulty(item) ~= nil
end

function MTIR.canReconditionClothes(item)
    return MTIR.getDegradeDifficulty(item) ~= nil
end

local function slotFlag(item, flag)
    local found = MTIR.getSlot(item)
    return found ~= nil and found[flag] == true
end

function MTIR.canClothesRip(item) return slotFlag(item, "canRip") end
function MTIR.canClothesDrop(item) return slotFlag(item, "canDrop") end
function MTIR.hasInsulationMod(item) return slotFlag(item, "insulationMod") end
function MTIR.hasCombatMod(item) return slotFlag(item, "combatMod") end
function MTIR.increasesTrip(item) return slotFlag(item, "incTrip") end
function MTIR.increasesStiffness(item) return slotFlag(item, "incStiffness") end

-- ----------------------------------------------------------------------------
-- Données d'objet
-- ----------------------------------------------------------------------------

--- Lecture seule : nil si l'objet n'a pas encore de taille.
function MTIR.getData(item)
    if not item or not item:hasModData() then
        return nil
    end
    return item:getModData()[MTIR.DATA_KEY]
end

--- Tirage proche d'une taille de référence (25 % en dessous, 60 % égale, 15 % au-dessus).
local function rollSizeNear(sizeName)
    local index = MTIR.getSizeIndex(sizeName)
    if not index then
        return nil
    end
    local candidates = {}
    local total = 0
    local weights = { { offset = -1, weight = 25 }, { offset = 0, weight = 60 }, { offset = 1, weight = 15 } }
    for _, entry in ipairs(weights) do
        local i = index + entry.offset
        if i >= 1 and i <= #MTIR.SIZE_LIST then
            local weight = MTIR.SIZE_LIST[i].chance * entry.weight
            table.insert(candidates, { name = MTIR.SIZE_LIST[i].name, weight = weight })
            total = total + weight
        end
    end
    local roll = ZombRand(total)
    local cumulative = 0
    for _, candidate in ipairs(candidates) do
        cumulative = cumulative + candidate.weight
        if roll < cumulative then
            return candidate.name
        end
    end
    return sizeName
end

--- 10 % des vêtements trouvés ont déjà été retouchés d'un cran.
local function rollResized(sizeName)
    if ZombRandFloat(0, 1) >= 0.1 then
        return 0
    end
    local index = MTIR.getSizeIndex(sizeName)
    if ZombRandFloat(0, 1) < 0.5 then
        return index < #MTIR.SIZE_LIST and -1 or 0
    end
    return index > 1 and 1 or 0
end

--- Autorité uniquement. Crée la donnée si absente et la renvoie.
function MTIR.createData(item, initSize)
    local modData = item:getModData()
    if modData[MTIR.DATA_KEY] then
        return modData[MTIR.DATA_KEY]
    end
    local sizeName = type(initSize) == "string" and rollSizeNear(initSize) or nil
    sizeName = sizeName or MTIR.getRandomClothesSize().name
    modData[MTIR.DATA_KEY] = { size = sizeName, reveal = false, hint = false, resized = rollResized(sizeName) }
    return modData[MTIR.DATA_KEY]
end

local CORPSE_CONTAINERS = { inventorymale = true, inventoryfemale = true }

--- Autorité : tous les vêtements d'un même corps reçoivent une taille voisine.
function MTIR.sizeClothingCollection(items, sizeName)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if MTIR.canClothesHaveSize(item) and not MTIR.getData(item) then
            MTIR.createData(item, sizeName)
        end
    end
end

--- Donnée existante, ou créée si l'on a l'autorité. Peut renvoyer nil côté client MP.
function MTIR.ensureData(item, initSize)
    local data = MTIR.getData(item)
    if data or not item or not MTIR.isAuthority() then
        return data
    end
    if not initSize then
        local container = item:getContainer()
        if container and CORPSE_CONTAINERS[container:getType()] then
            MTIR.sizeClothingCollection(container:getItems(), MTIR.getRandomClothesSize().name)
            data = MTIR.getData(item)
            if data then
                return data
            end
        end
    end
    return MTIR.createData(item, initSize)
end

--- Écart de l'objet pour une taille de joueur, nil si taille inconnue.
function MTIR.getItemDiff(item, playerSize)
    local data = MTIR.getData(item)
    if not data or not data.size then
        return nil
    end
    return MTIR.getSizeDiff(MTIR.getClothesSizeFromName(data.size), playerSize)
end

-- ----------------------------------------------------------------------------
-- Textes (clés de traduction ; le texte est résolu sur le client)
-- ----------------------------------------------------------------------------

local function diffBucket(diff)
    if diff < -2 then return "Very_Tight" end
    if diff < 0 then return "Tight" end
    if diff == 0 then return "Fit" end
    if diff > 2 then return "Very_Loose" end
    return "Loose"
end

function MTIR.getHintText(diff)
    return getText("IGUI_MTIR_Hint_" .. diffBucket(diff))
end

--- Réplique « au jugé », quand la taille n'est pas lue.
function MTIR.pickHintSay(diff)
    return { key = "IGUI_MTIR_Say_Hint_" .. diffBucket(diff) .. tostring(ZombRand(2)) }
end

--- Réplique après lecture de l'étiquette.
function MTIR.pickLabelSay(diff, size)
    return { key = "IGUI_MTIR_Say_Label_" .. diffBucket(diff) .. tostring(ZombRand(2)), arg = size.name }
end

-- ----------------------------------------------------------------------------
-- Difficultés, durées, coûts (formules d'origine)
-- ----------------------------------------------------------------------------

MTIR.FABRIC_DIFFICULTY = { Cotton = 0, Denim = 1, Leather = 2 }

function MTIR.getClothesFabricType(item)
    local fabric = item:getScriptItem():getFabricType()
    if fabric and MTIR.FABRIC_DIFFICULTY[fabric] ~= nil then
        return fabric
    end
    return nil
end

function MTIR.getStripType(fabric)
    if fabric == "Cotton" then return "Base.RippedSheets" end
    if fabric == "Denim" then return "Base.DenimStrips" end
    if fabric == "Leather" then return "Base.LeatherStrips" end
    return nil
end

local function fabricDifficulty(item)
    return MTIR.FABRIC_DIFFICULTY[item:getScriptItem():getFabricType() or ""] or 0
end

function MTIR.getClothesDifficulty(item)
    local found = MTIR.getSlot(item)
    return found and found.difficulty or 1
end

function MTIR.canResizeClothes(item)
    return MTIR.canClothesHaveSize(item) and MTIR.getClothesFabricType(item) ~= nil
end

function MTIR.getRequiredLevelToCheck(item)
    if not MTIR.opt("NeedTailoringLevel") then return 0 end
    return math.max(MTIR.getClothesDifficulty(item) - 1, 0)
end

function MTIR.getCheckDuration(item)
    return math.max(1, MTIR.getClothesDifficulty(item) * 50 * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getRequiredLevelToChange(item, isUpsizing)
    if not MTIR.opt("NeedTailoringLevel") then return 0 end
    local difficulty = MTIR.getClothesDifficulty(item) + fabricDifficulty(item)
    if isUpsizing then
        difficulty = difficulty + 1
    end
    return difficulty
end

function MTIR.getChangeDuration(item, isUpsizing)
    local duration = MTIR.getClothesDifficulty(item) * 150 + fabricDifficulty(item) * 75
    if isUpsizing then
        duration = duration + 300
    end
    return math.max(1, duration * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getSuccessChanceForChange(tailoring, requiredLevel)
    if tailoring < requiredLevel then
        return 0
    end
    return 0.5 + (tailoring - requiredLevel) * 0.25
end

function MTIR.getTailoringXpForChange(item, isUpsizing, isSuccess)
    local xp = MTIR.getClothesDifficulty(item) * 5 + fabricDifficulty(item) * 2.5
    if isUpsizing then
        xp = xp + 10
    end
    return xp * MTIR.opt("TailoringXpMultiplier") * (isSuccess and 1 or 0.2)
end

function MTIR.getRequiredStripCount(item) return MTIR.getClothesDifficulty(item) * 2 end
function MTIR.getRequiredPaperclip(item) return MTIR.getClothesDifficulty(item) * 2 end
function MTIR.getRequiredThreadCount(item) return MTIR.getClothesDifficulty(item) * 2 end

-- Effets d'un écart de taille.
function MTIR.getClothesRipChance(diff) return math.abs(diff) * MTIR.opt("RipChanceMultiplier") end
function MTIR.getClothesDropChance(diff) return (diff ^ 2) * MTIR.opt("DropChanceMultiplier") / 60 end
function MTIR.getInsulationReduction(diff) return 0.5 + 0.5 / (1 + MTIR.opt("InsulationReduceMultiplier") * diff) end
function MTIR.getCombatSpeedReduction(diff) return 0.05 * 2 ^ (diff - 1) * MTIR.opt("CombatSpeedReduceMultiplier") end
function MTIR.getExtraTripChance(diff) return 5 * diff * MTIR.opt("IncreaseTripChanceMultiplier") end
function MTIR.getExtraStiffness(diff) return math.abs(diff) * MTIR.opt("IncreaseStiffnessMultiplier") end

-- ----------------------------------------------------------------------------
-- Remise en état
-- ----------------------------------------------------------------------------

function MTIR.getRepairedTimes(item)
    return item:getHaveBeenRepaired()
end

function MTIR.getRequiredLevelToRecondition(item)
    if not MTIR.opt("NeedTailoringLevel") then return 0 end
    return MTIR.getDegradeDifficulty(item) or 0
end

function MTIR.getReconditionDuration(item)
    return math.max(1, (MTIR.getDegradeDifficulty(item) or 1) * 20 * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getRequiredThreadToRecondition(item)
    return (MTIR.getDegradeDifficulty(item) or 1) * 2
end

function MTIR.getRequiredStripToRecondition(item)
    return (MTIR.getDegradeDifficulty(item) or 1) * 2
end

function MTIR.getTailoringXpForRecondition(item, isSuccess)
    local repairedTimes = MTIR.getRepairedTimes(item)
    local difficulty = MTIR.getDegradeDifficulty(item) or 1
    local xp
    if isSuccess then
        xp = 0.25 * 2 ^ math.max(0, difficulty - repairedTimes)
    else
        xp = 0.2 * difficulty * math.max(0, 10 - repairedTimes) / 10
    end
    return xp * MTIR.opt("TailoringXpMultiplier")
end

--- XP d'Entretien d'une remise en état. L'original divisait par zéro à partir de 10 réparations.
function MTIR.getMaintenanceXpForRecondition(conditionGain, repairedTimes)
    if repairedTimes >= 10 then
        return 0
    end
    return conditionGain * 0.5 / (repairedTimes + 1)
end

--- levelBonus (facultatif) : niveaux de Couture ajoutés par une machine à coudre.
function MTIR.getPotentialRepairForRecondition(item, player, levelBonus)
    local maintenance = player:getPerkLevel(Perks.Maintenance)
    local tailoring = player:getPerkLevel(Perks.Tailoring) + (levelBonus or 0)
    local repairedTimes = MTIR.getRepairedTimes(item)
    local delta = tailoring - (MTIR.getDegradeDifficulty(item) or 1) + 1
    local potential = delta >= 0 and ((3 * delta) / (2 + delta) * 0.25) or 0
    potential = potential + (6 * maintenance) / (2 + maintenance) * 0.05
    return potential / (1 + repairedTimes)
end

function MTIR.getSuccessChanceForRecondition(item, player, levelBonus)
    local maintenance = player:getPerkLevel(Perks.Maintenance)
    local tailoring = player:getPerkLevel(Perks.Tailoring) + (levelBonus or 0)
    local repairedTimes = MTIR.getRepairedTimes(item)
    local delta = tailoring - (MTIR.getDegradeDifficulty(item) or 1) + 1
    local chance = delta >= 0 and ((5 * delta) / (1.5 + delta) * 0.25) or (delta * 0.25)
    chance = chance + maintenance * 0.05
    -- Lucky / Unlucky n'existent plus en 42.21 : le bonus d'origine disparaît.
    return chance - 0.02 * repairedTimes * (1 + 0.25 * repairedTimes)
end

local function spareBonus(item, spareItem, damping)
    local spareRepaired = MTIR.getRepairedTimes(spareItem)
    return 0.05 * spareItem:getCondition() / (1 + 0.5 * spareRepaired) / (1 + damping * MTIR.getRepairedTimes(item))
end

function MTIR.getPotentialRepairUsingSpare(item, player, spareItem, levelBonus)
    local potential = MTIR.getPotentialRepairForRecondition(item, player, levelBonus) + spareBonus(item, spareItem, 0.25)
    return math.max(0, math.min(1, potential))
end

function MTIR.getSuccessChanceUsingSpare(item, player, spareItem, levelBonus)
    local chance = MTIR.getSuccessChanceForRecondition(item, player, levelBonus) + spareBonus(item, spareItem, 0.1)
    return math.max(0, math.min(1, chance))
end

-- ----------------------------------------------------------------------------
-- Matériaux (ArrayList : seules les ArrayList transportent des objets dans
-- les paramètres réseau d'une action 42.21 ; une table Lua arrive vide)
-- ----------------------------------------------------------------------------

function MTIR.predicateNeedle(item)
    if item:isBroken() then return false end
    return item:hasTag(ItemTag.SEWING_NEEDLE) or item:getType() == "Needle"
end

function MTIR.predicateScissors(item)
    if item:isBroken() then return false end
    return item:hasTag(ItemTag.SCISSORS) or item:getType() == "Scissors"
end

--- Bobine de fil : objet à utilisations de type Thread ou tag base:thread
--- (contrôle de l'autorité : un aliment ou une huile a aussi des utilisations).
function MTIR.predicateThread(item)
    if not instanceof(item, "DrainableComboItem") then return false end
    return item:getType() == "Thread" or item:hasTag(ItemTag.THREAD)
end

function MTIR.getRemainingThread(threads)
    local total = 0
    for i = 0, threads:size() - 1 do
        total = total + threads:get(i):getCurrentUses()
    end
    return total
end

--- Fils suffisants pour `required` utilisations, ou nil.
function MTIR.pickThreads(threads, required)
    local picked = ArrayList.new()
    local total = 0
    for i = 0, threads:size() - 1 do
        local thread = threads:get(i)
        if total < required and thread:getCurrentUses() > 0 then
            total = total + thread:getCurrentUses()
            picked:add(thread)
        end
    end
    if total >= required then
        return picked
    end
    return nil
end

--- `required` premiers objets de la liste, ou nil.
function MTIR.pickItems(items, required)
    if items:size() < required then
        return nil
    end
    local picked = ArrayList.new()
    for i = 0, required - 1 do
        picked:add(items:get(i))
    end
    return picked
end

return MTIR
