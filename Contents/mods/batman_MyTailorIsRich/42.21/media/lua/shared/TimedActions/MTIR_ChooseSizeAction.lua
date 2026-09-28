-- ============================================================================
-- My Tailor Is Rich — fixer la taille d'un vêtement fabriqué sans taille
-- L'original écrivait la ModData côté client ; ici complete() le fait sur
-- l'autorité puis synchronise.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"

MTIR_ChooseSizeAction = ISBaseTimedAction:derive("MTIR_ChooseSizeAction")

local CHOOSE_DURATION = 20

function MTIR_ChooseSizeAction:isValid()
    if isClient() and self.started then
        return true
    end
    if not MTIR.SIZES[self.size] or not MTIR.hasItem(self.character, self.item) then
        return false
    end
    local data = MTIR.getData(self.item)
    return data ~= nil and data.size == nil
end

function MTIR_ChooseSizeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_ChooseClothesSize"))
    self.item:setJobDelta(0.0)
end

function MTIR_ChooseSizeAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function MTIR_ChooseSizeAction:stop()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_ChooseSizeAction:perform()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_ChooseSizeAction:complete()
    local data = MTIR.getData(self.item)
    if not data or data.size ~= nil or not MTIR.SIZES[self.size] then
        return false
    end
    data.size = self.size
    data.reveal = true
    data.hint = true
    MTIR.syncItem(self.character, self.item)
    MTIR.tell(self.character, { refresh = true })
    return true
end

function MTIR_ChooseSizeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return CHOOSE_DURATION
end

function MTIR_ChooseSizeAction:new(character, item, size)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.size = size
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
