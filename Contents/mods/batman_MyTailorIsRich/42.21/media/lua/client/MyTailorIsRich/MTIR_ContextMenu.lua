-- ============================================================================
-- My Tailor Is Rich — menu contextuel d'inventaire (client)
-- Lecture seule des données ; toute modification passe par une action
-- chronométrée partagée, exécutée par l'autorité.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Alterations"
require "MyTailorIsRich/MTIR_Reach"
require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/MTIR_CheckSizeAction"
require "TimedActions/MTIR_ResizeAction"
require "TimedActions/MTIR_ReconditionAction"
require "TimedActions/MTIR_MachineMaintenanceAction"
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

--- Rien à faire pour un vêtement porté sur soi ; approche d'un cadavre, meuble
--- ou véhicule pour le lire sur place ; sinon (sol, sac posé) transfert.
--- Faux : vêtement ignoré (conteneur inaccessible).
local function prepareCheck(player, item, approached)
    if MTIR.isCarried(player, item) then
        return true
    end
    local container = item:getContainer()
    if not container then
        return false
    end
    if MTIR.getInPlaceContainer(item) then
        -- walkToContainer vide la file avant de marcher : une approche par conteneur
        -- (une sélection vient d'un seul panneau, donc d'un seul conteneur).
        if approached[container] == nil then
            approached[container] = luautils.walkToContainer(container, player:getPlayerNum())
        end
        return approached[container]
    end
    ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(player, item, container,
        player:getInventory()))
    return true
end

local function queueCheck(player, clothes)
    local approached = {}
    for _, item in ipairs(clothes) do
        if prepareCheck(player, item, approached) then
            ISTimedActionQueue.add(MTIR_CheckSizeAction:new(player, item))
        end
    end
end

local function addCheckSizeOption(items, player, context)
    local clothes = collectItems(items, needsCheck)
    if #clothes > 0 then
        context:addOption(getText("IGUI_MTIR_JobType_CheckClothesSize"), player, queueCheck, clothes)
    end
end

-- ----------------------------------------------------------------------------
-- Besoins communs (texte riche des infobulles)
-- ----------------------------------------------------------------------------

local function needsHeader()
    return " <LINE> <LINE> <RGB:1,1,1> " .. getText("Tooltip_craft_Needs") .. ":"
end

--- Ligne du dé à coudre, seulement quand il est exigé (couture à la main, option RequireThimble).
local function thimbleLine(req)
    if not req.needsThimble then
        return ""
    end
    return needLine(req.thimble ~= nil, getText("IGUI_MTIR_Need_Thimble"))
end

--- Aiguille, ciseaux, fil et dé (champs de MTIR.getResizeRequirements / getReconditionRequirements).
local function toolLines(req)
    return needsHeader()
        .. needLine(req.needle ~= nil, getItemNameFromFullType("Base.Needle"))
        .. needLine(req.scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
        .. needLine(req.threads ~= nil,
            getItemNameFromFullType("Base.Thread") .. " " .. req.remainingThread .. "/" .. req.requiredThread)
        .. thimbleLine(req)
end

local function materialLine(req)
    return needLine(req.materials ~= nil, getItemNameFromFullType(req.materialType) .. " "
        .. req.availableMaterial .. "/" .. req.requiredMaterial)
end

-- Partagé avec MTIR_PatternMenu.lua.
MTIR.MenuUtil.needsHeader = needsHeader
MTIR.MenuUtil.thimbleLine = thimbleLine

--- Déséquipe ou rapatrie le vêtement, puis marche jusqu'à la machine s'il y en a une.
--- Faux si la machine est inaccessible (rien n'est alors ajouté après les transferts).
local function bringToWork(player, item, machine)
    bringClothing(player, item)
    if machine then
        return luautils.walkAdjObject(player, machine, true, true)
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Retoucher
-- ----------------------------------------------------------------------------

--- Transferts, outils en main puis retouche. machine : objet machine à coudre, ou nil (à la main).
local function queueResize(player, item, req, upsize, machine)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.materials)
    if not bringToWork(player, item, machine) then
        return
    end
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), req.scissors, true)
    ISWorldObjectContextMenu.equip(player, player:getSecondaryHandItem(), req.needle, false)
    ISTimedActionQueue.add(MTIR_ResizeAction:new(player, item, req.needle, req.scissors, req.threads,
        req.materials, upsize, machine and MTIR.encodeMachinePos(machine) or ""))
end

