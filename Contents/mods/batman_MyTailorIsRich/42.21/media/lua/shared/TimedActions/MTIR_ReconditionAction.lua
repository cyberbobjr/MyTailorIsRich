-- ============================================================================
-- My Tailor Is Rich — remettre un vêtement en état
--   MTIR_ReconditionAction      : fil + bandes du même tissu
--   MTIR_ReconditionSpareAction : fil + un exemplaire de rechange sacrifié
-- complete() tire le résultat et consomme côté serveur en MP.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"

-- ----------------------------------------------------------------------------
-- Tronc commun
-- ----------------------------------------------------------------------------

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

local function startCommon(self)
    self.item = MTIR.resolveItem(self.character, self.item)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_ReconditionClothes"))
    self.item:setJobDelta(0.0)
    self:setActionAnim("SewingCloth")
end

local function updateCommon(self)
    self.item:setJobDelta(self:getJobDelta())
end

local function stopCommon(self)
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

local function performCommon(self)
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

local function durationCommon(self)
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getReconditionDuration(self.item)
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

-- ----------------------------------------------------------------------------
-- Avec des bandes de tissu
-- ----------------------------------------------------------------------------

MTIR_ReconditionAction = ISBaseTimedAction:derive("MTIR_ReconditionAction")

function MTIR_ReconditionAction:isValid()
    if isClient() and self.started then
        return true
    end
    local character = self.character
    return MTIR.hasItem(character, self.item)
        and MTIR.hasItem(character, self.needle)
        and MTIR.hasItem(character, self.scissors)
        and MTIR.hasAllItems(character, self.threads)
        and MTIR.hasAllItems(character, self.strips)
end

MTIR_ReconditionAction.start = startCommon
MTIR_ReconditionAction.update = updateCommon
MTIR_ReconditionAction.stop = stopCommon
MTIR_ReconditionAction.perform = performCommon
MTIR_ReconditionAction.getDuration = durationCommon

function MTIR_ReconditionAction:complete()
    local item, character = self.item, self.character
    if not MTIR.canReconditionClothes(item) then
        return false
    end
    local threadUses = self.threadUses
    local stripUses = self.strips:size()
    local fx = { refresh = true }

    if ZombRandFloat(0, 1) < MTIR.getSuccessChanceForRecondition(item, character) then
        applyReconditionSuccess(item, character, MTIR.getPotentialRepairForRecondition(item, character))
    else
        applyReconditionFailure(item, character)
        threadUses = math.ceil(threadUses / 2)
        stripUses = math.ceil(stripUses / 2)
        fx.sound = "MTIR_ResizeFailed"
    end

    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.consumeItems(self.strips, stripUses)
    MTIR.updateOneClothes(item, character)
    MTIR.syncItem(character, item)
    MTIR.tell(character, fx)
    return true
end

function MTIR_ReconditionAction:new(character, item, needle, scissors, threads, strips, threadUses)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.strips = strips
    o.threadUses = threadUses
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end

-- ----------------------------------------------------------------------------
-- Avec un exemplaire de rechange
-- ----------------------------------------------------------------------------

MTIR_ReconditionSpareAction = ISBaseTimedAction:derive("MTIR_ReconditionSpareAction")

function MTIR_ReconditionSpareAction:isValid()
    if isClient() and self.started then
        return true
    end
    local character = self.character
    return MTIR.hasItem(character, self.item)
        and MTIR.hasItem(character, self.needle)
        and MTIR.hasItem(character, self.scissors)
        and MTIR.hasItem(character, self.spareItem)
        and MTIR.hasAllItems(character, self.threads)
end

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
    local item, character, spareItem = self.item, self.character, self.spareItem
    if not MTIR.canReconditionClothes(item) then
        return false
    end
    local threadUses = self.threadUses
    local fx = { refresh = true }

    if ZombRandFloat(0, 1) < MTIR.getSuccessChanceUsingSpare(item, character, spareItem) then
        applyReconditionSuccess(item, character, MTIR.getPotentialRepairUsingSpare(item, character, spareItem))
        MTIR.removeItem(spareItem)
    else
        applyReconditionFailure(item, character)
        threadUses = math.ceil(threadUses / 2)
        if not wearDownSpare(spareItem) then
            MTIR.syncItem(character, spareItem)
        end
        fx.sound = "MTIR_ResizeFailed"
    end

    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.updateOneClothes(item, character)
    MTIR.syncItem(character, item)
    MTIR.tell(character, fx)
    return true
end

function MTIR_ReconditionSpareAction:new(character, item, needle, scissors, threads, spareItem, threadUses)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.spareItem = spareItem
    o.threadUses = threadUses
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
