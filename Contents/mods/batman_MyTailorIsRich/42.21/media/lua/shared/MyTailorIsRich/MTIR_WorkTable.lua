-- ============================================================================
-- My Tailor Is Rich — table de travail (tracer un patron)
-- On étale le modèle et les feuilles sur une surface plane : tout objet marqué
-- table (IsTable : tables, bureaux, comptoirs, établis ; PropertyContainer.isTable)
-- ou la machine à pédale, qui est un meuble de couture.
-- ============================================================================

require "MyTailorIsRich/MTIR_SewingMachine"

--- Rayon (en cases) où chercher une table autour du personnage, au même étage.
local SEARCH_RADIUS = 4

function MTIR.isWorkTable(object)
    local props = object and object:getProperties()
    if props and props:isTable() then
        return true
    end
    return MTIR.getMachineKindName(object) == "treadle"
end

function MTIR.findWorkTable(square)
    if not square then
        return nil
    end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if MTIR.isWorkTable(object) then
            return object
        end
    end
    return nil
end

--- Table désignée par "x,y,z" (MTIR.encodeMachinePos), ou nil.
function MTIR.workTableFromPos(pos)
    return MTIR.findWorkTable(MTIR.squareFromPos(pos))
end

--- Table la plus proche du personnage, dans la même pièce (ou dehors, s'il y est).
function MTIR.findNearestWorkTable(character)
    local origin = character:getCurrentSquare()
    if not origin then
        return nil
    end
    local cell = getCell()
    local room = origin:getRoom()
    local cx, cy, z = origin:getX(), origin:getY(), origin:getZ()
    local best, bestDistance = nil, nil
    for x = cx - SEARCH_RADIUS, cx + SEARCH_RADIUS do
        for y = cy - SEARCH_RADIUS, cy + SEARCH_RADIUS do
            local square = cell:getGridSquare(x, y, z)
            local found = square and square:getRoom() == room and MTIR.findWorkTable(square)
            if found then
                local distance = (x - cx) ^ 2 + (y - cy) ^ 2
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = found, distance
                end
            end
        end
    end
    return best
end
