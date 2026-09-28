-- ============================================================================
-- My Tailor Is Rich — pointures de chaussures (système EU)
--
-- * Pied du personnage : pointure fixe, déduite du sexe et d'un hachage du
--   nom. Aucun stockage : même valeur en solo, sur le serveur et sur le client.
-- * Chaussures : ModData "MTIR_Shoe" = { size = 42, reveal, hint }.
--   Butin : répartition hommes/femmes ; cadavre : sexe du zombie.
-- * Effets : trop petite -> raideur des pieds, impossible à -3 ;
--   trop grande (+2 et au-delà) -> risque de chute en franchissant.
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"
require "MyTailorIsRich/MTIR_Sizing"

MTIR.SHOE_DATA_KEY = "MTIR_Shoe"

--- Écart à partir duquel la chaussure ne s'enfile plus.
MTIR.SHOE_TOO_TIGHT = -3

local SHOE_CHECK_DURATION = 30

-- Répartition des pointures EU (poids relatifs).
local DISTRIBUTION = {
    female = { { 35, 3 }, { 36, 8 }, { 37, 17 }, { 38, 24 }, { 39, 23 }, { 40, 15 }, { 41, 7 }, { 42, 3 } },
    male = { { 39, 3 }, { 40, 7 }, { 41, 14 }, { 42, 21 }, { 43, 23 }, { 44, 17 }, { 45, 9 }, { 46, 4 }, { 47, 2 } },
}

MTIR.SHOE_MIN = 35
MTIR.SHOE_MAX = 47

-- Enveloppes improvisées : elles s'adaptent à n'importe quel pied.
MTIR.UNSIZED_SHOES = {
    ["Base.Shoes_BurlapWrap"] = true,
    ["Base.Shoes_DenimWrap"] = true,
    ["Base.Shoes_LeatherWrap"] = true,
    ["Base.Shoes_RagWrap"] = true,
    ["Base.Shoes_TarpWrap"] = true,
    ["Base.Shoes_Twine"] = true,
}

local CORPSE_SEX = { inventoryfemale = true, inventorymale = false }

-- Butin sans propriétaire connu : part de pointures masculines selon le modèle.
-- Bottes de travail, militaires, de randonnée, de cowboy : surtout portées par des
-- hommes ; chaussures habillées à brides, sandales, pantoufles : plutôt des femmes.
-- Modèle absent (mods) : moitié-moitié.
local DEFAULT_MALE_SHARE = 0.5
MTIR.SHOE_MALE_SHARE = {
    ["Base.Shoes_ArmyBoots"] = 0.8,
    ["Base.Shoes_ArmyBootsDesert"] = 0.8,
    ["Base.Shoes_WorkBoots"] = 0.8,
    ["Base.Shoes_HikingBoots"] = 0.7,
    ["Base.Shoes_CowboyBoots"] = 0.75,
    ["Base.Shoes_CowboyBoots_Brown"] = 0.75,
    ["Base.Shoes_CowboyBoots_Black"] = 0.75,
    ["Base.Shoes_CowboyBoots_Fancy"] = 0.6,
    ["Base.Shoes_CowboyBoots_SnakeSkin"] = 0.7,
    ["Base.Shoes_BlackBoots"] = 0.65,
    ["Base.Shoes_Black"] = 0.6,
    ["Base.Shoes_Brown"] = 0.6,
    ["Base.Shoes_Wellies"] = 0.55,
    ["Base.Shoes_RidingBoots"] = 0.35,
    ["Base.Shoes_Fancy"] = 0.3,
    ["Base.Shoes_Strapped"] = 0.15,
    ["Base.Shoes_Sandals"] = 0.4,
    ["Base.Shoes_FlipFlop"] = 0.45,
    ["Base.Shoes_Slippers"] = 0.4,
}

function MTIR.getShoeMaleShare(item)
    return MTIR.SHOE_MALE_SHARE[item:getFullType()] or DEFAULT_MALE_SHARE
end

-- ----------------------------------------------------------------------------
-- Tirages
-- ----------------------------------------------------------------------------

local function totalWeight(list)
    local total = 0
    for _, entry in ipairs(list) do
        total = total + entry[2]
    end
    return total
end

