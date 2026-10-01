-- ============================================================================
-- My Tailor Is Rich — copier un patron sur des feuilles neuves
-- Sur une table de travail (MTIR_WorkTable), ciseaux en main principale, crayon
-- ou stylo dans l'autre, comme le tracé. L'original reste intact ; les feuilles
-- sont consommées. complete() crée la copie sur l'autorité (serveur en MP) :
-- précision réduite, utilisations neuves (MTIR_PatternCopy.lua).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `papers`
-- est une ArrayList ; `tablePos` est "x,y,z". Le serveur n'appelle jamais
-- isValid (NetTimedAction.isValid) : complete() refait toute la validation
-- (option, possession, doublons, types, outils en main, table, niveau).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_PatternCopy"
require "MyTailorIsRich/MTIR_WorkTable"
require "MyTailorIsRich/MTIR_SewingMachine"

MTIR_CopyPatternAction = ISBaseTimedAction:derive("MTIR_CopyPatternAction")

--- Données du patron copiable, ou nil.
local function copiableData(character, pattern, papers)
    local data = MTIR.getPatternData(pattern)
    if not MTIR.isPatternCopyEnabled() or not MTIR.isUsablePatternData(data) then
        return nil
    end
    if papers:size() < MTIR.getRequiredPaperToCopy(data) then
        return nil
    end
    if character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToCopy(data) then
        return nil
    end
    return data
end

--- Validation partagée par isValid et complete : données du patron, ou nil.
--- Feuilles sans doublon et du bon type, ciseaux et crayon en main, table à portée.
local function validate(self)
    local character = self.character
    local workTable = MTIR.workTableFromPos(self.tablePos)
    if not workTable or not MTIR.isWithinReach(character, workTable)
        or not MTIR.hasItem(character, self.pattern)
        or not MTIR.hasAllItemsOf(character, self.papers, MTIR.predicatePaper)
        or not MTIR.holdsTools(character, self.scissors, self.pen)
        or not MTIR.predicateScissors(self.scissors) or not MTIR.predicatePen(self.pen) then
        return nil
    end
    return copiableData(character, self.pattern, self.papers)
end

function MTIR_CopyPatternAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_CopyPatternAction:waitToStart()
    local workTable = MTIR.workTableFromPos(self.tablePos)
    if not workTable then
        return false
    end
    self.character:faceThisObject(workTable)
    return self.character:shouldBeTurning()
end

function MTIR_CopyPatternAction:start()
    self.pattern = MTIR.resolveItem(self.character, self.pattern)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.pen = MTIR.resolveItem(self.character, self.pen)
    self.started = true
    self.pattern:setJobType(getText("IGUI_MTIR_JobType_CopyPattern"))
    self.pattern:setJobDelta(0.0)
    self:setActionAnim("Making_Surface")
    self:setOverrideHandModels(self.scissors, self.pen)
    self.character:getEmitter():playSound("MapAddNote")
end

function MTIR_CopyPatternAction:update()
    self.pattern:setJobDelta(self:getJobDelta())
end

function MTIR_CopyPatternAction:stop()
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_CopyPatternAction:perform()
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_CopyPatternAction:complete()
    local data = validate(self)
    if not data then
        return false
    end
    local character = self.character
    if not MTIR.createPatternCopy(character, data) then
        return false
    end
    MTIR.consumeItems(self.papers, MTIR.getRequiredPaperToCopy(data))
    addXp(character, Perks.Tailoring, MTIR.getCopyXp(data))
    MTIR.tell(character, { refresh = true, halo = { itemType = MTIR.PATTERN_ITEM, good = true } })
    return true
end

function MTIR_CopyPatternAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local data = MTIR.getPatternData(self.pattern)
    return data and MTIR.getCopyDuration(data) or 1
end

function MTIR_CopyPatternAction:new(character, pattern, scissors, pen, papers, tablePos)
    local o = ISBaseTimedAction.new(self, character)
    o.tablePos = tablePos
    o.pattern = pattern
    o.scissors = scissors
    o.pen = pen
    o.papers = papers
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
