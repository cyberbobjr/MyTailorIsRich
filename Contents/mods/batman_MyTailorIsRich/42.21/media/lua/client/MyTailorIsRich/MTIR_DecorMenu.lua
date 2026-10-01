-- ============================================================================
-- My Tailor Is Rich — teindre et broder (client)
-- Menu contextuel d'inventaire, saisie du texte brodé, ligne d'infobulle de la
-- broderie et nom rétabli après un décousage décidé par le serveur.
-- Toute modification passe par une action chronométrée partagée, exécutée par
-- l'autorité (MTIR_DyeAction, MTIR_EmbroiderAction).
-- ============================================================================

require "MyTailorIsRich/MTIR_ContextMenu"
require "MyTailorIsRich/MTIR_Dyeing"
require "MyTailorIsRich/MTIR_Embroidery"
require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISTextBox"
require "TimedActions/MTIR_DyeAction"
require "TimedActions/MTIR_EmbroiderAction"

local MenuUtil = MTIR.MenuUtil

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

local function litres(value)
    return string.format("%.1f", value)
end

local function litreLine(ok, label, have, need)
    return MenuUtil.needLine(ok, label .. " " .. litres(have) .. "/" .. litres(need) .. " L")
end

-- ----------------------------------------------------------------------------
-- Teindre
-- ----------------------------------------------------------------------------

--- Récipient d'eau : le plus petit qui suffit, et le plus gros volume disponible.
local function findWater(player, needed)
    local all = player:getInventory():getAllEvalRecurse(MTIR.isWaterContainer)
    local best, bestAmount, maxAmount = nil, nil, 0
    for i = 0, all:size() - 1 do
        local container = all:get(i)
        local amount = MTIR.getFluidLitres(container)
        maxAmount = math.max(maxAmount, amount)
        if amount + 0.0001 >= needed and (not bestAmount or amount < bestAmount) then
            best, bestAmount = container, amount
        end
    end
    return best, maxAmount
end

local function queueDye(player, item, dye, water)
    ISInventoryPaneContextMenu.transferIfNeeded(player, dye)
    ISInventoryPaneContextMenu.transferIfNeeded(player, water)
    bringClothing(player, item)
    ISTimedActionQueue.add(MTIR_DyeAction:new(player, item, dye, water))
end

local function waterLine(item, maxWater)
    local need = MTIR.getDyeWaterLitres(item)
    return litreLine(maxWater + 0.0001 >= need, getText("Fluid_Name_Water"), maxWater, need)
end

local function addDyeSubOption(subMenu, player, item, dye, water, maxWater)
    local kind = MTIR.getDyeKind(dye)
    local r, g, b = MTIR.getDyeColor(dye)
    local dyeName = getItemNameFromFullType(dye:getFullType())
    local option = subMenu:addColorBoxOption(dyeName .. " (" .. MTIR.getColorName(r, g, b) .. ")", player, queueDye,
        item, dye, water)
    option.color = { r = r, g = g, b = b }
    local need = MTIR.getDyeLitres(item, kind)
    local have = MTIR.getFluidLitres(dye)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip:setName(getItemNameFromFullType(item:getFullType()))
    tooltip.texture = item:getTex()
    tooltip.description = getText("IGUI_MTIR_Dye_Soaked")
        .. MenuUtil.needsHeader()
        .. litreLine(have + 0.0001 >= need, dyeName, have, need)
        .. waterLine(item, maxWater)
    option.toolTip = tooltip
    option.notAvailable = water == nil or have + 0.0001 < need
end

local function addNoDyeOption(subMenu, item, maxWater)
    local option = subMenu:addOption(getText("IGUI_MTIR_Dye_NoDye"))
    option.notAvailable = true
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText("IGUI_MTIR_Dye_Soaked")
        .. MenuUtil.needsHeader()
        .. MenuUtil.needLine(false, getItemNameFromFullType("Base.IndustrialDye") .. " / "
            .. getItemNameFromFullType("Base.HairDyeCommon"))
        .. waterLine(item, maxWater)
    option.toolTip = tooltip
end

