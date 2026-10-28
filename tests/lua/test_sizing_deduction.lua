-- MTIR_Sizing : quels vêtements reçoivent une taille (C17, zone sans test).
-- Un emplacement connu décide seul ; un emplacement inventé par un mod est déduit des
-- parties du corps que le vêtement couvre ; les accessoires n'ont jamais de taille,
-- sauf si une option les force.

local T = {}

local PARTS

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing", NORMAL = "normal" }
    Perks = { Tailoring = "tailoring" }
    ScriptManager = { instance = { getItem = function() return nil end } }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    -- Clothing est un InventoryItem, comme dans le jeu.
    instanceof = function(o, class)
        return type(o) == "table"
            and (o.class == class or (class == "InventoryItem" and o.class == "Clothing"))
    end

    PARTS = {
        Torso_Upper = "Torso_Upper", Torso_Lower = "Torso_Lower",
        UpperArm_L = "UpperArm_L", UpperArm_R = "UpperArm_R",
        Groin = "Groin", UpperLeg_L = "UpperLeg_L", UpperLeg_R = "UpperLeg_R",
        Foot_L = "Foot_L", Foot_R = "Foot_R", Hand_L = "Hand_L", Head = "Head",
    }
    BloodBodyPartType = PARTS
    -- Le script donne ses « BloodClothingType » ; le moteur en déduit les parties
    -- couvertes. Ici le script porte directement la liste des parties.
    BloodClothingType = {
        getCoveredParts = function(parts)
            return {
                size = function() return #parts end,
                get = function(_, i) return parts[i + 1] end,
            }
        end,
    }

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Sizing.lua")
end

--- Script d'un vêtement : nom complet, emplacement du corps, parties couvertes.
local function script(fullName, location, covered, cosmetic)
    local parts = covered or {}
    return {
        class = "Script",
        getFullName = function() return fullName end,
        getItemType = function() return ItemType.CLOTHING end,
        isCosmetic = function() return cosmetic == true end,
        getBodyLocation = function() return location end,
        getBloodClothingType = function()
            if #parts == 0 then
                return { isEmpty = function() return true end }
            end
            parts.isEmpty = function() return false end
            return parts
        end,
    }
end

local function sizing(scriptItem)
    return MTIR.getSizing(scriptItem)
end

T["emplacement connu : le profil du vêtement, sans rien déduire"] = function()
    local result = sizing(script("Base.Tshirt_White", "Tshirt", { PARTS.Torso_Upper }))
    assertEq(result.kind, "clothes", "vêtement taillé")
    assertEq(result.slot.difficulty, 1, "t-shirt : difficulté 1")
    assertEq(result.slot.canDrop, false, "un haut ne tombe pas")

    assertEq(sizing(script("Base.Trousers", "Pants", { PARTS.Groin })).slot.canDrop, true,
        "un bas trop grand peut tomber")
    assertEq(sizing(script("Base.Dress_Normal", "Dress", { PARTS.Torso_Upper })).slot.difficulty, 3,
        "robe : difficulté 3")
end

T["emplacement shoes : une pointure"] = function()
    local boots = script("Base.Shoes_Boots", "Shoes", { PARTS.Foot_L, PARTS.Foot_R })
    assertEq(sizing(boots).kind, "shoe", "pointure")
    assertEq(sizing(boots).slot, nil, "aucun profil de vêtement")
end

T["emplacement inventé par un mod : déduit de ce qu'il couvre"] = function()
    local armour = script("Mod.LegPlate", "mod:legarmour", { PARTS.UpperLeg_L, PARTS.UpperLeg_R })
    assertEq(sizing(armour).kind, "clothes", "bas déduit")
    assertEq(sizing(armour).slot.incTrip, true, "profil bas")

    local coat = script("Mod.LongCoat", "mod:coat", { PARTS.Torso_Upper, PARTS.Groin })
    assertEq(sizing(coat).slot.difficulty, 3, "tenue complète déduite")

    local sleeves = script("Mod.Sleeves", "mod:sleeves", { PARTS.UpperArm_L, PARTS.UpperArm_R })
    assertEq(sizing(sleeves).slot.difficulty, 2, "deux bras : haut déduit")

    local greaves = script("Mod.Greaves", "mod:modboots", { PARTS.Foot_L, PARTS.Foot_R })
    assertEq(sizing(greaves).kind, "shoe", "pieds seuls : pointure")
