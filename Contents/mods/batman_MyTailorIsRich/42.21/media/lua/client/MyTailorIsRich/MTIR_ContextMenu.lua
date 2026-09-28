-- ============================================================================
-- My Tailor Is Rich — menu contextuel d'inventaire (client)
-- Lecture seule des données ; toute modification passe par une action
-- chronométrée partagée, exécutée par l'autorité.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/MTIR_CheckSizeAction"
require "TimedActions/MTIR_ResizeAction"
require "TimedActions/MTIR_ReconditionAction"
require "TimedActions/MTIR_ChooseSizeAction"
require "TimedActions/MTIR_DebugSizeAction"
require "MyTailorIsRich/MTIR_ShoeEffects"

-- ----------------------------------------------------------------------------
-- Aides d'affichage
-- ----------------------------------------------------------------------------

local function mark(ok)
    return ok and ISInventoryPaneContextMenu.ghs or ISInventoryPaneContextMenu.bhs
end

local function colorForPercent(percent)
    local color = ColorInfo.new(0, 0, 0, 1)
    local clamped = math.max(0, math.min(1, percent))
    getCore():getBadHighlitedColor():interp(getCore():getGoodHighlitedColor(), clamped, color)
    return " <RGB:" .. color:getR() .. "," .. color:getG() .. "," .. color:getB() .. "> "
end

local function needLine(ok, label)
    return " <LINE>" .. mark(ok) .. label
end

local function tailoringLine(tailoring, requiredLevel)
    local label = PerkFactory.getPerk(Perks.Tailoring):getName() .. " " .. tailoring .. "/" .. requiredLevel
    return needLine(tailoring >= requiredLevel, label)
end

local function chanceHeader(label, percent)
    return colorForPercent(percent) .. getText(label) .. " " .. math.ceil(percent * 100) .. "%"
end

-- Partagé avec MTIR_PatternMenu.lua.
MTIR.MenuUtil = {
    needLine = needLine,
    tailoringLine = tailoringLine,
    chanceHeader = chanceHeader,
    colorForPercent = colorForPercent,
}

local function repairedLine(repairedTimes)
    local value = repairedTimes == 0 and getText("Tooltip_never") or (repairedTimes .. "x")
    return " <LINE> <LINE> <RGB:1,1,0.8> " .. getText("Tooltip_weapon_Repaired") .. ": " .. value
end

--- Objets réels de la sélection (piles dépliées), filtrés.
local function collectItems(items, predicate)
    local list = {}
    for _, entry in ipairs(items) do
        if type(entry) == "table" then
            if entry.items then
                for j = 2, #entry.items do
                    if predicate(entry.items[j]) then
                        table.insert(list, entry.items[j])
                    end
                end
            end
        elseif predicate(entry) then
            table.insert(list, entry)
        end
    end
    return list
end

--- Un seul vêtement sélectionné, ou nil.
local function singleClothing(items)
    if #items ~= 1 then
        return nil
    end
    local entry = items[1]
    if type(entry) == "table" then
        entry = entry.items and #entry.items == 2 and entry.items[2] or nil
    end
    if entry and instanceof(entry, "Clothing") then
        return entry
    end
    return nil
end

local function getTools(player)
    local inventory = player:getInventory()
    return inventory:getFirstEvalRecurse(MTIR.predicateNeedle), inventory:getFirstEvalRecurse(MTIR.predicateScissors)
end

--- Déséquipe ou rapatrie le vêtement avant de travailler dessus.
local function bringClothing(player, item)
    if player:isEquippedClothing(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
    else
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    end
end

-- ----------------------------------------------------------------------------
-- Lire l'étiquette
-- ----------------------------------------------------------------------------

local function needsCheck(item)
    if MTIR.canShoeHaveSize(item) then
        local shoeData = MTIR.getShoeData(item)
        return not shoeData or not shoeData.reveal
    end
    if not MTIR.canClothesHaveSize(item) then
        return false
    end
    local data = MTIR.getData(item)
    return not data or not data.reveal
end

local function queueCheck(player, clothes)
    local inventory = player:getInventory()
    for _, item in ipairs(clothes) do
        local container = item:getContainer()
        if container and container ~= inventory then
            ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, container, inventory))
        end
        ISTimedActionQueue.add(MTIR_CheckSizeAction:new(player, item))
    end
end

local function addCheckSizeOption(items, player, context)
    local clothes = collectItems(items, needsCheck)
    if #clothes > 0 then
        context:addOption(getText("IGUI_MTIR_JobType_CheckClothesSize"), player, queueCheck, clothes)
    end
end

-- ----------------------------------------------------------------------------
-- Retoucher
-- ----------------------------------------------------------------------------