local function isDye(candidate)
    return MTIR.getDyeKind(candidate) ~= nil
end

local function addDyeOption(item, player, context)
    if not MTIR.isDyeingEnabled() or item:isBroken() then
        return
    end
    local tintable = MTIR.canTintClothing(item)
    -- La plupart des vêtements ne sont pas teintables : l'explication ne s'affiche
    -- que si le joueur a une teinture sur lui, pour ne pas encombrer chaque menu.
    if not tintable and not player:getInventory():getFirstEvalRecurse(isDye) then
        return
    end
    local option = context:addOption(getText("IGUI_MTIR_Dye"))
    if not tintable then
        -- Teinte ignorée par le rendu : pas d'action sans effet, une explication.
        option.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip.description = getText("IGUI_MTIR_Dye_NotTintable")
        option.toolTip = tooltip
        return
    end
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    local water, maxWater = findWater(player, MTIR.getDyeWaterLitres(item))
    local dyes = player:getInventory():getAllEvalRecurse(isDye)
    for i = 0, dyes:size() - 1 do
        addDyeSubOption(subMenu, player, item, dyes:get(i), water, maxWater)
    end
    if dyes:isEmpty() then
        addNoDyeOption(subMenu, item, maxWater)
    end
end

-- ----------------------------------------------------------------------------
-- Broder un nom
-- ----------------------------------------------------------------------------

--- Aiguille, fil (1 utilisation), dé (couture à la main) et niveau.
local function embroideryRequirements(player)
    local inventory = player:getInventory()
    local allThreads = inventory:getAllEvalRecurse(MTIR.predicateThread)
    local needsThimble = MTIR.needsThimble(nil)
    local req = {
        needle = inventory:getFirstEvalRecurse(MTIR.predicateNeedle),
        threads = MTIR.pickThreads(allThreads, MTIR.EMBROIDERY_THREAD),
        remainingThread = MTIR.getRemainingThread(allThreads),
        needsThimble = needsThimble,
        thimble = needsThimble and MTIR.findThimble(player) or nil,
        tailoring = player:getPerkLevel(Perks.Tailoring),
        requiredLevel = MTIR.getEmbroideryRequiredLevel(),
    }
    req.ready = req.needle ~= nil and req.threads ~= nil and (not needsThimble or req.thimble ~= nil)
        and req.tailoring >= req.requiredLevel
    return req
end

local function describeEmbroidery(req)
    return getText("IGUI_MTIR_Embroider_Info", tostring(MTIR.EMBROIDERY_MAX_CHARS))
        .. MenuUtil.needsHeader()
        .. MenuUtil.needLine(req.needle ~= nil, getItemNameFromFullType("Base.Needle"))
        .. MenuUtil.needLine(req.threads ~= nil, getItemNameFromFullType("Base.Thread") .. " "
            .. req.remainingThread .. "/" .. MTIR.EMBROIDERY_THREAD)
        .. MenuUtil.thimbleLine(req)
        .. MenuUtil.tailoringLine(req.tailoring, req.requiredLevel)
end

--- Nom complet dans la langue du joueur ; le texte seul si le nom serait trop long.
local function composeName(item, text)
    local name = getText("IGUI_MTIR_Embroider_ItemName", item:getDisplayName(), text)
    return MTIR.cleanEmbroideryText(name, MTIR.EMBROIDERY_NAME_MAX) or text
end

local function onEmbroiderClick(_, button, player, item)
    if button.internal ~= "OK" then
        return
    end
    local text = MTIR.cleanEmbroideryText(button.parent.entry:getText(), MTIR.EMBROIDERY_MAX_CHARS)
    local req = embroideryRequirements(player)
    if not text or not req.ready or MTIR.getEmbroidery(item) then
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.threads)
    bringClothing(player, item)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), req.needle, true)
    ISTimedActionQueue.add(MTIR_EmbroiderAction:new(player, item, req.needle, req.threads, text,
        composeName(item, text)))
end

local function validateEntry(_, text)
    return MTIR.cleanEmbroideryText(text, MTIR.EMBROIDERY_MAX_CHARS) ~= nil
end

