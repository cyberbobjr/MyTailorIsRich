-- MTIR_VanillaHooks : refus d'enfiler une chaussure trop petite (3 pointures ou
-- plus) ou un vêtement trop petit, refait dans complete() avant l'enfilage
-- vanilla : le serveur MP n'appelle jamais isValid (NetTimedAction).
-- ISWearClothing vanilla 42.21 chargé tel quel.

local T = {}
T.skip = not hasVanilla and "jeu absent : définir PZ_MEDIA" or nil

--- Objet simulé : chaussure ou vêtement, avec la catégorie et l'emplacement du vanilla.
local function newItem(kind, diff)
    local item = { kind = kind, diff = diff, modData = {} }
    function item:isBroken() return false end
    function item:hasTag() return false end
    function item:getCategory() return "Clothing" end
    function item:getBodyLocation() return kind == "shoe" and "Shoes" or "Tshirt" end
    function item:canBeEquipped() return "" end
    function item:getModData() return self.modData end
    return item
end

local function newCharacter()
    local character = { worn = {}, inventoryItems = {} }
    function character:getWornItem(location) return self.worn[location] end
    function character:setWornItem(location, item) self.worn[location] = item end
    function character:getHumanVisual()
        return { getHairModel = function() return { contains = function() return false end } end }
    end
    function character:getInventory()
        local owner = self
        return { contains = function(_, item) return owner.inventoryItems[item] == true end }
    end
    return character
end

function T.setup()
    isClient = function() return false end
    isServer = function() return true end
    instanceof = function() return false end
    ItemTag = { REPLACE_PRIMARY = "base:replaceprimary" }
    ItemBodyLocation = setmetatable({}, { __index = function(_, key) return key end })
    ISBaseTimedAction = { derive = function(_, type) return { Type = type } end }
    loadVanilla("shared/TimedActions/ISWearClothing.lua")
    -- Hooks voisins du fichier (non testés ici).
    ISUnequipAction = { complete = function() return true end, perform = function() end }
    ISRepairClothing = { complete = function() return true end }
    ISRemovePatch = { complete = function() return true end }
    ISFitnessAction = { exeLooped = function() end }
    ISHandcraftAction = { performRecipe = function() end }

    told = {}
    synced = 0
    MTIR = {
        SHOE_TOO_TIGHT = -3,
        isAuthority = function() return not isClient() end,
        canShoeHaveSize = function(item) return item.kind == "shoe" end,
        canClothesHaveSize = function(item) return item.kind == "clothes" end,
        getShoeData = function(item) return item.modData.shoe end,
        ensureShoeData = function(item)
            item.modData.shoe = item.modData.shoe or { size = 42 }
            return item.modData.shoe
        end,
        getData = function(item) return item.modData.size end,
        ensureData = function(item)
            item.modData.size = item.modData.size or { size = "M" }
            return item.modData.size
        end,
        getShoeDiff = function(item) return item.diff end,
        getItemDiff = function(item) return item.diff end,
        getPlayerShoeSize = function() return 42 end,
        getPlayerSize = function() return "M" end,
        pickShoeHintSay = function(diff) return { key = "shoe", arg = diff } end,
        pickHintSay = function(diff) return { key = "clothes", arg = diff } end,
        tell = function(_, fx) table.insert(told, fx) end,
        syncItem = function() synced = synced + 1 end,
        updateOneClothes = function() end,
    }
    loadMod("shared/MyTailorIsRich/MTIR_VanillaHooks.lua")
end

local function action(item, character)
    return setmetatable({ item = item, character = character }, { __index = ISWearClothing })
end

T["serveur MP : chaussure trop petite de 3 pointures refusée dans complete"] = function()
    local character = newCharacter()
    local shoe = newItem("shoe", -3)
    local result = action(shoe, character):complete()
    assertEq(result, false, "complete refuse")
    assertEq(character.worn.Shoes, nil, "rien n'est enfilé")
    assertEq(#told, 1, "joueur prévenu une fois")
    assertEq(told[1].say.key, "shoe", "phrase de chaussure")
    assertEq(shoe.modData.shoe.hint, true, "indice de pointure révélé")
    assertTrue(synced > 0, "données synchronisées")
end

T["serveur MP : chaussure trop petite de 2 pointures enfilée"] = function()
    local character = newCharacter()
    local shoe = newItem("shoe", -2)
    assertEq(action(shoe, character):complete(), true, "complete enfile")
    assertEq(character.worn.Shoes, shoe, "chaussure portée")
end

T["serveur MP : vêtement trop petit de 3 tailles refusé, 2 tailles enfilé"] = function()
    local character = newCharacter()
    local tight = newItem("clothes", -3)
    assertEq(action(tight, character):complete(), false, "refusé")
    assertEq(character.worn.Tshirt, nil, "rien n'est enfilé")
    assertEq(told[1].say.key, "clothes", "phrase de vêtement")
    local ok = newItem("clothes", -2)
    assertEq(action(ok, character):complete(), true, "enfilé")
    assertEq(character.worn.Tshirt, ok, "vêtement porté")
end

T["serveur MP : taille à choisir refusée"] = function()
    local character = newCharacter()
    local item = newItem("clothes", 0)
    item.modData.size = { size = nil }
    assertEq(action(item, character):complete(), false, "refusé")
    assertEq(told[1].say.key, "IGUI_MTIR_Say_Unchosen_Clothes_Size", "taille à choisir")
end

T["objet déjà porté : comportement vanilla, aucun refus"] = function()
    local character = newCharacter()
    local shoe = newItem("shoe", -4)
    character.worn.Shoes = shoe
    assertEq(action(shoe, character):complete(), false, "vanilla : déjà porté")
    assertEq(#told, 0, "aucun message")
end

T["solo : isValid refuse, et un seul message même si complete suit"] = function()
    isServer = function() return false end
    local character = newCharacter()
    local shoe = newItem("shoe", -3)
    character.inventoryItems[shoe] = true
    local wear = action(shoe, character)
    assertEq(wear:isValid(), false, "isValid refuse")
    assertEq(wear:complete(), false, "complete refuse aussi")
    assertEq(#told, 1, "un seul message")
    local fine = newItem("shoe", 0)
    character.inventoryItems[fine] = true
    assertEq(action(fine, character):isValid(), true, "chaussure à la pointure")
end

T["client MP sans données : isValid laisse le serveur trancher"] = function()
    isClient = function() return true end
    isServer = function() return false end
    local shoe = newItem("shoe", -3)
    assertEq(action(shoe, newCharacter()):isValid(), true, "pas de données côté client")
    assertEq(#told, 0, "aucun message")
end

return T