local function queueResize(player, item, needle, scissors, threads, materials, upsize)
    ISInventoryPaneContextMenu.transferIfNeeded(player, threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, materials)
    bringClothing(player, item)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), scissors, true)
    ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), needle, false)
    ISTimedActionQueue.add(MTIR_ResizeAction:new(player, item, needle, scissors, threads, materials, upsize))
end

--- Une option de retouche. upsize : bandes de tissu ; sinon trombones.
local function addResizeSubOption(subMenu, player, item, targetSize, upsize, tools)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToChange(item, upsize)
    local requiredThread = MTIR.getRequiredThreadCount(item)
    local requiredMaterial = upsize and MTIR.getRequiredStripCount(item) or MTIR.getRequiredPaperclip(item)
    local successChance = MTIR.getSuccessChanceForChange(tailoring, requiredLevel)

    local inventory = player:getInventory()
    local allThreads = inventory:getItemsFromType("Thread", true)
    local remainingThread = MTIR.getRemainingThread(allThreads)
    local materialType = upsize and MTIR.getStripType(MTIR.getClothesFabricType(item)) or "Base.Paperclip"
    local allMaterials = inventory:getItemsFromType(materialType, true)
    local threads = MTIR.pickThreads(allThreads, requiredThread)
    local materials = MTIR.pickItems(allMaterials, requiredMaterial)

    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_ToSize", targetSize.name), player, queueResize,
        item, tools.needle, tools.scissors, threads, materials, upsize)

    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = item:getTex()
    tooltip:setName(getItemNameFromFullType(item:getFullType()) .. " (" .. targetSize.name .. ")")
    tooltip.description = chanceHeader("Tooltip_chanceSuccess", successChance)
        .. " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_craft_Needs") .. ":"
        .. needLine(tools.needle ~= nil, getItemNameFromFullType("Base.Needle"))
        .. needLine(tools.scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. needLine(remainingThread >= requiredThread, getItemNameFromFullType("Base.Thread") .. " " .. remainingThread .. "/" .. requiredThread)
        .. needLine(allMaterials:size() >= requiredMaterial, getItemNameFromFullType(materialType) .. " " .. allMaterials:size() .. "/" .. requiredMaterial)
        .. tailoringLine(tailoring, requiredLevel)
    option.toolTip = tooltip
    option.notAvailable = not (tailoring >= requiredLevel and tools.needle and tools.scissors and threads and materials)
end

local function addResizeOption(item, player, context)
    local data = MTIR.getData(item)
    if item:isBroken() or not data or not data.size or not data.reveal or data.resized ~= 0 then
        return
    end
    local nextSize = MTIR.getNextSize(data.size)
    local prevSize = MTIR.getPrevSize(data.size)
    if not nextSize and not prevSize then
        return
    end
    local needle, scissors = getTools(player)
    local tools = { needle = needle, scissors = scissors }
    local option = context:addOption(getText("IGUI_MTIR_JobType_ResizeClothes"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if nextSize then
        addResizeSubOption(subMenu, player, item, nextSize, true, tools)
    end
    if prevSize then
        addResizeSubOption(subMenu, player, item, prevSize, false, tools)
    end
end

-- ----------------------------------------------------------------------------
-- Remettre en état
-- ----------------------------------------------------------------------------

local function queueReconditionStrips(player, item, needle, scissors, threads, strips, threadUses)
    ISInventoryPaneContextMenu.transferIfNeeded(player, needle)
    ISInventoryPaneContextMenu.transferIfNeeded(player, scissors)
    ISInventoryPaneContextMenu.transferIfNeeded(player, threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, strips)
    bringClothing(player, item)
    ISTimedActionQueue.add(MTIR_ReconditionAction:new(player, item, needle, scissors, threads, strips, threadUses))
end

local function queueReconditionSpare(player, item, needle, scissors, threads, spareItem, threadUses)
    ISInventoryPaneContextMenu.transferIfNeeded(player, needle)
    ISInventoryPaneContextMenu.transferIfNeeded(player, scissors)
    ISInventoryPaneContextMenu.transferIfNeeded(player, threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, spareItem)
    bringClothing(player, item)
    ISTimedActionQueue.add(MTIR_ReconditionSpareAction:new(player, item, needle, scissors, threads, spareItem, threadUses))
end

local function reconditionNeeds(ctx)
    return " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_craft_Needs") .. ":"
        .. needLine(ctx.needle ~= nil, getItemNameFromFullType("Base.Needle"))
        .. needLine(ctx.scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. needLine(ctx.remainingThread >= ctx.requiredThread,
            getItemNameFromFullType("Base.Thread") .. " " .. ctx.remainingThread .. "/" .. ctx.requiredThread)
end

local function addStripSubOption(subMenu, player, item, ctx)
    local stripType = MTIR.getStripType(MTIR.getClothesFabricType(item))
    local allStrips = player:getInventory():getItemsFromType(stripType, true)
    local requiredStrip = MTIR.getRequiredStripToRecondition(item)
    local strips = MTIR.pickItems(allStrips, requiredStrip)
    local potential = math.max(0, math.min(1, MTIR.getPotentialRepairForRecondition(item, player)))
    local chance = math.max(0, math.min(1, MTIR.getSuccessChanceForRecondition(item, player)))

    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseStrip", getItemNameFromFullType(stripType)),
        player, queueReconditionStrips, item, ctx.needle, ctx.scissors, ctx.threads, strips, ctx.requiredThread)
    option.notAvailable = not (ctx.needle and ctx.scissors and ctx.threads and strips)
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = chanceHeader("Tooltip_potentialRepair", potential)
        .. " <LINE>" .. chanceHeader("Tooltip_chanceSuccess", chance)
        .. reconditionNeeds(ctx)
        .. needLine(allStrips:size() >= requiredStrip,
            getItemNameFromFullType(stripType) .. " " .. allStrips:size() .. "/" .. requiredStrip)
        .. repairedLine(ctx.repairedTimes)
end

local function spareDisplayName(spareItem)
    local name = getItemNameFromFullType(spareItem:getFullType())
    local data = MTIR.getData(spareItem)
    if MTIR.canClothesHaveSize(spareItem) and data and data.reveal and data.size then
        name = name .. " (" .. data.size .. ")"
    end
    return name
end

local function addSpareSubOption(subMenu, player, item, spareItem, ctx)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToRecondition(item)
    local hasLevel = tailoring >= requiredLevel
    local potential = hasLevel and MTIR.getPotentialRepairUsingSpare(item, player, spareItem) or 0
    local chance = hasLevel and MTIR.getSuccessChanceUsingSpare(item, player, spareItem) or 0
    local spareCondition = spareItem:getCondition() / spareItem:getConditionMax()
    local spareRepaired = MTIR.getRepairedTimes(spareItem)
    local effective = spareCondition / (1 + 0.5 * spareRepaired)

    local grey = ColorInfo.new(0.5, 0.5, 0.5, 1)
    local color = ColorInfo.new(0, 0, 0, 1)
    getCore():getGoodHighlitedColor():interp(grey, 1 - effective, color)
    local name = spareDisplayName(spareItem)

    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseSpare", name), player,
        queueReconditionSpare, item, ctx.needle, ctx.scissors, ctx.threads, spareItem, ctx.requiredThread)
    option.notAvailable = not (ctx.needle and ctx.scissors and ctx.threads and hasLevel)
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = chanceHeader("Tooltip_potentialRepair", potential)
        .. " <LINE>" .. chanceHeader("Tooltip_chanceSuccess", chance)
        .. reconditionNeeds(ctx)
        .. " <LINE> <RGB:" .. color:getR() .. "," .. color:getG() .. "," .. color:getB() .. "> " .. name
        .. " <SPACE> (" .. math.ceil(spareCondition * 100) .. "%, "
        .. getText("IGUI_MTIR_JobType_Recondition_RepairedTimes", tostring(spareRepaired)) .. ")"
        .. tailoringLine(tailoring, requiredLevel)
        .. repairedLine(ctx.repairedTimes)
end

local function addMissingSpareSubOption(subMenu, player, item, ctx)
    local name = getItemNameFromFullType(item:getFullType())
    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseSpare", name))
    option.notAvailable = true
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = colorForPercent(0.5) .. getText("Tooltip_potentialRepair") .. " ???"
        .. " <LINE>" .. colorForPercent(0.5) .. getText("Tooltip_chanceSuccess") .. " ???"
        .. reconditionNeeds(ctx)
        .. " <LINE>" .. ISInventoryPaneContextMenu.bhs .. name
        .. tailoringLine(player:getPerkLevel(Perks.Tailoring), MTIR.getRequiredLevelToRecondition(item))
        .. repairedLine(ctx.repairedTimes)
end

local function addReconditionOption(item, player, context)
    if item:getCondition() >= item:getConditionMax() then
        return
    end
    local needle, scissors = getTools(player)
    local allThreads = player:getInventory():getItemsFromType("Thread", true)
    local requiredThread = MTIR.getRequiredThreadToRecondition(item)
    local ctx = {
        needle = needle,
        scissors = scissors,
        requiredThread = requiredThread,
        remainingThread = MTIR.getRemainingThread(allThreads),
        threads = MTIR.pickThreads(allThreads, requiredThread),
        repairedTimes = MTIR.getRepairedTimes(item),
    }

    local option = context:addOption(getText("IGUI_MTIR_JobType_ReconditionClothes"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)

    if MTIR.getClothesFabricType(item) then
        addStripSubOption(subMenu, player, item, ctx)
    end

    local spares = player:getInventory():getItemsFromType(item:getFullType(), true)
    local hasSpare = false
    for i = 0, spares:size() - 1 do
        local spareItem = spares:get(i)
        if spareItem ~= item then
            hasSpare = true
            addSpareSubOption(subMenu, player, item, spareItem, ctx)
        end
    end
    if not hasSpare then
        addMissingSpareSubOption(subMenu, player, item, ctx)
    end
end

-- ----------------------------------------------------------------------------
-- Choisir la taille d'un vêtement fabriqué
-- ----------------------------------------------------------------------------

local function needsChosenSize(item)
    if not MTIR.canClothesHaveSize(item) then
        return false
    end
    local data = MTIR.getData(item)
    return data ~= nil and data.size == nil
end

local function queueChooseSize(player, clothes, sizeName)
    for _, item in ipairs(clothes) do
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
        ISTimedActionQueue.add(MTIR_ChooseSizeAction:new(player, item, sizeName))
    end
end

local function addChooseSizeOption(items, player, context)
    local clothes = collectItems(items, needsChosenSize)
    if #clothes == 0 then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_JobType_ChooseClothesSize"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, size in ipairs(MTIR.SIZE_LIST) do
        subMenu:addOption(size.name, player, queueChooseSize, clothes, size.name)
    end
end

-- ----------------------------------------------------------------------------
-- Débogage : fixer ou effacer la taille (mode debug, ou rôle EditItem en MP)
-- ----------------------------------------------------------------------------

local function queueDebugSize(player, item, mode, size)
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    ISTimedActionQueue.add(MTIR_DebugSizeAction:new(player, item, mode, size))
end

local function addInfoOption(subMenu, text)
    local option = subMenu:addOption(text)
    option.notAvailable = true
end

local function addDebugShoeOptions(subMenu, player, item)
    local data = MTIR.getShoeData(item)
    addInfoOption(subMenu, getText("IGUI_MTIR_Debug_Foot", tostring(MTIR.getPlayerShoeSize(player))))
    addInfoOption(subMenu, getText("IGUI_MTIR_Debug_Stomp", string.format("%.2f", item:getStompPower()),
        string.format("%.2f", MTIR.getOriginalStompPower(item))))
    if not isClient() and MTIR.getFriction then
        addInfoOption(subMenu, getText("IGUI_MTIR_Debug_Friction", tostring(math.floor(MTIR.getFriction(player) * 100))))
    end
    if player:isEquippedClothing(item) then
        local percent = function(kind)
            return tostring(math.floor(MTIR.getShoeLossChance(player, kind) * 100 + 0.5))
        end
        addInfoOption(subMenu, getText("IGUI_MTIR_Debug_LossRisk", percent("fall"), percent("fenceRun")))
    end
    for size = MTIR.SHOE_MIN, MTIR.SHOE_MAX do
        local option = subMenu:addOption(getText("IGUI_MTIR_ShoeSize", tostring(size)), player, queueDebugSize,
            item, "shoe", tostring(size))
        option.notAvailable = data ~= nil and data.size == size
    end
end

local function addDebugClothesOptions(subMenu, player, item)
    local data = MTIR.getData(item)
    addInfoOption(subMenu, getText("IGUI_MTIR_Debug_Player", MTIR.getPlayerSize(player).name))
    for _, size in ipairs(MTIR.SIZE_LIST) do
        local option = subMenu:addOption(size.name, player, queueDebugSize, item, "clothes", size.name)
        option.notAvailable = data ~= nil and data.size == size.name
    end
end

local function addDebugOption(item, player, context)
    if not MTIR.canUseDebug(player) then
        return
    end
    local isShoe = MTIR.canShoeHaveSize(item)
    if not isShoe and not MTIR.canClothesHaveSize(item) then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_Debug_Menu"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if MTIR.getClimbTripChance then
        local risk = function(kind)
            return string.format("%.0f", MTIR.getClimbTripChance(player, kind))
        end
        addInfoOption(subMenu, getText("IGUI_MTIR_Debug_TripRisk", risk("fence"), risk("fenceRun"), risk("wall")))
    end
    if isShoe then
        addDebugShoeOptions(subMenu, player, item)
    else
        addDebugClothesOptions(subMenu, player, item)
    end
    subMenu:addOption(getText("IGUI_MTIR_Debug_Clear"), player, queueDebugSize, item, "clear", "")
end

-- ----------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end
    local clothing = singleClothing(items)
    if clothing then
        if MTIR.canResizeClothes(clothing) then
            addResizeOption(clothing, player, context)
        end
        if MTIR.canReconditionClothes(clothing) then
            addReconditionOption(clothing, player, context)
        end
        addDebugOption(clothing, player, context)
    end
    addCheckSizeOption(items, player, context)
    addChooseSizeOption(items, player, context)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
