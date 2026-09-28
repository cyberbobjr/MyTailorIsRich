-- ============================================================================
-- My Tailor Is Rich — effets partagés
--
-- * Stats dérivées (isolation, vitesse de combat, défenses) : calcul
--   déterministe, exécuté par l'autorité ET par le client MP (affichage).
-- * Effets d'autorité (chute, retrait, déchirure, usure, raideur) : solo ou
--   serveur seulement, puis synchronisés (syncItemFields, syncBodyPart,
--   syncVisuals) et signalés au client par MTIR.tell.
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"
require "MyTailorIsRich/MTIR_Shoes"
require "TimedActions/ISTransferAction"

MTIR.BodyDiffs = MTIR.BodyDiffs or {}
MTIR.DegradingChance = MTIR.DegradingChance or {}
MTIR.ServerCraftSize = MTIR.ServerCraftSize or {}

-- ----------------------------------------------------------------------------
-- Joueurs, notifications, synchronisation
-- ----------------------------------------------------------------------------

--- Clé stable d'un joueur dans le contexte courant.
--- Serveur : le compte (un onlineID peut être réattribué après une déconnexion).
function MTIR.playerKey(player)
    if isServer() then
        return "u" .. tostring(player:getUsername())
    end
    return "p" .. tostring(player:getPlayerNum())
end

--- Effets côté client : fx = { say = {key, arg}, sound, halo = {itemType, good}, refresh, resetModel }.
--- Serveur : commande réseau (sendServerCommand ne fait rien en solo). Solo et client MP : local.
function MTIR.tell(player, fx)
    if not player or not fx then
        return
    end
    if isServer() then
        -- OnServerCommand ne dit pas quel joueur local est visé (écran partagé) : on le joint.
        fx.playerOnlineId = player:getOnlineID()
        sendServerCommand(player, MTIR.NET_MODULE, "fx", fx)
    elseif MTIR.applyFx then
        MTIR.applyFx(player, fx)
    end
end

--- Pousse état, ModData et trous de l'objet vers son propriétaire (serveur seulement).
function MTIR.syncItem(player, item)
    if isServer() and player and item then
        syncItemFields(player, item)
    end
end

--- Retire un objet de son conteneur et le signale au réseau.
function MTIR.removeItem(item)
    local container = item and item:getContainer()
    if not container then
        return
    end
    container:Remove(item)
    sendRemoveItemFromContainer(container, item)
end

-- ----------------------------------------------------------------------------
-- Stats d'origine (script), mises en cache par type
-- ----------------------------------------------------------------------------

local originalInsulation = {}
local originalCombatSpeed = {}
local originalStats = {}

local function getOriginalInsulation(item)
    local fullType = item:getFullType()
    if originalInsulation[fullType] == nil then
        originalInsulation[fullType] = ScriptManager.instance:getItem(fullType):getInsulation()
    end
    return originalInsulation[fullType]
end

local function getOriginalCombatSpeed(item)
    local fullType = item:getFullType()
    if originalCombatSpeed[fullType] == nil then
        originalCombatSpeed[fullType] = instanceItem(fullType):getCombatSpeedModifier()
    end
    return originalCombatSpeed[fullType]
end

function MTIR.getOriginalStats(item)
    local fullType = item:getFullType()
    if not originalStats[fullType] then
        local sample = instanceItem(fullType)
        originalStats[fullType] = {
            biteDefense = sample:getBiteDefense() or 0,
            scratchDefense = sample:getScratchDefense() or 0,
            bulletDefense = sample:getBulletDefense() or 0,
            windResistance = sample:getWindresistance() or 0,
            waterResistance = sample:getWaterResistance() or 0,
        }
    end
    return originalStats[fullType]
end

-- ----------------------------------------------------------------------------
-- Stats dérivées
-- ----------------------------------------------------------------------------

