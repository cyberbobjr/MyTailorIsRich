-- ============================================================================
-- My Tailor Is Rich — broder un nom sur une machine à coudre
-- Lancée par l'onglet Broderie du panneau de la machine. Même broderie que
-- MTIR_EmbroiderAction (texte, nom composé, MTIR.applyEmbroidery), avec les
-- mécanismes des autres travaux machine (MTIR.MachineWork) : face à la machine,
-- son et bruit pour les zombies, usure, aiguille cassée, pas de dé à coudre.
--   * électrique : courant requis, durée et fil réduits, niveau de la main avec
--     le bonus de la machine ;
--   * à pédale : durée et fil un peu réduits, Couture EMBROIDERY_TREADLE_LEVEL
--     au niveau réel (bonus non compté).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ; `threads`
-- est une ArrayList ; `text` et `newName` sont saisis par le client ;
-- `machinePos` vaut "x,y,z" (jamais "" : cette action n'existe que sur machine).
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, aiguille en main, fil, niveau, texte,
-- vêtement non porté et non brodé, machine présente, alimentée, non bloquée et
-- à portée).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Alterations"
require "MyTailorIsRich/MTIR_Embroidery"

MTIR_MachineEmbroiderAction = ISBaseTimedAction:derive("MTIR_MachineEmbroiderAction")

--- Bonus de la machine si la broderie est possible, sinon nil.
local function canEmbroiderNow(self)
    local item, character = self.item, self.character
    if not MTIR.isEmbroideryEnabled() or not MTIR.canEmbroider(item) or item:isEquipped()
        or MTIR.getEmbroidery(item) then
        return nil
    end
    if not MTIR.isValidEmbroidery(self.text, self.newName) then
        return nil
    end
    if self.machinePos == "" then
        return nil
    end
    -- Machine présente, alimentée (électrique), non bloquée, et personnage à portée.
    local mods = MTIR.resolveWorkMods(character, self.machinePos, nil)
    if not mods or not mods.machine then
        return nil
    end
    local kindName = MTIR.getMachineKindName(mods.machine)
    local level = MTIR.getMachineEmbroideryLevel(character:getPerkLevel(Perks.Tailoring), kindName, mods)
    if level < MTIR.getMachineEmbroideryRequiredLevel(kindName) then
        return nil
    end
    if MTIR.getRemainingThread(self.threads) < MTIR.getMachineEmbroideryThread(mods) then
        return nil
    end
    if not self.needle or not MTIR.predicateNeedle(self.needle) then
        return nil
    end
    return mods
end

--- Validation partagée par isValid et complete : bonus de la machine, ou nil.
local function validate(self)
    local character = self.character
    if not MTIR.hasItem(character, self.item) or not MTIR.hasThreads(character, self.threads)
        or not MTIR.sameItem(character:getPrimaryHandItem(), self.needle) then
        return nil
    end
    return canEmbroiderNow(self)
end

function MTIR_MachineEmbroiderAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_MachineEmbroiderAction:waitToStart()
    return MTIR.MachineWork.waitToStart(self)
end

function MTIR_MachineEmbroiderAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.needle = MTIR.resolveItem(self.character, self.needle)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_Embroidering"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.needle, nil)
    MTIR.MachineWork.start(self, "MTIR_ResizeClothes")
end

function MTIR_MachineEmbroiderAction:update()
    self.item:setJobDelta(self:getJobDelta())
    MTIR.MachineWork.update(self)
end

function MTIR_MachineEmbroiderAction:stop()
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_MachineEmbroiderAction:perform()
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_MachineEmbroiderAction:complete()
    local mods = validate(self)
    if not mods then
        return false
    end
    local item, character = self.item, self.character
    local threadUses = MTIR.getMachineEmbroideryThread(mods)
    local fx = { refresh = true }
    -- Aiguille cassée tirée avant l'issue, comme les autres travaux machine.
    local broke = MTIR.MachineWork.rollBreak(mods)
    if not broke and ZombRandFloat(0, 1) < MTIR.getMachineEmbroiderySuccess(mods) then
        MTIR.applyEmbroidery(item, self.text, self.newName)
        addXp(character, Perks.Tailoring, MTIR.getEmbroideryXp())
    else
        -- Broderie ratée : le vêtement garde son nom, la moitié du fil est perdue.
        threadUses = math.ceil(threadUses / 2)
        fx.sound = "MTIR_ResizeFailed"
        fx.say = broke and { key = "IGUI_MTIR_Say_NeedleBroke" } or nil
    end
    MTIR.MachineWork.applyWear(self, mods, broke)
    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.syncItem(character, item)
    MTIR.tell(character, fx)
    return true
end

function MTIR_MachineEmbroiderAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getMachineEmbroideryDuration(self.text, MTIR.MachineWork.durationMods(self))
end

--- needle : aiguille tenue en main principale ; threads : ArrayList de bobines ;
--- text : texte brodé (nettoyé) ; newName : nouveau nom composé par le client ;
--- machinePos : "x,y,z" de la machine (MTIR.encodeMachinePos).
--- (Pas de paramètre `name` : NetTimedAction réserve ce champ au nom de l'action.)
function MTIR_MachineEmbroiderAction:new(character, item, needle, threads, text, newName, machinePos)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.threads = threads
    o.text = type(text) == "string" and text or ""
    o.newName = type(newName) == "string" and newName or ""
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    -- S'éloigner de la machine interrompt le travail.
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