local function pickWeighted(list, roll)
    local cumulative = 0
    for _, entry in ipairs(list) do
        cumulative = cumulative + entry[2]
        if roll < cumulative then
            return entry[1]
        end
    end
    return list[#list][1]
end

--- Pointure aléatoire ; isFemale = nil pour un propriétaire inconnu (butin).
function MTIR.randomShoeSize(isFemale)
    if isFemale == nil then
        isFemale = ZombRand(2) == 0
    end
    local list = isFemale and DISTRIBUTION.female or DISTRIBUTION.male
    return pickWeighted(list, ZombRand(totalWeight(list)))
end

--- Butin : le modèle oriente vers une pointure d'homme ou de femme.
function MTIR.randomShoeSizeForItem(item)
    local isFemale = ZombRandFloat(0, 1) >= MTIR.getShoeMaleShare(item)
    return MTIR.randomShoeSize(isFemale)
end

--- Pointure voisine : 70 % identique, 15 % une de moins, 15 % une de plus.
function MTIR.shoeSizeNear(size)
    local roll = ZombRand(100)
    local result = size
    if roll < 15 then
        result = size - 1
    elseif roll >= 85 then
        result = size + 1
    end
    return math.max(MTIR.SHOE_MIN, math.min(MTIR.SHOE_MAX, result))
end

local function hashString(text)
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + string.byte(text, i)) % 2147483647
    end
    return hash
end

--- Pointure du pied du personnage : stable pour un même personnage, partout.
function MTIR.getPlayerShoeSize(player)
    local descriptor = player:getDescriptor()
    local name = descriptor and (tostring(descriptor:getForename()) .. " " .. tostring(descriptor:getSurname()))
        or tostring(player:getUsername())
    local list = player:isFemale() and DISTRIBUTION.female or DISTRIBUTION.male
    return pickWeighted(list, hashString(name) % totalWeight(list))
end

-- ----------------------------------------------------------------------------
-- Détection et données
-- ----------------------------------------------------------------------------

--- Emplacement « shoes », ou emplacement de mod couvrant seulement les pieds (MTIR_Sizing).
function MTIR.canShoeHaveSize(item)
    if not MTIR.opt("EnableShoeSizes") then
        return false
    end
    if not item or not instanceof(item, "Clothing") or MTIR.getSizingKind(item) ~= "shoe" then
        return false
    end
    return not MTIR.UNSIZED_SHOES[item:getFullType()]
end

--- Lecture seule : nil si la chaussure n'a pas encore de pointure.
function MTIR.getShoeData(item)
    if not item or not item:hasModData() then
        return nil
    end
    return item:getModData()[MTIR.SHOE_DATA_KEY]
end

--- Autorité uniquement.
function MTIR.createShoeData(item, size)
    local modData = item:getModData()
    if not modData[MTIR.SHOE_DATA_KEY] then
        modData[MTIR.SHOE_DATA_KEY] = { size = size, reveal = false, hint = false }
    end
    return modData[MTIR.SHOE_DATA_KEY]
end

--- Autorité : toutes les chaussures d'une collection reçoivent la même pointure.
function MTIR.sizeShoesInCollection(items, size)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if MTIR.canShoeHaveSize(item) and not MTIR.getShoeData(item) then
            MTIR.createShoeData(item, size)
        end
    end
end

--- Donnée existante, ou créée si l'on a l'autorité (sexe du cadavre si connu).
function MTIR.ensureShoeData(item)
    local data = MTIR.getShoeData(item)
    if data or not item or not MTIR.isAuthority() then
        return data
    end
    local container = item:getContainer()
    local isFemale = container and CORPSE_SEX[container:getType()]
    if isFemale ~= nil then
        MTIR.sizeShoesInCollection(container:getItems(), MTIR.randomShoeSize(isFemale))
        data = MTIR.getShoeData(item)
        if data then
            return data
        end
    end
    return MTIR.createShoeData(item, MTIR.randomShoeSizeForItem(item))
end

--- Écart en pointures (positif = trop grande), nil si pointure inconnue.
function MTIR.getShoeDiff(item, footSize)
    local data = MTIR.getShoeData(item)
    if not data or not data.size then
        return nil
    end
    return data.size - footSize
end

--- Écart ramené à l'échelle des effets des vêtements (1 cran = 1 taille).
--- Une pointure de plus reste confortable ; au-delà, le pied flotte.
function MTIR.getShoeEffectDiff(diff)
    if diff <= MTIR.SHOE_TOO_TIGHT then
        return MTIR.SHOE_TOO_TIGHT
    end
    if diff < 0 then
        return diff
    end
    if diff <= 1 then
        return 0
    end
    return math.min(diff - 1, 3)
