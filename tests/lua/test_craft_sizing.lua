-- MTIR_VanillaHooks : taille du vêtement fabriqué (C17, zone sans test).
-- Pendant une fabrication, l'autorité remplace Actions.addOrDropItem : le vêtement
-- qui sort reçoit la taille choisie par le joueur, la chaussure la pointure de
-- l'artisan. Sans choix transmis, la taille reste à choisir.

local T = {}

local ADDED, CHARACTER

function T.setup()
    instanceof = function(o, class) return type(o) == "table" and o.class == class end
    isClient = function() return false end
    isServer = function() return true end

    -- Globales vanilla enveloppées par le fichier, réduites à ce qui est appelé ici.
    ISWearClothing = { isValid = function() return true end, getDuration = function() return 1 end,
        complete = function() return true end }
    ISUnequipAction = { complete = function() return true end, perform = function() end }
    ISRepairClothing = { complete = function() return true end }
    ISRemovePatch = { complete = function() return true end }
    ISFitnessAction = { exeLooped = function() end }

    ADDED = {}
    VANILLA_ADD = function(target, item)
        table.insert(ADDED, { target = target, item = item })
    end
    Actions = { addOrDropItem = VANILLA_ADD }

    -- La recette vanilla crée ses objets puis les donne par Actions.addOrDropItem.
    -- `nest` : une recette qui en déclenche une autre pendant sa propre fabrication,
    -- ce qui repasse par l'enveloppe du mod (craftDepth).
    OVERRIDE_INSIDE_NESTED = nil
    ISHandcraftAction = {
        performRecipe = function(self)
            for _, item in ipairs(self.outputs or {}) do
                Actions.addOrDropItem(self.character, item)
            end
            if self.nest then
                local nested = self.nest
                self.nest = nil
                ISHandcraftAction.performRecipe(nested)
                OVERRIDE_INSIDE_NESTED = Actions.addOrDropItem ~= VANILLA_ADD
            end
            if self.boom then
                error("recette en erreur")
            end
        end,
    }

    MTIR = {
        DATA_KEY = "MTIR",
        SHOE_DATA_KEY = "MTIR_Shoe",
        isAuthority = function() return true end,
        canShoeHaveSize = function(item) return item.kind == "shoe" end,
        canClothesHaveSize = function(item) return item.kind == "clothes" end,
        getShoeData = function(item) return item:getModData().MTIR_Shoe end,
        getData = function(item) return item:getModData().MTIR end,
        getPlayerShoeSize = function() return 41 end,
        getPlayerSize = function() return { name = "M" } end,
        applyDerivedStats = function() end,
        ServerCraftSize = {},
        playerKey = function() return "u" .. "Benjamin" end,
    }
    function MTIR.setCraftSizeFor(_, fullType, sizeName)
        MTIR.ServerCraftSize[fullType] = sizeName
    end
    function MTIR.getCraftSizeFor(_, fullType)
        return MTIR.ServerCraftSize[fullType]
    end

    loadMod("shared/MyTailorIsRich/MTIR_VanillaHooks.lua")

    CHARACTER = { class = "IsoPlayer", isLocalPlayer = function() return true end }
end

--- Objet fabriqué : vêtement ou chaussure, sans données du mod.
local function output(kind, fullType)
    local item = { kind = kind, modData = {} }
    function item:getModData() return self.modData end
    function item:getFullType() return fullType end
    return item
end

--- Fabrique les objets donnés, comme ISHandcraftAction:performRecipe en jeu.
local function craft(outputs, boom)
    local action = { character = CHARACTER, outputs = outputs, boom = boom }
    if boom then
        return pcall(ISHandcraftAction.performRecipe, action)
    end
    ISHandcraftAction.performRecipe(action)
    return true
end

T["le vêtement fabriqué prend la taille choisie, déjà lue"] = function()
    MTIR.setCraftSizeFor(CHARACTER, "Base.Tshirt_White", "L")
    local tshirt = output("clothes", "Base.Tshirt_White")
    craft({ tshirt })
    local data = tshirt.modData.MTIR
    assertEq(data.size, "L", "taille choisie")
    assertEq(data.reveal, true, "taille connue : c'est le joueur qui l'a faite")
    assertEq(data.hint, true, "ajustement connu")
    assertEq(data.resized, 0, "jamais retouché")
    assertEq(#ADDED, 1, "objet donné une fois")
end

T["sans taille transmise, la taille reste à choisir"] = function()
    local tshirt = output("clothes", "Base.Tshirt_White")
    craft({ tshirt })
    assertEq(tshirt.modData.MTIR.size, nil, "taille à choisir")
    assertEq(tshirt.modData.MTIR.reveal, true, "le reste est connu")
end

T["la chaussure fabriquée est à la pointure de l'artisan"] = function()
    local boots = output("shoe", "Base.Shoes_Boots")
    craft({ boots })
    local data = boots.modData.MTIR_Shoe
    assertEq(data.size, 41, "pointure de l'artisan")
    assertEq(data.reveal, true, "pointure connue")
    assertEq(data.hint, true, "ajustement connu")
end

T["un objet qui a déjà ses données n'est pas retouché"] = function()
    local tshirt = output("clothes", "Base.Tshirt_White")
    tshirt.modData.MTIR = { size = "S", reveal = false, hint = false, resized = 2 }
    MTIR.setCraftSizeFor(CHARACTER, "Base.Tshirt_White", "L")
    craft({ tshirt })
    assertEq(tshirt.modData.MTIR.size, "S", "taille gardée")
    assertEq(tshirt.modData.MTIR.resized, 2, "retouches gardées")
end

T["un objet sans taille possible passe sans rien recevoir"] = function()
    local hammer = output("tool", "Base.Hammer")
    craft({ hammer })
    assertEq(hammer.modData.MTIR, nil, "aucune donnée de taille")
    assertEq(hammer.modData.MTIR_Shoe, nil, "aucune pointure")
    assertEq(#ADDED, 1, "objet donné quand même")
end

T["la fonction vanilla est rendue après la fabrication, même en erreur"] = function()
    local original = Actions.addOrDropItem
    craft({ output("clothes", "Base.Tshirt_White") })
    assertEq(Actions.addOrDropItem, original, "rendue après une fabrication normale")

    local ok = craft({ output("clothes", "Base.Tshirt_White") }, true)
    assertEq(ok, false, "l'erreur de la recette est relancée")
    assertEq(Actions.addOrDropItem, original, "rendue malgré l'erreur")
end

T["fabrication imbriquée : la fonction vanilla n'est rendue qu'à la fin"] = function()
    MTIR.setCraftSizeFor(CHARACTER, "Base.Trousers", "S")
    local inner = output("clothes", "Base.Trousers")
    ISHandcraftAction.performRecipe({
        character = CHARACTER,
        outputs = { output("clothes", "Base.Tshirt_White") },
        nest = { character = CHARACTER, outputs = { inner } },
    })
    assertEq(inner.modData.MTIR.size, "S", "la recette imbriquée a aussi reçu sa taille")
    assertEq(OVERRIDE_INSIDE_NESTED, true, "encore remplacée après la recette imbriquée")
    assertEq(Actions.addOrDropItem, VANILLA_ADD, "rendue à la fin")
end

return T
