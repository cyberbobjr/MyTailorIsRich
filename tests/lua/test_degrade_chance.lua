-- MTIR_Effects : chance d'usure d'un vêtement porté (C17, zone sans test).
-- Un vêtement sale, mouillé ou ensanglanté s'abîme plus vite ; un vêtement protecteur
-- ou imperméable, une haute compétence et une bonne taille le freinent. L'option
-- ClothesDegradingChance multiplie le tout.

local T = {}

local PLAYER, STATS

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing" }
    Perks = { Tailoring = "tailoring", Maintenance = "maintenance" }
    ScriptManager = { instance = { getItem = function() return nil end } }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class)
        return type(o) == "table" and (o.class == class
            or (class == "InventoryItem" and o.class == "Clothing"))
    end
    isServer = function() return false end
    isClient = function() return false end
    ZombRandFloat = function() return 0 end

    -- Valeurs du script de l'objet, lues sur une instance et mises en cache par type.
    STATS = { biteDefense = 0, scratchDefense = 0, bulletDefense = 0,
        windResistance = 0, waterResistance = 0, insulation = 0, combatSpeed = 1 }
    instanceItem = function()
        return {
            getBiteDefense = function() return STATS.biteDefense end,
            getScratchDefense = function() return STATS.scratchDefense end,
            getBulletDefense = function() return STATS.bulletDefense end,
            getWindresistance = function() return STATS.windResistance end,
            getWaterResistance = function() return STATS.waterResistance end,
            getCombatSpeedModifier = function() return STATS.combatSpeed end,
        }
    end

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Effects.lua")
    -- Taille du vêtement : fournie par le banc (MTIR_Sizing et MTIR_Shoes non chargés).
    MTIR.canClothesHaveSize = function() return true end
    MTIR.getPlayerSize = function() return { name = "M" } end
    MTIR.getItemDiff = function(item) return item.diff end

    PLAYER = { tailoring = 0, maintenance = 0 }
    function PLAYER:getPerkLevel(perk)
        return perk == Perks.Tailoring and self.tailoring or self.maintenance
    end
end

--- Vêtement porté : état de saleté, de sang, d'humidité et écart de taille.
local function garment(fields)
    local item = fields or {}
    item.class = "Clothing"
    item.id = item.id or 1
    function item:getFullType() return "Base.Tshirt_White" .. tostring(self.id) end
    function item:getID() return self.id end
    function item:getDirtiness() return self.dirty or 0 end
    function item:getBloodLevel() return self.blood or 0 end
    function item:getWetness() return self.wet or 0 end
    return item
end

local function chance(item)
    return MTIR.calcDegradeChance(item, PLAYER)
end

T["les jours min et max de l'option fixent la chance de base"] = function()
    local base = chance(garment({ id = 1, diff = 0 }))
    assertTrue(base > 0, "une chance existe")

    SandboxVars.MyTailorIsRich.MinDaysToDegrade = 10
    SandboxVars.MyTailorIsRich.MaxDaysToDegrade = 20
    assertTrue(chance(garment({ id = 2, diff = 0 })) > base, "des vêtements qui durent moins")

    -- Bornes inversées : le mod revient aux 30 et 360 jours par défaut.
    SandboxVars.MyTailorIsRich.MinDaysToDegrade = 400
    SandboxVars.MyTailorIsRich.MaxDaysToDegrade = 10
    assertEq(chance(garment({ id = 3, diff = 0 })), base, "bornes inversées : valeurs par défaut")
end

T["l'état du vêtement : seul le sang pèse vraiment"] = function()
    local base = chance(garment({ id = 1, diff = 0 }))
    -- Saleté, sang et humidité se lisent de 0 à 100. Formule d'origine :
    -- (sang x 4 + humidité x 2 + saleté) / 7, seuil de 0,25, puis mise au cube.
    -- La boue seule (1/7) n'atteint pas le seuil et la pluie seule (2/7) le dépasse
    -- de si peu que rien ne change : il faut du sang, ou les trois à la fois.
    assertEq(chance(garment({ id = 2, diff = 0, dirty = 100 })), base, "couvert de boue : rien")
    assertTrue(chance(garment({ id = 3, diff = 0, wet = 100 })) - base < base * 0.001,
        "trempé de pluie : à peine plus")
    assertTrue(chance(garment({ id = 4, diff = 0, blood = 100 })) > base * 1.03, "ensanglanté")
    assertTrue(chance(garment({ id = 5, diff = 0, blood = 100, wet = 100, dirty = 100 }))
        > base * 1.4, "sang, pluie et boue : moitié plus vite")
end

T["compétences : Entretien et Couture freinent l'usure"] = function()
    local base = chance(garment({ id = 1, diff = 0 }))
    PLAYER.tailoring = 10
    local withTailoring = chance(garment({ id = 2, diff = 0 }))
    assertTrue(withTailoring < base, "Couture 10")
    PLAYER.tailoring = 0
    PLAYER.maintenance = 10
    local withMaintenance = chance(garment({ id = 3, diff = 0 }))
    assertTrue(withMaintenance < withTailoring, "Entretien compte double")
end

T["un vêtement trop petit s'abîme plus vite, trop grand ne change rien"] = function()
    local base = chance(garment({ id = 1, diff = 0 }))
    assertTrue(chance(garment({ id = 2, diff = -1 })) > base, "une taille trop petit")
    assertTrue(chance(garment({ id = 3, diff = -2 })) > chance(garment({ id = 4, diff = -1 })),
        "deux tailles trop petit")
    assertEq(chance(garment({ id = 5, diff = -3 })), chance(garment({ id = 6, diff = -2 })),
        "au-delà de deux tailles : plafonné")
    assertEq(chance(garment({ id = 7, diff = 2 })), base, "trop grand : aucun effet")
end

T["protection et imperméabilité freinent l'usure"] = function()
    local base = chance(garment({ id = 1, diff = 0 }))
    STATS.biteDefense = 100
    local armoured = chance(garment({ id = 2, diff = 0 }))
    assertTrue(armoured < base, "vêtement protecteur")
    STATS.biteDefense = 0
    STATS.waterResistance = 1
    STATS.windResistance = 1  -- résistances de 0 à 1, contrairement aux défenses
    assertTrue(chance(garment({ id = 3, diff = 0 })) < base, "vêtement imperméable")
end

T["la chance est gardée pour l'infobulle"] = function()
    local item = garment({ id = 42, diff = 0 })
    local value = chance(item)
    assertEq(MTIR.DegradingChance[42], value, "rangée sous l'identifiant de l'objet")
end

return T