--- Texte riche : chance puis besoins (MTIR.getResizeRequirements).
local function describeResize(item, req, upsize)
    return chanceHeader("Tooltip_chanceSuccess", req.success)
        .. toolLines(req)
        .. materialLine(req)
        .. tailoringLine(req.effectiveLevel, req.requiredLevel)
end

--- Une option de retouche à la main. upsize : bandes de tissu ; sinon trombones.
local function addResizeSubOption(subMenu, player, item, upsize)
    local req = MTIR.getResizeRequirements(player, item, upsize, MTIR.SEW_BY_HAND)
    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_ToSize", req.targetSize.name), player, queueResize,
        item, req, upsize, nil)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.texture = item:getTex()
    tooltip:setName(getItemNameFromFullType(item:getFullType()) .. " (" .. req.targetSize.name .. ")")
    tooltip.description = describeResize(item, req, upsize)
    option.toolTip = tooltip
    option.notAvailable = not req.ready
end

local function addResizeOption(item, player, context)
    local canUp = MTIR.getResizeTarget(item, true) ~= nil
    local canDown = MTIR.getResizeTarget(item, false) ~= nil
    if not canUp and not canDown then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_JobType_ResizeClothes"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    if canUp then
        addResizeSubOption(subMenu, player, item, true)
    end
    if canDown then
        addResizeSubOption(subMenu, player, item, false)
    end
end

-- ----------------------------------------------------------------------------
-- Remettre en état
-- ----------------------------------------------------------------------------

--- Transferts puis remise en état. spareItem : exemplaire de rechange, ou nil (bandes).
--- machine : objet machine à coudre, ou nil (à la main).
local function queueRecondition(player, item, req, spareItem, machine)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.needle)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.scissors)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.threads)
    ISInventoryPaneContextMenu.transferIfNeeded(player, spareItem or req.materials)
    if not bringToWork(player, item, machine) then
        return
    end
    local machinePos = machine and MTIR.encodeMachinePos(machine) or ""
    if spareItem then
        ISTimedActionQueue.add(MTIR_ReconditionSpareAction:new(player, item, req.needle, req.scissors, req.threads,
            spareItem, machinePos))
    else
        ISTimedActionQueue.add(MTIR_ReconditionAction:new(player, item, req.needle, req.scissors, req.threads,
            req.materials, machinePos))
    end
end

local function spareDisplayName(spareItem)
    local name = getItemNameFromFullType(spareItem:getFullType())
    local data = MTIR.getData(spareItem)
    if MTIR.canClothesHaveSize(spareItem) and data and data.reveal and data.size then
        name = name .. " (" .. data.size .. ")"
    end
    return name
end

--- Ligne de l'exemplaire de rechange, teintée selon son état et ses réparations.
local function spareLine(spareItem)
    local spareCondition = spareItem:getCondition() / spareItem:getConditionMax()
    local spareRepaired = MTIR.getRepairedTimes(spareItem)
    local effective = spareCondition / (1 + 0.5 * spareRepaired)
    local grey = ColorInfo.new(0.5, 0.5, 0.5, 1)
    local color = ColorInfo.new(0, 0, 0, 1)
    getCore():getGoodHighlitedColor():interp(grey, 1 - effective, color)
    return " <LINE> <RGB:" .. color:getR() .. "," .. color:getG() .. "," .. color:getB() .. "> "
        .. spareDisplayName(spareItem)
        .. " <SPACE> (" .. math.ceil(spareCondition * 100) .. "%, "
        .. getText("IGUI_MTIR_JobType_Recondition_RepairedTimes", tostring(spareRepaired)) .. ")"
end

--- Texte riche : potentiel, chance puis besoins (MTIR.getReconditionRequirements).
local function describeRecondition(item, req, spareItem)
    local text = chanceHeader("Tooltip_potentialRepair", req.potential)
        .. " <LINE>" .. chanceHeader("Tooltip_chanceSuccess", req.success)
        .. toolLines(req)
    if spareItem then
        text = text .. spareLine(spareItem) .. tailoringLine(req.effectiveLevel, req.requiredLevel)
    else
        text = text .. materialLine(req)
    end
    return text .. repairedLine(req.repairedTimes)
end

local function addStripSubOption(subMenu, player, item)
    local req = MTIR.getReconditionRequirements(player, item, MTIR.SEW_BY_HAND, nil)
    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseStrip",
        getItemNameFromFullType(req.materialType)), player, queueRecondition, item, req, nil, nil)
    option.notAvailable = not req.ready
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = describeRecondition(item, req, nil)
end

