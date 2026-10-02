-- Lecture des étiquettes : filtres partagés, sans créer de données côté client.
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Reach"

function MTIR.needsSizeCheck(item, character, bulk)
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
    if bulk and data and data.hint and MTIR.opt("NeedTailoringLevel")
            and character:getPerkLevel(Perks.Tailoring) < MTIR.getRequiredLevelToCheck(item) then
        return false
    end
    return true
end

function MTIR.getCorpseContainer(item)
    local container = MTIR.getInPlaceContainer(item)
    local parent = container and container:getParent()
    if parent and instanceof(parent, "IsoDeadBody") and not parent:isAnimal() then
        return container
    end
    return nil
end

function MTIR.canCheckCorpse(character, container)
    local parent = container and container:getParent()
    if not parent or not instanceof(parent, "IsoDeadBody") or parent:isAnimal() then return false end
    local square, current = parent:getSquare(), character:getCurrentSquare()
    if not square or not current or not character:canAccessContainer(container) then return false end
    if square ~= current and not current:canReachTo(square) then return false end
    if (isClient() or isServer()) and not SafeHouse.isSafehouseAllowLoot(square, character) then return false end
    local dx, dy = square:getX() + 0.5 - character:getX(), square:getY() + 0.5 - character:getY()
    return math.abs(square:getZ() - character:getZ()) < 1
        and dx * dx + dy * dy <= MTIR.CHECK_REACH * MTIR.CHECK_REACH
end
