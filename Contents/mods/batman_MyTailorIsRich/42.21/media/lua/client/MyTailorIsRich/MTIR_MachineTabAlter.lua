-- ============================================================================
-- My Tailor Is Rich — onglets « Retouche » et « Remise en état » du panneau de
-- machine à coudre (client)
-- Même disposition que l'onglet Patron : on glisse un vêtement (ou on clique
-- pour choisir), on choisit l'option (taille visée, ou bandes de tissu /
-- vêtement de rechange), puis le bouton lance l'action avec la machine.
-- Besoins, texte et file d'actions : MTIR.getResizeRequirements,
-- MTIR.getReconditionRequirements et MTIR.AlterUI (MTIR_Alterations.lua,
-- MTIR_ContextMenu.lua). Les vêtements sont suivis par identifiant (un transfert
-- MP peut changer l'instance). Lecture seule.
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISComboBox"
require "MyTailorIsRich/MTIR_MachineUIUtil"
require "MyTailorIsRich/MTIR_ContextMenu"

MTIR_MachineTabAlter = ISPanel:derive("MTIR_MachineTabAlter")

local UI = MTIR.MachineUI
local PAD, SLOT, FONT_HGT = UI.PAD, UI.SLOT, UI.FONT_HGT

-- ----------------------------------------------------------------------------
-- Modes
-- ----------------------------------------------------------------------------

--- Vêtement retouchable : taille connue, jamais retouché (comme le menu contextuel).
local function canResize(item)
    if not instanceof(item, "Clothing") or item:isBroken() or not MTIR.canResizeClothes(item) then
        return false
    end
    local data = MTIR.getData(item)
    if not data or not data.size or not data.reveal or data.resized ~= 0 then
        return false
    end
    return MTIR.getNextSize(data.size) ~= nil or MTIR.getPrevSize(data.size) ~= nil
end

--- Vêtement à remettre en état : abîmé et d'un emplacement qui s'use.
local function canRecondition(item)
    return instanceof(item, "Clothing") and MTIR.canReconditionClothes(item)
        and item:getCondition() < item:getConditionMax()
end

--- Options de retouche : agrandir (bandes de tissu) ou rétrécir (trombones).
local function resizeChoices(_, item)
    local data = MTIR.getData(item)
    local choices = {}
    local nextSize = MTIR.getNextSize(data.size)
    local prevSize = MTIR.getPrevSize(data.size)
    if nextSize then
        table.insert(choices, { label = getText("IGUI_MTIR_Machine_ResizeUp", nextSize.name), upsize = true })
    end
    if prevSize then
        table.insert(choices, { label = getText("IGUI_MTIR_Machine_ResizeDown", prevSize.name), upsize = false })
    end
    return choices
end

--- Options de remise en état : bandes du tissu du vêtement, ou un vêtement identique.
local function reconditionChoices(player, item)
    local choices = {}
    local stripType = MTIR.getStripType(MTIR.getClothesFabricType(item))
    if stripType then
        table.insert(choices, { label = getText("IGUI_MTIR_JobType_Recondition_UseStrip",
            getItemNameFromFullType(stripType)) })
    end
    local spares = player:getInventory():getItemsFromFullType(item:getFullType(), true)
    for i = 0, spares:size() - 1 do
        local spare = spares:get(i)
        if MTIR.isValidSpare(item, spare) then
            local percent = math.ceil(spare:getCondition() / spare:getConditionMax() * 100)
            local api = MTIR.AlterUI
            local name = api and api.spareDisplayName and api.spareDisplayName(spare) or spare:getDisplayName()
            table.insert(choices, { spare = spare, label = getText("IGUI_MTIR_JobType_Recondition_UseSpare",
                name .. " (" .. percent .. " %)") })
        end
    end
    return choices
end

--- Besoins et texte d'une option ; nil si l'API des retouches est absente.
local function resizeRequest(player, item, choice, mods)
    if not MTIR.getResizeRequirements or not MTIR.AlterUI then
        return nil, ""
    end
    local req = MTIR.getResizeRequirements(player, item, choice.upsize, mods)
    return req, MTIR.AlterUI.describeResize(item, req, choice.upsize) .. UI.consumedText({ req = req })
end

local function reconditionRequest(player, item, choice, mods)
    if not MTIR.getReconditionRequirements or not MTIR.AlterUI then
        return nil, ""
    end
    local req = MTIR.getReconditionRequirements(player, item, mods, choice.spare)
    return req, MTIR.AlterUI.describeRecondition(item, req, choice.spare)
        .. UI.consumedText({ req = req, spare = choice.spare })
end

local function queueResize(player, item, req, choice, machine)
    MTIR.AlterUI.queueResize(player, item, req, choice.upsize, machine)
end

local function queueRecondition(player, item, req, choice, machine)
    MTIR.AlterUI.queueRecondition(player, item, req, choice.spare, machine)
end

MTIR_MachineTabAlter.MODES = {
    resize = {
        verify = canResize,
        choices = resizeChoices,
        request = resizeRequest,
        queue = queueResize,
        actionTypes = { MTIR_ResizeAction = true },
        help = "IGUI_MTIR_Machine_HelpResize",
        empty = "IGUI_MTIR_Machine_NoResizable",
        dropHere = "IGUI_MTIR_Machine_DropClothes",
        button = "IGUI_MTIR_Machine_Resize",
        working = "IGUI_MTIR_Machine_Resizing",
    },
    recondition = {
        verify = canRecondition,
        choices = reconditionChoices,
        request = reconditionRequest,
        queue = queueRecondition,
        actionTypes = { MTIR_ReconditionAction = true, MTIR_ReconditionSpareAction = true },
        help = "IGUI_MTIR_Machine_HelpRecondition",
        noChoice = "IGUI_MTIR_Machine_NoReconditionOption",
        empty = "IGUI_MTIR_Machine_NoDamaged",
        dropHere = "IGUI_MTIR_Machine_DropClothes",
        button = "IGUI_MTIR_Machine_Recondition",
        working = "IGUI_MTIR_Machine_Reconditioning",
    },
}

-- ----------------------------------------------------------------------------
-- Emplacement du vêtement
-- ----------------------------------------------------------------------------

function MTIR_MachineTabAlter:verifyItem(item)
    return self.mode.verify(item)
end

function MTIR_MachineTabAlter:onItemDropped(items)
    for _, item in ipairs(items) do
        if self.mode.verify(item) then
            self:setItem(item)
            return
        end
    end
end

function MTIR_MachineTabAlter:onItemRemoved()
    self:setItem(nil)
end

function MTIR_MachineTabAlter:chooseItem(box)
    local player = self.window.player
    UI.openChooser(box, player, UI.collectItems(player, self.mode.verify), function(item)
        return item:getDisplayName()
    end, self.mode.empty, self, MTIR_MachineTabAlter.setItem)
end

-- ----------------------------------------------------------------------------
-- Construction
-- ----------------------------------------------------------------------------

function MTIR_MachineTabAlter:createChildren()
    self.slot = UI.newSlot(self, PAD, 0, {
        player = self.window.player,
        onDrop = MTIR_MachineTabAlter.onItemDropped,
        onRemove = MTIR_MachineTabAlter.onItemRemoved,
        verify = MTIR_MachineTabAlter.verifyItem,
        onChoose = MTIR_MachineTabAlter.chooseItem,
        tooltipKey = "IGUI_MTIR_Machine_SlotClothesTooltip",
        tooltipItemKey = "IGUI_MTIR_Machine_SlotClothesTooltipItem",
    })
    local comboY = SLOT + PAD
    local comboHeight = FONT_HGT + 6
    local label = getTextManager():MeasureStringX(UIFont.Small, self.texts.option) + PAD
    self.choiceCombo = ISComboBox:new(PAD + label, comboY, self.width - PAD * 2 - label, comboHeight, self,
        MTIR_MachineTabAlter.onChoiceChanged)
    self.choiceCombo:initialise()
    self:addChild(self.choiceCombo)
    self.details = UI.newDetails(self, comboY + comboHeight + PAD)
    self.button = UI.newActionButton(self, self.labels.idle, MTIR_MachineTabAlter.onRun)
    self:setItem(nil)
end

--- Bouton sous le texte des besoins ; maxHeight (facultatif) : place disponible,
--- au-delà de laquelle le texte des besoins défile.
function MTIR_MachineTabAlter:layout(maxHeight)
    local fixed = self.details:getY() + PAD + self.button:getHeight()
    local detailsHeight = UI.fitDetails(self.details, maxHeight and maxHeight - fixed or nil)
    local buttonY = self.details:getY() + detailsHeight + PAD
    self.button:setY(buttonY)
    self:setHeight(buttonY + self.button:getHeight())
end

-- ----------------------------------------------------------------------------
-- État
-- ----------------------------------------------------------------------------

function MTIR_MachineTabAlter:setItem(item)
    self.item = item
    self.slot:setStoredItem(item)
    self:fillChoices()
    self:refresh()
end

--- Options du vêtement, en gardant l'option choisie quand elle existe encore.
function MTIR_MachineTabAlter:fillChoices()
    local previous = self:selectedChoice()
    self.choiceCombo:clear()
    self.choiceCombo.selected = 0
    if not self.item then
        return
    end
    for index, choice in ipairs(self.mode.choices(self.window.player, self.item)) do
        self.choiceCombo:addOptionWithData(choice.label, choice)
        if index == 1 or (previous and previous.label == choice.label) then
            self.choiceCombo.selected = index
        end
    end
end

function MTIR_MachineTabAlter:selectedChoice()
    local index = self.choiceCombo.selected
    return index and index > 0 and self.choiceCombo:getOptionData(index) or nil
end

function MTIR_MachineTabAlter:onChoiceChanged()
    self:refresh()
end

--- Retrouve le vêtement par son identifiant (instance remplacée en MP) ; l'oublie
--- s'il a quitté l'inventaire ou ne s'y prête plus (déjà retouché, réparé).
function MTIR_MachineTabAlter:dropLostItem()
    if not self.item then
        return false
    end
    local current = UI.resolveCarried(self.window.player, self.item)
    if current and self.mode.verify(current) then
        if current ~= self.item then
            self.item = current
            self.slot:setStoredItem(current)
        end
        return false
    end
    self:setItem(nil)
    return true
end

--- Vêtement de rechange choisi : retrouvé par identifiant, ou options recalculées s'il est parti.
function MTIR_MachineTabAlter:dropLostSpare()
    local choice = self:selectedChoice()
    if not (choice and choice.spare) then
        return
    end
    local current = UI.resolveCarried(self.window.player, choice.spare)
    if not current then
        self:fillChoices()
    elseif current ~= choice.spare then
        choice.spare = current
    end
end

function MTIR_MachineTabAlter:refresh()
    if self:dropLostItem() then
        return
    end
    self:dropLostSpare()
    local window = self.window
    local choice = self.item and self:selectedChoice()
    if self.item and not choice then
        -- Aucune option jusqu'ici : un exemplaire identique a pu arriver dans l'inventaire.
        self:fillChoices()
        choice = self:selectedChoice()
    end
    local text = ""
    self.request = nil
    if not self.item then
        text = getText(self.mode.help)
    elseif choice then
        self.request, text = self.mode.request(window.player, self.item, choice, MTIR.getMachineMods(window.machine))
    elseif self.mode.noChoice then
        -- Ni bandes pour ce tissu, ni exemplaire identique (comme addMissingSpareSubOption).
        text = " <RGB:0.95,0.35,0.3> " .. getText(self.mode.noChoice, getItemNameFromFullType(self.item:getFullType()))
    end
    if UI.setDetails(self.details, text) then
        window:layout()
    end
    local problem = MTIR.getSewingMachineProblem(nil, window.machine, nil)
    self.button.tooltip = problem and getText(problem) or nil
    self.canRun = self.request ~= nil and self.request.ready == true and problem == nil
end

--- Besoins recalculés juste avant de lancer : jamais une demande périmée.
function MTIR_MachineTabAlter:onRun()
    if self.window.busy or not self.window:checkMachine() then
        return
    end
    self:refresh()
    local choice = self:selectedChoice()
    if not self.canRun or not self.item or not choice then
        return
    end
    self.mode.queue(self.window.player, self.item, self.request, choice, self.window.machine)
end

function MTIR_MachineTabAlter:showProgress(action, running, busy)
    UI.showProgress(self.button, action, running, self.canRun and not busy, self.labels)
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

--- Nom du vêtement, puis sa taille (retouche) ou son état et ses réparations.
function MTIR_MachineTabAlter:renderItemInfo(x)
    local item = self.item
    self:drawText(item:getDisplayName(), x, 0, 1, 1, 1, 1, UIFont.Medium)
    local y = UI.FONT_HGT_MEDIUM + 4
    local dim = UI.DIM
    if self.modeName == "resize" then
        local data = MTIR.getData(item)
        self:drawText(getText("IGUI_MTIR_Machine_ItemSize", data and data.size or "?"), x, y,
            dim.r, dim.g, dim.b, 1, UIFont.Small)
        return
    end
    local percent = math.floor(item:getCondition() / item:getConditionMax() * 100)
    self:drawText(getText("IGUI_MTIR_Machine_ItemCondition", tostring(percent)), x, y,
        dim.r, dim.g, dim.b, 1, UIFont.Small)
    self:drawText(getText("IGUI_MTIR_JobType_Recondition_RepairedTimes", tostring(MTIR.getRepairedTimes(item))),
        x, y + FONT_HGT + 2, dim.r, dim.g, dim.b, 1, UIFont.Small)
end

function MTIR_MachineTabAlter:render()
    ISPanel.render(self)
    local infoX = PAD + SLOT + PAD
    if self.item then
        self:renderItemInfo(infoX)
    else
        self:drawText(self.texts.dropHere, infoX, (SLOT - FONT_HGT) / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
    self:drawText(self.texts.option, PAD, self.choiceCombo:getY() + 3, 1, 1, 1, 1, UIFont.Small)
end

--- modeName : "resize" ou "recondition".
function MTIR_MachineTabAlter:new(x, y, width, window, modeName)
    local o = ISPanel.new(self, x, y, width, SLOT)
    o.window = window
    o.modeName = modeName
    o.mode = MTIR_MachineTabAlter.MODES[modeName]
    o.ACTION_TYPES = o.mode.actionTypes
    o.background = false
    o.canRun = false
    o.labels = UI.progressLabels(o.mode.button, "IGUI_MTIR_Machine_Preparing", o.mode.working)
    o.texts = { option = getText("IGUI_MTIR_Machine_Option"), dropHere = getText(o.mode.dropHere) }
    return o
end
