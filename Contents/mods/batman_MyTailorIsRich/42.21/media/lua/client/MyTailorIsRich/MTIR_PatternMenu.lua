-- ============================================================================
-- My Tailor Is Rich — menu contextuel des patrons (client)
-- « Tracer un patron » sur un vêtement ou une paire ; « Coudre d'après le
-- patron » sur un patron, avec une option par taille. Lecture seule : tout
-- passe par les actions partagées exécutées par l'autorité.
-- ============================================================================

require "MyTailorIsRich/MTIR_ContextMenu"
require "TimedActions/MTIR_TracePatternAction"
require "TimedActions/MTIR_SewPatternAction"

local U = MTIR.MenuUtil

--- Un seul objet sélectionné, ou nil.
local function singleItem(items)
    if #items ~= 1 then
        return nil
    end
    local entry = items[1]
    if type(entry) == "table" then
        return entry.items and #entry.items == 2 and entry.items[2] or nil
    end
    return entry
end

local function needsHeader()
    return " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_craft_Needs") .. ":"
end

local function countLine(ok, fullType, have, need)
    return U.needLine(ok, getItemNameFromFullType(fullType) .. " " .. have .. "/" .. need)
end

local function bringToHands(player, primary, secondary)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), primary, true)
    ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), secondary, false)
end

-- ----------------------------------------------------------------------------
-- Tracer
-- ----------------------------------------------------------------------------

