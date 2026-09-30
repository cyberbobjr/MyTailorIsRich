-- ============================================================================
-- My Tailor Is Rich — lire une étiquette sans prendre le vêtement
--
-- Un vêtement porté sur soi (inventaire ou sac porté) se lit où qu'on soit.
-- Dans un cadavre, un meuble ou un coffre de véhicule, il se lit sur place, à
-- portée de main : le serveur retrouve ces conteneurs par leur position
-- (ContainerID : DeadBody, ObjectContainer, Vehicle) et y renvoie l'objet par
-- syncItemFields.
-- Au sol, ou dans un sac lui-même posé dans le monde, le serveur ne voit qu'un
-- conteneur « floor » reconstruit (ContainerID.java:404-440) ou une position
-- incomplète : ces vêtements passent encore par l'inventaire.
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"

--- Distance (cases) entre le joueur et un conteneur lu sur place.
--- luautils.walkToContainer s'arrête à moins de 2 cases ; marge pour le réseau.
MTIR.CHECK_REACH = 2.5
--- Véhicule : son test d'accès (luaTest) vérifie la zone ; ceci n'est qu'un garde-fou.
MTIR.CHECK_VEHICLE_REACH = 8

local function isNear(character, x, y, z, reach)
    if math.abs(z - character:getZ()) >= 1 then
        return false
    end
    local dx, dy = x - character:getX(), y - character:getY()
    return dx * dx + dy * dy <= reach * reach
end

--- Vrai si l'objet est dans l'inventaire du personnage ou dans un sac qu'il porte.
function MTIR.isCarried(character, item)
    local container = item and item:getContainer()
    return container ~= nil and container:isInCharacterInventory(character)
end

--- Conteneur du monde où lire l'étiquette sur place (cadavre, meuble, véhicule),
--- ou nil : sol, sac posé dans le monde, inventaire d'un autre personnage.
function MTIR.getInPlaceContainer(item)
    local container = item and item:getContainer()
    if not container or container:getType() == "floor" or container:getContainingItem() then
        return nil
    end
    local parent = container:getParent()
    if not parent or instanceof(parent, "IsoGameCharacter") then
        return nil
    end
    return container
end

--- Le personnage peut-il lire l'étiquette ? Revérifié par le serveur dans complete().
function MTIR.canReachItem(character, item)
    if MTIR.isCarried(character, item) then
        return true
    end
    local container = MTIR.getInPlaceContainer(item)
    if not container or not character:canAccessContainer(container) then
        return false
    end
    local part = container:getVehiclePart()
    if part then
        local vehicle = part:getVehicle()
        return vehicle:canAccessContainer(part:getIndex(), character)
            and (character:getVehicle() == vehicle
                or isNear(character, vehicle:getX(), vehicle:getY(), vehicle:getZ(), MTIR.CHECK_VEHICLE_REACH))
    end
    local square = container:getParent():getSquare()
    return square ~= nil
        and isNear(character, square:getX() + 0.5, square:getY() + 0.5, square:getZ(), MTIR.CHECK_REACH)
end
