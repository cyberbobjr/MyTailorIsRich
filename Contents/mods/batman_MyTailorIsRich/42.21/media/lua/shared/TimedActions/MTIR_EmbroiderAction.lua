-- ============================================================================
-- My Tailor Is Rich — broder un nom sur un vêtement, ou découdre la broderie
--
-- Paramètres réseau : les champs portent le nom des paramètres de new() ;
-- `threads` est une ArrayList (une table Lua arriverait vide) ; `text` et
-- `newName` sont des chaînes saisies par le client, revérifiées par l'autorité.
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, outil en main, fil, dé, niveau,
-- texte nettoyé, vêtement non porté et non déjà brodé).
-- Nom : setName puis setCustomName(true), transmis par syncItemFields. Au
-- décousage, le nom du script n'est pas transmis (syncItemFields n'envoie un nom
-- que s'il est personnalisé) : le serveur prévient le client, qui rétablit le nom
-- dans sa langue (MTIR_DecorMenu.lua).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Alterations"
require "MyTailorIsRich/MTIR_Embroidery"

-- ----------------------------------------------------------------------------
-- Broder
-- ----------------------------------------------------------------------------

MTIR_EmbroiderAction = ISBaseTimedAction:derive("MTIR_EmbroiderAction")

local function canEmbroiderNow(self)
    local item, character = self.item, self.character
    if not MTIR.isEmbroideryEnabled() or not MTIR.canEmbroider(item) or item:isEquipped()
        or MTIR.getEmbroidery(item) then
        return false
    end
    if not MTIR.isValidEmbroidery(self.text, self.newName) then
        return false
    end
    if character:getPerkLevel(Perks.Tailoring) < MTIR.getEmbroideryRequiredLevel()
        or not MTIR.hasThimbleFor(character, nil) then
        return false
    end
    return MTIR.getRemainingThread(self.threads) >= MTIR.EMBROIDERY_THREAD
        and self.needle ~= nil and MTIR.predicateNeedle(self.needle)
end

--- Validation partagée par isValid et complete.
local function validateEmbroider(self)
    local character = self.character
    if not MTIR.hasItem(character, self.item) or not MTIR.hasThreads(character, self.threads)
        or not MTIR.sameItem(character:getPrimaryHandItem(), self.needle) then
        return false
    end
    return canEmbroiderNow(self)
end

function MTIR_EmbroiderAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validateEmbroider(self)
end

function MTIR_EmbroiderAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.needle = MTIR.resolveItem(self.character, self.needle)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_Embroidering"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.needle, nil)
    self.sound = self.character:getEmitter():playSound("MTIR_ResizeClothes")
end

function MTIR_EmbroiderAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function MTIR_EmbroiderAction:stop()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_EmbroiderAction:perform()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_EmbroiderAction:complete()
    if not validateEmbroider(self) then
        return false
    end
    local item, character = self.item, self.character
    MTIR.applyEmbroidery(item, self.text, self.newName)
    MTIR.consumeThreads(self.threads, MTIR.EMBROIDERY_THREAD)
    addXp(character, Perks.Tailoring, MTIR.getEmbroideryXp())
    MTIR.syncItem(character, item)
    MTIR.tell(character, { refresh = true })
    return true
end

function MTIR_EmbroiderAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getEmbroideryDuration(self.text)
end

--- needle : aiguille tenue en main principale ; threads : ArrayList de bobines ;
--- text : texte brodé (nettoyé) ; newName : nouveau nom composé par le client.
--- (Pas de paramètre `name` : NetTimedAction réserve ce champ au nom de l'action
--- et le réécrit sur le serveur après new.)
function MTIR_EmbroiderAction:new(character, item, needle, threads, text, newName)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.needle = needle
    o.threads = threads
    o.text = type(text) == "string" and text or ""
    o.newName = type(newName) == "string" and newName or ""
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end

-- ----------------------------------------------------------------------------
-- Découdre la broderie
-- ----------------------------------------------------------------------------

MTIR_UnpickEmbroideryAction = ISBaseTimedAction:derive("MTIR_UnpickEmbroideryAction")

local function validateUnpick(self)
    local character, item = self.character, self.item
    if not MTIR.hasItem(character, item) or item:isEquipped() or not MTIR.getEmbroidery(item) then
        return false
    end
    return self.scissors ~= nil and MTIR.sameItem(character:getPrimaryHandItem(), self.scissors)
        and MTIR.predicateScissors(self.scissors)
end

function MTIR_UnpickEmbroideryAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validateUnpick(self)
end

function MTIR_UnpickEmbroideryAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_Unpicking"))
    self.item:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, nil)
end

function MTIR_UnpickEmbroideryAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function MTIR_UnpickEmbroideryAction:stop()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_UnpickEmbroideryAction:perform()
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function MTIR_UnpickEmbroideryAction:complete()
    if not validateUnpick(self) then
        return false
    end
    local item, character = self.item, self.character
    local prevName = MTIR.removeEmbroidery(item)
    MTIR.syncItem(character, item)
    if isServer() then
        sendServerCommand(character, MTIR.NET_MODULE, "embroideryRemoved", {
            playerOnlineId = character:getOnlineID(),
            itemId = item:getID(),
            prevName = prevName,
        })
    end
    MTIR.tell(character, { refresh = true })
    return true
end

function MTIR_UnpickEmbroideryAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getUnpickDuration()
end

--- scissors : ciseaux tenus en main principale.
function MTIR_UnpickEmbroideryAction:new(character, item, scissors)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.scissors = scissors
    o.stopOnWalk = false
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
