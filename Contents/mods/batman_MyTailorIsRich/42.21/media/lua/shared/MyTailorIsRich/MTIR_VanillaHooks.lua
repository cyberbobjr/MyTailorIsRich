-- ============================================================================
-- My Tailor Is Rich — hooks sur les actions vanilla (partagés)
--
-- En 42.21, complete() fait le vrai travail (serveur en MP, local en solo)
-- et s'exécute après perform() quoi qu'il arrive : refuser un vêtement se
-- fait dans isValid(), pas dans perform().
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISWearClothing"
require "TimedActions/ISUnequipAction"
require "TimedActions/ISRepairClothing"
require "TimedActions/ISRemovePatch"
require "TimedActions/ISFitnessAction"
require "Entity/TimedActions/ISHandcraftAction"
require "ActionManager"

if MTIR.vanillaHooksInstalled then
    return
end
MTIR.vanillaHooksInstalled = true

-- ----------------------------------------------------------------------------
-- Enfiler un vêtement
-- ----------------------------------------------------------------------------

local function refuseWear(action, fx)
    if action.mtirRefused then
        return
    end
    action.mtirRefused = true
    MTIR.tell(action.character, fx)
end

--- Chaussure trop petite de 3 pointures ou plus : impossible à enfiler.
local function isValidShoe(action)
    local item = action.item
    local data = MTIR.getShoeData(item)
    if not data and MTIR.isAuthority() then
        data = MTIR.ensureShoeData(item)
        MTIR.syncItem(action.character, item)
    end
    if not data then
        return true
    end
    local diff = MTIR.getShoeDiff(item, MTIR.getPlayerShoeSize(action.character))
    if diff and diff <= MTIR.SHOE_TOO_TIGHT then
        if MTIR.isAuthority() and not data.hint then
            data.hint = true
            MTIR.syncItem(action.character, item)
        end
        refuseWear(action, { say = MTIR.pickShoeHintSay(diff), refresh = true })
        return false
    end
    return true
end

local wearIsValid = ISWearClothing.isValid
function ISWearClothing:isValid()
    if not wearIsValid(self) then
        return false
    end
    local item = self.item
    if MTIR.canShoeHaveSize(item) then
        return isValidShoe(self)
    end
    if not MTIR.canClothesHaveSize(item) then
        return true
    end

    local data = MTIR.getData(item)
    if not data and MTIR.isAuthority() then
        data = MTIR.ensureData(item)
        MTIR.syncItem(self.character, item)
    end
    if not data then
        -- Client MP sans taille connue : le serveur tranchera.
        return true
    end

    if not data.size then
        refuseWear(self, { say = { key = "IGUI_MTIR_Say_Unchosen_Clothes_Size" } })
        return false
    end

    local diff = MTIR.getItemDiff(item, MTIR.getPlayerSize(self.character))
    if diff and diff < -2 then
        if MTIR.isAuthority() and not data.hint then
            data.hint = true
            MTIR.syncItem(self.character, item)
        end
        refuseWear(self, { say = MTIR.pickHintSay(diff), refresh = true })
        return false
    end
    return true
end

local wearGetDuration = ISWearClothing.getDuration
function ISWearClothing:getDuration()
    local duration = wearGetDuration(self)
    if duration <= 1 or not self.item then
        return duration
    end
    if MTIR.canShoeHaveSize(self.item) then
        local shoeDiff = MTIR.getShoeDiff(self.item, MTIR.getPlayerShoeSize(self.character))
        if shoeDiff and shoeDiff < 0 then
            -- Chaussure serrée : plus longue à enfiler.
            return duration * (1 + 0.25 * math.abs(shoeDiff))
        end
        return duration
    end
    if not MTIR.canClothesHaveSize(self.item) then
        return duration
    end
    local diff = MTIR.getItemDiff(self.item, MTIR.getPlayerSize(self.character))
    if not diff or diff == 0 then
        return duration
    end
    if diff < 0 then
        -- Plus c'est petit, plus c'est long à enfiler.
        return duration * (1 + 0.25 * 2 ^ (math.abs(diff) - 1))
    end
    -- Plus c'est grand, plus c'est rapide.
    return duration * math.max(0.1, 1 - 0.1 * diff)
end

