-- ============================================================================
-- My Tailor Is Rich — classeur à patrons, copie et aperçu 3D (client)
-- Menu contextuel :
--   * patron : « Ranger dans le classeur », « Copier le patron », « Aperçu sur moi » ;
--   * classeur : « Patrons (n/max) » → un sous-menu par patron rangé (coudre,
--     sortir, aperçu), « Ranger tous les patrons (n) ».
-- Infobulle du classeur (TooltipLib) : la liste des patrons rangés.
-- Lecture seule : tout changement passe par une action chronométrée exécutée
-- par l'autorité (MTIR_BinderStoreAction, MTIR_BinderTakeAction,
-- MTIR_CopyPatternAction, MTIR_SewPatternAction).
-- ============================================================================

require "MyTailorIsRich/MTIR_PatternMenu"
require "MyTailorIsRich/MTIR_PatternPreview"
require "MyTailorIsRich/MTIR_PatternBinder"
require "MyTailorIsRich/MTIR_PatternCopy"
require "MyTailorIsRich/MTIR_WorkTable"
require "TimedActions/MTIR_BinderStoreAction"
require "TimedActions/MTIR_BinderTakeAction"
require "TimedActions/MTIR_CopyPatternAction"

local U = MTIR.MenuUtil

-- Patrons listés dans l'infobulle d'un classeur, au plus.
local TOOLTIP_MAX_LINES = 12

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

local function carried(player, predicate)
    local found = player:getInventory():getAllEvalRecurse(predicate)
    local list = {}
    for i = 0, found:size() - 1 do
        table.insert(list, found:get(i))
    end
    return list
end

local function usesText(data)
    return tostring(data and data.uses or 0) .. "/" .. tostring(MTIR.opt("PatternMaxUses"))
end

--- Libellé d'un patron rangé : nom et utilisations restantes.
local function entryLabel(binder, entry)
    return MTIR.getSourcePatternName(binder, entry.id) .. " (" .. usesText(MTIR.binderEntryPattern(entry)) .. ")"
end

local function binderLabel(binder)
    return binder:getName() .. " (" .. MTIR.getBinderCount(binder) .. "/" .. MTIR.getBinderCapacity() .. ")"
end

local function addPreviewOption(context, player, fullType)
    if not fullType or not MTIR.PatternPreview.canPreview(fullType) then
        return
    end
    context:addOption(getText("IGUI_MTIR_Preview"), player, MTIR.PatternPreview.open, fullType)
end

-- ----------------------------------------------------------------------------
-- Ranger
-- ----------------------------------------------------------------------------

--- Classeur et patron dans l'inventaire principal (patron lâché s'il est en main), puis rangement.
local function queueStore(player, binder, pattern)
    ISInventoryPaneContextMenu.transferIfNeeded(player, binder)
    if player:isEquipped(pattern) then
        ISTimedActionQueue.add(ISUnequipAction:new(player, pattern, 50))
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, pattern)
    ISTimedActionQueue.add(MTIR_BinderStoreAction:new(player, binder, pattern))
end

--- Range autant de patrons que le classeur a de places libres.
local function queueStoreAll(player, binder, patterns)
    local free = MTIR.getBinderCapacity() - MTIR.getBinderCount(binder)
    for i = 1, math.min(free, #patterns) do
        queueStore(player, binder, patterns[i])
    end
end

local function setFullTooltip(option, binder)
    option.notAvailable = true
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = ISInventoryPaneContextMenu.bhs
        .. getText("IGUI_MTIR_Binder_Full", tostring(MTIR.getBinderCapacity()))
    option.toolTip.texture = binder:getTex()
end

local function addStoreOption(pattern, player, context)
    local binders = carried(player, MTIR.isBinder)
    if #binders == 0 then
        return
    end
    local label = getText("IGUI_MTIR_Binder_Store")
    if #binders == 1 then
        local option = context:addOption(label, player, queueStore, binders[1], pattern)
        if MTIR.isBinderFull(binders[1]) then
            setFullTooltip(option, binders[1])
        end
        return
    end
    local option = context:addOption(label)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    for _, binder in ipairs(binders) do
        local sub = subMenu:addOption(binderLabel(binder), player, queueStore, binder, pattern)
        if MTIR.isBinderFull(binder) then
            setFullTooltip(sub, binder)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Copier
-- ----------------------------------------------------------------------------

local function bringToHands(player, primary, secondary)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), primary, true)
    ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), secondary, false)
