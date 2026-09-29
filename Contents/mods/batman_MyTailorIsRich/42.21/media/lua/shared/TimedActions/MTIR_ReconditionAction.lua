-- ============================================================================
-- My Tailor Is Rich — remettre un vêtement en état
--   MTIR_ReconditionAction      : fil + bandes du même tissu
--   MTIR_ReconditionSpareAction : fil + un exemplaire de rechange sacrifié
-- complete() tire le résultat et consomme côté serveur en MP.
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `threads`
-- et `strips` sont des ArrayList ; `machinePos` vaut "x,y,z" sur une machine à
-- coudre, "" à la main. Le fil nécessaire est recalculé par l'autorité (bonus
-- de la machine compris), jamais reçu du client.
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, doublons, types, outils en main).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Alterations"

-- ----------------------------------------------------------------------------
-- Tronc commun
-- ----------------------------------------------------------------------------

local function startCommon(self)
    self.item = MTIR.resolveItem(self.character, self.item)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_ReconditionClothes"))
    self.item:setJobDelta(0.0)
    self:setActionAnim("SewingCloth")
    -- À la main : aucun son (comportement d'origine) ; sur machine : son de la machine.
    MTIR.MachineWork.start(self, nil)
end

local function updateCommon(self)
    self.item:setJobDelta(self:getJobDelta())
    MTIR.MachineWork.update(self)
end

local function stopCommon(self)
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

local function performCommon(self)
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

local function durationCommon(self)
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getReconditionDurationWith(self.item, MTIR.MachineWork.durationMods(self))
end

local function waitCommon(self)
    return MTIR.MachineWork.waitToStart(self)
end

--- Vérifications communes (autorité et client avant le début) : bonus ou nil.
local function commonMods(self)
    local item, character = self.item, self.character
    if not MTIR.canReconditionClothes(item) or item:getCondition() >= item:getConditionMax() then
        return nil
    end
    if not self.needle or not self.scissors
        or not MTIR.predicateNeedle(self.needle) or not MTIR.predicateScissors(self.scissors) then
        return nil
    end
    local mods = MTIR.resolveWorkMods(character, self.machinePos, nil)
    if not mods or not MTIR.hasThimbleFor(character, mods) then
        return nil
    end
    if MTIR.getRemainingThread(self.threads) < MTIR.getReconditionThreadUses(item, mods) then
        return nil
    end
    return mods
end

--- Possession commune : vêtement, aiguille et ciseaux, fil sans doublon.
local function ownsCommon(self)
    local character = self.character
    return MTIR.hasItem(character, self.item)
        and MTIR.hasItem(character, self.needle)
        and MTIR.hasItem(character, self.scissors)
        and MTIR.hasThreads(character, self.threads)
end

--- Réussite commune : gain d'état, compteur de réparations, XP Couture et Entretien.
local function applyReconditionSuccess(item, character, potentialRepair)
    local conditionGain = math.ceil(potentialRepair * (item:getConditionMax() - item:getCondition()))
    local repairedTimes = MTIR.getRepairedTimes(item)
    addXp(character, Perks.Tailoring, MTIR.getTailoringXpForRecondition(item, true))
    addXp(character, Perks.Maintenance, MTIR.getMaintenanceXpForRecondition(conditionGain, repairedTimes))
    item:setCondition(item:getCondition() + conditionGain)
    item:setHaveBeenRepaired(item:getHaveBeenRepaired() + 1)
end

--- Échec commun : perte d'état possible, XP réduite.
local function applyReconditionFailure(item, character)
    if ZombRandFloat(0, 1) < MTIR.opt("ChanceToDegradeOnFailure") then
        item:setCondition(item:getCondition() - 1)
    end
    addXp(character, Perks.Tailoring, MTIR.getTailoringXpForRecondition(item, false))
end

--- Fin commune, une fois l'issue décidée : usure de la machine, fil,
--- statistiques, synchronisation et retour au client.
local function finishCommon(self, mods, broke, threadUses, fx)
    MTIR.MachineWork.applyWear(self, mods, broke)
    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.updateOneClothes(self.item, self.character)
    MTIR.syncItem(self.character, self.item)
    MTIR.tell(self.character, fx)
end

local function failureFx(broke)
    return { refresh = true, sound = "MTIR_ResizeFailed", say = broke and { key = "IGUI_MTIR_Say_NeedleBroke" } or nil }
end

-- ----------------------------------------------------------------------------
-- Avec des bandes de tissu
-- ----------------------------------------------------------------------------

MTIR_ReconditionAction = ISBaseTimedAction:derive("MTIR_ReconditionAction")

--- Bandes du tissu du vêtement, en nombre suffisant.
local function stripsOk(self)
    local stripType = MTIR.getStripType(MTIR.getClothesFabricType(self.item))
    local strips = self.strips
    if not stripType or not strips or strips:size() < MTIR.getRequiredStripToRecondition(self.item) then
        return false
    end
    for i = 0, strips:size() - 1 do
        if strips:get(i):getFullType() ~= stripType then
            return false
        end
    end
    return true
end

--- Validation partagée par isValid et complete : bonus de travail, ou nil.
local function validateStrips(self)
    if not ownsCommon(self) or not MTIR.hasAllItems(self.character, self.strips) or not stripsOk(self) then
        return nil
    end
    return commonMods(self)
end

function MTIR_ReconditionAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validateStrips(self) ~= nil
end

MTIR_ReconditionAction.waitToStart = waitCommon
MTIR_ReconditionAction.start = startCommon
MTIR_ReconditionAction.update = updateCommon
MTIR_ReconditionAction.stop = stopCommon
MTIR_ReconditionAction.perform = performCommon
MTIR_ReconditionAction.getDuration = durationCommon

function MTIR_ReconditionAction:complete()
    local mods = validateStrips(self)
    if not mods then
        return false
    end
    local item, character = self.item, self.character
    local threadUses = MTIR.getReconditionThreadUses(item, mods)
    local stripUses = MTIR.getRequiredStripToRecondition(item)
    local fx = { refresh = true }
    local broke = MTIR.MachineWork.rollBreak(mods)
    local chance = MTIR.applySuccessMalus(MTIR.getSuccessChanceForRecondition(item, character, mods.levelBonus), mods)

    if not broke and ZombRandFloat(0, 1) < chance then
        applyReconditionSuccess(item, character, MTIR.getPotentialRepairForRecondition(item, character, mods.levelBonus))
    else
        applyReconditionFailure(item, character)
        threadUses = math.ceil(threadUses / 2)
        stripUses = math.ceil(stripUses / 2)
        fx = failureFx(broke)
    end

    MTIR.consumeItems(self.strips, stripUses)
    finishCommon(self, mods, broke, threadUses, fx)
    return true
end

--- machinePos : "x,y,z" d'une machine à coudre (MTIR.encodeMachinePos), ou nil/"" à la main.
function MTIR_ReconditionAction:new(character, item, needle, scissors, threads, strips, machinePos)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.strips = strips
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    -- Sur une machine, s'éloigner interrompt le travail ; à la main, on coud en marchant.
    o.stopOnWalk = o.machinePos ~= ""
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end

-- ----------------------------------------------------------------------------
-- Avec un exemplaire de rechange
-- ----------------------------------------------------------------------------

MTIR_ReconditionSpareAction = ISBaseTimedAction:derive("MTIR_ReconditionSpareAction")

--- Validation partagée par isValid et complete : exemplaire possédé, du même
--- type (MTIR.isValidSpare) et niveau effectif suffisant ; bonus ou nil.
local function validateSpare(self)
    if not ownsCommon(self) or not MTIR.hasItem(self.character, self.spareItem)
        or not MTIR.isValidSpare(self.item, self.spareItem) then
        return nil
    end
    local mods = commonMods(self)
    if not mods or MTIR.getEffectiveTailoring(self.character, mods) < MTIR.getRequiredLevelToRecondition(self.item) then
        return nil
    end
    return mods
end

function MTIR_ReconditionSpareAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validateSpare(self) ~= nil
end

MTIR_ReconditionSpareAction.waitToStart = waitCommon
MTIR_ReconditionSpareAction.start = startCommon
MTIR_ReconditionSpareAction.update = updateCommon
MTIR_ReconditionSpareAction.stop = stopCommon
MTIR_ReconditionSpareAction.perform = performCommon
MTIR_ReconditionSpareAction.getDuration = durationCommon

--- Échec : l'exemplaire de rechange s'abîme, parfois jusqu'à disparaître.
local function wearDownSpare(spareItem)
    while ZombRand(2) == 0 do
        if spareItem:getCondition() > 0 then
            spareItem:setCondition(spareItem:getCondition() - 1)
        else
            MTIR.removeItem(spareItem)
            return true
        end
    end
    return false
end

function MTIR_ReconditionSpareAction:complete()
    local mods = validateSpare(self)
    if not mods then
        return false
    end
    local item, character, spareItem = self.item, self.character, self.spareItem
    local threadUses = MTIR.getReconditionThreadUses(item, mods)
    local fx = { refresh = true }
    local broke = MTIR.MachineWork.rollBreak(mods)
    local chance = MTIR.applySuccessMalus(MTIR.getSuccessChanceUsingSpare(item, character, spareItem, mods.levelBonus), mods)

    if not broke and ZombRandFloat(0, 1) < chance then
        applyReconditionSuccess(item, character,
            MTIR.getPotentialRepairUsingSpare(item, character, spareItem, mods.levelBonus))
        MTIR.removeItem(spareItem)
    else
        applyReconditionFailure(item, character)
        threadUses = math.ceil(threadUses / 2)
        if not wearDownSpare(spareItem) then
            MTIR.syncItem(character, spareItem)
        end
        fx = failureFx(broke)
    end

    finishCommon(self, mods, broke, threadUses, fx)
    return true
end

--- machinePos : "x,y,z" d'une machine à coudre (MTIR.encodeMachinePos), ou nil/"" à la main.
function MTIR_ReconditionSpareAction:new(character, item, needle, scissors, threads, spareItem, machinePos)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.spareItem = spareItem
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    -- Sur une machine, s'éloigner interrompt le travail ; à la main, on coud en marchant.
    o.stopOnWalk = o.machinePos ~= ""
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
