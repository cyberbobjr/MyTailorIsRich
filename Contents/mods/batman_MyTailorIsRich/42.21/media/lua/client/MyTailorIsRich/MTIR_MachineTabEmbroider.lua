-- ============================================================================
-- My Tailor Is Rich — onglet « Broderie » du panneau de machine à coudre (client)
-- Même disposition que les autres onglets : on glisse un vêtement (ou on clique
-- pour choisir), on saisit le texte (prérempli avec le prénom du personnage),
-- l'aperçu donne le nom obtenu, puis « Broder » marche jusqu'à la machine,
-- aiguille en main, et lance MTIR_MachineEmbroiderAction.
-- Texte nettoyé et nom composé comme la broderie à la main (MTIR_DecorMenu.lua) ;
-- niveau, fil et durée ajustés par la machine (MTIR_Embroidery.lua). Un vêtement
-- déjà brodé reste affiché avec sa broderie : on la découd à la main, aux ciseaux,
-- par le menu contextuel. Les vêtements sont suivis par identifiant (un transfert
-- MP peut changer l'instance). Lecture seule, sauf la file d'actions.
-- Manette : X choisit le vêtement, haut ouvre le clavier à l'écran, A brode.
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "MyTailorIsRich/MTIR_MachineUIUtil"
require "MyTailorIsRich/MTIR_ContextMenu"
require "MyTailorIsRich/MTIR_DecorMenu"
require "MyTailorIsRich/MTIR_Embroidery"
require "TimedActions/MTIR_MachineEmbroiderAction"

MTIR_MachineTabEmbroider = ISPanel:derive("MTIR_MachineTabEmbroider")

local UI = MTIR.MachineUI
local PAD, SLOT, FONT_HGT = UI.PAD, UI.SLOT, UI.FONT_HGT
-- Largeur du champ : le texte le plus long tient (police et taille réelles), plus la marge du curseur.
local ENTRY_TEXT_MARGIN = 16
local WARN = { r = 0.95, g = 0.85, b = 0.4 }

MTIR_MachineTabEmbroider.ACTION_TYPES = { MTIR_MachineEmbroiderAction = true }

local function entryMinWidth()
    return getTextManager():MeasureStringX(UIFont.Small, string.rep("n", MTIR.EMBROIDERY_MAX_CHARS))
        + ENTRY_TEXT_MARGIN
end

--- Largeur minimale de l'onglet : étiquette du texte (selon la langue et la police) et champ de saisie.
function MTIR_MachineTabEmbroider.minWidth()
    local label = getTextManager():MeasureStringX(UIFont.Small, getText("IGUI_MTIR_Machine_EmbroiderText"))
    return PAD + label + PAD + entryMinWidth() + PAD
end

--- Vêtement à broder : brodable et sans broderie (comme le menu contextuel).
local function canEmbroiderItem(item)
    return MTIR.canEmbroider(item) and MTIR.getEmbroidery(item) == nil
end

--- Vêtement gardé dans l'emplacement : brodable, déjà brodé ou non (après le
--- travail, l'onglet montre la broderie obtenue).
local function keepsItem(item)
    return MTIR.canEmbroider(item)
end

-- ----------------------------------------------------------------------------
-- Besoins
-- ----------------------------------------------------------------------------

--- Aiguille, fil (réduit par la machine), niveau (bonus de la machine, sauf à
--- pédale) et chance (usure). Pas de dé à coudre sur une machine.
local function embroideryRequirements(player, machine)
    local mods = MTIR.getMachineMods(machine)
    local kindName = MTIR.getMachineKindName(machine)
    local inventory = player:getInventory()
    local allThreads = inventory:getAllEvalRecurse(MTIR.predicateThread)
    local requiredThread = MTIR.getMachineEmbroideryThread(mods)
    local tailoring = player:getPerkLevel(Perks.Tailoring)
    local req = {
        mods = mods,
        kindName = kindName,
        needle = inventory:getFirstEvalRecurse(MTIR.predicateNeedle),
        requiredThread = requiredThread,
        remainingThread = MTIR.getRemainingThread(allThreads),
        threads = MTIR.pickThreads(allThreads, requiredThread),
        effectiveLevel = MTIR.getMachineEmbroideryLevel(tailoring, kindName, mods),
        requiredLevel = MTIR.getMachineEmbroideryRequiredLevel(kindName),
        success = MTIR.getMachineEmbroiderySuccess(mods),
    }
    req.ready = req.needle ~= nil and req.threads ~= nil and req.effectiveLevel >= req.requiredLevel
    return req
end

--- Ligne de Couture ; à pédale, la raison du niveau plus élevé.
local function tailoringLine(req)
    local label = PerkFactory.getPerk(Perks.Tailoring):getName() .. " " .. req.effectiveLevel .. "/"
        .. req.requiredLevel
    if req.kindName == "treadle" and req.requiredLevel > 0 then
        label = label .. " " .. getText("IGUI_MTIR_Machine_EmbroiderTreadleLevel")
    end
    return MTIR.MenuUtil.needLine(req.effectiveLevel >= req.requiredLevel, label)
end

--- Texte riche : nom obtenu (ou texte refusé), chance, besoins, objets utilisés.
local function describeEmbroidery(req, name)
    local util = MTIR.MenuUtil
    local text
    if name then
        text = " <RGB:1,1,1> " .. getText("IGUI_MTIR_Machine_EmbroiderResult", name)
    else
        text = " <RGB:0.95,0.35,0.3> "
            .. getText("IGUI_MTIR_Machine_EmbroiderInvalid", tostring(MTIR.EMBROIDERY_MAX_CHARS))
    end
    return text .. " <LINE> <LINE> " .. util.chanceHeader("Tooltip_chanceSuccess", req.success)
        .. util.needsHeader()
        .. util.needLine(req.needle ~= nil, getItemNameFromFullType("Base.Needle"))
        .. util.needLine(req.threads ~= nil, getItemNameFromFullType("Base.Thread") .. " "
            .. req.remainingThread .. "/" .. req.requiredThread)
        .. tailoringLine(req)
        .. UI.consumedText({ req = req })
end

-- ----------------------------------------------------------------------------
-- Emplacement du vêtement
-- ----------------------------------------------------------------------------

function MTIR_MachineTabEmbroider:verifyItem(item)
    return canEmbroiderItem(item)
end

function MTIR_MachineTabEmbroider:onItemDropped(items)
    for _, item in ipairs(items) do
        if canEmbroiderItem(item) then
            self:setItem(item)
            return
        end
    end
end

function MTIR_MachineTabEmbroider:onItemRemoved()
    self:setItem(nil)
end

function MTIR_MachineTabEmbroider:chooseItem(box)
    local player = self.window.player
    UI.openChooser(box, player, UI.collectItems(player, canEmbroiderItem), function(item)
        return item:getDisplayName()
    end, "IGUI_MTIR_Machine_NoEmbroiderable", self, MTIR_MachineTabEmbroider.setItem)
end

-- ----------------------------------------------------------------------------
-- Construction
-- ----------------------------------------------------------------------------

function MTIR_MachineTabEmbroider:createChildren()
    self.slot = UI.newSlot(self, PAD, 0, {
        player = self.window.player,
        onDrop = MTIR_MachineTabEmbroider.onItemDropped,
        onRemove = MTIR_MachineTabEmbroider.onItemRemoved,
        verify = MTIR_MachineTabEmbroider.verifyItem,
        onChoose = MTIR_MachineTabEmbroider.chooseItem,
        tooltipKey = "IGUI_MTIR_Machine_SlotClothesTooltip",
        tooltipItemKey = "IGUI_MTIR_Machine_SlotClothesTooltipItem",
    })
    local entryY = SLOT + PAD
    local entryHeight = FONT_HGT + 6
    local label = getTextManager():MeasureStringX(UIFont.Small, self.texts.label) + PAD
    local player = self.window.player
    local forename = player:getDescriptor() and player:getDescriptor():getForename() or ""
    self.entry = ISTextEntryBox:new(forename, PAD + label, entryY, self.width - PAD * 2 - label, entryHeight)
    self.entry:initialise()
    self.entry:instantiate()
    self.entry:setMaxTextLength(MTIR.EMBROIDERY_MAX_CHARS)
    self.entry.target = self
    self.entry.onTextChangeFunction = MTIR_MachineTabEmbroider.onTextChanged
    self:addChild(self.entry)
    self.details = UI.newDetails(self, entryY + entryHeight + PAD)
    self.button = UI.newActionButton(self, self.labels.idle, MTIR_MachineTabEmbroider.onRun)
    self:setItem(nil)
end

--- Bouton sous le texte des besoins ; maxHeight (facultatif) : place disponible,
--- au-delà de laquelle le texte des besoins défile.
function MTIR_MachineTabEmbroider:layout(maxHeight)
    local fixed = self.details:getY() + PAD + self.button:getHeight()
    local detailsHeight = UI.fitDetails(self.details, maxHeight and maxHeight - fixed or nil)
    local buttonY = self.details:getY() + detailsHeight + PAD
    self.button:setY(buttonY)
    self:setHeight(buttonY + self.button:getHeight())
end

-- ----------------------------------------------------------------------------
-- État
-- ----------------------------------------------------------------------------

function MTIR_MachineTabEmbroider:setItem(item)
    self.item = item
    self.slot:setStoredItem(item)
    self:refresh()
end

function MTIR_MachineTabEmbroider:onTextChanged()
    self:refresh()
end

--- Le champ rend la main au clavier du jeu : un champ retiré ou masqué en
--- gardant le focus bloquerait les touches jusqu'au prochain clic gauche.
function MTIR_MachineTabEmbroider:releaseFocus()
    if self.entry and self.entry:isFocused() then
        self.entry:unfocus()
    end
end

function MTIR_MachineTabEmbroider:setVisible(visible)
    if not visible then
        self:releaseFocus()
    end
    ISPanel.setVisible(self, visible)
end

--- Manette : clavier à l'écran sur le champ (comme ISTextEntryBox:onJoypadDown),
--- le focus revient ensuite à la fenêtre.
function MTIR_MachineTabEmbroider:editText(joypadData)
    if not joypadData or OnScreenKeyboard.IsVisible() then
        return
    end
    local keyboard = OnScreenKeyboard.Show(joypadData.player, self.entry, joypadData)
    keyboard.prevFocus = joypadData.focus
    joypadData.focus = keyboard
    self.joypadEditing = true
end

--- Le clavier à l'écran redonne le focus clavier au champ en se fermant
--- (ISOnScreenKeyboard:hide) : on le rend aussitôt, sinon les touches du clavier
--- resteraient bloquées (écran partagé avec un joueur au clavier).
function MTIR_MachineTabEmbroider:prerender()
    ISPanel.prerender(self)
    if self.joypadEditing and not OnScreenKeyboard.IsVisible() then
        self.joypadEditing = false
        self:releaseFocus()
    end
end

--- Retrouve le vêtement par son identifiant (instance remplacée en MP) ; l'oublie
--- s'il a quitté l'inventaire ou ne peut plus être brodé.
function MTIR_MachineTabEmbroider:dropLostItem()
    if not self.item then
        return false
    end
    local current = UI.resolveCarried(self.window.player, self.item)
    if current and keepsItem(current) then
        if current ~= self.item then
            self.item = current
            self.slot:setStoredItem(current)
        end
        return false
    end
    self:setItem(nil)
    return true
end

--- Texte saisi, nettoyé, et nom composé dans la langue du joueur ; nil, nil si refusé.
function MTIR_MachineTabEmbroider:currentText()
    -- Lu comme la boîte de saisie de la broderie à la main (ISTextBox : entry:getText()).
    local text = MTIR.cleanEmbroideryText(self.entry:getText(), MTIR.EMBROIDERY_MAX_CHARS)
    if not text or not self.item then
        return text, nil
    end
    return text, MTIR.EmbroideryUI.composeName(self.item, text)
end

function MTIR_MachineTabEmbroider:refresh()
    if self:dropLostItem() then
        return
    end
    local window = self.window
    local text
    self.request = nil
    self.embroidery = self.item and MTIR.getEmbroidery(self.item) or nil
    local cleanText, name = self:currentText()
    if not self.item then
        text = getText("IGUI_MTIR_Machine_HelpEmbroider", tostring(MTIR.EMBROIDERY_MAX_CHARS))
    elseif self.embroidery then
        text = " <RGB:" .. WARN.r .. "," .. WARN.g .. "," .. WARN.b .. "> "
            .. getText("IGUI_MTIR_Machine_AlreadyEmbroidered", self.embroidery.text)
    else
        self.request = embroideryRequirements(window.player, window.machine)
        text = describeEmbroidery(self.request, name)
    end
    if UI.setDetails(self.details, text) then
        window:layout()
    end
    local problem = MTIR.getSewingMachineProblem(nil, window.machine, nil)
    self.button.tooltip = problem and getText(problem) or nil
    self.canRun = self.request ~= nil and self.request.ready == true and name ~= nil and cleanText ~= nil
        and problem == nil
end

--- Transferts, marche jusqu'à la machine, aiguille en main, puis broderie.
local function queueEmbroider(player, item, req, text, name, machine)
    ISInventoryPaneContextMenu.transferIfNeeded(player, req.threads)
    if not MTIR.AlterUI.bringToWork(player, item, machine) then
        return
    end
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), req.needle, true)
    ISTimedActionQueue.add(MTIR_MachineEmbroiderAction:new(player, item, req.needle, req.threads, text, name,
        MTIR.encodeMachinePos(machine)))
