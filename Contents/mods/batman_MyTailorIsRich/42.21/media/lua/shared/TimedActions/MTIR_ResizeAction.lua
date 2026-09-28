-- ============================================================================
-- My Tailor Is Rich — agrandir (bandes de tissu) ou rétrécir (trombones)
-- Remplace ISUpsizeClothes / ISDownsizeClothes (client seul) par une action
-- partagée : complete() décide et consomme côté serveur en MP.
--
-- Paramètres réseau : les champs portent le nom des paramètres de new() ;
-- `threads` et `materials` sont des ArrayList (une table Lua arriverait vide).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"

MTIR_ResizeAction = ISBaseTimedAction:derive("MTIR_ResizeAction")

function MTIR_ResizeAction:isValid()
    if isClient() and self.started then
        return true
    end
    local character = self.character
    return MTIR.hasItem(character, self.item)
        and MTIR.hasAllItems(character, self.threads)
        and MTIR.hasAllItems(character, self.materials)
        and MTIR.sameItem(character:getPrimaryHandItem(), self.scissors)
        and MTIR.sameItem(character:getSecondaryHandItem(), self.needle)
end

function MTIR_ResizeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.needle = MTIR.resolveItem(self.character, self.needle)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.started = true
    local jobKey = self.upsize and "IGUI_MTIR_JobType_UpsizeClothes" or "IGUI_MTIR_JobType_DownsizeClothes"
    self.item:setJobType(getText(jobKey))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.needle)
    self.sound = self.character:getEmitter():playSound("MTIR_ResizeClothes")
end

function MTIR_ResizeAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function MTIR_ResizeAction:stop()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_ResizeAction:perform()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

--- Réussite : état ajusté selon la marge de Couture (ou perte si à la limite).
local function applySuccessCondition(item, tailoring, requiredLevel)
    if not MTIR.canClothesDegrade(item) then
        return
    end
    if tailoring > requiredLevel then
        item:setCondition(item:getCondition() + ZombRand(math.min(tailoring - requiredLevel, 3) + 1))
    elseif ZombRandFloat(0, 1) < MTIR.opt("ChanceToDegradeOnFailure") then
        item:setCondition(item:getCondition() - 1)
    end
end

function MTIR_ResizeAction:complete()
    local item, character, upsize = self.item, self.character, self.upsize
    local data = MTIR.getData(item)
    if not data or not data.size or not data.reveal or data.resized ~= 0 then
        return false
    end
    local newSize = upsize and MTIR.getNextSize(data.size) or MTIR.getPrevSize(data.size)
    if not newSize then
        return false
    end

    local tailoring = character:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToChange(item, upsize)
    local threadUses = MTIR.getRequiredThreadCount(item)
    local materialUses = self.materials:size()
    local fx = { refresh = true }

    if ZombRandFloat(0, 1) < MTIR.getSuccessChanceForChange(tailoring, requiredLevel) then
        data.size = newSize.name
        data.resized = upsize and 1 or -1
        applySuccessCondition(item, tailoring, requiredLevel)
        MTIR.updateOneClothes(item, character)
        addXp(character, Perks.Tailoring, MTIR.getTailoringXpForChange(item, upsize, true))
    else
        if MTIR.canClothesDegrade(item) and ZombRandFloat(0, 1) < 0.5 then
            item:setCondition(item:getCondition() - 1)
        end
        addXp(character, Perks.Tailoring, MTIR.getTailoringXpForChange(item, upsize, false))
        -- Un échec ne coûte que la moitié des matériaux.
        threadUses = math.ceil(threadUses / 2)
        materialUses = math.ceil(materialUses / 2)
        fx.sound = "MTIR_ResizeFailed"
    end

    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.consumeItems(self.materials, materialUses)
    MTIR.syncItem(character, item)
    MTIR.tell(character, fx)
    return true
end

function MTIR_ResizeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getChangeDuration(self.item, self.upsize)
end

--- upsize : true = agrandir (materials = bandes), false = rétrécir (materials = trombones).
function MTIR_ResizeAction:new(character, item, needle, scissors, threads, materials, upsize)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.materials = materials
    o.upsize = upsize == true
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
