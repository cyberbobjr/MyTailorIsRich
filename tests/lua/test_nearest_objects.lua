-- MTIR_WorkTable : objet le plus proche du personnage (table de travail, machine à
-- coudre pour le bouton « Coudre à la machine » de l'album), même pièce et même
-- étage, dans un rayon de quelques cases.

local T = {}

local GRID, CHARACTER

local function square(x, y, room)
    local sq = { x = x, y = y, room = room, objects = {} }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return 0 end
    function sq:getRoom() return self.room end
    function sq:getObjects()
        local list = self.objects
        return { size = function() return #list end, get = function(_, i) return list[i + 1] end }
    end
    GRID[x .. "," .. y] = sq
    return sq
end

local function place(sq, kind)
    local object = { kind = kind, getSquare = function() return sq end }
    table.insert(sq.objects, object)
    return object
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    GRID = {}
    getCell = function()
        return { getGridSquare = function(_, x, y) return GRID[x .. "," .. y] end }
    end
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")
    loadMod("shared/MyTailorIsRich/MTIR_WorkTable.lua")
    MTIR.isSewingMachine = function(object) return object.kind == "machine" end
    CHARACTER = { square = square(10, 10, "workshop") }
    function CHARACTER:getCurrentSquare() return self.square end
end

T["la machine la plus proche, dans la pièce du personnage"] = function()
    local far = place(square(13, 10, "workshop"), "machine")
    local near = place(square(11, 11, "workshop"), "machine")
    place(square(10, 11, "kitchen"), "machine")
    assertEq(MTIR.findNearestSewingMachine(CHARACTER), near, "la plus proche de la même pièce")
    assertTrue(far ~= near, "deux machines dans la pièce")
end

T["rien à portée : nil"] = function()
    place(square(20, 10, "workshop"), "machine")
    place(square(11, 10, "workshop"), "table")
    assertEq(MTIR.findNearestSewingMachine(CHARACTER), nil, "trop loin, ou pas une machine")
end

T["personnage hors du monde chargé : nil"] = function()
    CHARACTER.square = nil
    assertEq(MTIR.findNearestSewingMachine(CHARACTER), nil, "sans case")
end

return T