local function addSpareSubOption(subMenu, player, item, spareItem)
    local req = MTIR.getReconditionRequirements(player, item, MTIR.SEW_BY_HAND, spareItem)
    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseSpare", spareDisplayName(spareItem)),
        player, queueRecondition, item, req, spareItem, nil)
    option.notAvailable = not req.ready
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = describeRecondition(item, req, spareItem)
end

local function addMissingSpareSubOption(subMenu, player, item)
    local req = MTIR.getReconditionRequirements(player, item, MTIR.SEW_BY_HAND, nil)
    local name = getItemNameFromFullType(item:getFullType())
    local option = subMenu:addOption(getText("IGUI_MTIR_JobType_Recondition_UseSpare", name))
    option.notAvailable = true
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip.description = colorForPercent(0.5) .. getText("Tooltip_potentialRepair") .. " ???"
        .. " <LINE>" .. colorForPercent(0.5) .. getText("Tooltip_chanceSuccess") .. " ???"
        .. toolLines(req)
        .. " <LINE>" .. ISInventoryPaneContextMenu.bhs .. name
        .. tailoringLine(req.effectiveLevel, req.requiredLevel)
        .. repairedLine(req.repairedTimes)
end

local function addReconditionOption(item, player, context)
    if item:getCondition() >= item:getConditionMax() then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_JobType_ReconditionClothes"))
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)

    if MTIR.getClothesFabricType(item) then
        addStripSubOption(subMenu, player, item)
    end

    local spares = player:getInventory():getItemsFromType(item:getFullType(), true)
    local hasSpare = false
    for i = 0, spares:size() - 1 do
        local spareItem = spares:get(i)
        if MTIR.isValidSpare(item, spareItem) then
            hasSpare = true
            addSpareSubOption(subMenu, player, item, spareItem)
        end
    end
    if not hasSpare then
        addMissingSpareSubOption(subMenu, player, item)
    end
end

-- ----------------------------------------------------------------------------
-- Entretenir une machine à coudre (appelé par le panneau de la machine)
-- ----------------------------------------------------------------------------

--- Texte riche des besoins d'un entretien (MTIR.getMaintenanceRequirements).
local function describeMaintenance(req)
    local perkName = PerkFactory.getPerk(req.perk):getName()
    return getText("IGUI_MTIR_Maintenance_Info", tostring(math.floor(req.condition + 0.5)), tostring(req.gain))
        .. needsHeader()
        .. needLine(req.screwdriver ~= nil, getItemNameFromFullType("Base.Screwdriver"))
        .. needLine(req.oil ~= nil, getText("IGUI_MTIR_Maintenance_Oil", tostring(req.requiredOilUses)))
        .. " <LINE> <RGB:1,1,1> " .. perkName .. " " .. req.perkLevel
end

--- Marche jusqu'à la machine, tournevis en main, puis entretien. Faux si rien n'a été lancé.
local function queueMaintenance(player, machine)
    local req = MTIR.getMaintenanceRequirements(player, machine)
    if not req.ready then
        return false
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.oil)
    if not luautils.walkAdjObject(player, machine, true, true) then
        return false
    end
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), req.screwdriver, true)
    ISTimedActionQueue.add(MTIR_MachineMaintenanceAction:new(player, MTIR.encodeMachinePos(machine),
        req.screwdriver, req.oil))
    return true
end

--- Interface des retouches, remises en état et entretiens, partagée avec le panneau
--- de la machine à coudre (MTIR_SewingMachineWindow.lua) :
---   describeResize(item, req, upsize)           -> texte riche (req : MTIR.getResizeRequirements)
---   describeRecondition(item, req, spareItem)   -> texte riche (req : MTIR.getReconditionRequirements)
---   describeMaintenance(req)                    -> texte riche (req : MTIR.getMaintenanceRequirements)
---   queueResize(player, item, req, upsize, machine|nil)
---   queueRecondition(player, item, req, spareItem|nil, machine|nil)
---   queueMaintenance(player, machine)           -> vrai si l'entretien a été mis en file
--- machine = nil : travail à la main ; sinon marche jusqu'à la machine avant l'action.
MTIR.AlterUI = {
    describeResize = describeResize,
    describeRecondition = describeRecondition,
    describeMaintenance = describeMaintenance,
    queueResize = queueResize,
    queueRecondition = queueRecondition,
    queueMaintenance = queueMaintenance,
    spareDisplayName = spareDisplayName,
}

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
