-- MTIR_ClientFx : la taille choisie pour l'artisanat est renvoyée à l'autorité au
-- début de la fabrication (C11). Une commande Lua n'est pas ordonnée par rapport aux
-- paquets de l'action : sans ce renvoi, changer de taille puis coudre aussitôt
-- pouvait coudre l'ancienne taille.

local T = {}

local SENT, STARTED, PLAYER

function T.setup()
    SENT, STARTED = {}, 0
    ResourceType = { Item = "item", Entity = "entity" }
    ItemType = { CLOTHING = "clothing", NORMAL = "normal" }

    PLAYER = { local_ = true }
    function PLAYER:isLocalPlayer() return self.local_ end
    function getPlayer() return PLAYER end

    function sendClientCommand(player, module, command, args)
        table.insert(SENT, { player = player, module = module, command = command,
            fullType = args.fullType, size = args.size })
    end

    ISHandcraftAction = {
        start = function()
            STARTED = STARTED + 1
            return "vanilla"
        end,
    }

    MTIR = {
        NET_MODULE = "MTIR",
        SIZE_LIST = { { name = "S" }, { name = "M" }, { name = "L" } },
        getSizeIndex = function(name)
            for i, size in ipairs(MTIR.SIZE_LIST) do
                if size.name == name then return i end
            end
            return nil
        end,
        canOutputHaveSize = function(output) return output.sizable ~= false end,
        applyFxInstalled = true,
    }
    loadMod("client/MyTailorIsRich/MTIR_ClientFx.lua")
end

--- Liste à l'interface des listes Java (size / get à partir de 0).
local function javaList(values)
    return {
        size = function() return #values end,
        get = function(_, i) return values[i + 1] end,
    }
end

--- Sortie d'une recette : un script de ressource et les objets qu'il peut produire.
local function output(fullName, itemType, sizable)
    return {
        getFullName = function() return fullName end,
        getItemType = function() return itemType or ItemType.CLOTHING end,
        sizable = sizable,
    }
end

local function recipe(outputs, resourceType)
    local script = {
        getResourceType = function() return resourceType or ResourceType.Item end,
        getPossibleResultItems = function() return javaList(outputs) end,
    }
    return { getOutputs = function() return javaList({ script }) end }
end

--- Lance l'action vanilla enveloppée, comme le jeu au début de la fabrication.
local function startCraft(craftRecipe)
    return ISHandcraftAction.start({ character = PLAYER, craftRecipe = craftRecipe })
end

T["la taille choisie est renvoyée au début de la fabrication"] = function()
    MTIR.setUICraftSize("Base.Tshirt_White", "L")
    assertEq(#SENT, 1, "envoi au changement de taille")
    SENT = {}
    startCraft(recipe({ output("Base.Tshirt_White") }))
    assertEq(#SENT, 1, "renvoyée au début de l'action")
    assertEq(SENT[1].command, "setCraftSize", "même commande")
    assertEq(SENT[1].fullType, "Base.Tshirt_White", "type de sortie")
    assertEq(SENT[1].size, "L", "taille courante")
end

T["l'action vanilla est lancée et son résultat rendu"] = function()
    MTIR.setUICraftSize("Base.Tshirt_White", "M")
    assertEq(startCraft(recipe({ output("Base.Tshirt_White") })), "vanilla", "résultat vanilla")
    assertEq(STARTED, 1, "start vanilla appelé une fois")
end

T["rien à renvoyer si aucune taille n'a été choisie"] = function()
    startCraft(recipe({ output("Base.Tshirt_White") }))
    assertEq(#SENT, 0, "aucune commande")
end

T["sorties non vêtement ou sans taille possible ignorées"] = function()
    MTIR.setUICraftSize("Base.Hammer", "L")
    MTIR.setUICraftSize("Base.Bandana", "L")
    SENT = {}
    startCraft(recipe({ output("Base.Hammer", ItemType.NORMAL), output("Base.Bandana", nil, false) }))
    assertEq(#SENT, 0, "ni l'outil ni le vêtement sans taille")
end

T["sortie d'entité (établi) sans objet : aucun renvoi"] = function()
    MTIR.setUICraftSize("Base.Tshirt_White", "L")
    SENT = {}
    startCraft(recipe({ output("Base.Tshirt_White") }, ResourceType.Entity))
    assertEq(#SENT, 0, "sortie non objet ignorée")
end

T["personnage distant : aucun renvoi"] = function()
    MTIR.setUICraftSize("Base.Tshirt_White", "L")
    SENT = {}
    PLAYER.local_ = false
    startCraft(recipe({ output("Base.Tshirt_White") }))
    assertEq(#SENT, 0, "seul le joueur local envoie")
    assertEq(STARTED, 1, "l'action vanilla part quand même")
end

T["plusieurs vêtements produits : une taille chacun"] = function()
    MTIR.setUICraftSize("Base.Tshirt_White", "L")
    MTIR.setUICraftSize("Base.Trousers", "M")
    SENT = {}
    startCraft(recipe({ output("Base.Tshirt_White"), output("Base.Trousers") }))
    assertEq(#SENT, 2, "les deux renvoyées")
    assertEq(SENT[1].size .. SENT[2].size, "LM", "chacune sa taille")
end

return T
