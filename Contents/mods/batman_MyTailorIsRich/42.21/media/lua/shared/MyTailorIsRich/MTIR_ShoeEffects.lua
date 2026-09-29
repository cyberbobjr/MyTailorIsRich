-- ============================================================================
-- My Tailor Is Rich — effets continus des chaussures mal ajustées
--
-- Trop petites (-1, -2)  : inconfort (humeur vanilla), ampoules en marchant,
--                          plus fréquentes en courant.
-- Trop grandes (+2 et +) : endurance consommée en plus en course/sprint,
--                          ampoules rares en courant (talon qui frotte).
-- Très grandes (+3 et +) : inconfort léger, chaussure perdue en sprintant.
--
-- Autorité (solo, serveur) : tout. Client MP : plancher d'inconfort local,
-- pour l'affichage de l'humeur entre deux synchronisations.
--
-- La vitesse ne se règle pas directement en 42.21 (voir pz-knowledge) :
-- les ampoules ralentissent via les blessures au pied, l'endurance via
-- l'humeur d'épuisement.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"

-- Ampoules : jauge de frottement. Minutes de jeu de mouvement continu pour la
-- remplir, par allure { marche, course, sprint } ; nil = pas de frottement.
-- Trop grande : le talon ne frotte qu'en courant.
local BLISTER_MINUTES = {
    [-2] = { 45, 15, 10 },
    [-1] = { 120, 45, 30 },
    [2] = { nil, 90, 60 },
    [3] = { nil, 45, 30 },
}
-- Au repos, une jauge pleine se vide en une heure de jeu.
local FRICTION_RECOVERY_PER_MINUTE = 1 / 60
local FRICTION_WARNING = 0.5

-- Perte de chaussure trop grande.
-- Continu : probabilité par minute de jeu, par allure (course, sprint), par cran d'effet au-delà du premier.
local SHOE_LOSS_RATE_BY_PACE = { [2] = 0.01, [3] = 0.03 }
-- Événements : probabilité par cran d'effet (+2 = 1 cran, +3 = 2, +4 et plus = 3).
local EVENT_LOSS_CHANCE = {
    fence = 0.05, fenceRun = 0.08, fenceSprint = 0.12,
    wall = 0.08, window = 0.04, fall = 0.15,
}
local EVENT_LOSS_MAX = 0.9
-- Tirage raté de moins de (facteur - 1) x la chance : « elle a failli partir ».
local NEAR_MISS_FACTOR = 2
-- Maintien du modèle : sans lacets, la chaussure s'échappe plus facilement.
local DEFAULT_SLIP = 1.0
local SHOE_SLIP = {
    ["Base.Shoes_FlipFlop"] = 2.0,
    ["Base.Shoes_Slippers"] = 2.0,
    ["Base.Shoes_Sandals"] = 1.5,
    ["Base.Shoes_Wellies"] = 1.5,
    ["Base.Shoes_Fancy"] = 1.3,
    ["Base.Shoes_Strapped"] = 0.9,
    ["Base.Shoes_ArmyBoots"] = 0.6,
    ["Base.Shoes_ArmyBootsDesert"] = 0.6,
    ["Base.Shoes_HikingBoots"] = 0.6,
    ["Base.Shoes_WorkBoots"] = 0.7,
    ["Base.Shoes_BlackBoots"] = 0.8,
}

-- Part de la dépense d'endurance vanilla ajoutée par cran d'effet.
local ENDURANCE_SHARE_PER_EFFECT = 0.15

-- Facteur vanilla de la dépense de course (IsoPlayer.updateEndurance :
-- enddelta 1.4 x 2.3, x 0.5, mod 0.7), appliqué à RunningEnduranceReduce
-- ou SprintingEnduranceReduce de shared/defines.lua.
local VANILLA_ENDURANCE_FACTOR = 1.4 * 2.3 * 0.5 * 0.7

local DISCOMFORT_FLOOR = { [-1] = 25, [-2] = 45 }
local DISCOMFORT_FLOOR_VERY_LOOSE = 25

-- Toutes les données de la partie du corps (vanilla : ClientCommands debug).
local BODY_PART_SYNC_ALL = 0xFFFFFFFFFFF

local function intensity()
    return math.max(0, MTIR.opt("ShoeEffectMultiplier") or 1)
end

local function statMask(stat)
    return SyncPlayerStatsPacket.getBitMaskForStat(stat)
end

--- Chaussure portée et son écart, ou nil.
local function wornShoe(player)
    local shoe = player:getWornItem(ItemBodyLocation.SHOES)
    if not shoe or not MTIR.canShoeHaveSize(shoe) then
        return nil, nil
    end
    return shoe, MTIR.getShoeDiff(shoe, MTIR.getPlayerShoeSize(player))
end