local wearComplete = ISWearClothing.complete
function ISWearClothing:complete()
    local result = wearComplete(self)
    local item, character = self.item, self.character
    if not result or not item then
        return result
    end
    if MTIR.canShoeHaveSize(item) then
        local shoeData = MTIR.ensureShoeData(item)
        if shoeData and not shoeData.reveal and not shoeData.hint then
            shoeData.hint = true
            MTIR.syncItem(character, item)
            local shoeDiff = MTIR.getShoeDiff(item, MTIR.getPlayerShoeSize(character))
            if shoeDiff then
                MTIR.tell(character, { say = MTIR.pickShoeHintSay(shoeDiff), refresh = true })
            end
        end
    elseif MTIR.canClothesHaveSize(item) then
        local data = MTIR.ensureData(item)
        if data and data.size and not data.reveal and not data.hint then
            -- Une fois enfilé, le personnage devine à peu près la taille.
            data.hint = true
            MTIR.syncItem(character, item)
            local diff = MTIR.getItemDiff(item, MTIR.getPlayerSize(character))
            if diff then
                MTIR.tell(character, { say = MTIR.pickHintSay(diff), refresh = true })
            end
        end
    end
    MTIR.updateOneClothes(item, character)
    return result
end

-- ----------------------------------------------------------------------------
-- Retirer un vêtement : rendre ses stats d'origine
-- ----------------------------------------------------------------------------

local unequipComplete = ISUnequipAction.complete
function ISUnequipAction:complete()
    local result = unequipComplete(self)
    if self.item and instanceof(self.item, "Clothing") then
        MTIR.updateOneClothes(self.item, self.character)
    end
    return result
end

local unequipPerform = ISUnequipAction.perform
function ISUnequipAction:perform()
    local result = unequipPerform(self)
    -- Client MP : copie locale, pour l'affichage.
    if isClient() and self.item and instanceof(self.item, "Clothing") then
        MTIR.updateOneClothes(self.item, self.character)
    end
    return result
end

-- ----------------------------------------------------------------------------
-- Rustines : l'usure est gérée par le mod, poser ou retirer une rustine
-- ne change plus l'état du vêtement.
-- ----------------------------------------------------------------------------

local function keepCondition(original)
    return function(self)
        local clothing = self.clothing
        if not clothing or not MTIR.canClothesDegrade(clothing) then
            return original(self)
        end
        local condition = clothing:getCondition()
        local result = original(self)
        clothing:setCondition(condition)
        MTIR.syncItem(self.character, clothing)
        return result
    end
end

ISRepairClothing.complete = keepCondition(ISRepairClothing.complete)
ISRemovePatch.complete = keepCondition(ISRemovePatch.complete)

-- ----------------------------------------------------------------------------
-- Exercice en vêtement serré : raideur supplémentaire (autorité)
-- ----------------------------------------------------------------------------

local fitnessExeLooped = ISFitnessAction.exeLooped
function ISFitnessAction:exeLooped()
    fitnessExeLooped(self)
    if MTIR.isAuthority() and self.exeData then
        MTIR.applyExerciseStiffness(self.character, self.exeData.stiffness)
    end
end

-- ----------------------------------------------------------------------------
-- Artisanat : le vêtement fabriqué reçoit la taille choisie, révélée.
-- Sans choix transmis par le client, la taille reste à choisir (size = nil).
-- ----------------------------------------------------------------------------

local craftDepth = 0
local originalAddOrDropItem = nil

local function installCraftSizing(character)
    originalAddOrDropItem = Actions.addOrDropItem
    Actions.addOrDropItem = function(target, item, ...)
        if MTIR.canShoeHaveSize(item) and not MTIR.getShoeData(item) then
            -- Chaussure fabriquée : faite à la pointure de l'artisan.
            item:getModData()[MTIR.SHOE_DATA_KEY] = {
                size = MTIR.getPlayerShoeSize(character),
                reveal = true,
                hint = true,
            }
        elseif MTIR.canClothesHaveSize(item) and not MTIR.getData(item) then
            item:getModData()[MTIR.DATA_KEY] = {
                size = MTIR.getCraftSizeFor(character, item:getFullType()),
                reveal = true,
                hint = true,
                resized = 0,
            }
        end
        return originalAddOrDropItem(target, item, ...)
    end
end

local handcraftPerformRecipe = ISHandcraftAction.performRecipe
function ISHandcraftAction:performRecipe()
    if craftDepth == 0 then
        installCraftSizing(self.character)
    end
    craftDepth = craftDepth + 1
    local ok, err = pcall(handcraftPerformRecipe, self)
    craftDepth = craftDepth - 1
    if craftDepth == 0 and originalAddOrDropItem then
        Actions.addOrDropItem = originalAddOrDropItem
        originalAddOrDropItem = nil
    end
    if not ok then
        error(err)
    end
end

-- ----------------------------------------------------------------------------
-- Tenue modifiée : recalcul des stats dérivées
-- (autorité, ou client MP pour son propre personnage)
-- ----------------------------------------------------------------------------

local function onClothingUpdated(character)
    if not instanceof(character, "IsoPlayer") then
        return
    end
    if MTIR.isAuthority() or character:isLocalPlayer() then
        MTIR.applyDerivedStats(character)
    end
end

Events.OnClothingUpdated.Add(onClothingUpdated)
