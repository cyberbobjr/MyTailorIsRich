-- ============================================================================
-- My Tailor Is Rich — agrandir (bandes de tissu) ou rétrécir (trombones)
-- Remplace ISUpsizeClothes / ISDownsizeClothes (client seul) par une action
-- partagée : complete() décide et consomme côté serveur en MP.
--
-- Paramètres réseau : les champs portent le nom des paramètres de new() ;
-- `threads` et `materials` sont des ArrayList (une table Lua arriverait vide) ;
-- `machinePos` vaut "x,y,z" sur une machine à coudre, "" à la main.
-- L'autorité revérifie tout ce que le client a choisi (machine, dé, fil,
-- matériaux, outils, niveau).
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, doublons, types, outils en main).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Alterations"

MTIR_ResizeAction = ISBaseTimedAction:derive("MTIR_ResizeAction")

--- Matériaux du bon type et en nombre suffisant.
local function materialsOk(self)
    local materialType, required = MTIR.getResizeMaterial(self.item, self.upsize)
    if not self.materials or not materialType or self.materials:size() < required then
        return false
    end
    for i = 0, self.materials:size() - 1 do
        if self.materials:get(i):getFullType() ~= materialType then
            return false
        end
    end
    return true
end

--- Bonus de travail si la retouche est possible, sinon nil.
local function canResize(self)
    local item, character = self.item, self.character
    if not MTIR.canResizeClothes(item) or not MTIR.getResizeTarget(item, self.upsize) then
        return nil
    end
    local mods = MTIR.resolveWorkMods(character, self.machinePos, nil)
    if not mods or not MTIR.hasThimbleFor(character, mods) then
        return nil
    end
    if MTIR.getEffectiveTailoring(character, mods) < MTIR.getRequiredLevelToChange(item, self.upsize) then
        return nil
    end
    if MTIR.getRemainingThread(self.threads) < MTIR.getResizeThreadUses(item, mods) then
        return nil
    end
    if not materialsOk(self) or not self.needle or not self.scissors
        or not MTIR.predicateNeedle(self.needle) or not MTIR.predicateScissors(self.scissors) then
        return nil
    end
    return mods
end

--- Validation partagée par isValid et complete : bonus de travail, ou nil.
local function validate(self)
    local character = self.character
    if not MTIR.hasItem(character, self.item)
        or not MTIR.hasThreads(character, self.threads)
        or not MTIR.hasAllItems(character, self.materials)
        or not MTIR.holdsTools(character, self.scissors, self.needle) then
        return nil
    end
    return canResize(self)
end

function MTIR_ResizeAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_ResizeAction:waitToStart()
    return MTIR.MachineWork.waitToStart(self)
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
    MTIR.MachineWork.start(self, "MTIR_ResizeClothes")
end

function MTIR_ResizeAction:update()
    self.item:setJobDelta(self:getJobDelta())
    MTIR.MachineWork.update(self)
end

function MTIR_ResizeAction:stop()
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_ResizeAction:perform()
    MTIR.MachineWork.stopSound(self)
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

--- Réussite de la retouche : nouvelle taille, état, XP.
local function applyResize(self, effective, requiredLevel)
    local item, data = self.item, MTIR.getData(self.item)
    data.size = MTIR.getResizeTarget(item, self.upsize).name
    data.resized = self.upsize and 1 or -1
    applySuccessCondition(item, effective, requiredLevel)
    MTIR.updateOneClothes(item, self.character)
    addXp(self.character, Perks.Tailoring, MTIR.getTailoringXpForChange(item, self.upsize, true))
end

function MTIR_ResizeAction:complete()
    local mods = validate(self)
    if not mods then
        return false
    end
    local item, character, upsize = self.item, self.character, self.upsize
    local requiredLevel = MTIR.getRequiredLevelToChange(item, upsize)
    local effective = MTIR.getEffectiveTailoring(character, mods)
    local threadUses = MTIR.getResizeThreadUses(item, mods)
    local _, materialUses = MTIR.getResizeMaterial(item, upsize)
    local fx = { refresh = true }
    local broke = MTIR.MachineWork.rollBreak(mods)
    local chance = MTIR.applySuccessMalus(MTIR.getSuccessChanceForChange(effective, requiredLevel), mods)

    if not broke and ZombRandFloat(0, 1) < chance then
        applyResize(self, effective, requiredLevel)
    else
        if MTIR.canClothesDegrade(item) and ZombRandFloat(0, 1) < 0.5 then
            item:setCondition(item:getCondition() - 1)
        end
        addXp(character, Perks.Tailoring, MTIR.getTailoringXpForChange(item, upsize, false))
        -- Un échec ne coûte que la moitié des matériaux.
        threadUses = math.ceil(threadUses / 2)
        materialUses = math.ceil(materialUses / 2)
        fx.sound = "MTIR_ResizeFailed"
        fx.say = broke and { key = "IGUI_MTIR_Say_NeedleBroke" } or nil
    end

    MTIR.MachineWork.applyWear(self, mods, broke)
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
    return MTIR.getResizeDurationWith(self.item, self.upsize, MTIR.MachineWork.durationMods(self))
end

--- upsize : true = agrandir (materials = bandes), false = rétrécir (materials = trombones).
--- machinePos : "x,y,z" d'une machine à coudre (MTIR.encodeMachinePos), ou nil/"" à la main.
function MTIR_ResizeAction:new(character, item, needle, scissors, threads, materials, upsize, machinePos)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.materials = materials
    o.upsize = upsize == true
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    -- Sur une machine, s'éloigner interrompt le travail ; à la main, on coud en marchant.
    o.stopOnWalk = o.machinePos ~= ""
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
