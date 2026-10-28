-- MTIR_ShoeEffects : effets continus d'une paire mal ajustée (C17, zone sans test).
-- Trop petites : ampoules en marchant, plus vite en courant. Trop grandes :
-- endurance consommée en plus et chaussure qui finit par partir.

local T = {}

local PLAYER, SAID, DROPPED, ROLL

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemBodyLocation = { SHOES = "shoes" }
    CharacterTrait = { DESENSITIZED = "desensitized" }
    CharacterStat = { DISCOMFORT = "discomfort", ENDURANCE = "endurance" }
    BodyPartType = { Foot_L = "Foot_L", Foot_R = "Foot_R" }
    SyncPlayerStatsPacket = { getBitMaskForStat = function() return 0 end }
    ZomboidGlobals = { RunningEnduranceReduce = 0.0003, SprintingEnduranceReduce = 0.0009 }
    ItemType = { CLOTHING = "clothing" }
    ScriptManager = { instance = { getItem = function() return nil end } }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class) return type(o) == "table" and o.class == class end
    isServer = function() return false end
    isClient = function() return false end
    isDebugEnabled = function() return false end
    ZombRand = function() return 0 end
    ROLL = 0.99
    ZombRandFloat = function() return ROLL end

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Sizing.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Shoes.lua")
    loadMod("shared/MyTailorIsRich/MTIR_ShoeEffects.lua")

    -- Pointure du personnage et écart de la paire : fournis par le banc.
    -- MTIR_Effects n est pas charge ici : cle du joueur comme en solo.
    MTIR.playerKey = function(player) return "p" .. tostring(player:getPlayerNum()) end
    MTIR.canShoeHaveSize = function(item) return item ~= nil end
    MTIR.getPlayerShoeSize = function() return 43 end
    MTIR.getShoeDiff = function(shoe) return shoe.diff end
    SAID, DROPPED = {}, {}
    MTIR.tell = function(_, fx) table.insert(SAID, fx) end
    MTIR.dropWornItem = function(shoe) table.insert(DROPPED, shoe); return true end

    PLAYER = { traits = {}, discomfort = 0, endurance = 1, scratched = {} }
    function PLAYER:getWornItem(location)
        if self.shoe and location == ItemBodyLocation.SHOES then return self.shoe end
        return nil
    end
    function PLAYER:getWornItems()
        local shoe = self.shoe
        return {
            size = function() return shoe and 1 or 0 end,
            getItemByIndex = function() return shoe end,
        }
    end
    function PLAYER:hasTrait(trait) return self.traits[trait] == true end
    function PLAYER:getPlayerNum() return 0 end
    function PLAYER:isPlayerMoving() return (self.pace or 0) > 0 end
    function PLAYER:isRunning() return (self.pace or 0) == 2 end
    function PLAYER:isSprinting() return (self.pace or 0) == 3 end
    function PLAYER:getStats()
        local owner = self
        return {
            get = function(_, stat) return stat == CharacterStat.DISCOMFORT and owner.discomfort or 0 end,
            set = function() end,
            remove = function(_, stat, amount)
                if stat == CharacterStat.ENDURANCE then owner.endurance = owner.endurance - amount end
            end,
        }
    end
    function PLAYER:getBodyDamage()
        local owner = self
        return {
            getBodyPart = function(_, part)
                return {
                    scratched = function() return owner.scratched[part] == true end,
                    setScratched = function() owner.scratched[part] = true end,
                }
            end,
        }
    end
end

--- Chausse la paire d'écart `diff` (nil : pieds nus) et avance `minutes` à l'allure
--- donnée (0 immobile, 1 marche, 2 course, 3 sprint).
local function wear(diff, fullType)
    PLAYER.shoe = diff and { diff = diff, getFullType = function() return fullType or "Base.Shoes_Random" end } or nil
end

local function move(pace, minutes)
    PLAYER.pace = pace
    MTIR.applyShoeTick(PLAYER, 1, minutes)
end

local function friction()
    return MTIR.getFriction(PLAYER)
end

local function scratchedFeet()
    local n = 0
    for _ in pairs(PLAYER.scratched) do n = n + 1 end
    return n
end

T["deux pointures trop petites : ampoule après 45 minutes de marche"] = function()
    wear(-2)
    move(1, 44)
    assertEq(scratchedFeet(), 0, "pas encore d'ampoule")
    assertTrue(friction() > 0.9, "jauge presque pleine")
    move(1, 2)
    assertEq(scratchedFeet(), 1, "ampoule à un pied")
    assertEq(friction(), 0, "jauge remise à zéro")
end