--- 0 immobile, 1 marche, 2 course, 3 sprint.
local function movementPace(player)
    if not player:isPlayerMoving() then
        return 0
    end
    if player:isSprinting() then
        return 3
    end
    if player:isRunning() then
        return 2
    end
    return 1
end

local function roll(chancePerMinute, minutes)
    return ZombRandFloat(0, 1) < math.min(1, chancePerMinute * minutes)
end

-- ----------------------------------------------------------------------------
-- Inconfort
-- ----------------------------------------------------------------------------

local function discomfortFloor(diff)
    if diff < 0 then
        return DISCOMFORT_FLOOR[math.max(diff, -2)] or 0
    end
    if diff >= 3 then
        return DISCOMFORT_FLOOR_VERY_LOOSE
    end
    return 0
end

MTIR.DiscomfortFloor = {}
MTIR.DiscomfortCorrected = MTIR.DiscomfortCorrected or {}
-- Nombre d'entrées de DiscomfortFloor : sans plancher, les boucles par tick s'arrêtent là.
local floorCount = 0

--- Début d'un recalcul complet (toutes les ~30 ticks) : les joueurs morts ou partis
--- sortent de la table, et le compte ne peut pas dériver.
function MTIR.resetDiscomfortFloors()
    MTIR.DiscomfortFloor = {}
    floorCount = 0
end

--- Vrai si au moins un joueur a un plancher d'inconfort à maintenir.
function MTIR.hasDiscomfortFloors()
    return floorCount > 0
end

--- Recalcule le plancher d'inconfort du joueur (appel peu fréquent : pointure, hachage).
function MTIR.refreshDiscomfortFloor(player)
    local key = MTIR.playerKey(player)
    local floor = 0
    if intensity() > 0 and not player:hasTrait(CharacterTrait.DESENSITIZED) then
        local _, diff = wornShoe(player)
        floor = diff and discomfortFloor(diff) or 0
    end
    local had = MTIR.DiscomfortFloor[key] ~= nil
    local value = floor > 0 and floor or nil
    MTIR.DiscomfortFloor[key] = value
    if value and not had then
        floorCount = floorCount + 1
    elseif had and not value then
        floorCount = floorCount - 1
    end
end

--- À appeler à chaque tick : vanilla (BodyDamage.UpdateDiscomfort) fait redescendre la
--- stat vers sa cible à chaque mise à jour, sans frein à la baisse. Les appelants sautent
--- la boucle entière quand hasDiscomfortFloors() est faux.
function MTIR.enforceDiscomfortFloor(player)
    local key = MTIR.playerKey(player)
    local floor = MTIR.DiscomfortFloor[key]
    if not floor then
        return
    end
    local stats = player:getStats()
    if stats:get(CharacterStat.DISCOMFORT) < floor then
        stats:set(CharacterStat.DISCOMFORT, floor)
        MTIR.DiscomfortCorrected[key] = true
    end
end

--- Serveur : synchronise l'inconfort seulement s'il a été corrigé depuis le dernier envoi.
--- Le client MP maintient aussi le plancher localement : l'envoi n'a pas besoin d'être fréquent.
function MTIR.syncDiscomfortIfCorrected(player)
    local key = MTIR.playerKey(player)
    if not MTIR.DiscomfortCorrected[key] then
        return
    end
    MTIR.DiscomfortCorrected[key] = nil
    if isServer() then
        syncPlayerStats(player, statMask(CharacterStat.DISCOMFORT))
    end
end

-- ----------------------------------------------------------------------------
-- Ampoules
-- ----------------------------------------------------------------------------

MTIR.Friction = MTIR.Friction or {}

local function blisterMinutes(diff, pace)
    if pace <= 0 then
        return nil
    end
    local key = diff < 0 and math.max(diff, -2) or math.min(diff, 3)
    local row = BLISTER_MINUTES[key]
    return row and row[pace] or nil
end

--- Égratignure sans infection sur un pied encore intact.
local function giveBlister(player)
    local bodyDamage = player:getBodyDamage()
    local feet = MTIR.getFeetParts()
    local first = ZombRand(2) + 1
    for offset = 0, 1 do
        local part = bodyDamage:getBodyPart(feet[(first + offset - 1) % 2 + 1])
        if not part:scratched() then
            part:setScratched(true, true)
            if isServer() then
                syncBodyPart(part, BODY_PART_SYNC_ALL)
            end
            MTIR.tell(player, { say = { key = "IGUI_MTIR_Say_Blister" .. tostring(ZombRand(2)) } })
            return true
        end
    end
    return false
end

