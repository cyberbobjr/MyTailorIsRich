-- ============================================================================
-- My Tailor Is Rich — tracer un patron d'après un vêtement ou des chaussures
-- Ciseaux en main principale, crayon ou stylo dans l'autre ; les feuilles sont
-- consommées, le modèle est conservé intact. complete() crée le patron sur
-- l'autorité (serveur en MP).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `papers`
-- est une ArrayList (une table Lua arriverait vide).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Patterns"

MTIR_TracePatternAction = ISBaseTimedAction:derive("MTIR_TracePatternAction")

local function canTrace(character, item, papers)
    local model = MTIR.describeModel(item)
    if not model or not MTIR.canTraceCondition(item) or character:isEquippedClothing(item) then
        return nil
    end
    if not papers or papers:size() < MTIR.getRequiredPaper(model) then
        return nil
    end
    if character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToTrace(model) then
        return nil
    end
    return model
end

function MTIR_TracePatternAction:isValid()
    if isClient() and self.started then
        return true
    end
    local character = self.character
    return MTIR.hasItem(character, self.item)
        and MTIR.hasAllItems(character, self.papers)
        and MTIR.sameItem(character:getPrimaryHandItem(), self.scissors)
        and MTIR.sameItem(character:getSecondaryHandItem(), self.pen)
        and canTrace(character, self.item, self.papers) ~= nil
end

function MTIR_TracePatternAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.pen = MTIR.resolveItem(self.character, self.pen)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_TracePattern"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.pen)
    self.character:getEmitter():playSound("MapAddNote")
end

function MTIR_TracePatternAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function MTIR_TracePatternAction:stop()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_TracePatternAction:perform()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_TracePatternAction:complete()
    local character, item = self.character, self.item
    local model = canTrace(character, item, self.papers)
    if not model then
        return false
    end
    if not MTIR.createPattern(character, item, model) then
        return false
    end
    MTIR.consumeItems(self.papers, MTIR.getRequiredPaper(model))
    addXp(character, Perks.Tailoring, MTIR.getTraceXp(model))
    MTIR.tell(character, { refresh = true, halo = { itemType = MTIR.PATTERN_ITEM, good = true } })
    return true
end

function MTIR_TracePatternAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local model = MTIR.describeModel(self.item)
    return model and MTIR.getTraceDuration(model) or 1
end

function MTIR_TracePatternAction:new(character, item, scissors, pen, papers)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.scissors = scissors
    o.pen = pen
    o.papers = papers
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