local function openEmbroideryBox(player, item)
    local playerNum = player:getPlayerNum()
    local defaultText = player:getDescriptor() and player:getDescriptor():getForename() or ""
    local box = ISTextBox:new(0, 0, 280, 180, getText("IGUI_MTIR_Embroider_Title"), defaultText, nil,
        onEmbroiderClick, playerNum, player, item)
    box.maxChars = MTIR.EMBROIDERY_MAX_CHARS
    box.noEmpty = true
    box:setValidateFunction(nil, validateEntry)
    box:setValidateTooltipText(getText("IGUI_MTIR_Embroider_InvalidText"))
    box:initialise()
    box:addToUIManager()
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, box)
    end
end

local function queueUnpick(player, item, scissors)
    bringClothing(player, item)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), scissors, true)
    ISTimedActionQueue.add(MTIR_UnpickEmbroideryAction:new(player, item, scissors))
end

local function addUnpickOption(item, player, context, data)
    local scissors = player:getInventory():getFirstEvalRecurse(MTIR.predicateScissors)
    local option = context:addOption(getText("IGUI_MTIR_Unpick"), player, queueUnpick, item, scissors)
    option.notAvailable = scissors == nil
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = getText("IGUI_MTIR_Embroidery_Label") .. " " .. data.text
        .. MenuUtil.needsHeader()
        .. MenuUtil.needLine(scissors ~= nil, getItemNameFromFullType("Base.Scissors"))
    option.toolTip = tooltip
end

local function addEmbroideryOption(item, player, context)
    if not MTIR.isEmbroideryEnabled() or not MTIR.canEmbroider(item) then
        return
    end
    local data = MTIR.getEmbroidery(item)
    if data then
        addUnpickOption(item, player, context, data)
        return
    end
    local req = embroideryRequirements(player)
    local option = context:addOption(getText("IGUI_MTIR_Embroider"), player, openEmbroideryBox, item)
    option.notAvailable = not req.ready
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = describeEmbroidery(req)
    option.toolTip = tooltip
end

-- ----------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    local clothing = player and singleClothing(items)
    if not clothing then
        return
    end
    addDyeOption(clothing, player, context)
    addEmbroideryOption(clothing, player, context)
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

-- ----------------------------------------------------------------------------
-- Décousage décidé par le serveur : syncItemFields ne transmet pas un nom
-- redevenu celui du script ; le client le rétablit dans sa langue.
-- ----------------------------------------------------------------------------

local function findLocalPlayer(onlineId)
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player and player:getOnlineID() == onlineId then
            return player
        end
    end
    return getPlayer()
end

local function onServerCommand(module, command, args)
    if module ~= MTIR.NET_MODULE or command ~= "embroideryRemoved" or type(args) ~= "table"
        or type(args.itemId) ~= "number" then
        return
    end
    local player = findLocalPlayer(args.playerOnlineId)
    local item = player and player:getInventory():getItemWithIDRecursiv(args.itemId)
    if not item then
        return
    end
    item:getModData()[MTIR.EMBROIDERY_KEY] = nil
    MTIR.restoreEmbroideredName(item, type(args.prevName) == "string" and args.prevName or nil)
    player:getInventory():setDrawDirty(true)
    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- ----------------------------------------------------------------------------
-- Infobulle (TooltipLib, prérequis du mod)
-- ----------------------------------------------------------------------------

require "TooltipLib/Core"

if TooltipLib and type(TooltipLib.registerProvider) == "function" then
    local WHITE = { 1, 1, 1, 1 }
    local LABEL = { 0.8, 0.8, 0.8, 1 }
    TooltipLib.registerProvider({
        id = "MTIR_Embroidery",
        target = "item",
        description = "IGUI_MTIR_TooltipProviderEmbroidery",
        enabled = function(item)
            return instanceof(item, "Clothing") and MTIR.getEmbroidery(item) ~= nil
        end,
        callback = function(ctx)
            local data = MTIR.getEmbroidery(ctx.item)
            if data then
                ctx:addKeyValue(getText("IGUI_MTIR_Embroidery_Label"), data.text, LABEL, WHITE)
            end
        end,
    })
end
