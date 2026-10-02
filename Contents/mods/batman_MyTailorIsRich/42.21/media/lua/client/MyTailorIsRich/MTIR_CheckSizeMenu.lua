-- Collecte au clic : seulement les cadavres accessibles, sans déplacement ni transfert.
require "MyTailorIsRich/MTIR_LabelCheck"
require "TimedActions/MTIR_CheckSizeAction"

MTIR.CheckSizeMenu = {}
local Menu = MTIR.CheckSizeMenu

function Menu.collectCorpseItems(player, containers)
    local result, seen = {}, {}
    for _, container in ipairs(containers) do
        if MTIR.canCheckCorpse(player, container) then
            local items = container:getItems()
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                local id = item:getID()
                if not seen[id] and item:getContainer() == container and MTIR.needsSizeCheck(item, player, true) then
                    seen[id] = true
                    result[#result + 1] = { item = item, container = container }
                end
            end
        end
    end
    return result
end

function Menu.collectNearbyItems(player)
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
                local objects = square:getStaticMovingObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if instanceof(object, "IsoDeadBody") and not object:isAnimal() then
                        local container = object:getContainer()
                        if container and not seen[container] then
                            seen[container] = true
                            containers[#containers + 1] = container
                        end
                    end
                end
            end
        end
    end
    return Menu.collectCorpseItems(player, containers)
end

local function queueBatch(player, entries)
    for _, entry in ipairs(entries) do
        ISTimedActionQueue.add(MTIR_CheckSizeAction:new(player, entry.item, entry.container))
    end
end

local function checkCorpse(player, containers)
    queueBatch(player, Menu.collectCorpseItems(player, containers))
end

local function checkNearby(player)
    queueBatch(player, Menu.collectNearbyItems(player))
end

function Menu.addOptions(selected, player, context, queueSelection)
    if #selected == 0 then return end
    local clothes, containers, seen = {}, {}, {}
    for _, item in ipairs(selected) do
        if MTIR.needsSizeCheck(item) then clothes[#clothes + 1] = item end
        local container = MTIR.getCorpseContainer(item)
        if container and not seen[container] then
            seen[container] = true
            containers[#containers + 1] = container
        end
    end
    local corpseItems = Menu.collectCorpseItems(player, containers)
    local nearbyItems = Menu.collectNearbyItems(player)
    if #clothes == 0 and #corpseItems == 0 and #nearbyItems == 0 then return end
    local option = context:addOption(getText("IGUI_MTIR_JobType_CheckClothesSize"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if #clothes > 0 then
        subMenu:addOption(getText("IGUI_MTIR_CheckSize_Selection"), player, queueSelection, clothes)
    end
    if #containers > 0 then
        local corpse = subMenu:addOption(getText("IGUI_MTIR_CheckSize_Corpse"), player, checkCorpse, containers)
        corpse.notAvailable = #corpseItems == 0
    end
    local nearby = subMenu:addOption(getText("IGUI_MTIR_CheckSize_Nearby"), player, checkNearby)
    nearby.notAvailable = #nearbyItems == 0
end
