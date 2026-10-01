-- ============================================================================
-- My Tailor Is Rich — ranger un patron dans un classeur à patrons
-- Le patron disparaît de l'inventaire : il devient une entrée de la ModData du
-- classeur (MTIR_PatternBinder.lua), avec toutes ses données. complete() agit
-- sur l'autorité (serveur en MP) puis synchronise le classeur (syncItemFields).
--
-- Paramètres réseau : champs nommés comme les paramètres de new(). Le serveur
-- n'appelle jamais isValid (NetTimedAction.isValid) : complete() refait toute
-- la validation (possession des deux objets, types, place libre).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_PatternBinder"

MTIR_BinderStoreAction = ISBaseTimedAction:derive("MTIR_BinderStoreAction")

local DURATION = 40

--- Validation partagée par isValid et complete.
local function validate(self)
    local character = self.character
    return MTIR.isBinder(self.binder) and MTIR.hasItem(character, self.binder)
        and MTIR.hasItem(character, self.pattern) and not MTIR.sameItem(self.binder, self.pattern)
        and MTIR.getPatternData(self.pattern) ~= nil and not MTIR.isBinderFull(self.binder)
end

function MTIR_BinderStoreAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self)
end

function MTIR_BinderStoreAction:start()
    self.binder = MTIR.resolveItem(self.character, self.binder)
    self.pattern = MTIR.resolveItem(self.character, self.pattern)
    self.started = true
    self.binder:setJobType(getText("IGUI_MTIR_JobType_BinderStore"))
    self.binder:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self.character:getEmitter():playSound("MapAddNote")
end

function MTIR_BinderStoreAction:update()
    self.binder:setJobDelta(self:getJobDelta())
end

function MTIR_BinderStoreAction:stop()
    self.started = false
    self.binder:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_BinderStoreAction:perform()
    self.started = false
    self.binder:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_BinderStoreAction:complete()
    if not validate(self) then
        return false
    end
    if not MTIR.storePatternInBinder(self.character, self.binder, self.pattern) then
        return false
    end
    MTIR.tell(self.character, { refresh = true })
    return true
end

function MTIR_BinderStoreAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return math.max(1, DURATION * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR_BinderStoreAction:new(character, binder, pattern)
    local o = ISBaseTimedAction.new(self, character)
    o.binder = binder
    o.pattern = pattern
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