--- Applique l'écart de taille à l'objet ; enregistre les zones serrées dans bodyDiffs.
function MTIR.updateClothesForDiff(item, player, diff, bodyDiffs)
    if not instanceof(item, "Clothing") then
        return
    end
    local insulation = getOriginalInsulation(item)
    local combatSpeed = getOriginalCombatSpeed(item)

    if diff and player:isEquippedClothing(item) then
        if diff > 0 then
            if MTIR.hasInsulationMod(item) then
                insulation = insulation * MTIR.getInsulationReduction(diff)
            end
            if MTIR.hasCombatMod(item) then
                combatSpeed = combatSpeed - MTIR.getCombatSpeedReduction(diff)
            end
        elseif diff < 0 and bodyDiffs and MTIR.increasesStiffness(item) then
            local parts = BloodClothingType.getCoveredParts(item:getBloodClothingType())
            for i = 0, parts:size() - 1 do
                -- BloodBodyPartType.Back n'a pas d'équivalent : FromIndex renvoie la sentinelle MAX.
                local bodyPartType = BodyPartType.FromIndex(BloodBodyPartType.ToIndex(parts:get(i)))
                if bodyPartType ~= BodyPartType.MAX then
                    bodyDiffs[bodyPartType] = math.min(bodyDiffs[bodyPartType] or 0, diff)
                end
            end
        end
    end

    item:setInsulation(math.min(insulation, 1))
    item:setCombatSpeedModifier(math.max(combatSpeed, 0.5))
end

--- Protection et résistances diminuent avec l'état du vêtement porté.
function MTIR.updateClothesStats(item, player)
    if not instanceof(item, "Clothing") then
        return
    end
    local stats = MTIR.getOriginalStats(item)
    local bite, scratch, bullet = stats.biteDefense, stats.scratchDefense, stats.bulletDefense
    local wind, water = stats.windResistance, stats.waterResistance
    local protectionLoss = MTIR.opt("ProtectionLossEachCondition") / 100.0
    local resistanceLoss = MTIR.opt("ResistanceLossEachCondition") / 100.0

    if player:isEquippedClothing(item) then
        local lostCondition = item:getConditionMax() - item:getCondition()
        local remainProtection = math.max(0, 1 - lostCondition * protectionLoss)
        local remainResistance = math.max(0, 1 - lostCondition * resistanceLoss)
        bite, scratch, bullet = bite * remainProtection, scratch * remainProtection, bullet * remainProtection
        wind, water = wind * remainResistance, water * remainResistance
    end

    if protectionLoss > 0 then
        item:setBiteDefense(bite)
        item:setScratchDefense(scratch)
        item:setBulletDefense(bullet)
    end
    if resistanceLoss > 0 then
        item:setWindresistance(wind)
        item:setWaterResistance(water)
    end
end

--- Recalcule un seul vêtement (port, retrait, retouche).
function MTIR.updateOneClothes(item, player)
    if not item or not player or not instanceof(item, "Clothing") then
        return
    end
    if MTIR.canClothesHaveSize(item) then
        MTIR.updateClothesForDiff(item, player, MTIR.getItemDiff(item, MTIR.getPlayerSize(player)), nil)
    elseif MTIR.canShoeHaveSize(item) then
        MTIR.updateShoeStats(item, player, nil)
    end
    if MTIR.canClothesDegrade(item) then
        MTIR.updateClothesStats(item, player)
    end
end

--- Recalcule tous les vêtements portés et les zones serrées du joueur.
function MTIR.applyDerivedStats(player)
    local bodyDiffs = {}
    MTIR.BodyDiffs[MTIR.playerKey(player)] = bodyDiffs
    local playerSize = MTIR.getPlayerSize(player)
    local footSize = MTIR.getPlayerShoeSize(player)
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and instanceof(item, "Clothing") then
            if MTIR.canClothesHaveSize(item) then
                MTIR.updateClothesForDiff(item, player, MTIR.getItemDiff(item, playerSize), bodyDiffs)
            elseif MTIR.canShoeHaveSize(item) then
                MTIR.applyShoeEffects(item, player, footSize, bodyDiffs)
            end
            if MTIR.canClothesDegrade(item) then
                MTIR.updateClothesStats(item, player)
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Effets d'autorité sur les vêtements portés
-- ----------------------------------------------------------------------------

