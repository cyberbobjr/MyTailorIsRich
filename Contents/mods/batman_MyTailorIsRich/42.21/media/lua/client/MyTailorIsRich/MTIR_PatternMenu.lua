-- ============================================================================
-- My Tailor Is Rich — menu contextuel des patrons (client)
-- « Tracer un patron » sur un vêtement ou une paire ; « Coudre d'après le
-- patron » sur un patron, avec une option par taille. Lecture seule : tout
-- passe par les actions partagées exécutées par l'autorité.
-- Un patron rangé dans un classeur à patrons se coud de la même façon : la
-- source est alors le classeur et l'id de l'entrée (MTIR_PatternBinder.lua).
-- ============================================================================

require "MyTailorIsRich/MTIR_ContextMenu"
require "TimedActions/MTIR_TracePatternAction"
require "TimedActions/MTIR_SewPatternAction"
require "MyTailorIsRich/MTIR_SewingMachine"
require "MyTailorIsRich/MTIR_Alterations"
require "MyTailorIsRich/MTIR_WorkTable"
require "MyTailorIsRich/MTIR_PatternBinder"

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

--- Transferts, déshabillage éventuel, marche jusqu'à la table, outils en main, tracé.
local function queueTrace(player, item, scissors, pen, papers, workTable)
    ISInventoryPaneContextMenu.transferIfNeeded(player, papers)
    if player:isEquippedClothing(item) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, item, 50))
    else
        ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    end
    if not luautils.walkAdjObject(player, workTable, true, true) then
        return
    end
    bringToHands(player, scissors, pen)
    ISTimedActionQueue.add(MTIR_TracePatternAction:new(player, item, scissors, pen, papers,
        MTIR.encodeMachinePos(workTable)))
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
    local workTable = MTIR.findNearestWorkTable(player)

    local option = context:addOption(getText("IGUI_MTIR_JobType_TracePattern"), player, queueTrace,
        item, scissors, pen, papers, workTable)
    option.notAvailable = not (scissors and pen and papers and workTable and conditionOk
        and tailoring >= requiredLevel)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = item:getTex()
    tooltip:setName(getText("IGUI_MTIR_PatternName", getItemNameFromFullType(item:getFullType())))
    tooltip.description = getText("IGUI_MTIR_Pattern_TraceInfo", tostring(MTIR.opt("PatternMaxUses")))
        .. needsHeader()
        .. U.needLine(scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. U.needLine(pen ~= nil, getText("IGUI_MTIR_Pattern_Pen"))
        .. countLine(papers ~= nil, MTIR.getPaperType(), allPapers:size(), requiredPaper)
        .. U.needLine(conditionOk, getText("IGUI_MTIR_Pattern_GoodCondition"))
        .. U.needLine(workTable ~= nil, getText("IGUI_MTIR_Pattern_WorkTable"))
        .. U.tailoringLine(tailoring, requiredLevel)
    option.toolTip = tooltip
end

-- ----------------------------------------------------------------------------
-- Coudre
-- ----------------------------------------------------------------------------

--- Transferts, outils en main puis couture. machine : objet machine à coudre, ou nil (à la main).
--- Chaussures : l'alêne et la colle (req.awl, req.glue) rejoignent l'inventaire principal.
--- entryId : patron rangé dans le classeur `pattern`, ou nil.
local function queueSew(player, pattern, req, size, machine, entryId)
    ISInventoryPaneContextMenu.transferIfNeeded(player, pattern)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.materials)
    local awl = req.needsAwl and req.awl or nil
    local glue = req.needsGlue and req.glue or nil
    if awl then
        ISInventoryPaneContextMenu.transferIfNeeded(player, awl)
    end
    if glue then
        ISInventoryPaneContextMenu.transferIfNeeded(player, glue)
    end
    if machine and not luautils.walkAdjObject(player, machine, true, true) then
        return
    end
    bringToHands(player, req.scissors, req.needle)
    ISTimedActionQueue.add(MTIR_SewPatternAction:new(player, pattern, req.needle, req.scissors, req.threads,
        req.materials, size, machine and MTIR.encodeMachinePos(machine) or "", awl, glue, entryId))
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

local function isOwnSize(player, data, size)
    if data.kind == "shoe" then
        return tonumber(size) == MTIR.getPlayerShoeSize(player)
    end
    return size == MTIR.getPlayerSize(player).name
