-- MTIR_ServerTranslations : rechargement des traductions sur un serveur MP qui
-- les a lues avant de charger les mods (clés brutes), et migration des noms de
-- patrons enregistrés en clé brute dans les inventaires des joueurs connectés.

local T = {}

local PATTERN_ITEM = "Base.MTIR_TailorPattern"

local function newItem(fullType, name, modData)
    local item = { fullType = fullType, name = name, modData = modData or {} }
    function item:getFullType() return self.fullType end
    function item:getName() return self.name end
    function item:setName(value) self.name = value end
    function item:setCustomName(value) self.customName = value end
    function item:getModData() return self.modData end
    function item:hasModData() return true end
    return item
end

--- ArrayList simulée (index 0).
local function arrayList(values)
    return { size = function() return #values end, get = function(_, i) return values[i + 1] end }
end

function T.setup()
    isClient = function() return false end
    isServer = function() return true end
    LOADED = false
    RELOADS = 0
    getTextOrNull = function(key, arg)
        if not LOADED then
            return nil
        end
        if key == "IGUI_MTIR_Hint_Fit" then
            return "(Fit)"
        end
        if key == "IGUI_MTIR_PatternName" then
            return "Pattern: " .. tostring(arg)
        end
        return nil
    end
    getItemNameFromFullType = function(fullType) return fullType end
    Translator = { loadFiles = function()
        RELOADS = RELOADS + 1
        LOADED = true
    end }
    MTIR = { opt = function() return 20 end }
    loadMod("shared/MyTailorIsRich/MTIR_Patterns.lua")
    synced = {}
    MTIR.syncItem = function(_, item) table.insert(synced, item) end
    loadMod("shared/MyTailorIsRich/MTIR_PatternBinder.lua")
end

T["traductions du mod rechargées une fois au chargement"] = function()
    loadMod("server/MyTailorIsRich/MTIR_ServerTranslations.lua")
    assertEq(RELOADS, 1, "un rechargement au chargement du fichier")
    assertEq(MTIR.ServerTranslations.ensure(), false, "déjà présentes : rien à refaire")
    assertEq(RELOADS, 1, "pas de second rechargement")
    assertEq(listenerCount("EveryTenMinutes"), 1, "migration périodique sur le serveur")
end

T["solo ou traductions déjà lues : aucun rechargement"] = function()
    LOADED = true
    isServer = function() return false end
    loadMod("server/MyTailorIsRich/MTIR_ServerTranslations.lua")
    assertEq(RELOADS, 0, "aucun rechargement")
    assertEq(listenerCount("EveryTenMinutes"), 0, "pas de migration en solo")
end

T["client : rien"] = function()
    isClient = function() return true end
    loadMod("server/MyTailorIsRich/MTIR_ServerTranslations.lua")
    assertEq(RELOADS, 0, "client : rien")
    assertEq(MTIR.ServerTranslations, nil, "module absent côté client")
end

T["migration : patrons des joueurs connectés renommés et synchronisés"] = function()
    loadMod("server/MyTailorIsRich/MTIR_ServerTranslations.lua")
    local raw = newItem(PATTERN_ITEM, "IGUI_MTIR_PatternName", { MTIR_Pattern = { fullType = "Base.Jeans",
        kind = "clothes" } })
    local fine = newItem(PATTERN_ITEM, "Pattern: Shirt", { MTIR_Pattern = { fullType = "Base.Shirt",
        kind = "clothes" } })
    local other = newItem("Base.Apple", "IGUI_MTIR_Whatever")
    local all = { raw, fine, other }
    local inventory = { getAllEvalRecurse = function(_, predicate)
        local found = {}
        for _, item in ipairs(all) do
            if predicate(item) then
                table.insert(found, item)
            end
        end
        return arrayList(found)
    end }
    local player = { getInventory = function() return inventory end, isDead = function() return false end,
        getUsername = function() return "bob" end }
    getOnlinePlayers = function() return arrayList({ player }) end
    triggerEvent("EveryTenMinutes")
    assertEq(raw.name, "Pattern: Base.Jeans", "nom recalculé")
    assertEq(fine.name, "Pattern: Shirt", "nom ordinaire intact")
    assertEq(other.name, "IGUI_MTIR_Whatever", "objet hors du mod intact")
    assertEq(#synced, 1, "seul l'objet corrigé est synchronisé")
    assertEq(synced[1], raw, "objet synchronisé")
    triggerEvent("EveryTenMinutes")
    assertEq(#synced, 1, "rien de plus au passage suivant")
end

return T
