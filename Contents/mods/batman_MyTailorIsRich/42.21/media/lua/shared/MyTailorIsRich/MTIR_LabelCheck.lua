-- Lecture des étiquettes : filtres partagés, sans créer de données côté client.
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Reach"

--- `withTape` : mesure au mètre ruban, qui lit la taille quel que soit le niveau.
function MTIR.needsSizeCheck(item, character, bulk, withTape)
    if not item then return false end
    if MTIR.canShoeHaveSize(item) then
        local data = MTIR.getShoeData(item)
        return not data or not data.reveal
    end
    if not MTIR.canClothesHaveSize(item) then return false end
    local data = MTIR.getData(item)
    if data and data.reveal then return false end
    -- En groupe, ne pas relire un indice sans pouvoir apprendre davantage.
    -- La sélection manuelle reste possible ; une progression débloque la relecture.
    if bulk and not withTape and data and data.hint and MTIR.opt("NeedTailoringLevel")
            and character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToCheck(item) then
        return false
    end
    return true
end

--- Conteneur lisible en groupe : cadavre humain ou meuble posé dans le monde
--- (armoire, commode, coffre…). Ni sol, ni sac posé, ni véhicule, ni personnage.
function MTIR.isBatchContainer(container)
    if not container or container:getType() == "floor" or container:getContainingItem()
            or container:getVehiclePart() then
        return false
    end
    local parent = container:getParent()
    if not parent or instanceof(parent, "IsoGameCharacter") then return false end
    if instanceof(parent, "IsoDeadBody") then return not parent:isAnimal() end
    return true
end

function MTIR.isCorpseContainer(container)
    local parent = container and container:getParent()
    return parent ~= nil and instanceof(parent, "IsoDeadBody") and not parent:isAnimal()
end

--- Conteneur du vêtement à proposer en lecture groupée, ou nil.
function MTIR.getBatchContainer(item)
    local container = MTIR.getInPlaceContainer(item)
    if MTIR.isBatchContainer(container) then
        return container
    end
    return nil
end

--- Cadavre ou meuble à portée de main : même étage, sans mur entre les cases,
--- accessible (cadenas) et hors zone protégée. Revérifié par l'autorité.
function MTIR.canCheckContainer(character, container)
    if not MTIR.isBatchContainer(container) then return false end
    local square, current = container:getParent():getSquare(), character:getCurrentSquare()
    if not square or not current or not character:canAccessContainer(container) then return false end
    if square ~= current and not current:canReachTo(square) then return false end
    if (isClient() or isServer()) and not SafeHouse.isSafehouseAllowLoot(square, character) then return false end
    local dx, dy = square:getX() + 0.5 - character:getX(), square:getY() + 0.5 - character:getY()
    return math.abs(square:getZ() - character:getZ()) < 1
        and dx * dx + dy * dy <= MTIR.CHECK_REACH * MTIR.CHECK_REACH
end