end

--- Besoins et texte recalculés juste avant de lancer : jamais une demande périmée.
function MTIR_MachineTabEmbroider:onRun()
    local window = self.window
    if window.busy or not window:checkMachine() then
        return
    end
    self:releaseFocus()
    self:refresh()
    local text, name = self:currentText()
    if not self.canRun or not self.item or not text or not name then
        return
    end
    queueEmbroider(window.player, self.item, self.request, text, name, window.machine)
end

function MTIR_MachineTabEmbroider:showProgress(action, running, busy)
    UI.showProgress(self.button, action, running, self.canRun and not busy, self.labels)
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

--- Nom du vêtement, puis sa broderie (ou son absence).
function MTIR_MachineTabEmbroider:renderItemInfo(x)
    self:drawText(self.item:getDisplayName(), x, 0, 1, 1, 1, 1, UIFont.Medium)
    local y = UI.FONT_HGT_MEDIUM + 4
    local data = self.embroidery
    if data then
        self:drawText(self.texts.embroidered .. " " .. data.text, x, y, WARN.r, WARN.g, WARN.b, 1, UIFont.Small)
    else
        local dim = UI.DIM
        self:drawText(self.texts.notEmbroidered, x, y, dim.r, dim.g, dim.b, 1, UIFont.Small)
    end
end

function MTIR_MachineTabEmbroider:render()
    ISPanel.render(self)
    local infoX = PAD + SLOT + PAD
    if self.item then
        self:renderItemInfo(infoX)
    else
        self:drawText(self.texts.dropHere, infoX, (SLOT - FONT_HGT) / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
    self:drawText(self.texts.label, PAD, self.entry:getY() + 3, 1, 1, 1, 1, UIFont.Small)
end

function MTIR_MachineTabEmbroider:new(x, y, width, window)
    local o = ISPanel.new(self, x, y, width, SLOT)
    o.window = window
    o.background = false
    o.canRun = false
    o.labels = UI.progressLabels("IGUI_MTIR_Machine_Embroider", "IGUI_MTIR_Machine_Preparing",
        "IGUI_MTIR_Machine_Embroidering")
    o.texts = {
        label = getText("IGUI_MTIR_Machine_EmbroiderText"),
        dropHere = getText("IGUI_MTIR_Machine_DropClothes"),
        embroidered = getText("IGUI_MTIR_Embroidery_Label"),
        notEmbroidered = getText("IGUI_MTIR_Machine_NotEmbroidered"),
    }
    return o
end
