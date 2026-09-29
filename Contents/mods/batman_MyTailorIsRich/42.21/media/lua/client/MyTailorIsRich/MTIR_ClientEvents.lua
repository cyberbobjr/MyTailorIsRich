-- ============================================================================
-- My Tailor Is Rich — événements côté client
--   * Escalade : demande de tirage des déchirures à l'autorité (commande
--     "climb"), puis, à la sortie d'une escalade réussie, trébuchement dû à
--     une tenue mal ajustée (mécanisme vanilla BumpedState, synchronisé en MP).
--   * MP : stats dérivées du personnage local recalculées chaque minute,
--     pour l'affichage (l'autorité fait le même calcul de son côté).
--   * Transfert hors de l'inventaire : stats d'origine rendues au vêtement.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_ShoeEffects"
require "TimedActions/ISInventoryTransferAction"

local DISCOMFORT_TICKS = 30

if MTIR.clientEventsInstalled then
    return
end
MTIR.clientEventsInstalled = true

local function climbKind(player, state)
    if instanceof(state, "ClimbOverWallState") then
        return "wall"
    end
    if instanceof(state, "ClimbThroughWindowState") then
        return "window"
    end
    if instanceof(state, "ClimbOverFenceState") then
        if player:getVariableBoolean("VaultOverSprint") then
            return "fenceSprint"
        end
        if player:getVariableBoolean("VaultOverRun") then
            return "fenceRun"
        end
        return "fence"
    end
    return nil
end

-- Trébuchement à la réception, par genre d'escalade (course et sprint : valeurs
-- d'origine ; au pas, le jeu ne fait jamais tomber, d'où un risque réduit).
local WALK_TRIP_FACTOR = 0.4
local FENCE_KINDS = { fence = WALK_TRIP_FACTOR, fenceRun = 1, fenceSprint = 1 }

--- Bas ou tenue complète trop grands (diff > 0), ou tout vêtement trop serré (diff < 0).
local function clothesTripChance(player, tight)
    local playerSize = MTIR.getPlayerSize(player)
    local worn = player:getWornItems()
    local total = 0
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and MTIR.canClothesHaveSize(item) and (tight or MTIR.increasesTrip(item)) then
            local diff = MTIR.getItemDiff(item, playerSize)
            if diff and ((tight and diff < 0) or (not tight and diff > 0)) then
                total = total + MTIR.getExtraTripChance(math.abs(diff))
            end
        end
    end
    return total
end

--- Risque (en %) de trébucher en sortant d'une escalade réussie.
function MTIR.getClimbTripChance(player, kind)
    if kind == "wall" then
        return clothesTripChance(player, true) + MTIR.getShoeTripChance(player)
    end
    local factor = FENCE_KINDS[kind]
    if not factor then
        return 0
    end
    return (clothesTripChance(player, false) + MTIR.getShoeTripChance(player)) * factor
end

--- Même séquence que le trébuchement vanilla d'un personnage ivre (IsoPlayer.adjustMovementForDrunks) :
--- l'état BumpedState qui en résulte est transmis aux autres joueurs par le jeu.
local function trip(player)
    player:setVariable("BumpDone", false)
    player:clearVariable("BumpFallType")
    player:setBumpType("trippingFromSprint")
    player:setBumpFall(true)
    player:setBumpFallType(ZombRand(5) == 0 and "pushedFront" or "pushedBehind")
    player:reportEvent("wasBumped")
end

--- Chute, trébuchement, renversement par un zombie, chute d'une hauteur.
local function isFallState(state)
    return instanceof(state, "PlayerFallDownState")
        or instanceof(state, "PlayerKnockedDown")
        or instanceof(state, "PlayerFallingState")
end

local function isClimbState(state)
    return instanceof(state, "ClimbOverFenceState") or instanceof(state, "ClimbOverWallState")
end

-- Escalade en cours par joueur local : genre, et issue vanilla réussie ou non.
local pendingClimbs = {}

