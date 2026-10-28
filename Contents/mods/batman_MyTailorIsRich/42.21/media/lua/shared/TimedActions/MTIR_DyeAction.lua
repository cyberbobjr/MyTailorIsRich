-- ============================================================================
-- My Tailor Is Rich — teindre un vêtement
-- Bain de teinture : une teinture vanilla (colorant industriel ou teinture pour
-- cheveux, dont la couleur est celle du mélange) et de l'eau. Le vêtement prend
-- la couleur et ressort trempé.
--
-- Paramètres réseau : les champs portent le nom des paramètres de new().
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, vêtement teintable et non porté,
-- teinture pure et en quantité, eau), applique la couleur, consomme les fluides
-- et synchronise (syncItemFields pour le vêtement, sendItemStats pour les
-- récipients). Les autres joueurs voient la couleur quand le vêtement est
-- enfilé (SyncClothing transmet la teinte du visuel).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_ActionBase"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Dyeing"

MTIR_DyeAction = ISBaseTimedAction:derive("MTIR_DyeAction")

--- Validation partagée par isValid et complete : sorte de teinture, ou nil.
local function validate(self)
    local character = self.character
    if not MTIR.hasItem(character, self.item) or not MTIR.hasItem(character, self.dye)
        or not MTIR.hasItem(character, self.water) then
        return nil
    end
    return MTIR.checkDyeBath(self.item, self.dye, self.water)
end

function MTIR_DyeAction:isValid()
    return MTIR.Action.startedOnClient(self) or validate(self) ~= nil
end

function MTIR_DyeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.dye = MTIR.resolveItem(self.character, self.dye)
    self.water = MTIR.resolveItem(self.character, self.water)
    MTIR.Action.startProgress(self, self.item, "IGUI_MTIR_JobType_Dyeing")
    -- Animation et accessoires de la recette vanilla « Dye Clothes » (timedAction MixingBucket).
    self:setActionAnim("MixingBucket")
    self:setOverrideHandModels("Base.WoodenStick_Broken", "Base.CraftingBucket")
    self.sound = self.character:playSound("WashClothing")
end

function MTIR_DyeAction:update()
    MTIR.Action.updateProgress(self, self.item)
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function MTIR_DyeAction:stop()
    stopSound(self)
    MTIR.Action.stop(self, self.item)
end

function MTIR_DyeAction:perform()
    stopSound(self)
    MTIR.Action.perform(self, self.item)
end

function MTIR_DyeAction:complete()
    local kind = validate(self)
    if not kind then
        return false
    end
    local item, character = self.item, self.character
    local r, g, b = MTIR.getDyeColor(self.dye)
    MTIR.applyDyeColor(item, r, g, b)
    MTIR.drainFluid(self.dye, MTIR.getDyeLitres(item, kind))
    MTIR.drainFluid(self.water, MTIR.getDyeWaterLitres(item))
    sendItemStats(self.dye)
    sendItemStats(self.water)
    -- Sorti du bain : trempé.
    item:setWetness(100)
    addXp(character, Perks.Tailoring, MTIR.getDyeXp(item))
    MTIR.syncItem(character, item)
    MTIR.tell(character, { refresh = true, resetModel = true })
    return true
end

function MTIR_DyeAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getDyeDuration(self.item)
end

--- item : vêtement (non porté) ; dye : récipient de teinture ; water : récipient d'eau.
function MTIR_DyeAction:new(character, item, dye, water)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.dye = dye
    o.water = water
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
