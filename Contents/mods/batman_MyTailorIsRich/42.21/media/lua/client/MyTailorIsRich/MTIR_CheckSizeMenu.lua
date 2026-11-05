-- Collecte au clic : cadavres et meubles accessibles, sans déplacement ni transfert.
require "MyTailorIsRich/MTIR_LabelCheck"
require "TimedActions/MTIR_CheckSizeAction"

MTIR.CheckSizeMenu = {}
local Menu = MTIR.CheckSizeMenu

function Menu.collectContainerItems(player, containers, withTape)
    local result, seen = {}, {}
    for _, container in ipairs(containers) do
        if MTIR.canCheckContainer(player, container) then
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                local id = item:getID()
                if not seen[id] and item:getContainer() == container
                        and MTIR.needsSizeCheck(item, player, true, withTape) then
                    seen[id] = true
                    result[#result + 1] = { item = item, container = container }
                end
            end
        end
    end
    return result
end

local function addContainer(containers, seen, container)
    if container and not seen[container] and MTIR.isBatchContainer(container) then
        seen[container] = true
        containers[#containers + 1] = container
    end
end

function Menu.collectNearbyItems(player, withTape)
    local containers, seen = {}, {}
    local cell = getCell()
    -- Comme le panneau de butin vanilla : la case du joueur et ses huit voisines.
    -- canReachTo exclut murs, fenêtres et portes bloquant la lecture sur place.
    local radius = 1
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for dy = -radius, radius do
        for dx = -radius, radius do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            if square then
                local bodies = square:getStaticMovingObjects()
                for i = 0, bodies:size() - 1 do
                    local body = bodies:get(i)
                    if instanceof(body, "IsoDeadBody") then
                        addContainer(containers, seen, body:getContainer())
                    end
                end
                -- Meubles : un objet peut porter plusieurs conteneurs (frigo et congélateur).
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    for index = 0, object:getContainerCount() - 1 do
                        addContainer(containers, seen, object:getContainerByIndex(index))
                    end
                end
            end
        end
    end
    return Menu.collectContainerItems(player, containers, withTape)
end

local function queueBatch(player, entries, withTape)
    for _, entry in ipairs(entries) do
        ISTimedActionQueue.add(MTIR_CheckSizeAction:new(player, entry.item, entry.container, withTape))
    end
end

local function checkContainers(player, containers, withTape)
    queueBatch(player, Menu.collectContainerItems(player, containers, withTape), withTape)
end

local function checkNearby(player, withTape)
    queueBatch(player, Menu.collectNearbyItems(player, withTape), withTape)
end

local function allCorpses(containers)
    for _, container in ipairs(containers) do
        if not MTIR.isCorpseContainer(container) then return false end
    end
    return true
end

function Menu.addOptions(selected, player, context, queueSelection)
    if #selected == 0 then return end
    -- Avec un mètre ruban, la lecture d'étiquette devient une mesure : deux fois plus
    -- rapide et sans niveau de Couture.
    local withTape = MTIR.findMeasuringTape(player) ~= nil
    local clothes, containers, seen = {}, {}, {}
    for _, item in ipairs(selected) do
        if MTIR.needsSizeCheck(item) then clothes[#clothes + 1] = item end
        addContainer(containers, seen, MTIR.getBatchContainer(item))
    end
    local containerItems = Menu.collectContainerItems(player, containers, withTape)
    local nearbyItems = Menu.collectNearbyItems(player, withTape)
    if #clothes == 0 and #containerItems == 0 and #nearbyItems == 0 then return end
    local title = withTape and "IGUI_MTIR_Measure_Clothes" or "IGUI_MTIR_JobType_CheckClothesSize"
    local option = context:addOption(getText(title))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if #clothes > 0 then
        subMenu:addOption(getText("IGUI_MTIR_CheckSize_Selection"), player, queueSelection,
            clothes, withTape)
    end
    if #containers > 0 then
        local label = allCorpses(containers) and "IGUI_MTIR_CheckSize_Corpse" or "IGUI_MTIR_CheckSize_Container"
        local here = subMenu:addOption(getText(label), player, checkContainers, containers, withTape)
        here.notAvailable = #containerItems == 0
    end
    local nearby = subMenu:addOption(getText("IGUI_MTIR_CheckSize_Nearby"), player, checkNearby, withTape)
    nearby.notAvailable = #nearbyItems == 0
end
