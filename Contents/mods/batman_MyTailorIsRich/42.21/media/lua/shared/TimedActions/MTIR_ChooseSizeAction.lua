-- ============================================================================
-- My Tailor Is Rich — fixer la taille d'un vêtement fabriqué sans taille
-- L'original écrivait la ModData côté client ; ici complete() le fait sur
-- l'autorité puis synchronise.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_ActionBase"
require "MyTailorIsRich/MTIR_Effects"

MTIR_ChooseSizeAction = ISBaseTimedAction:derive("MTIR_ChooseSizeAction")

local CHOOSE_DURATION = 20

--- Validation partagée par isValid et complete (le serveur n'appelle pas isValid) :
--- données de taille à compléter, ou nil.
local function validate(self)
    if not MTIR.SIZES[self.size] or not MTIR.hasItem(self.character, self.item) then
        return nil
    end
    local data = MTIR.getData(self.item)
    if not data or data.size ~= nil then
        return nil
    end
    return data
end

function MTIR_ChooseSizeAction:isValid()
    return MTIR.Action.startedOnClient(self) or validate(self) ~= nil
end

function MTIR_ChooseSizeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    MTIR.Action.startProgress(self, self.item, "IGUI_MTIR_JobType_ChooseClothesSize")
end

function MTIR_ChooseSizeAction:update()
    MTIR.Action.updateProgress(self, self.item)
end

function MTIR_ChooseSizeAction:stop()
    MTIR.Action.stop(self, self.item)
end

function MTIR_ChooseSizeAction:perform()
    MTIR.Action.perform(self, self.item)
end

function MTIR_ChooseSizeAction:complete()
    local data = validate(self)
    if not data then
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