T["courir et sprinter remplissent la jauge plus vite"] = function()
    wear(-2)
    move(2, 15)
    assertEq(scratchedFeet(), 1, "15 minutes de course suffisent")
    wear(-1)
    move(3, 30)
    assertEq(scratchedFeet(), 2, "une pointure trop petite : 30 minutes de sprint")
end

T["avertissement à mi-jauge, une seule fois"] = function()
    wear(-2)
    move(1, 23)
    assertEq(#SAID, 1, "les pieds chauffent")
    move(1, 5)
    assertEq(#SAID, 1, "pas répété")
end

T["bonne pointure, pieds nus ou immobile : la jauge redescend"] = function()
    wear(-2)
    move(1, 30)
    assertTrue(friction() > 0.6, "jauge montée")
    wear(0)
    move(1, 30)
    assertTrue(friction() < 0.2, "bonne pointure : elle redescend")
    wear(-2)
    move(1, 30)
    move(0, 60)
    assertEq(friction(), 0, "une heure au repos vide la jauge")
end

T["trop grandes : rien en marchant, ampoule en courant longtemps"] = function()
    wear(2)
    move(1, 200)
    assertEq(scratchedFeet(), 0, "le talon ne frotte pas à la marche")
    assertEq(friction(), 0, "aucune jauge")
    move(2, 90)
    assertEq(scratchedFeet(), 1, "90 minutes de course")
end

T["endurance consommée en plus seulement à partir de deux pointures de trop"] = function()
    wear(1)
    move(2, 10)
    assertEq(PLAYER.endurance, 1, "une pointure de trop : rien")
    wear(2)
    move(2, 10)
    assertTrue(PLAYER.endurance < 1, "deux de trop : endurance entamée en courant")
    local afterRun = PLAYER.endurance
    wear(2)
    move(1, 10)
    assertEq(PLAYER.endurance, afterRun, "à la marche : rien")
end

T["chaussure trop grande perdue en courant, jamais en marchant"] = function()
    ROLL = 0.0
    wear(3)
    move(1, 10)
    assertEq(#DROPPED, 0, "la marche ne fait rien perdre")
    move(2, 10)
    assertEq(#DROPPED, 1, "perdue en courant")
end

T["chance de perte sur un franchissement : modèle et écart comptent"] = function()
    wear(2, "Base.Shoes_ArmyBoots")
    local boots = MTIR.getShoeLossChance(PLAYER, "fence")
    wear(2, "Base.Shoes_FlipFlop")
    local flipFlops = MTIR.getShoeLossChance(PLAYER, "fence")
    assertTrue(flipFlops > boots, "tongs plus glissantes que des rangers")
    wear(4, "Base.Shoes_FlipFlop")
    assertTrue(MTIR.getShoeLossChance(PLAYER, "fence") > flipFlops, "plus grandes, plus de risque")
    wear(1, "Base.Shoes_FlipFlop")
    assertEq(MTIR.getShoeLossChance(PLAYER, "fence"), 0, "une pointure de trop : aucun risque")
    wear(2, "Base.Shoes_FlipFlop")
    assertEq(MTIR.getShoeLossChance(PLAYER, "jump"), 0, "événement inconnu")
end

T["tirage d'un franchissement : perte, presque perdue, ou rien"] = function()
    wear(3, "Base.Shoes_FlipFlop")
    ROLL = 0.0
    MTIR.rollShoeLossEvent(PLAYER, "fall")
    assertEq(#DROPPED, 1, "perdue")

    -- Rangers deux pointures trop grandes : chance faible, tirage loin au-dessus.
    wear(2, "Base.Shoes_ArmyBoots")
    SAID = {}
    ROLL = 0.5
    MTIR.rollShoeLossEvent(PLAYER, "fall")
    assertEq(#DROPPED, 1, "gardée")
    assertEq(#SAID, 0, "aucun message")

    ROLL = MTIR.getShoeLossChance(PLAYER, "fall") * 1.5
    MTIR.rollShoeLossEvent(PLAYER, "fall")
    assertEq(#DROPPED, 1, "gardée de peu")
    assertEq(#SAID, 1, "elle a failli partir")
end

T["effets des chaussures désactivés : plus rien"] = function()
    SandboxVars.MyTailorIsRich.ShoeEffectMultiplier = 0
    ROLL = 0.0
    wear(-2)
    move(1, 120)
    assertEq(scratchedFeet(), 0, "aucune ampoule")
    wear(3)
    move(2, 60)
    assertEq(#DROPPED, 0, "aucune perte")
    assertEq(MTIR.getShoeLossChance(PLAYER, "fall"), 0, "aucune chance d'événement")
end

return T
