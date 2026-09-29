-- ============================================================================
-- My Tailor Is Rich — besoins des retouches, remises en état et entretiens
--
-- Mêmes formules que MTIR_Core.lua, avec les bonus de travail (`mods`) :
--   MTIR.SEW_BY_HAND à la main, MTIR.getMachineMods(machine) sur une machine.
--   * durée × durationFactor ;
--   * niveau effectif = Couture + levelBonus (seuil ET chance) ;
--   * chance − successMalus (machine usée), bornée entre 0 et 1 ;
--   * fil × threadFactor (arrondi au-dessus, au moins 1).
-- Partagé : le menu contextuel, le panneau de la machine ET les actions
-- (isValid/complete sur l'autorité) s'appuient sur les mêmes fonctions.
-- ============================================================================

require "MyTailorIsRich/MTIR_SewingMachine"
require "MyTailorIsRich/MTIR_MachineSound"

local PAPERCLIP_TYPE = "Base.Paperclip"
local MAINTENANCE_XP = 5

-- ----------------------------------------------------------------------------
-- Formules avec bonus
-- ----------------------------------------------------------------------------

local function modsOrHand(mods)
    return mods or MTIR.SEW_BY_HAND
end

--- Fil avec bonus : base × threadFactor, arrondi au-dessus, au moins 1.
function MTIR.applyThreadFactor(base, mods)
    return math.max(1, math.ceil(base * modsOrHand(mods).threadFactor))
end

--- Chance bornée entre 0 et 1, après le malus d'une machine usée.
function MTIR.applySuccessMalus(chance, mods)
    return math.max(0, math.min(1, chance - (modsOrHand(mods).successMalus or 0)))
end

--- Niveau de Couture effectif (compétence + bonus de la machine).
function MTIR.getEffectiveTailoring(player, mods)
    return player:getPerkLevel(Perks.Tailoring) + modsOrHand(mods).levelBonus
end

--- Type et nombre de matériaux d'une retouche : bandes du tissu (agrandir) ou trombones (rétrécir).
function MTIR.getResizeMaterial(item, upsize)
    if upsize then
        return MTIR.getStripType(MTIR.getClothesFabricType(item)), MTIR.getRequiredStripCount(item)
    end
    return PAPERCLIP_TYPE, MTIR.getRequiredPaperclip(item)
end

function MTIR.getResizeThreadUses(item, mods)
    return MTIR.applyThreadFactor(MTIR.getRequiredThreadCount(item), mods)
end

function MTIR.getResizeDurationWith(item, upsize, mods)
    return math.max(1, MTIR.getChangeDuration(item, upsize) * modsOrHand(mods).durationFactor)
end

--- Taille visée par une retouche, ou nil (taille inconnue, déjà retouché, bout de gamme).
function MTIR.getResizeTarget(item, upsize)
    local data = MTIR.getData(item)
    if item:isBroken() or not data or not data.size or not data.reveal or data.resized ~= 0 then
        return nil
    end
    return upsize and MTIR.getNextSize(data.size) or MTIR.getPrevSize(data.size)
end

function MTIR.getReconditionThreadUses(item, mods)
    return MTIR.applyThreadFactor(MTIR.getRequiredThreadToRecondition(item), mods)
end

function MTIR.getReconditionDurationWith(item, mods)
    return math.max(1, MTIR.getReconditionDuration(item) * modsOrHand(mods).durationFactor)
end

--- Vrai si `spareItem` peut servir d'exemplaire de rechange pour `item`.
--- Exemplaire de rechange : même type, autre objet, et ni porté ni tenu en main
--- (sinon removeItem le sacrifierait sans le retirer du corps).
function MTIR.isValidSpare(item, spareItem)
    return spareItem ~= nil and item ~= nil and spareItem:getID() ~= item:getID()
        and spareItem:getFullType() == item:getFullType()
        and not spareItem:isEquipped()
end

-- ----------------------------------------------------------------------------
-- Collecte dans l'inventaire (sacs compris)
-- ----------------------------------------------------------------------------

--- Fil : utilisations requises, restantes et liste suffisante (ArrayList ou nil).
local function collectThreads(inventory, required)
    local allThreads = inventory:getItemsFromType("Thread", true)
    return MTIR.getRemainingThread(allThreads), MTIR.pickThreads(allThreads, required)
end

--- Outils communs et dé à coudre (seulement exigé à la main).
local function baseRequirements(player, mods, requiredThread)
    local inventory = player:getInventory()
    local remaining, threads = collectThreads(inventory, requiredThread)
    local needsThimble = MTIR.needsThimble(mods)
    return {
        mods = mods,
        machine = mods.machine,
        needle = inventory:getFirstEvalRecurse(MTIR.predicateNeedle),
        scissors = inventory:getFirstEvalRecurse(MTIR.predicateScissors),
        requiredThread = requiredThread,
        remainingThread = remaining,
        threads = threads,
        tailoring = player:getPerkLevel(Perks.Tailoring),
        effectiveLevel = MTIR.getEffectiveTailoring(player, mods),
        needsThimble = needsThimble,
        thimble = needsThimble and MTIR.findThimble(player) or nil,
    }
end

local function toolsReady(req)
    return req.needle ~= nil and req.scissors ~= nil and req.threads ~= nil
        and (not req.needsThimble or req.thimble ~= nil)
end

-- ----------------------------------------------------------------------------
-- Retouche
-- ----------------------------------------------------------------------------

--- Tout ce qu'il faut pour agrandir (upsize = true) ou rétrécir un vêtement.
--- mods : MTIR.SEW_BY_HAND (défaut) ou MTIR.getMachineMods(machine).
--- Champs rendus :
---   mods, machine (objet ou nil) ;
---   needle, scissors : outils trouvés (InventoryItem ou nil) ;
---   requiredThread, remainingThread (utilisations), threads (ArrayList choisie ou nil) ;
---   materialType (fullType), requiredMaterial, availableMaterial (nombres),
---   materials (ArrayList choisie ou nil) ;
---   tailoring (compétence), effectiveLevel (avec bonus), requiredLevel ;
---   targetSize (entrée de MTIR.SIZES, ou nil si la retouche n'est pas possible) ;
---   success (0..1, malus de machine usée compris) ;
---   needsThimble (booléen), thimble (InventoryItem ou nil) ;
---   duration (unités d'action), ready (tout est réuni).
function MTIR.getResizeRequirements(player, item, upsize, mods)
    mods = modsOrHand(mods)
    local req = baseRequirements(player, mods, MTIR.getResizeThreadUses(item, mods))
    local materialType, requiredMaterial = MTIR.getResizeMaterial(item, upsize)
    local allMaterials = materialType and player:getInventory():getItemsFromFullType(materialType, true) or nil
    req.materialType = materialType
    req.requiredMaterial = requiredMaterial
    req.availableMaterial = allMaterials and allMaterials:size() or 0
    req.materials = allMaterials and MTIR.pickItems(allMaterials, requiredMaterial) or nil
    req.requiredLevel = MTIR.getRequiredLevelToChange(item, upsize)
    req.targetSize = MTIR.getResizeTarget(item, upsize)
    req.success = MTIR.applySuccessMalus(MTIR.getSuccessChanceForChange(req.effectiveLevel, req.requiredLevel), mods)
    req.duration = MTIR.getResizeDurationWith(item, upsize, mods)
    req.ready = toolsReady(req) and req.materials ~= nil and req.targetSize ~= nil
        and req.effectiveLevel >= req.requiredLevel
    return req
end

-- ----------------------------------------------------------------------------
-- Remise en état
-- ----------------------------------------------------------------------------

--- Bandes de tissu : matériaux, sans seuil de niveau (comportement d'origine).
local function stripRequirements(player, item, req)
    local stripType = MTIR.getStripType(MTIR.getClothesFabricType(item))
    local allStrips = stripType and player:getInventory():getItemsFromFullType(stripType, true) or nil
    req.materialType = stripType
    req.requiredMaterial = MTIR.getRequiredStripToRecondition(item)
    req.availableMaterial = allStrips and allStrips:size() or 0
    req.materials = allStrips and MTIR.pickItems(allStrips, req.requiredMaterial) or nil
    req.potential = math.max(0, math.min(1, MTIR.getPotentialRepairForRecondition(item, player, req.mods.levelBonus)))
    req.success = MTIR.applySuccessMalus(MTIR.getSuccessChanceForRecondition(item, player, req.mods.levelBonus), req.mods)
    req.ready = toolsReady(req) and req.materials ~= nil
end

--- Exemplaire de rechange : niveau requis, sacrifié en cas de réussite.
local function spareRequirements(player, item, spareItem, req)
    req.materialType = item:getFullType()
    req.requiredMaterial = 1
    req.availableMaterial = 1
    req.materials = ArrayList.new()
    req.materials:add(spareItem)
    local valid = MTIR.isValidSpare(item, spareItem)
    local bonus = req.mods.levelBonus
    req.potential = (valid and req.hasLevel) and MTIR.getPotentialRepairUsingSpare(item, player, spareItem, bonus) or 0
    req.success = (valid and req.hasLevel)
        and MTIR.applySuccessMalus(MTIR.getSuccessChanceUsingSpare(item, player, spareItem, bonus), req.mods) or 0
    req.ready = toolsReady(req) and valid and req.hasLevel
end

--- Tout ce qu'il faut pour remettre un vêtement en état.
--- spareItem : exemplaire de rechange du même type, ou nil pour les bandes de tissu.
--- Champs rendus : ceux de MTIR.getResizeRequirements (sauf targetSize), plus :
---   spareItem (ou nil) ; materials : bandes choisies (ArrayList ou nil), ou, avec
---   un exemplaire de rechange, une ArrayList qui ne contient que lui (affichage :
---   l'action le reçoit à part) ; materialType : type des bandes (nil si le tissu
---   n'en a pas) ou fullType du vêtement ;
---   hasLevel (niveau effectif ≥ requis ; bloquant seulement avec un exemplaire) ;
---   potential (0..1 : part de l'état manquant regagnée en cas de réussite) ;
---   repairedTimes (réparations déjà faites sur le vêtement) ;
---   canRecondition (vêtement concerné et abîmé).
function MTIR.getReconditionRequirements(player, item, mods, spareItem)
    mods = modsOrHand(mods)
    local req = baseRequirements(player, mods, MTIR.getReconditionThreadUses(item, mods))
    req.spareItem = spareItem
    req.requiredLevel = MTIR.getRequiredLevelToRecondition(item)
    req.hasLevel = req.effectiveLevel >= req.requiredLevel
    req.repairedTimes = MTIR.getRepairedTimes(item)
    req.duration = MTIR.getReconditionDurationWith(item, mods)
    req.canRecondition = MTIR.canReconditionClothes(item) and item:getCondition() < item:getConditionMax()
    if spareItem then
        spareRequirements(player, item, spareItem, req)
    else
        stripRequirements(player, item, req)
    end
    req.ready = req.ready and req.canRecondition
    return req
end

-- ----------------------------------------------------------------------------
-- Travail sur machine, commun aux trois actions (couture, retouche, remise en état)
-- `self` est l'action ; `self.machinePos` vaut "x,y,z" ou "" (à la main).
-- ----------------------------------------------------------------------------

-- Intervalle du bruit, en unités d'action : ≈ 2 s au rythme normal
-- (GameTime.getMultiplier ≈ 0,8 par image à 60 images/s).
local NOISE_INTERVAL = 96

local MachineWork = {}
MTIR.MachineWork = MachineWork

--- Machine désignée par l'action, ou nil (à la main, ou machine introuvable).
function MachineWork.machine(self)
    if self.machinePos == nil or self.machinePos == "" then
        return nil
    end
    return MTIR.machineFromPos(self.machinePos)
end

--- Bonus servant à la durée : sans test de distance (le client calcule la durée
--- avant d'avoir marché jusqu'à la machine) ; isValid/complete revérifient tout.
function MachineWork.durationMods(self)
    local machine = MachineWork.machine(self)
    return machine and MTIR.getMachineMods(machine) or MTIR.SEW_BY_HAND
end

--- Se tourner vers la machine avant de commencer (modèle ISFixGenerator:waitToStart).
function MachineWork.waitToStart(self)
    local machine = MachineWork.machine(self)
    if not machine then
        return false
    end
    self.character:faceThisObject(machine)
    return self.character:shouldBeTurning()
end

--- Client : son de la machine (en boucle, posé sur la machine et relayé aux
--- autres joueurs, MTIR_MachineSound) ou son de couture à la main (handSound,
--- facultatif), premier bruit.
function MachineWork.start(self, handSound)
    local machine = MachineWork.machine(self)
    self.workMachine = machine
    self.noiseTimer = 0
    if machine then
        self.character:faceThisObject(machine)
        MTIR.emitMachineNoise(self.character, machine)
        self.machineSound = MTIR.MachineSound.start(self.character, machine)
    end
    if not self.machineSound and handSound then
        self.sound = self.character:getEmitter():playSound(handSound)
    end
end

--- Client : face à la machine et bruit qui attire les zombies toutes les ~2 s.
function MachineWork.update(self)
    local machine = self.workMachine
    if not machine then
        return
    end
    self.character:faceThisObject(machine)
    self.noiseTimer = (self.noiseTimer or 0) + getGameTime():getMultiplier()
    if self.noiseTimer >= NOISE_INTERVAL then
        self.noiseTimer = 0
        MTIR.emitMachineNoise(self.character, machine)
        MTIR.MachineSound.keepAlive(self.machineSound)
    end
end

function MachineWork.stopSound(self)
    if self.machineSound then
        MTIR.MachineSound.stop(self.machineSound)
        self.machineSound = nil
    elseif self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

--- Autorité, avant l'issue du travail : vrai si l'aiguille va casser (sans effet ;
--- le travail compte alors comme un échec). Toujours faux à la main.
function MachineWork.rollBreak(mods)
    return mods ~= nil and mods.machine ~= nil and MTIR.rollNeedleBreak(mods.machine)
end

--- Autorité, une fois l'issue décidée et le résultat créé : usure de la machine
--- et, si `broke`, retrait de l'aiguille utilisée.
function MachineWork.applyWear(self, mods, broke)
    if not mods or not mods.machine then
        return
    end
    MTIR.wearMachine(mods.machine)
    if broke and self.needle then
        self.character:removeFromHands(self.needle)
        MTIR.removeItem(self.needle)
    end
end

-- ----------------------------------------------------------------------------
-- Entretien de la machine
-- ----------------------------------------------------------------------------

function MTIR.getMaintenanceXp()
    return MAINTENANCE_XP
end

--- Besoins d'un entretien. Champs rendus :
---   enabled (option EnableMachineMaintenance), condition (0..100), gain (points regagnés),
---   perk (Perks.Electricity ou Perks.Mechanics), perkLevel ;
---   screwdriver (InventoryItem ou nil), oil (InventoryItem ou nil : huile alimentaire
---   du jeu, tag base:oil, avec au moins requiredOilUses utilisations),
---   requiredOilUses (MTIR.MAINTENANCE_OIL_USES) ; duration ; ready.
function MTIR.getMaintenanceRequirements(player, machine)
    local inventory = player:getInventory()
    local perk = MTIR.getMaintenancePerk(machine)
    local req = {
        enabled = MTIR.isMaintenanceEnabled(),
        condition = MTIR.getMachineCondition(machine),
        gain = MTIR.getMaintenanceGain(player, machine),
        perk = perk,
        perkLevel = player:getPerkLevel(perk),
        screwdriver = inventory:getFirstEvalRecurse(MTIR.predicateScrewdriver),
        oil = inventory:getFirstEvalRecurse(MTIR.predicateMaintenanceOil),
        requiredOilUses = MTIR.MAINTENANCE_OIL_USES,
        duration = MTIR.getMaintenanceDuration(),
    }
    req.ready = req.enabled and MTIR.isSewingMachine(machine) and req.condition < 100
        and req.screwdriver ~= nil and req.oil ~= nil
    return req
end

return MTIR