local function wearsBelt(worn)
    for i = 0, worn:size() - 1 do
        if MTIR.locKey(worn:getItemByIndex(i)) == "belt" then
            return true
        end
    end
    return false
end

local function canPlayerDropClothes(player, worn)
    if player:isAsleep() or player:getVehicle() then
        return false
    end
    if wearsBelt(worn) then
        return false
    end
    return player:getPrimaryHandItem() ~= nil and player:getSecondaryHandItem() ~= nil
end

local SKIRT_KEYS = { skirt = true, longskirt = true }

--- Autorité : retire un objet porté et le pose au sol. Faux si le personnage n'a pas de case.
function MTIR.dropWornItem(item, player)
    local square = player:getCurrentSquare()
    if not square then
        return false
    end
    if item:isFavorite() then
        item:setFavorite(false)
    end
    player:removeWornItem(item)
    triggerEvent("OnClothingUpdated", player)
    MTIR.updateOneClothes(item, player)
    local x, y, z = ISTransferAction.GetDropItemOffset(player, square, item)
    MTIR.removeItem(item)
    square:AddWorldInventoryItem(item, x, y, z)
    return true
end

--- Un bas trop grand tombe au sol.
function MTIR.dropClothes(item, player)
    local key = MTIR.locKey(item)
    if not MTIR.dropWornItem(item, player) then
        return
    end
    local prefix = SKIRT_KEYS[key] and "IGUI_MTIR_Say_Dropped_Skirt" or "IGUI_MTIR_Say_Dropped_Pants"
    MTIR.tell(player, { sound = "PutItemInBag", say = { key = prefix .. tostring(ZombRand(2)) }, refresh = true })
end

--- Le personnage a grossi : le vêtement ne tient plus.
function MTIR.removeTooTight(item, player)
    player:removeWornItem(item)
    triggerEvent("OnClothingUpdated", player)
    MTIR.updateOneClothes(item, player)
    MTIR.tell(player, { sound = "PutItemInBag", say = { key = "IGUI_MTIR_Say_Nofit_Clothes" .. tostring(ZombRand(2)) }, refresh = true })
end

--- Autorité, chaque minute : tailles de la tenue de départ, chute, retrait.
function MTIR.applyAuthorityWornEffects(player)
    local worn = player:getWornItems()
    local playerSize = MTIR.getPlayerSize(player)
    local canDrop = canPlayerDropClothes(player, worn)
    local toDrop, toRemove = {}, {}

    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and MTIR.canShoeHaveSize(item) and not MTIR.getShoeData(item) then
            -- Chaussures de départ : à la pointure du porteur, à une près.
            local shoeData = MTIR.createShoeData(item, MTIR.shoeSizeNear(MTIR.getPlayerShoeSize(player)))
            shoeData.hint = true
            MTIR.syncItem(player, item)
        end
        if item and MTIR.canClothesHaveSize(item) then
            local data = MTIR.getData(item)
            if not data then
                -- Tenue de départ ou objet antérieur au mod : taille proche du porteur.
                data = MTIR.createData(item, playerSize.name)
                data.hint = true
                MTIR.syncItem(player, item)
            end
            local diff = MTIR.getItemDiff(item, playerSize)
            if diff then
                if canDrop and diff > 0 and MTIR.canClothesDrop(item)
                    and ZombRandFloat(0, 1) < MTIR.getClothesDropChance(diff) then
                    table.insert(toDrop, item)
                elseif diff < -2 then
                    table.insert(toRemove, item)
                end
            end
        end
    end

    -- Modifier la tenue après le parcours : retirer pendant l'itération décale les index.
    for _, item in ipairs(toDrop) do
        MTIR.dropClothes(item, player)
    end
    for _, item in ipairs(toRemove) do
        MTIR.removeTooTight(item, player)
    end
end

-- ----------------------------------------------------------------------------
-- Usure
-- ----------------------------------------------------------------------------

