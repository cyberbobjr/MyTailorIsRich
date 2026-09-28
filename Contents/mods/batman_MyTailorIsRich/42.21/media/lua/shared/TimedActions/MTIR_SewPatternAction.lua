-- ============================================================================
-- My Tailor Is Rich — coudre un vêtement ou des chaussures d'après un patron
-- Ciseaux (ou couteau pour le cuir) en main principale, aiguille (ou alêne)
-- dans l'autre. complete() décide sur l'autorité : réussite, écart de taille
-- éventuel, consommation des matériaux et usure du patron.
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ;
-- `threads` et `materials` sont des ArrayList ; `size` est un texte
-- (XS..XXL ou pointure).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Patterns"

MTIR_SewPatternAction = ISBaseTimedAction:derive("MTIR_SewPatternAction")

--- Données du patron si la couture est possible, sinon nil.
local function canSew(self)
    local data = MTIR.getPatternData(self.pattern)
    if not data or (data.uses or 0) <= 0 or not MTIR.patternModelExists(data) then
        return nil
    end
    if not MTIR.isValidPatternSize(data, self.size) then
        return nil
    end
    local character = self.character
    if character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToSew(data) then
        return nil
    end
    if not self.threads or MTIR.getRemainingThread(self.threads) < MTIR.getPatternThread(data) then
        return nil
    end
    if not self.materials
        or MTIR.countMaterialUnits(data.fabric, self.materials) < MTIR.getPatternMaterialUnits(data, self.size) then
        return nil
    end
    if not self.needle or not self.scissors then
        return nil
    end
    local needleOk = MTIR.predicatePatternNeedle(data.fabric)
    local cutterOk = MTIR.predicatePatternCutter(data.fabric)
    if not needleOk(self.needle) or not cutterOk(self.scissors) then
        return nil
    end
    return data
end

function MTIR_SewPatternAction:isValid()
    if isClient() and self.started then
        return true
    end
    local character = self.character
    return MTIR.hasItem(character, self.pattern)
        and MTIR.hasAllItems(character, self.threads)
        and MTIR.hasAllItems(character, self.materials)
        and MTIR.sameItem(character:getPrimaryHandItem(), self.scissors)
        and MTIR.sameItem(character:getSecondaryHandItem(), self.needle)
        and canSew(self) ~= nil
end

function MTIR_SewPatternAction:start()
    self.pattern = MTIR.resolveItem(self.character, self.pattern)
    self.needle = MTIR.resolveItem(self.character, self.needle)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.started = true
    self.pattern:setJobType(getText("IGUI_MTIR_JobType_SewPattern"))
    self.pattern:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.needle)
    self.sound = self.character:getEmitter():playSound("MTIR_ResizeClothes")
end

function MTIR_SewPatternAction:update()
    self.pattern:setJobDelta(self:getJobDelta())
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function MTIR_SewPatternAction:stop()
    stopSound(self)
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_SewPatternAction:perform()
    stopSound(self)
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

--- Une couture (réussie ou non) use le patron ; usé jusqu'au bout, il disparaît.
local function wearPattern(character, pattern, data)
    data.uses = (data.uses or 1) - 1
    if data.uses <= 0 then
        MTIR.removeItem(pattern)
        return true
    end
    MTIR.syncItem(character, pattern)
    return false
end

local function sayForOffset(data, asked, obtained)
    if asked == obtained then
        return nil
    end
    local bigger
    if data.kind == "shoe" then
        bigger = tonumber(obtained) > tonumber(asked)
    else
        bigger = MTIR.getSizeIndex(obtained) > MTIR.getSizeIndex(asked)
    end
    return { key = bigger and "IGUI_MTIR_Say_PatternBigger" or "IGUI_MTIR_Say_PatternSmaller", arg = obtained }
end

function MTIR_SewPatternAction:complete()
    local data = canSew(self)
    if not data then
        return false
    end
    local character = self.character
    local tailoring = character:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToSew(data)
    local threadUses = MTIR.getPatternThread(data)
    local materialUnits = MTIR.getPatternMaterialUnits(data, self.size)
    local fx = { refresh = true }

    if ZombRandFloat(0, 1) < MTIR.getSuccessChanceForChange(tailoring, requiredLevel) then
        local obtained = MTIR.rollPatternSize(data, self.size, tailoring)
        if not MTIR.createFromPattern(character, data, obtained, tailoring - requiredLevel) then
            return false
        end
        addXp(character, Perks.Tailoring, MTIR.getSewXp(data, true))
        fx.halo = { itemType = data.fullType, good = true }
        fx.say = sayForOffset(data, self.size, obtained)
    else
        addXp(character, Perks.Tailoring, MTIR.getSewXp(data, false))
        -- Un échec gâche la moitié du fil et du tissu.
        threadUses = math.ceil(threadUses / 2)
        materialUnits = math.ceil(materialUnits / 2)
        fx.sound = "MTIR_ResizeFailed"
        fx.say = { key = "IGUI_MTIR_Say_PatternFailed" }
    end

    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.consumeMaterials(data.fabric, self.materials, materialUnits)
    if wearPattern(character, self.pattern, data) then
        fx.say = fx.say or { key = "IGUI_MTIR_Say_PatternWornOut" }
    end
    MTIR.tell(character, fx)
    return true
end

function MTIR_SewPatternAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local data = MTIR.getPatternData(self.pattern)
    return data and MTIR.getSewDuration(data) or 1
end

function MTIR_SewPatternAction:new(character, pattern, needle, scissors, threads, materials, size)
    local o = ISBaseTimedAction.new(self, character)
    o.pattern = pattern
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.materials = materials
    o.size = tostring(size)
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
