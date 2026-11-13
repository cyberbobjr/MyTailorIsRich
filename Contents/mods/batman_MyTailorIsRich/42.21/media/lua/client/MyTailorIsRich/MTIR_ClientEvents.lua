-- ============================================================================
-- My Tailor Is Rich — événements côté client
--   * Escalade : demande de tirage des déchirures à l'autorité (commande
--     "climb"), puis, à la sortie d'une escalade réussie, trébuchement dû à
--     une tenue mal ajustée (mécanisme vanilla BumpedState, synchronisé en MP).
--   * Corde de draps et échelle (42.22 : ClimbState monte, ClimbDownState
--     descend) : accrocs et chaussure perdue tirés par l'autorité au départ ;
--     pied qui glisse à la sortie d'une échelle, pantalon trop grand qui glisse
--     sur la corde (trébuchement à l'arrivée par la fenêtre du haut).
--   * MP : stats dérivées du personnage local recalculées chaque minute,
--     pour l'affichage (l'autorité fait le même calcul de son côté).
--   * Transfert hors de l'inventaire : stats d'origine rendues au vêtement.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_ShoeEffects"
require "MyTailorIsRich/MTIR_ClientFx"
require "TimedActions/ISInventoryTransferAction"

local DISCOMFORT_TICKS = 30

if MTIR.clientEventsInstalled then
    return
end
MTIR.clientEventsInstalled = true

--- Corde de draps ou échelle, à la montée ou à la descente, sinon nil. Le jeu pose
--- l'échelle sur le personnage à l'entrée dans l'état (ClimbState.enter), avant
--- OnAIStateChange (StateMachine.changeState).
local function ropeOrLadderKind(player, state)
    if instanceof(state, "ClimbState") then
        return player:isClimbingLadder() and "ladder" or "rope"
    end
    if instanceof(state, "ClimbDownState") then
        return player:isClimbingDownLadder() and "ladderDown" or "ropeDown"
    end
    return nil
end

local function climbKind(player, state)
    local ropeKind = ropeOrLadderKind(player, state)
    if ropeKind then
        return ropeKind
    end
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
local ROPE_KINDS = { rope = true, ropeDown = true, ladder = true, ladderDown = true }
local LADDER_KINDS = { ladder = true, ladderDown = true }
-- Échelle : un pied qui rate un barreau, pas une chute : risque réduit de moitié.
local LADDER_TRIP_FACTOR = 0.5
-- Pantalon qui glisse sur la corde : risque réduit de moitié, à l'arrivée seulement.
local ROPE_PANTS_TRIP_FACTOR = 0.5
-- Phrase dite en trébuchant, par genre d'escalade (défaut : IGUI_MTIR_Say_ClimbTrip).
local TRIP_SAY = {
    ropeTop = "IGUI_MTIR_Say_RopePants",
    ladder = "IGUI_MTIR_Say_LadderSlip",
    ladderDown = "IGUI_MTIR_Say_LadderSlip",
}

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

local function wearsBelt(player)
    local worn = player:getWornItems()
    for i = 0, worn:size() - 1 do
        if MTIR.locKey(worn:getItemByIndex(i)) == "belt" then
            return true
        end
    end
    return false
end

--- Bas trop grands qui peuvent tomber (pantalon, jupe), sans ceinture.
local function loosePantsTripChance(player)
    if wearsBelt(player) then
        return 0
    end
    local playerSize = MTIR.getPlayerSize(player)
    local worn = player:getWornItems()
    local total = 0
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        if item and MTIR.canClothesHaveSize(item) and MTIR.canClothesDrop(item) then
            local diff = MTIR.getItemDiff(item, playerSize)
            if diff and diff > 0 then
                total = total + MTIR.getExtraTripChance(diff)
            end
        end
    end
    return total
end

--- Risque (en %) de trébucher en sortant d'une escalade réussie.
function MTIR.getClimbTripChance(player, kind)
    if kind == "ropeTop" then
        return loosePantsTripChance(player) * ROPE_PANTS_TRIP_FACTOR
    end
    if LADDER_KINDS[kind] then
        local socks = MTIR.isInSocksOnly(player) and MTIR.getExtraTripChance(1) or 0
        return (MTIR.getShoeTripChance(player) + socks) * LADDER_TRIP_FACTOR
    end
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

local function isRopeOrLadderState(state)
    return instanceof(state, "ClimbState") or instanceof(state, "ClimbDownState")
end

--- Tout état d'escalade dont la sortie peut finir en trébuchement.
local function isTrackedClimbState(state)
    return isClimbState(state) or isRopeOrLadderState(state) or instanceof(state, "ClimbThroughWindowState")
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
    if newState and isFallState(newState) then
        return
    end
    if newState and isTrackedClimbState(newState) then
        -- Haut de la corde : on entre par la fenêtre ; le pantalon se juge à l'arrivée.
        if pending.kind == "rope" and instanceof(newState, "ClimbThroughWindowState") then
            pendingClimbs[index] = { kind = "ropeTop", success = true }
        end
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
    character:Say(getText((TRIP_SAY[pending.kind] or "IGUI_MTIR_Say_ClimbTrip") .. tostring(ZombRand(2))))
    -- Chute : tirage de la perte de chaussure par l'autorité (solo : traité localement).
    sendClientCommand(character, MTIR.NET_MODULE, "fall", {})
end

local function onAIStateChange(character, newState, previousState)
    if not character or not instanceof(character, "IsoPlayer") or not character:isLocalPlayer() then
        return
    end
    if previousState and isTrackedClimbState(previousState) then
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
    if ROPE_KINDS[kind] then
        pendingClimbs[character:getPlayerNum()] = { kind = kind, success = true }
        -- Changement de sens sur l'échelle, corde bloquée en haut : même escalade,
        -- pas de nouveau tirage.
        if previousState and isRopeOrLadderState(previousState) then
            return
        end
        if isDebugEnabled() then
            print("[MTIR] climb " .. kind)
        end
        -- Solo : la commande est traitée localement par MTIR_Server (OnClientCommand).
        sendClientCommand(character, MTIR.NET_MODULE, "climb", { kind = kind })
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

--- Personnage neuf (solo comme client MP) : les tailles d'artisanat du précédent sont
--- oubliées. Un second joueur local qui arrive n'efface pas les choix du premier
--- (la table est commune aux joueurs locaux).
local function onCreatePlayer(playerNum, player)
    if player and playerNum == 0 then
        MTIR.forgetUICraftSizes()
    end
end

Events.OnAIStateChange.Add(onAIStateChange)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.EveryOneMinute.Add(onEveryOneMinute)
Events.OnTick.Add(onTick)
