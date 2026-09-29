-- ============================================================================
-- My Tailor Is Rich — outil de débogage : fixer ou effacer une taille
-- mode = "clothes" (size = "XS".."XXL"), "shoe" (size = "35".."47"),
--        "clear" (efface taille et pointure : nouveau tirage au prochain usage).
-- Réservé au mode debug ou, en MP, à un rôle ayant Capability.EditItem :
-- le serveur revérifie dans complete().
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Effects"

MTIR_DebugSizeAction = ISBaseTimedAction:derive("MTIR_DebugSizeAction")

--- Validation partagée par isValid et complete (le serveur n'appelle pas isValid).
local function validate(self)
    return MTIR.canUseDebug(self.character) and MTIR.hasItem(self.character, self.item)
end

function MTIR_DebugSizeAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self)
end

function MTIR_DebugSizeAction:start()
    self.item = MTIR.resolveItem(self.character, self.item)
    self.started = true
end

function MTIR_DebugSizeAction:perform()
    self.started = false
    ISBaseTimedAction.perform(self)
end

local function applyDebugSize(item, mode, size)
    local modData = item:getModData()
    if mode == "clothes" and MTIR.canClothesHaveSize(item) and MTIR.SIZES[size] then
        modData[MTIR.DATA_KEY] = { size = size, reveal = true, hint = true, resized = 0 }
        return true
    end
    local shoeSize = tonumber(size)
    if mode == "shoe" and MTIR.canShoeHaveSize(item) and shoeSize
        and shoeSize >= MTIR.SHOE_MIN and shoeSize <= MTIR.SHOE_MAX then
        modData[MTIR.SHOE_DATA_KEY] = { size = shoeSize, reveal = true, hint = true }
        return true
    end
    if mode == "clear" then
        modData[MTIR.DATA_KEY] = nil
        modData[MTIR.SHOE_DATA_KEY] = nil
        return true
    end
    return false
end

function MTIR_DebugSizeAction:complete()
    local item, character = self.item, self.character
    if not validate(self) or not applyDebugSize(item, self.mode, self.size) then
        return false
    end
    MTIR.updateOneClothes(item, character)
    if character:isEquippedClothing(item) then
        MTIR.applyDerivedStats(character)
    end
    MTIR.syncItem(character, item)
    MTIR.tell(character, { refresh = true })
    return true
end

function MTIR_DebugSizeAction:getDuration()
    return 1
end

function MTIR_DebugSizeAction:new(character, item, mode, size)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.mode = mode
    o.size = size
    o.stopOnWalk = false
    o.stopOnRun = false
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