end

T["un seul bras ou une main : aucune taille"] = function()
    assertEq(sizing(script("Mod.ArmGuard", "mod:armguard", { PARTS.UpperArm_L })), nil,
        "un seul bras ne suffit pas")
    assertEq(sizing(script("Mod.Mitten", "mod:mitten", { PARTS.Hand_L })), nil,
        "une main n'est pas une chaussure")
    assertEq(sizing(script("Mod.Weird", "mod:weird", { PARTS.Foot_L, PARTS.Hand_L })), nil,
        "pieds plus autre chose : rien")
end

T["accessoires et cosmétiques : jamais de taille"] = function()
    assertEq(sizing(script("Base.Hat_Army", "Hat", { PARTS.Head })), nil, "chapeau")
    assertEq(sizing(script("Mod.Holster", "mod:legholster", { PARTS.UpperLeg_L, PARTS.UpperLeg_R })),
        nil, "emplacement reconnu par le motif « holster »")
    assertEq(sizing(script("Base.MakeUp_Eyes", "mod:makeupeyes", { PARTS.Head }, true)), nil,
        "cosmétique")
    assertEq(sizing(script("Mod.Nowhere", nil, { PARTS.Torso_Upper })), nil, "sans emplacement")
end

T["sans partie couverte : aucune taille, sauf si une option le force"] = function()
    assertEq(sizing(script("Mod.Plate", "mod:plate", {})), nil, "rien de couvert")
    -- L emplacement est nomme sans son prefixe de module (MTIR.locKey le retire).
    SandboxVars.MyTailorIsRich.ExtraSizedLocations = "plate:2"
    local forced = sizing(script("Mod.Plate2", "mod:plate", {}))
    assertEq(forced.kind, "clothes", "emplacement forcé")
    assertEq(forced.slot.difficulty, 2, "difficulté de l'option")
    assertEq(forced.slot.canRip, false, "profil neutre : ne se déchire pas")
end

T["ListCustomClothes force un accessoire, ListExcludedClothes retire un vêtement"] = function()
    SandboxVars.MyTailorIsRich.ListCustomClothes = "Mod.Cape:3"
    ScriptManager.instance.getItem = function(_, name)
        if name == "Mod.Cape" then
            return { getItemType = function() return ItemType.CLOTHING end }
        end
        return nil
    end
    local cape = sizing(script("Mod.Cape", "Back", { PARTS.Torso_Upper }))
    assertEq(cape.kind, "clothes", "accessoire forcé par l'option")
    assertEq(cape.slot.difficulty, 3, "difficulté de l'option")

    SandboxVars.MyTailorIsRich.ListExcludedClothes = "Base.Tshirt_White"
    assertEq(sizing(script("Base.Tshirt_White", "Tshirt", { PARTS.Torso_Upper })), nil, "exclu")
end

T["le résultat est mis en cache par type, et oublié si une option change"] = function()
    local tshirt = script("Base.Tshirt_White", "Tshirt", { PARTS.Torso_Upper })
    assertEq(sizing(tshirt).kind, "clothes", "taillé")
    SandboxVars.MyTailorIsRich.ListExcludedClothes = "Base.Tshirt_White"
    assertEq(sizing(tshirt), nil, "option changée : nouvelle décision")
    SandboxVars.MyTailorIsRich.ListExcludedClothes = ""
    assertEq(sizing(tshirt).kind, "clothes", "exclusion retirée")
end

T["canClothesHaveSize n'accepte qu'un vrai vêtement d'inventaire"] = function()
    local def = script("Base.Tshirt_White", "Tshirt", { PARTS.Torso_Upper })
    local worn = { class = "Clothing", getScriptItem = function() return def end }
    assertTrue(MTIR.canClothesHaveSize(worn), "vêtement porté")
    assertEq(MTIR.canClothesHaveSize({ class = "InventoryItem" }), false,
        "objet qui n'est pas un vêtement")
    assertEq(MTIR.canClothesHaveSize(nil), false, "rien")
    assertTrue(MTIR.canOutputHaveSize(def), "sortie de recette")
end

return T
