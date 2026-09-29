-- ============================================================================
-- My Tailor Is Rich — tracer un patron d'après un vêtement ou des chaussures
-- Sur une table de travail (MTIR_WorkTable), ciseaux en main principale, crayon
-- ou stylo dans l'autre. Le modèle est décousu et découpé pour reporter ses
-- pièces sur les feuilles : il est détruit, comme les feuilles. complete() crée
-- le patron sur l'autorité (serveur en MP).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `papers`
-- est une ArrayList (une table Lua arriverait vide) ; `tablePos` est "x,y,z".
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, doublons, types, outils en main).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Patterns"
require "MyTailorIsRich/MTIR_WorkTable"

MTIR_TracePatternAction = ISBaseTimedAction:derive("MTIR_TracePatternAction")

local function canTrace(character, item, papers)
    local model = MTIR.describeModel(item)
    if not model or not MTIR.canTraceCondition(item) or character:isEquippedClothing(item) then
        return nil
    end
    if papers:size() < MTIR.getRequiredPaper(model) then
        return nil
    end
    if character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToTrace(model) then
        return nil
    end
    return model
end

--- Validation partagée par isValid et complete : modèle décrit, ou nil.
--- Feuilles sans doublon et du bon type, ciseaux et crayon en main, table à portée.
local function validate(self)
    local character = self.character
    local workTable = MTIR.workTableFromPos(self.tablePos)
    if not workTable or not MTIR.isWithinReach(character, workTable)
        or not MTIR.hasItem(character, self.item)
        or not MTIR.hasAllItemsOf(character, self.papers, MTIR.predicatePaper)
        or not MTIR.holdsTools(character, self.scissors, self.pen)
        or not MTIR.predicateScissors(self.scissors) or not MTIR.predicatePen(self.pen) then
        return nil
    end
    return canTrace(character, self.item, self.papers)
end

function MTIR_TracePatternAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_TracePatternAction:waitToStart()
    local workTable = MTIR.workTableFromPos(self.tablePos)
    if not workTable then
        return false
    end
    self.character:faceThisObject(workTable)
    return self.character:shouldBeTurning()
end

function MTIR_TracePatternAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.pen = MTIR.resolveItem(self.character, self.pen)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_TracePattern"))
    self.item:setJobDelta(0.0)
    -- Mains au travail sur une surface (animation vanilla B42 des établis).
    self:setActionAnim("Making_Surface")
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
    local model = validate(self)
    if not model then
        return false
    end
    if not MTIR.createPattern(character, item, model) then
        return false
    end
    MTIR.consumeItems(self.papers, MTIR.getRequiredPaper(model))
    -- Le modèle a été découpé pour reporter ses pièces : il ne reste rien.
    MTIR.removeItem(item)
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

function MTIR_TracePatternAction:new(character, item, scissors, pen, papers, tablePos)
    local o = ISBaseTimedAction.new(self, character)
    o.tablePos = tablePos
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