local function queueTrace(player, item, scissors, pen, papers)
    ISInventoryPaneContextMenu.transferIfNeeded(player, papers)
    if player:isEquippedClothing(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
    else
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    end
    bringToHands(player, scissors, pen)
    ISTimedActionQueue.add(MTIR_TracePatternAction:new(player, item, scissors, pen, papers))
end

local function addBlockedTrace(context, item, reasonKey)
    local option = context:addOption(getText("IGUI_MTIR_JobType_TracePattern"))
    option.notAvailable = true
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.texture = item:getTex()
    option.toolTip.description = ISInventoryPaneContextMenu.bhs .. getText(reasonKey)
end

local function addTraceOption(item, player, context)
    local kind, reasonKey = MTIR.getTraceKind(item)
    if not kind then
        if reasonKey then
            addBlockedTrace(context, item, reasonKey)
        end
        return
    end
    local model = MTIR.describeModel(item)
    local inventory = player:getInventory()
    local scissors = inventory:getFirstEvalRecurse(MTIR.predicateScissors)
    local pen = inventory:getFirstEvalRecurse(MTIR.predicatePen)
    local allPapers = inventory:getItemsFromFullType(MTIR.getPaperType(), true)
    local requiredPaper = MTIR.getRequiredPaper(model)
    local papers = MTIR.pickItems(allPapers, requiredPaper)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToTrace(model)
    local conditionOk = MTIR.canTraceCondition(item)

    local option = context:addOption(getText("IGUI_MTIR_JobType_TracePattern"), player, queueTrace,
        item, scissors, pen, papers)
    option.notAvailable = not (scissors and pen and papers and conditionOk and tailoring >= requiredLevel)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = item:getTex()
    tooltip:setName(getText("IGUI_MTIR_PatternName", getItemNameFromFullType(item:getFullType())))
    tooltip.description = getText("IGUI_MTIR_Pattern_TraceInfo", tostring(MTIR.opt("PatternMaxUses")))
        .. needsHeader()
        .. U.needLine(scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. U.needLine(pen ~= nil, getText("IGUI_MTIR_Pattern_Pen"))
        .. countLine(papers ~= nil, MTIR.getPaperType(), allPapers:size(), requiredPaper)
        .. U.needLine(conditionOk, getText("IGUI_MTIR_Pattern_GoodCondition"))
        .. U.tailoringLine(tailoring, requiredLevel)
    option.toolTip = tooltip
end

-- ----------------------------------------------------------------------------
-- Coudre
-- ----------------------------------------------------------------------------

local function queueSew(player, pattern, needle, scissors, threads, materials, size)
    ISInventoryPaneContextMenu.transferIfNeeded(player, pattern)
    ISInventoryPaneContextMenu.transferIfNeeded(player, threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, materials)
    bringToHands(player, scissors, needle)
    ISTimedActionQueue.add(MTIR_SewPatternAction:new(player, pattern, needle, scissors, threads, materials, size))
end

local function materialNames(fabric)
    local names = {}
    for _, fullType in ipairs(MTIR.getPatternMaterialTypes(fabric)) do
        local name = getItemNameFromFullType(fullType)
        local known = false
        for _, existing in ipairs(names) do
            known = known or existing == name
        end
        if not known then
            table.insert(names, name)
        end
    end
    return table.concat(names, ", ")
end

--- Outils, fil et capacités communs à toutes les tailles du patron.
local function sewContext(player, data)
    local inventory = player:getInventory()
    local allThreads = inventory:getItemsFromType("Thread", true)
    local requiredThread = MTIR.getPatternThread(data)
    local leather = data.fabric == "Leather"
    return {
        needleLabel = leather and getText("IGUI_MTIR_Pattern_NeedleOrAwl") or getItemNameFromFullType("Base.Needle"),
        cutterLabel = leather and getText("IGUI_MTIR_Pattern_ScissorsOrKnife") or getItemNameFromFullType("Base.Scissors"),
        needle = inventory:getFirstEvalRecurse(MTIR.predicatePatternNeedle(data.fabric)),
        scissors = inventory:getFirstEvalRecurse(MTIR.predicatePatternCutter(data.fabric)),
        requiredThread = requiredThread,
        remainingThread = MTIR.getRemainingThread(allThreads),
        threads = MTIR.pickThreads(allThreads, requiredThread),
        tailoring = player:getPerkLevel(Perks.Tailoring),
        requiredLevel = MTIR.getRequiredLevelToSew(data),
    }
end

local function isOwnSize(player, data, size)
    if data.kind == "shoe" then
        return tonumber(size) == MTIR.getPlayerShoeSize(player)
    end
    return size == MTIR.getPlayerSize(player).name
end

local function addSizeOption(subMenu, player, pattern, data, size, ctx)
    local requiredUnits = MTIR.getPatternMaterialUnits(data, size)
    local available, materials = MTIR.pickPatternMaterials(player:getInventory(), data.fabric, requiredUnits)
    local label = data.kind == "shoe" and getText("IGUI_MTIR_ShoeSize", size) or size
    if isOwnSize(player, data, size) then
        label = label .. " " .. getText("IGUI_MTIR_Pattern_YourSize")
    end
    local option = subMenu:addOption(label, player, queueSew, pattern, ctx.needle, ctx.scissors, ctx.threads,
        materials, size)
    option.notAvailable = not (ctx.needle and ctx.scissors and ctx.threads and materials
        and ctx.tailoring >= ctx.requiredLevel)

    local success = ctx.tailoring >= ctx.requiredLevel
        and MTIR.getSuccessChanceForChange(ctx.tailoring, ctx.requiredLevel) or 0
    local offChance = MTIR.getPatternOffChance(data, ctx.tailoring)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = pattern:getTex()
    tooltip:setName(getItemNameFromFullType(data.fullType) .. " (" .. size .. ")")
    tooltip.description = U.chanceHeader("Tooltip_chanceSuccess", math.min(1, success))
        .. " <LINE>" .. U.colorForPercent(1 - offChance * 2)
        .. getText("IGUI_MTIR_Pattern_OffChance", tostring(math.floor(offChance * 100 + 0.5)))
        .. needsHeader()
        .. U.needLine(ctx.needle ~= nil, ctx.needleLabel)
        .. U.needLine(ctx.scissors ~= nil, ctx.cutterLabel)
        .. countLine(ctx.threads ~= nil, "Base.Thread", ctx.remainingThread, ctx.requiredThread)
        .. U.needLine(materials ~= nil, getText("IGUI_MTIR_Pattern_Material", materialNames(data.fabric),
            tostring(available), tostring(requiredUnits)))
        .. U.tailoringLine(ctx.tailoring, ctx.requiredLevel)
    option.toolTip = tooltip
end

local function addSewOption(pattern, player, context)
    local data = MTIR.getPatternData(pattern)
    if not data then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_JobType_SewPattern"))
    if not MTIR.patternModelExists(data) or (data.uses or 0) <= 0 then
        option.notAvailable = true
        option.toolTip = ISInventoryPaneContextMenu.addToolTip()
        option.toolTip.description = ISInventoryPaneContextMenu.bhs .. getText("IGUI_MTIR_Pattern_MissingModel")
        return
    end
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    local ctx = sewContext(player, data)
    for _, size in ipairs(MTIR.getPatternSizes(data)) do
        addSizeOption(subMenu, player, pattern, data, size, ctx)
    end
end

-- ----------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local item = player and singleItem(items)
    if not item then
        return
    end
    if MTIR.isPattern(item) then
        addSewOption(item, player, context)
    elseif instanceof(item, "Clothing") then
        addTraceOption(item, player, context)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
