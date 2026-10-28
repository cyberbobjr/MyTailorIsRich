-- MTIR_SewingMachine : portée de main d'une machine ou d'une table de travail (C16).
-- Même étage, case voisine, et aucun mur entre les deux cases — sinon on cousait à
-- travers une cloison.

local T = {}

local CHARACTER

--- Case simulée ; reachable = false pose une cloison devant elle (canReachTo du jeu,
--- appelé sur la case du personnage, rend faux pour cette case).
local function square(x, y, z, reachable)
    local sq = { reachable = reachable ~= false }
    function sq:getX() return x end
    function sq:getY() return y end
    function sq:getZ() return z end
    function sq:canReachTo(other) return other == self or other.reachable ~= false end
    return sq
end

local function object(sq)
    return { getSquare = function() return sq end }
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")

    -- Personnage au centre de la case 10,10,0.
    CHARACTER = { x = 10.5, y = 10.5, z = 0, square = square(10, 10, 0) }
    function CHARACTER:getX() return self.x end
    function CHARACTER:getY() return self.y end
    function CHARACTER:getZ() return self.z end
    function CHARACTER:getCurrentSquare() return self.square end
end

T["machine sur la case du personnage"] = function()
    assertTrue(MTIR.isWithinReach(CHARACTER, object(CHARACTER.square)), "même case")
end

T["case voisine dégagée, diagonale comprise"] = function()
    assertTrue(MTIR.isWithinReach(CHARACTER, object(square(11, 10, 0))), "à l'est")
    assertTrue(MTIR.isWithinReach(CHARACTER, object(square(9, 11, 0))), "en diagonale")
end

T["cloison entre les deux cases : refusé"] = function()
    local behindWall = square(11, 10, 0, false)
    assertEq(MTIR.isWithinReach(CHARACTER, object(behindWall)), false, "mur entre les cases")
end

T["autre étage : refusé"] = function()
    assertEq(MTIR.isWithinReach(CHARACTER, object(square(10, 10, 1))), false, "étage au-dessus")
end

T["trop loin, même sans mur : refusé"] = function()
    -- Case atteignable d'après le jeu, mais le personnage est à deux cases.
    CHARACTER.x = 7.5
    assertEq(MTIR.isWithinReach(CHARACTER, object(square(10, 10, 0))), false, "3 cases à l'ouest")
    CHARACTER.x = 8.9
    assertEq(MTIR.isWithinReach(CHARACTER, object(square(10, 10, 0))), true, "1,6 case : encore à portée")
end

T["personnage sans case, ou objet sans case"] = function()
    CHARACTER.square = nil
    assertEq(MTIR.isWithinReach(CHARACTER, object(square(10, 10, 0))), false, "personnage hors monde")
    CHARACTER.square = square(10, 10, 0)
    assertEq(MTIR.isWithinReach(CHARACTER, object(nil)), false, "objet retiré")
    assertEq(MTIR.isWithinReach(CHARACTER, nil), false, "aucun objet")
end

return T