--- La jauge monte en marchant (plus vite en courant), redescend au repos ou avec
--- une paire à la bonne pointure ; avertissement à mi-course, ampoule quand elle est pleine.
local function updateFriction(player, diff, pace, minutes)
    if minutes <= 0 then
        return
    end
    local key = MTIR.playerKey(player)
    local state = MTIR.Friction[key] or { value = 0, warned = false }
    MTIR.Friction[key] = state

    local limit = diff and blisterMinutes(diff, pace) or nil
    if limit then
        state.value = state.value + minutes * intensity() / limit
    else
        state.value = math.max(0, state.value - minutes * FRICTION_RECOVERY_PER_MINUTE)
    end

    if state.value < FRICTION_WARNING then
        state.warned = false
    elseif not state.warned then
        state.warned = true
        MTIR.tell(player, { say = { key = "IGUI_MTIR_Say_FeetHot" .. tostring(ZombRand(2)) } })
    end

    if state.value >= 1 then
        state.value = 0
        state.warned = false
        giveBlister(player)
    end
end

--- Niveau de la jauge de frottement (0 à 1), pour le débogage.
function MTIR.getFriction(player)
    local state = MTIR.Friction[MTIR.playerKey(player)]
    return state and state.value or 0
end

-- ----------------------------------------------------------------------------
-- Endurance et perte de chaussure (trop grande)
-- ----------------------------------------------------------------------------

local function drainEndurance(player, diff, pace, timeFactor)
    if pace < 2 or diff < 2 then
        return
    end
    local reduce = pace == 3 and ZomboidGlobals.SprintingEnduranceReduce or ZomboidGlobals.RunningEnduranceReduce
    local share = ENDURANCE_SHARE_PER_EFFECT * MTIR.getShoeEffectDiff(diff) * intensity()
    local amount = reduce * VANILLA_ENDURANCE_FACTOR * timeFactor * share
    if amount <= 0 then
        return
    end
    player:getStats():remove(CharacterStat.ENDURANCE, amount)
    if isServer() then
        syncPlayerStats(player, statMask(CharacterStat.ENDURANCE))
    end
end

local function slipFactor(shoe)
    return SHOE_SLIP[shoe:getFullType()] or DEFAULT_SLIP
end

local function loseShoe(player, shoe)
    if MTIR.dropWornItem(shoe, player) then
        MTIR.tell(player, {
            sound = "PutItemInBag",
            say = { key = "IGUI_MTIR_Say_LostShoe" .. tostring(ZombRand(2)) },
            refresh = true,
        })
    end
end

--- Continu : en courant ou en sprintant, à partir de +3.
local function rollShoeLoss(player, shoe, diff, pace, minutes)
    local rate = SHOE_LOSS_RATE_BY_PACE[pace]
    local effect = MTIR.getShoeEffectDiff(diff)
    if not rate or effect < 2 then
        return
    end
    if roll(rate * (effect - 1) * slipFactor(shoe) * intensity(), minutes) then
        loseShoe(player, shoe)
    end
end

--- Probabilité de perdre la chaussure portée sur un événement (0 si aucun risque).
function MTIR.getShoeLossChance(player, kind)
    local base = EVENT_LOSS_CHANCE[kind]
    if not base or intensity() <= 0 then
        return 0
    end
    local shoe, diff = wornShoe(player)
    local effect = diff and MTIR.getShoeEffectDiff(diff) or 0
    if effect <= 0 then
        return 0
    end
    return math.min(EVENT_LOSS_MAX, base * effect * slipFactor(shoe) * intensity())
end

--- Autorité : tirage ponctuel sur un saut de barrière, une escalade ou une chute.
--- Un tirage manqué de peu prévient le joueur : la chaussure a failli partir.
function MTIR.rollShoeLossEvent(player, kind)
    local chance = MTIR.getShoeLossChance(player, kind)
    if chance <= 0 then
        return
    end
    local draw = ZombRandFloat(0, 1)
    if isDebugEnabled() then
        print(string.format("[MTIR] shoe loss %s: chance %.2f, roll %.2f", tostring(kind), chance, draw))
    end
    if draw < chance then
        loseShoe(player, (wornShoe(player)))
    elseif draw < chance * NEAR_MISS_FACTOR then
        MTIR.tell(player, { say = { key = "IGUI_MTIR_Say_ShoeSlipping" .. tostring(ZombRand(2)) } })
    end
end

-- ----------------------------------------------------------------------------

--- Autorité. timeFactor : somme des multiplicateurs de temps ; minutes : minutes de jeu écoulées.
function MTIR.applyShoeTick(player, timeFactor, minutes)
    local shoe, diff = wornShoe(player)
    local active = diff ~= nil and intensity() > 0
    local pace = movementPace(player)
    -- Pieds nus, bonne pointure ou effets coupés : la jauge redescend.
    updateFriction(player, active and diff or nil, active and pace or 0, minutes)
    if not active or pace == 0 or minutes <= 0 then
        return
    end
    drainEndurance(player, diff, pace, timeFactor)
    rollShoeLoss(player, shoe, diff, pace, minutes)
end

return MTIR
