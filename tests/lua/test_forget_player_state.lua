-- Purge de l'état gardé en mémoire pour un joueur (C08) : jauge d'ampoules,
-- inconfort à corriger, zones serrées et taille d'artisanat. La clé est le compte
-- (serveur) ou l'emplacement local (solo) : le personnage suivant la réutilise.

local T = {}

function T.setup()
    ItemBodyLocation = { SHOES = "shoes" }
    CharacterTrait = { DESENSITIZED = "desensitized" }
    CharacterStat = { DISCOMFORT = "discomfort", ENDURANCE = "endurance" }
    SyncPlayerStatsPacket = { getBitMaskForStat = function() return 0 end }
    isServer = function() return false end
    isClient = function() return false end
    isDebugEnabled = function() return false end
    ZombRand = function() return 0 end
    ZombRandFloat = function() return 0.99 end
    MTIR = {
        SIZES = { M = true, L = true },
        opt = function() return 1 end,
        canShoeHaveSize = function(item) return item ~= nil end,
        getPlayerShoeSize = function() return 43 end,
        getShoeDiff = function(shoe) return shoe.diff end,
        getShoeEffectDiff = function() return 0 end,
    }
    loadMod("shared/MyTailorIsRich/MTIR_Effects.lua")
    loadMod("shared/MyTailorIsRich/MTIR_ShoeEffects.lua")
    -- Les deux fichiers posent la vraie MTIR.tell (solo : effets d'interface) : ici
    -- seuls les appels comptent, pas l'affichage.
    MTIR.said = {}
    MTIR.tell = function(_, fx) table.insert(MTIR.said, fx) end
end

--- Joueur simulé ; num = emplacement local (clé en solo), diff = écart de pointure.
local function newPlayer(num, diff)
    local player = { num = num, traits = {}, discomfort = 0, moving = false, running = false }
    if diff then
        player.shoe = { diff = diff }
    end
    function player:getPlayerNum() return self.num end
    function player:getWornItem(location)
        if self.shoe and location == ItemBodyLocation.SHOES then
            return self.shoe
        end
        return nil
    end
    function player:getWornItems()
        local shoe = self.shoe
        return {
            size = function() return shoe and 1 or 0 end,
            getItemByIndex = function() return shoe end,
        }
    end
    function player:hasTrait(trait) return self.traits[trait] == true end
    function player:isPlayerMoving() return self.moving end
    function player:isRunning() return self.running end
    function player:isSprinting() return false end
    function player:getStats()
        local owner = self
        return {
            get = function(_, stat) return stat == CharacterStat.DISCOMFORT and owner.discomfort or 0 end,
            set = function(_, stat, value)
                if stat == CharacterStat.DISCOMFORT then owner.discomfort = value end
            end,
            remove = function() end,
        }
    end
    return player
end

--- Marche `minutes` minutes de jeu avec les chaussures portées.
local function walk(player, minutes)
    player.moving = true
    MTIR.applyShoeTick(player, 1, minutes)
    player.moving = false
end

T["la jauge d'ampoules du mort n'est pas héritée"] = function()
    local player = newPlayer(0, -2)
    walk(player, 30)
    assertTrue(MTIR.getFriction(player) > 0.5, "jauge remplie aux deux tiers (45 min pour une ampoule)")
    MTIR.forgetPlayerShoeState(player)
    assertEq(MTIR.getFriction(player), 0, "personnage suivant, pieds reposés")
end

T["la jauge des autres joueurs reste en place"] = function()
    local dead, other = newPlayer(0, -2), newPlayer(1, -2)
    walk(dead, 30)
    walk(other, 30)
    MTIR.forgetPlayerShoeState(dead)
    assertEq(MTIR.getFriction(dead), 0, "joueur purgé")
    assertTrue(MTIR.getFriction(other) > 0.5, "joueur voisin intact")
end

T["l'inconfort à corriger est oublié"] = function()
    local player = newPlayer(0, -2)
    MTIR.refreshDiscomfortFloor(player)
    MTIR.enforceDiscomfortFloor(player)
    assertEq(MTIR.DiscomfortCorrected[MTIR.playerKey(player)], true, "correction notée")
    MTIR.forgetPlayerShoeState(player)
    assertEq(MTIR.DiscomfortCorrected[MTIR.playerKey(player)], nil, "oubliée")
end

T["zones serrées et taille d'artisanat oubliées"] = function()
    local player = newPlayer(0)
    local key = MTIR.playerKey(player)
    MTIR.BodyDiffs[key] = { torso = -2 }
    MTIR.setCraftSizeFor(player, "Base.Tshirt_White", "L")
    assertEq(MTIR.getCraftSizeFor(player, "Base.Tshirt_White"), "L", "taille retenue")
    MTIR.forgetPlayerEffects(player)
    assertEq(MTIR.BodyDiffs[key], nil, "zones serrées oubliées")
    assertEq(MTIR.getCraftSizeFor(player, "Base.Tshirt_White"), nil, "taille du mort non héritée")
end

T["sans joueur, les purges ne font rien"] = function()
    MTIR.forgetPlayerEffects(nil)
    MTIR.forgetPlayerShoeState(nil)
    assertTrue(true, "aucune erreur")
end

return T
