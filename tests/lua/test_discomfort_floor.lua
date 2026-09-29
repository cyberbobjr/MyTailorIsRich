-- MTIR_ShoeEffects : plancher d'inconfort des chaussures mal ajustées et
-- compteur qui permet aux boucles par tick de ne rien faire sans plancher.

local T = {}

function T.setup()
    ItemBodyLocation = { SHOES = "shoes" }
    CharacterTrait = { DESENSITIZED = "desensitized" }
    CharacterStat = { DISCOMFORT = "discomfort" }
    OPTION = 1
    MTIR = {
        opt = function() return OPTION end,
        playerKey = function(player) return player.key end,
        canShoeHaveSize = function() return true end,
        getPlayerShoeSize = function() return 43 end,
        getShoeDiff = function(shoe) return shoe.diff end,
    }
    loadMod("shared/MyTailorIsRich/MTIR_ShoeEffects.lua")
end

--- Joueur simulé ; diff = écart de pointure de la chaussure portée (nil : pieds nus).
local function newPlayer(key, diff)
    local player = { key = key, traits = {}, discomfort = 0 }
    if diff then
        player.shoe = { diff = diff }
    end
    function player:getWornItem() return self.shoe end
    function player:hasTrait(trait) return self.traits[trait] == true end
    function player:getStats()
        local owner = self
        return {
            get = function(_, stat) return stat == CharacterStat.DISCOMFORT and owner.discomfort or 0 end,
            set = function(_, stat, value) if stat == CharacterStat.DISCOMFORT then owner.discomfort = value end end,
        }
    end
    return player
end

local function refreshAll(players)
    MTIR.resetDiscomfortFloors()
    for _, player in ipairs(players) do
        MTIR.refreshDiscomfortFloor(player)
    end
end

T["aucun plancher au départ"] = function()
    assertEq(MTIR.hasDiscomfortFloors(), false, "au chargement")
    refreshAll({ newPlayer("a", 0), newPlayer("b", 1), newPlayer("c") })
    assertEq(MTIR.hasDiscomfortFloors(), false, "bonnes pointures et pieds nus")
end

T["chaussures trop petites : plancher maintenu"] = function()
    local player = newPlayer("a", -2)
    refreshAll({ player })
    assertEq(MTIR.hasDiscomfortFloors(), true, "plancher actif")
    MTIR.enforceDiscomfortFloor(player)
    assertEq(player.discomfort, 45, "inconfort relevé au plancher")
    player.discomfort = 80
    MTIR.enforceDiscomfortFloor(player)
    assertEq(player.discomfort, 80, "un inconfort plus haut n'est pas abaissé")
end

T["très grandes (+3) : plancher léger"] = function()
    local player = newPlayer("a", 3)
    refreshAll({ player })
    MTIR.enforceDiscomfortFloor(player)
    assertEq(player.discomfort, 25, "plancher très grandes")
end

T["le compte suit les changements de chaussures"] = function()
    local player = newPlayer("a", -1)
    MTIR.refreshDiscomfortFloor(player)
    MTIR.refreshDiscomfortFloor(player)
    assertEq(MTIR.hasDiscomfortFloors(), true, "compté une seule fois")
    player.shoe.diff = 0
    MTIR.refreshDiscomfortFloor(player)
    assertEq(MTIR.hasDiscomfortFloors(), false, "retiré après changement")
end

T["le recalcul complet oublie les joueurs partis"] = function()
    local staying, leaving = newPlayer("a", 0), newPlayer("b", -2)
    refreshAll({ staying, leaving })
    assertEq(MTIR.hasDiscomfortFloors(), true, "avant départ")
    refreshAll({ staying })
    assertEq(MTIR.hasDiscomfortFloors(), false, "après départ")
end

T["Insensible ou option à 0 : pas de plancher"] = function()
    local player = newPlayer("a", -2)
    player.traits[CharacterTrait.DESENSITIZED] = true
    refreshAll({ player })
    assertEq(MTIR.hasDiscomfortFloors(), false, "trait Insensible")
    OPTION = 0
    refreshAll({ newPlayer("b", -2) })
    assertEq(MTIR.hasDiscomfortFloors(), false, "effets désactivés")
end

T["correction signalée pour la synchronisation"] = function()
    local player = newPlayer("a", -1)
    refreshAll({ player })
    MTIR.enforceDiscomfortFloor(player)
    assertEq(MTIR.DiscomfortCorrected.a, true, "correction notée")
end

return T