end

function MTIR.getShoeCheckDuration()
    return math.max(1, SHOE_CHECK_DURATION * MTIR.opt("ActionTimeMultiplier"))
end

-- ----------------------------------------------------------------------------
-- Textes
-- ----------------------------------------------------------------------------

local function shoeBucket(diff)
    if diff <= -2 then return "Very_Tight" end
    if diff < 0 then return "Tight" end
    if diff == 0 then return "Fit" end
    if diff >= 3 then return "Very_Loose" end
    return "Loose"
end

function MTIR.getShoeHintText(diff)
    return getText("IGUI_MTIR_Hint_" .. shoeBucket(diff))
end

function MTIR.pickShoeHintSay(diff)
    return { key = "IGUI_MTIR_Say_ShoeHint_" .. shoeBucket(diff) .. tostring(ZombRand(2)) }
end

function MTIR.pickShoeLabelSay(diff, size)
    return { key = "IGUI_MTIR_Say_ShoeLabel_" .. shoeBucket(diff) .. tostring(ZombRand(2)), arg = tostring(size) }
end

-- ----------------------------------------------------------------------------
-- Effets
-- ----------------------------------------------------------------------------

local feet = nil

function MTIR.getFeetParts()
    feet = feet or { BodyPartType.Foot_L, BodyPartType.Foot_R }
    return feet
end

-- Écrasement d'un zombie au sol (CombatManager.java:868-872) :
--   dégâts = (0,7 à 1,0 + Force x 0,2) x StompPower de la paire portée ; pieds nus x0,5.
-- Un zombie normal a 1,8 à 2,1 PV : une botte (2,5) tue d'un coup, pieds nus il en faut 2-3.
-- Trop grande, le pied flotte : la force glisse vers celle d'un pied nu,
-- 35 % du chemin par cran d'effet (+2 : 35 %, +3 : 70 %, +4 et plus : pied nu).
local BAREFOOT_STOMP_POWER = 0.5
local STOMP_TOWARD_BAREFOOT_PER_EFFECT = 0.35
local originalStompPower = {}

function MTIR.getOriginalStompPower(item)
    local fullType = item:getFullType()
    if originalStompPower[fullType] == nil then
        originalStompPower[fullType] = instanceItem(fullType):getStompPower()
    end
    return originalStompPower[fullType]
end

--- Recalcule la force d'écrasement de la paire (valeur d'origine si non portée).
function MTIR.updateShoeStats(item, player, footSize)
    local original = MTIR.getOriginalStompPower(item)
    local stompPower = original
    if player:isEquippedClothing(item) then
        local diff = MTIR.getShoeDiff(item, footSize or MTIR.getPlayerShoeSize(player))
        local effect = diff and MTIR.getShoeEffectDiff(diff) or 0
        if effect > 0 then
            local share = math.min(1, STOMP_TOWARD_BAREFOOT_PER_EFFECT * effect)
            local barefoot = math.min(BAREFOOT_STOMP_POWER, original)
            stompPower = original + (barefoot - original) * share
        end
    end
    item:setStompPower(stompPower)
end

--- Chaussure portée trop petite : les pieds se raidissent (bodyDiffs).
--- Trop grande : force d'écrasement réduite.
function MTIR.applyShoeEffects(item, player, footSize, bodyDiffs)
    MTIR.updateShoeStats(item, player, footSize)
    if not bodyDiffs or not player:isEquippedClothing(item) then
        return
    end
    local diff = MTIR.getShoeDiff(item, footSize)
    if not diff then
        return
    end
    local effect = MTIR.getShoeEffectDiff(diff)
    if effect < 0 then
        for _, bodyPartType in ipairs(MTIR.getFeetParts()) do
            bodyDiffs[bodyPartType] = math.min(bodyDiffs[bodyPartType] or 0, effect)
        end
    end
end

--- Supplément de chute (en %) dû aux chaussures trop grandes portées.
function MTIR.getShoeTripChance(player)
    local footSize = MTIR.getPlayerShoeSize(player)
    local worn = player:getWornItems()
    local total = 0
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and MTIR.canShoeHaveSize(item) then
            local diff = MTIR.getShoeDiff(item, footSize)
            local effect = diff and MTIR.getShoeEffectDiff(diff) or 0
            if effect > 0 then
                total = total + MTIR.getExtraTripChance(effect)
            end
        end
    end
    return total
end

return MTIR
