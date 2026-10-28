-- ============================================================================
-- My Tailor Is Rich — sortir un patron d'un classeur à patrons
-- complete() recrée sur l'autorité (serveur en MP) l'objet patron rangé sous
-- `entryId` (même type, même nom, même ModData), l'ajoute à l'inventaire
-- (sendAddItemToContainer) puis synchronise le classeur (syncItemFields).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `entryId`
-- est l'id stable de l'entrée (MTIR_PatternBinder.lua), jamais sa place dans la
-- liste. Le serveur n'appelle jamais isValid : complete() revérifie tout.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_ActionBase"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_PatternBinder"

MTIR_BinderTakeAction = ISBaseTimedAction:derive("MTIR_BinderTakeAction")

local DURATION = 40

local function validate(self)
    return MTIR.isBinder(self.binder) and MTIR.hasItem(self.character, self.binder)
        and MTIR.getBinderEntryData(self.binder, self.entryId) ~= nil
end

function MTIR_BinderTakeAction:isValid()
    return MTIR.Action.startedOnClient(self) or validate(self)
end

function MTIR_BinderTakeAction:start()
    self.binder = MTIR.resolveItem(self.character, self.binder)
    MTIR.Action.startProgress(self, self.binder, "IGUI_MTIR_JobType_BinderTake")
    self:setActionAnim(CharacterActionAnims.Craft)
    self.character:getEmitter():playSound("MapAddNote")
end

function MTIR_BinderTakeAction:update()
    MTIR.Action.updateProgress(self, self.binder)
end

function MTIR_BinderTakeAction:stop()
    MTIR.Action.stop(self, self.binder)
end

function MTIR_BinderTakeAction:perform()
    MTIR.Action.perform(self, self.binder)
end

function MTIR_BinderTakeAction:complete()
    if not validate(self) then
        return false
    end
    local item = MTIR.takePatternFromBinder(self.character, self.binder, self.entryId)
    if not item then
        return false
    end
    MTIR.tell(self.character, { refresh = true, halo = { itemType = item:getFullType(), good = true } })
    return true
end

function MTIR_BinderTakeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return math.max(1, DURATION * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR_BinderTakeAction:new(character, binder, entryId)
    local o = ISBaseTimedAction.new(self, character)
    o.binder = binder
    o.entryId = tonumber(entryId)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
