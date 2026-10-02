-- ============================================================================
-- My Tailor Is Rich — lire l'étiquette d'un vêtement
-- Serveur (MP) ou local (solo) : complete() crée la taille si besoin, la révèle
-- selon le niveau de Couture, donne l'XP et synchronise l'objet.
-- Le vêtement peut rester dans un cadavre, un meuble ou un véhicule à portée
-- (MTIR_Reach) : l'étiquette se lit sur place, sans le prendre.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Reach"
require "MyTailorIsRich/MTIR_LabelCheck"

MTIR_CheckSizeAction = ISBaseTimedAction:derive("MTIR_CheckSizeAction")

function MTIR_CheckSizeAction:canBeginCheck()
    self.item = MTIR.resolveItem(self.character, self.item)
    if not self.item then return false end
    if self.corpseCheck and (not self.corpseContainer or self.item:getContainer() ~= self.corpseContainer
            or not self.corpseContainer:getItems():contains(self.item)
            or not MTIR.canCheckCorpse(self.character, self.corpseContainer)) then
        return false
    end
    return MTIR.canReachItem(self.character, self.item)
        and MTIR.needsSizeCheck(self.item, self.character, self.corpseCheck)
end

function MTIR_CheckSizeAction:begin()
    if not self:canBeginCheck() then
        local queue = ISTimedActionQueue.getTimedActionQueue(self.character)
        -- Écarter aussi les lectures invalides suivantes sans récursion sur un tas de corps.
        local following = queue.queue[2]
        while following and following.Type == self.Type and not following:canBeginCheck() do
            queue:removeFromQueue(following)
            following = queue.queue[2]
        end
        queue:onCompleted(self)
        return
    end
    ISBaseTimedAction.begin(self)
end

function MTIR_CheckSizeAction:isValid()
    if isClient() and self.started then
        return true
    end
    return MTIR.canReachItem(self.character, self.item)
end

function MTIR_CheckSizeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.started = true
    self.item:setJobType(getText("IGUI_MTIR_JobType_CheckClothesSize"))
    self.item:setJobDelta(0.0)
    self:setActionAnim("Loot")
    self:setAnimVariable("LootPosition", "")
    self:setOverrideHandModels(nil, nil)
    local container = MTIR.getInPlaceContainer(self.item)
    if container then
        self.character:faceThisObject(container:getParent())
    end
    self.sound = self.character:getEmitter():playSound("MTIR_CheckSize")
end

function MTIR_CheckSizeAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
end

function MTIR_CheckSizeAction:stop()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_CheckSizeAction:perform()
    stopSound(self)
    self.started = false
    self.item:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

--- Chaussure : la pointure est imprimée à l'intérieur, lisible sans Couture.
local function completeShoe(item, character)
    local data = MTIR.ensureShoeData(item)
    if not data then
        return false
    end
    data.reveal = true
    local diff = MTIR.getShoeDiff(item, MTIR.getPlayerShoeSize(character))
    MTIR.syncItem(character, item)
    MTIR.tell(character, { say = MTIR.pickShoeLabelSay(diff, data.size), refresh = true })
    return true
end

function MTIR_CheckSizeAction:complete()
    local item, character = self.item, self.character
    -- Le serveur n'appelle pas isValid : la portée est revérifiée ici.
    if not MTIR.canReachItem(character, item) then
        return false
    end
    if self.corpseCheck and (not self.corpseContainer or item:getContainer() ~= self.corpseContainer
            or not self.corpseContainer:getItems():contains(item)
            or not MTIR.canCheckCorpse(character, self.corpseContainer)) then
        return false
    end
    if MTIR.canShoeHaveSize(item) then
        return completeShoe(item, character)
    end
    if not MTIR.canClothesHaveSize(item) then
        return false
    end
    local data = MTIR.ensureData(item)
    if not data then
        return false
    end
    if not data.size then
        MTIR.tell(character, { say = { key = "IGUI_MTIR_Say_Unchosen_Clothes_Size" } })
        return true
    end

    local clothesSize = MTIR.getClothesSizeFromName(data.size)
    local diff = MTIR.getSizeDiff(clothesSize, MTIR.getPlayerSize(character))
    local level = character:getPerkLevel(Perks.Tailoring)
    local canRead = data.reveal or not MTIR.opt("NeedTailoringLevel")
        or level >= MTIR.getRequiredLevelToCheck(item)

    local say
    if canRead then
        local firstReading = not data.reveal
        data.reveal = true
        say = MTIR.pickLabelSay(diff, clothesSize)
        if firstReading and level < 5 then
            addXp(character, Perks.Tailoring, (0.5 - level * 0.1) * MTIR.opt("TailoringXpMultiplier"))
        end
    else
        data.hint = true
        say = MTIR.pickHintSay(diff)
    end

    MTIR.syncItem(character, item)
    MTIR.tell(character, { say = say, refresh = true })
    return true
end

function MTIR_CheckSizeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    if MTIR.canShoeHaveSize(self.item) then
        return MTIR.getShoeCheckDuration()
    end
    return MTIR.getCheckDuration(self.item)
end

function MTIR_CheckSizeAction:new(character, item, corpseContainer)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.corpseContainer = corpseContainer
    -- Le booléen reste présent même si le conteneur ne peut plus être résolu en MP.
    o.corpseCheck = corpseContainer ~= nil
    -- Lecture sur place : s'éloigner du conteneur l'interrompt.
    o.stopOnWalk = not MTIR.isCarried(character, item)
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