local function clamp01(value)
    return math.max(0, math.min(100, value or 0)) / 100
end

function MTIR.calcDegradeChance(item, player)
    local maintenance = player:getPerkLevel(Perks.Maintenance)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local skillFactor = 1 - math.sqrt((maintenance * 2 + tailoring) / 30) / 2

    local diff = 0
    if MTIR.canClothesHaveSize(item) then
        local itemDiff = MTIR.getItemDiff(item, MTIR.getPlayerSize(player))
        if itemDiff then
            diff = math.max(-2, math.min(0, itemDiff))
        end
    end
    local diffFactor = 0.5 + 2 / (4 + diff)

    local stats = MTIR.getOriginalStats(item)
    local bite, scratch, bullet = clamp01(stats.biteDefense), clamp01(stats.scratchDefense), clamp01(stats.bulletDefense)
    local defenseFactor = math.min(0.5, (bite * 4 + bullet * 2 + scratch) / 7) / 0.5
    defenseFactor = 1 - 0.2 * math.sqrt(defenseFactor)

    local resistanceFactor = math.min(0.75, (stats.waterResistance + stats.windResistance) / 2) / 0.75
    resistanceFactor = 1 - 0.5 * math.sqrt(resistanceFactor)

    -- 42.21 : getDirtiness() (getDirtyness() n'existe pas).
    local dirty = clamp01(item:getDirtiness())
    local blood = clamp01(item:getBloodLevel())
    local wet = clamp01(item:getWetness())
    local damageFactor = math.max(0, (blood * 4 + wet * 2 + dirty) / 7 - 0.25) / 0.75
    damageFactor = 1 + 0.5 * damageFactor ^ 3

    local params = MTIR.getDegradeParams()
    local total = damageFactor * defenseFactor * resistanceFactor * skillFactor * diffFactor
    local chance = params.baseChance * total ^ params.modifier
    MTIR.DegradingChance[item:getID()] = chance
    return chance
end

--- Autorité, chaque heure : un vêtement porté peut perdre un point d'état.
function MTIR.degradeWornClothes(player)
    if not MTIR.opt("EnableClothesDegrading") then
        return
    end
    local worn = player:getWornItems()
    local degraded = {}
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and instanceof(item, "Clothing") and MTIR.canClothesDegrade(item)
            and ZombRandFloat(0, 1) < MTIR.calcDegradeChance(item, player) then
            table.insert(degraded, item)
        end
    end
    for _, item in ipairs(degraded) do
        item:setCondition(item:getCondition() - 1)
        MTIR.updateClothesStats(item, player)
        MTIR.syncItem(player, item)
        MTIR.tell(player, {
            halo = { itemType = item:getFullType(), good = false },
            sound = item:getCondition() <= 0 and "PutItemInBag" or nil,
        })
    end
end

-- ----------------------------------------------------------------------------
-- Déchirures à l'escalade
-- ----------------------------------------------------------------------------

local CLIMB_RIP_CHANCE = { wall = 0.01, window = 0.002, fence = 0.001, fenceRun = 0.004, fenceSprint = 0.005 }

function MTIR.ripClothes(item, player)
    if not item:getCanHaveHoles() then
        return false
    end
    local visual = item:getVisual()
    local covered = BloodClothingType.getCoveredParts(item:getBloodClothingType())
    local candidates = {}
    for i = 0, covered:size() - 1 do
        local part = covered:get(i)
        if visual:getHole(part) == 0 then
            table.insert(candidates, part)
        end
    end
    if #candidates == 0 then
        return false
    end
    local part = candidates[ZombRand(#candidates) + 1]
    visual:setHole(part)
    item:removePatch(part)
    if not MTIR.canClothesDegrade(item) then
        item:setCondition(math.max(0, item:getCondition() - item:getCondLossPerHole()))
    end
    MTIR.syncItem(player, item)
    return true
end

--- Autorité : tirage des déchirures des vêtements trop petits après une escalade.
function MTIR.rollClimbRips(player, kind)
    local baseChance = CLIMB_RIP_CHANCE[kind]
    if not baseChance then
        return
    end
    local playerSize = MTIR.getPlayerSize(player)
    local worn = player:getWornItems()
    local tight = {}
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and MTIR.canClothesHaveSize(item) and MTIR.canClothesRip(item) then
            local diff = MTIR.getItemDiff(item, playerSize)
            if diff and diff < 0 then
                table.insert(tight, { item = item, diff = diff })
            end
        end
    end

    local ripped = false
    for _, entry in ipairs(tight) do
        if ZombRandFloat(0, 1) < baseChance * MTIR.getClothesRipChance(entry.diff) then
            if MTIR.ripClothes(entry.item, player) then
                ripped = true
                baseChance = baseChance / 2
            end
        end
    end
    if ripped then
        if isServer() then
            syncVisuals(player)
        end
        MTIR.tell(player, { sound = "MTIR_TightClothesRip", refresh = true, resetModel = true })
    end
end

-- ----------------------------------------------------------------------------
-- Raideur musculaire (autorité : l'état du corps appartient au serveur en MP)
-- ----------------------------------------------------------------------------

local legParts = nil
local exerciseRegions = nil

local function getLegParts()
    legParts = legParts or {
        BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
        BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R,
    }
    return legParts
end

local function getExerciseRegions()
    exerciseRegions = exerciseRegions or {
        arms = { BodyPartType.ForeArm_L, BodyPartType.ForeArm_R, BodyPartType.UpperArm_L, BodyPartType.UpperArm_R },
        legs = getLegParts(),
        chest = { BodyPartType.Torso_Upper },
        abs = { BodyPartType.Torso_Lower },
    }
    return exerciseRegions
end

local function addStiffness(bodyPart, amount, changed)
    bodyPart:setStiffness(math.min(100, bodyPart:getStiffness() + amount))
    changed[bodyPart] = true
end

local function syncStiffness(changed)
    if not isServer() then
        return
    end
    for bodyPart in pairs(changed) do
        syncBodyPart(bodyPart, MTIR.BD_STIFFNESS)
    end
end

--- timeFactor : somme des multiplicateurs de temps écoulés depuis le dernier appel.
function MTIR.applyStiffness(player, timeFactor)
    local bodyDiffs = MTIR.BodyDiffs[MTIR.playerKey(player)]
    if not bodyDiffs or timeFactor <= 0 then
        return
    end
    local bodyDamage = player:getBodyDamage()
    local changed = {}

    -- Récupération ralentie : la raideur ne redescend pas sous 5 x l'écart.
    local fitness = player:getFitness()
    if fitness and not fitness:onGoingStiffness() then
        local parts = bodyDamage:getBodyParts()
        for i = 0, parts:size() - 1 do
            local bodyPart = parts:get(i)
            local stiffness = bodyPart:getStiffness()
            local diff = bodyDiffs[bodyPart:getType()] or 0
            if stiffness > 0 and diff < 0 then
                local extra = (stiffness < 5 * math.abs(diff)) and 0.002 or (math.abs(diff) * 0.0005)
                addStiffness(bodyPart, extra * timeFactor, changed)
            end
        end
    end

    -- Bas ou chaussures trop serrés en marchant, courant ou sprintant.
    if player:isPlayerMoving() then
        local pace = 1.0
        if player:isRunning() then
            pace = 2.0
        elseif player:isSprinting() then
            pace = 3.0
        end
        local multiplier = MTIR.opt("IncreaseStiffnessMultiplier")
        local function stiffenMoving(bodyPartType)
            local diff = bodyDiffs[bodyPartType] or 0
            if diff < 0 then
                local amount = 0.00075 * pace * (math.abs(diff) + 1) / 2 * multiplier
                addStiffness(bodyDamage:getBodyPart(bodyPartType), amount * timeFactor, changed)
            end
        end
        for _, bodyPartType in ipairs(getLegParts()) do
            stiffenMoving(bodyPartType)
        end
        for _, bodyPartType in ipairs(MTIR.getFeetParts()) do
            stiffenMoving(bodyPartType)
        end
    end

    syncStiffness(changed)
end

--- Répétition d'exercice en vêtement serré (appelé depuis ISFitnessAction:exeLooped).
function MTIR.applyExerciseStiffness(player, stiffnessRegions)
    local bodyDiffs = MTIR.BodyDiffs[MTIR.playerKey(player)]
    if not bodyDiffs or type(stiffnessRegions) ~= "string" then
        return
    end
    local bodyDamage = player:getBodyDamage()
    local changed = {}
    for _, region in ipairs(luautils.split(stiffnessRegions, ",")) do
        for _, bodyPartType in ipairs(getExerciseRegions()[region] or {}) do
            local diff = bodyDiffs[bodyPartType] or 0
            if diff < 0 then
                addStiffness(bodyDamage:getBodyPart(bodyPartType), MTIR.getExtraStiffness(diff), changed)
            end
        end
    end
    syncStiffness(changed)
end

-- ----------------------------------------------------------------------------
-- Taille choisie pour l'artisanat (envoyée par le client, lue par l'autorité)
-- ----------------------------------------------------------------------------

function MTIR.setCraftSizeFor(player, fullType, sizeName)
    if type(fullType) ~= "string" or not MTIR.SIZES[sizeName] then
        return
    end
    local key = MTIR.playerKey(player)
    MTIR.ServerCraftSize[key] = MTIR.ServerCraftSize[key] or {}
    MTIR.ServerCraftSize[key][fullType] = sizeName
end

function MTIR.getCraftSizeFor(player, fullType)
    local sizes = MTIR.ServerCraftSize[MTIR.playerKey(player)]
    return sizes and sizes[fullType] or nil
end

-- ----------------------------------------------------------------------------
-- Outils des actions chronométrées (modèle vanilla ISRepairClothing) :
-- client MP -> comparaison par ID ; solo et serveur -> objets eux-mêmes.
-- ----------------------------------------------------------------------------

function MTIR.hasItem(character, item)
    if not item then
        return false
    end
    local inventory = character:getInventory()
    if isClient() then
        return inventory:containsID(item:getID())
    end
    return inventory:contains(item)
end

function MTIR.hasAllItems(character, items)
    if not items then
        return false
    end
    -- Un client modifié pourrait citer plusieurs fois le même objet pour payer moins.
    local seen = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if not item or seen[item:getID()] or not MTIR.hasItem(character, item) then
            return false
        end
        seen[item:getID()] = true
    end
    return true
end

--- Client MP : récupère l'instance locale à jour après les échanges réseau.
function MTIR.resolveItem(character, item)
    if not isClient() or not item then
        return item
    end
    return character:getInventory():getItemById(item:getID()) or item
end

function MTIR.sameItem(a, b)
    return a ~= nil and b ~= nil and a:getID() == b:getID()
end

--- Outils de débogage : mode debug, ou en MP un rôle autorisé à éditer les objets
--- (même règle que le menu vanilla, ISInventoryPaneContextMenu.lua:4682).
function MTIR.canUseDebug(player)
    if isDebugEnabled() then
        return true
    end
    if (isClient() or isServer()) and player then
        local role = player:getRole()
        return role ~= nil and role:hasCapability(Capability.EditItem)
    end
    return false
end

--- Consomme `uses` utilisations de fil, dans l'ordre de la liste.
function MTIR.consumeThreads(threads, uses)
    for i = 0, threads:size() - 1 do
        local thread = threads:get(i)
        while uses > 0 and thread:getCurrentUses() > 0 do
            thread:UseAndSync()
            uses = uses - 1
        end
    end
end

--- Retire les `count` premiers objets de la liste.
function MTIR.consumeItems(items, count)
    for i = 0, items:size() - 1 do
        if count <= 0 then
            return
        end
        MTIR.removeItem(items:get(i))
        count = count - 1
    end
end

return MTIR