--- Sortie d'une escalade réussie : tirage du trébuchement dû à la tenue.
--- On ne réécrit pas l'issue de l'escalade : le paquet d'état MP est déjà
--- construit quand OnAIStateChange part, les autres joueurs verraient une réussite.
local function onClimbExit(character, newState)
    local index = character:getPlayerNum()
    local pending = pendingClimbs[index]
    pendingClimbs[index] = nil
    if not pending or not pending.success or character:isDead() then
        return
    end
    if newState and (isClimbState(newState) or isFallState(newState)) then
        return
    end
    local chance = MTIR.getClimbTripChance(character, pending.kind)
    if isDebugEnabled() then
        print(string.format("[MTIR] climb exit %s, trip chance %.1f", pending.kind, chance) .. " %")
    end
    if chance <= 0 or ZombRandFloat(0, 100) >= chance then
        return
    end
    trip(character)
    character:Say(getText("IGUI_MTIR_Say_ClimbTrip" .. tostring(ZombRand(2))))
    -- Chute : tirage de la perte de chaussure par l'autorité (solo : traité localement).
    sendClientCommand(character, MTIR.NET_MODULE, "fall", {})
end

local function onAIStateChange(character, newState, previousState)
    if not character or not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then
        return
    end
    if previousState and isClimbState(previousState) then
        onClimbExit(character, newState)
    end
    if not newState then
        return
    end
    if isFallState(newState) then
        if isDebugEnabled() then
            print("[MTIR] fall state " .. tostring(newState))
        end
        -- Solo : la commande est traitée localement par MTIR_Server (OnClientCommand).
        sendClientCommand(character, MTIR.NET_MODULE, "fall", {})
        return
    end
    local kind = climbKind(character, newState)
    if not kind then
        return
    end
    -- L'issue est fixée à l'entrée dans l'état (vanilla) : "fall" pour une clôture
    -- ratée, "fail" pour un mur ou un grillage lâché.
    local outcome = character:getVariableString("ClimbFenceOutcome")
    local fell = outcome == "fall" or (kind == "wall" and outcome == "fail")
    if kind ~= "window" then
        -- Seule une escalade réussie (ni chute, ni corde, ni obstacle) peut finir en trébuchement.
        pendingClimbs[character:getPlayerNum()] = { kind = kind, success = outcome == "success" }
    end
    if isDebugEnabled() then
        print(string.format("[MTIR] climb %s, outcome %s", kind, tostring(outcome)))
    end
    -- Solo : la commande est traitée localement par MTIR_Server (OnClientCommand).
    sendClientCommand(character, MTIR.NET_MODULE, "climb", { kind = kind, fell = fell })
end

local function onEveryOneMinute()
    if not isClient() then
        return
    end
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isLocalPlayer() and not player:isDead() then
            MTIR.applyDerivedStats(player)
        end
    end
end

local transferPerform = ISInventoryTransferAction.perform
function ISInventoryTransferAction:perform()
    local item = self.item
    local leavesPlayer = item and instanceof(item, "Clothing")
        and self.srcContainer and self.srcContainer == self.character:getInventory()
    local result = transferPerform(self)
    if leavesPlayer then
        MTIR.updateOneClothes(item, self.character)
    end
    return result
end

--- Client MP : plancher d'inconfort local, pour que l'humeur ne clignote pas
--- entre deux synchronisations du serveur (qui reste l'autorité).
local discomfortTicks = 0

local function forEachLocalPlayer(callback)
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isLocalPlayer() and not player:isDead() then
            callback(player)
        end
    end
end

local function onTick()
    if not isClient() then
        return
    end
    discomfortTicks = discomfortTicks + 1
    if discomfortTicks >= DISCOMFORT_TICKS then
        discomfortTicks = 0
        MTIR.resetDiscomfortFloors()
        forEachLocalPlayer(MTIR.refreshDiscomfortFloor)
    end
    -- Sans chaussure mal ajustée, la boucle par tick s'arrête là.
    if MTIR.hasDiscomfortFloors() then
        forEachLocalPlayer(MTIR.enforceDiscomfortFloor)
    end
end

Events.OnAIStateChange.Add(onAIStateChange)
Events.EveryOneMinute.Add(onEveryOneMinute)
Events.OnTick.Add(onTick)
