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
    MTIR.canShoeHaveSize = function(item) return item ~= nil and item.shoe == true end
    MTIR.getPlayerShoeSize = function() return 43 end
    MTIR.getShoeDiff = function(shoe) return shoe.diff end
    SAID, DROPPED = {}, {}
    MTIR.tell = function(_, fx) table.insert(SAID, fx) end
    MTIR.dropWornItem = function(shoe) table.insert(DROPPED, shoe); return true end

    PLAYER = { traits = {}, discomfort = 0, endurance = 1, scratched = {}, socks = nil }
    function PLAYER:getWornItem(location)
        if self.shoe and location == ItemBodyLocation.SHOES then return self.shoe end
        return nil
    end
    function PLAYER:getWornItems()
        local worn = {}
        if self.shoe then worn[#worn + 1] = self.shoe end
        if self.socks then worn[#worn + 1] = self.socks end
        return {
            size = function() return #worn end,
            getItemByIndex = function(_, i) return worn[i + 1] end,
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
    PLAYER.shoe = diff and {
        shoe = true,
        diff = diff,
        getFullType = function() return fullType or "Base.Shoes_Random" end,
        getBodyLocation = function() return "Shoes" end,
    } or nil
end

--- Chaussettes portées : isolation du script (0,15 chevilles, 0,35 montantes,
--- 0,55 épaisses) et humidité de 0 à 100.
local function socks(insulation, wetness)
    PLAYER.socks = insulation and {
        getBodyLocation = function() return "base:socks" end,
        getInsulation = function() return insulation end,
        getWetness = function() return wetness or 0 end,
    } or nil
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

T["chaussettes : le frottement ralentit, trempées il s'emballe"] = function()
    wear(-2)
    move(1, 20)
    local bare = friction()

    MTIR.Friction = {}
    socks(0.15)
    move(1, 20)
    local ankle = friction()
    assertTrue(ankle < bare, "chaussettes de cheville : un peu moins de frottement")

    MTIR.Friction = {}
    socks(0.55)
    move(1, 20)
    local heavy = friction()
    assertTrue(heavy < ankle, "chaussettes épaisses : nettement moins")

    MTIR.Friction = {}
    socks(0.55, 100)
    move(1, 20)
    assertTrue(friction() > bare, "trempées : pire que pieds nus dans la chaussure")
end

T["chaussettes épaisses : une pointure de trop comblée"] = function()
    wear(2)
    socks(0.55)
    move(2, 200)
    assertEq(scratchedFeet(), 0, "deux pointures de trop comblées : plus d'ampoule")
    assertEq(MTIR.getShoeLossChance(PLAYER, "fall"), 0, "ni risque de perdre la chaussure")

    socks(0.35)
    MTIR.Friction = {}
    move(2, 90)
    assertEq(scratchedFeet(), 0, "chaussettes montantes : elles freinent le frottement")
    move(2, 30)
    assertEq(scratchedFeet(), 1, "mais elles ne comblent pas la pointure : l'ampoule vient")
end

T["chaussettes épaisses : une paire trop grande de trois reste gênante"] = function()
    wear(3, "Base.Shoes_FlipFlop")
    socks(0.55)
    assertTrue(MTIR.getShoeLossChance(PLAYER, "fall") > 0, "il reste une pointure de trop")
    socks(nil)
    assertTrue(MTIR.getShoeLossChance(PLAYER, "fall")
        > 0, "sans chaussettes, le risque est entier")
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

T["corde et échelle : la chaussure perdue tombe en bas"] = function()
    local fromZs, ground = {}, { ground = true }
    MTIR.getGroundSquareBelow = function(_, fromZ)
        table.insert(fromZs, fromZ)
        return ground
    end
    local dropSquares = {}
    MTIR.dropWornItem = function(shoe, _, square)
        table.insert(DROPPED, shoe)
        table.insert(dropSquares, square or "pieds")
        return true
    end
    function PLAYER:getCurrentSquare() return { getZ = function() return 2 end } end
    wear(3, "Base.Shoes_FlipFlop")
    ROLL = 0.0
    MTIR.rollShoeLossEvent(PLAYER, "rope")
    assertEq(dropSquares[1], ground, "au pied de la corde")
    assertEq(fromZs[1], 2, "recherche depuis l'étage courant à la montée")
    assertEq(SAID[1].say.key, "IGUI_MTIR_Say_ShoeFellBelow0", "phrase de la chute")
    MTIR.rollShoeLossEvent(PLAYER, "ladderDown")
    assertEq(fromZs[2], 1, "depuis l'étage du dessous à la descente")
    MTIR.rollShoeLossEvent(PLAYER, "fall")
    assertEq(dropSquares[3], "pieds", "chute : aux pieds du personnage")
end

T["chaussettes sans chaussures : seulement sans rien aux pieds"] = function()
    assertEq(MTIR.isInSocksOnly(PLAYER), false, "pieds nus")
    socks(0.15)
    assertEq(MTIR.isInSocksOnly(PLAYER), true, "chaussettes seules")
    wear(0)
    assertEq(MTIR.isInSocksOnly(PLAYER), false, "chaussé")
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