end

--- Transferts, marche jusqu'à la table, outils en main, copie.
local function queueCopy(player, pattern, scissors, pen, papers, workTable)
    ISInventoryPaneContextMenu.transferIfNeeded(player, papers)
    ISInventoryPaneContextMenu.transferIfNeeded(player, pattern)
    if not luautils.walkAdjObject(player, workTable, true, true) then
        return
    end
    bringToHands(player, scissors, pen)
    ISTimedActionQueue.add(MTIR_CopyPatternAction:new(player, pattern, scissors, pen, papers,
        MTIR.encodeMachinePos(workTable)))
end

local function addCopyOption(pattern, player, context)
    local data = MTIR.getPatternData(pattern)
    if not MTIR.isPatternCopyEnabled() or not data then
        return
    end
    local inventory = player:getInventory()
    local scissors = inventory:getFirstEvalRecurse(MTIR.predicateScissors)
    local pen = inventory:getFirstEvalRecurse(MTIR.predicatePen)
    local allPapers = inventory:getItemsFromFullType(MTIR.getPaperType(), true)
    local requiredPaper = MTIR.getRequiredPaperToCopy(data)
    local papers = MTIR.pickItems(allPapers, requiredPaper)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local requiredLevel = MTIR.getRequiredLevelToCopy(data)
    local usable = MTIR.isUsablePatternData(data)
    local workTable = MTIR.findNearestWorkTable(player)

    local option = context:addOption(getText("IGUI_MTIR_JobType_CopyPattern"), player, queueCopy,
        pattern, scissors, pen, papers, workTable)
    option.notAvailable = not (usable and scissors and pen and papers and workTable and tailoring >= requiredLevel)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = pattern:getTex()
    tooltip:setName(getText("IGUI_MTIR_PatternCopyName", getItemNameFromFullType(data.fullType)))
    local description = getText("IGUI_MTIR_Pattern_CopyInfo", tostring(MTIR.getCopyPrecision(data)),
        tostring(data.precision or 0), tostring(MTIR.opt("PatternMaxUses")))
    if not usable then
        description = description .. " <LINE> " .. ISInventoryPaneContextMenu.bhs
            .. getText("IGUI_MTIR_Pattern_MissingModel")
    end
    tooltip.description = description
        .. " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_craft_Needs") .. ":"
        .. U.needLine(scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. U.needLine(pen ~= nil, getText("IGUI_MTIR_Pattern_Pen"))
        .. U.needLine(papers ~= nil, getItemNameFromFullType(MTIR.getPaperType()) .. " "
            .. allPapers:size() .. "/" .. requiredPaper)
        .. U.needLine(workTable ~= nil, getText("IGUI_MTIR_Pattern_WorkTable"))
        .. U.tailoringLine(tailoring, requiredLevel)
    option.toolTip = tooltip
end

-- ----------------------------------------------------------------------------
-- Classeur
-- ----------------------------------------------------------------------------

local function queueTake(player, binder, entryId)
    ISInventoryPaneContextMenu.transferIfNeeded(player, binder)
    ISTimedActionQueue.add(MTIR_BinderTakeAction:new(player, binder, entryId))
end

--- Sous-menu d'un patron rangé : coudre (tailles), sortir, aperçu.
local function addEntryOption(subMenu, player, binder, entry)
    local data = MTIR.binderEntryPattern(entry)
    local option = subMenu:addOption(entryLabel(binder, entry))
    local entryMenu = subMenu:getNew(subMenu)
    subMenu:addSubMenu(option, entryMenu)
    if data then
        MTIR.SewUI.addSewOption(binder, player, entryMenu, entry.id)
    end
    entryMenu:addOption(getText("IGUI_MTIR_Binder_TakeOut"), player, queueTake, binder, entry.id)
    if data and MTIR.patternModelExists(data) then
        addPreviewOption(entryMenu, player, data.fullType)
    end
end

local function addBinderOptions(binder, player, context)
    local entries = MTIR.getBinderEntries(binder)
    local label = getText("IGUI_MTIR_Binder_Patterns", tostring(#entries), tostring(MTIR.getBinderCapacity()))
    local option = context:addOption(label)
    if #entries == 0 then
        option.notAvailable = true
        option.toolTip = ISInventoryPaneContextMenu.addToolTip()
        option.toolTip.description = getText("IGUI_MTIR_Binder_Empty")
    else
        local subMenu = context:getNew(context)
        context:addSubMenu(option, subMenu)
        for _, entry in ipairs(entries) do
            addEntryOption(subMenu, player, binder, entry)
        end
    end
    local patterns = carried(player, MTIR.isPattern)
    if #patterns > 0 then
        local store = context:addOption(getText("IGUI_MTIR_Binder_StoreAll", tostring(#patterns)), player,
            queueStoreAll, binder, patterns)
        if MTIR.isBinderFull(binder) then
            setFullTooltip(store, binder)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Poids des classeurs (client MP)
-- ----------------------------------------------------------------------------

--- syncItemFields transmet la ModData du classeur mais pas son actualWeight
--- (SyncItemFieldsPacket : seul `weight` part, sauf pour un aliment) : un client
--- MP recalcule localement le poids de ses classeurs d'après leur contenu.
local function refreshBinderWeights(player)
    if not isClient() or not player then
        return
    end
    for _, binder in ipairs(carried(player, MTIR.isBinder)) do
        MTIR.applyBinderWeight(binder)
    end
end

--- Après chaque notification du serveur (rangement, sortie, couture : MTIR.tell),
--- envoyée après la synchronisation du classeur.
local function onServerCommand(module, command)
    if module ~= MTIR.NET_MODULE or command ~= "fx" then
        return
    end
    for i = 0, getNumActivePlayers() - 1 do
        refreshBinderWeights(getSpecificPlayer(i))
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- ----------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    refreshBinderWeights(player)
    local item = player and singleItem(items)
    if not item then
        return
    end
    if MTIR.isPattern(item) then
        local data = MTIR.getPatternData(item)
        addStoreOption(item, player, context)
        addCopyOption(item, player, context)
        if data and MTIR.patternModelExists(data) then
            addPreviewOption(context, player, data.fullType)
        end
    elseif MTIR.isBinder(item) then
        addBinderOptions(item, player, context)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

-- ----------------------------------------------------------------------------
-- Infobulle du classeur (TooltipLib, prérequis du mod)
-- ----------------------------------------------------------------------------

require "TooltipLib/Core"

local WHITE = { 1, 1, 1, 1 }
local DIM = { 0.75, 0.75, 0.75, 1 }
local WORN = { 0.9, 0.5, 0.4, 1 }

local function binderTooltip(ctx)
    local binder = ctx.item
    local entries = MTIR.getBinderEntries(binder)
    ctx:addKeyValue(getText("IGUI_MTIR_Binder_Contents"), #entries .. "/" .. MTIR.getBinderCapacity(), WHITE, WHITE)
    for index, entry in ipairs(entries) do
        if index > TOOLTIP_MAX_LINES then
            ctx:addLabel(getText("IGUI_MTIR_Binder_More", tostring(#entries - TOOLTIP_MAX_LINES)), DIM)
            return
        end
        local data = MTIR.binderEntryPattern(entry)
        local usable = MTIR.isUsablePatternData(data)
        ctx:addKeyValue(MTIR.getSourcePatternName(binder, entry.id), usesText(data), DIM, usable and WHITE or WORN)
    end
end

if TooltipLib and type(TooltipLib.registerProvider) == "function" then
    TooltipLib.registerProvider({
        id = "MTIR_PatternBinder",
        target = "item",
        description = "IGUI_MTIR_TooltipProviderBinder",
        enabled = function(item)
            return MTIR.isBinder(item)
        end,
        callback = binderTooltip,
    })
end