end

local function sizeLabel(player, data, size)
    local label = data.kind == "shoe" and getText("IGUI_MTIR_ShoeSize", size) or size
    if isOwnSize(player, data, size) then
        label = label .. " " .. getText("IGUI_MTIR_Pattern_YourSize")
    end
    return label
end

--- Chaussures : alêne et colle (champs needsAwl/awl, needsGlue/glue de MTIR.getSewRequirements).
local function shoeToolLines(req)
    local text = ""
    if req.needsAwl then
        text = text .. U.needLine(req.awl ~= nil, getItemNameFromFullType("Base.Awl"))
    end
    if req.needsGlue then
        text = text .. U.needLine(req.glue ~= nil, getText("IGUI_MTIR_Pattern_Glue", tostring(req.requiredGlue)))
    end
    return text
end

--- Texte riche : chances puis besoins (MTIR.getSewRequirements).
local function describeSew(data, req)
    local shoe = data.kind == "shoe"
    local leather = data.fabric == "Leather"
    local needleLabel = (leather and not shoe) and getText("IGUI_MTIR_Pattern_NeedleOrAwl")
        or getItemNameFromFullType("Base.Needle")
    local cutterLabel = (leather or shoe) and getText("IGUI_MTIR_Pattern_ScissorsOrKnife")
        or getItemNameFromFullType("Base.Scissors")
    return U.chanceHeader("Tooltip_chanceSuccess", req.success)
        .. " <LINE>" .. U.colorForPercent(1 - req.offChance * 2)
        .. getText("IGUI_MTIR_Pattern_OffChance", tostring(math.floor(req.offChance * 100 + 0.5)))
        .. needsHeader()
        .. U.needLine(req.needle ~= nil, needleLabel)
        .. shoeToolLines(req)
        .. U.needLine(req.scissors ~= nil, cutterLabel)
        .. countLine(req.threads ~= nil, "Base.Thread", req.remainingThread, req.requiredThread)
        .. U.thimbleLine(req)
        .. U.needLine(req.materials ~= nil, getText("IGUI_MTIR_Pattern_Material", materialNames(data.fabric),
            tostring(req.availableUnits), tostring(req.requiredUnits)))
        .. U.tailoringLine(req.effectiveLevel or req.tailoring, req.requiredLevel)
end

--- Partagé avec le panneau de la machine à coudre (MTIR_SewingMachineWindow.lua) :
---   queueSew(player, pattern, req, size, machine|nil, entryId|nil) : transferts (alêne
---     et colle des chaussures compris, pris dans req), marche jusqu'à la machine (si
---     machine), outils en main, puis MTIR_SewPatternAction (entryId : patron rangé
---     dans le classeur `pattern`) ;
---   sizeLabel(player, data, size) -> libellé de taille (« (votre taille) » compris) ;
---   describeSew(data, req) -> texte riche (req : MTIR.getSewRequirements ; ligne du dé
---     à coudre quand req.needsThimble ; alêne et colle quand req.needsAwl / needsGlue).
MTIR.SewUI = { queueSew = queueSew, sizeLabel = sizeLabel, describeSew = describeSew }

local function addSizeOption(subMenu, player, pattern, data, size, entryId)
    local req = MTIR.getSewRequirements(player, data, size, MTIR.SEW_BY_HAND)
    local option = subMenu:addOption(sizeLabel(player, data, size), player, queueSew, pattern, req, size, nil,
        entryId)
    option.notAvailable = not req.ready
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = pattern:getTex()
    tooltip:setName(getItemNameFromFullType(data.fullType) .. " (" .. size .. ")")
    tooltip.description = describeSew(data, req)
    option.toolTip = tooltip
end

--- « Coudre d'après le patron » et ses tailles. entryId : patron rangé dans le
--- classeur `pattern` (menu du classeur), sinon nil.
local function addSewOption(pattern, player, context, entryId)
    local data = MTIR.getSourcePatternData(pattern, entryId)
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
    for _, size in ipairs(MTIR.getPatternSizes(data)) do
        addSizeOption(subMenu, player, pattern, data, size, entryId)
    end
end

--- Pour le menu du classeur (MTIR_PatternBinderMenu.lua).
MTIR.SewUI.addSewOption = addSewOption

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
