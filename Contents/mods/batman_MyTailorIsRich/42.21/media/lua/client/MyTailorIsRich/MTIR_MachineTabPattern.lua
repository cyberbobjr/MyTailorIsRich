-- ============================================================================
-- My Tailor Is Rich — onglet « Patron » du panneau de machine à coudre (client)
-- On glisse un patron (ou on clique pour choisir), on règle la taille et la
-- quantité, puis « Coudre » : MTIR.SewUI.queueSew avec la machine. En série,
-- la pièce suivante est lancée automatiquement quand la précédente est finie,
-- tant que le panneau reste ouvert, que le patron existe et que tout est prêt.
-- Le dernier patron utilisé est re-sélectionné à l'ouverture (par joueur).
-- Les objets sont suivis par identifiant (un transfert MP peut changer l'instance).
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISComboBox"
require "MyTailorIsRich/MTIR_MachineUIUtil"
require "MyTailorIsRich/MTIR_PatternMenu"

MTIR_MachineTabPattern = ISPanel:derive("MTIR_MachineTabPattern")

local UI = MTIR.MachineUI
local PAD, SLOT, FONT_HGT = UI.PAD, UI.SLOT, UI.FONT_HGT
local ICON = 48
-- Au plus autant de pièces que d'utilisations restantes du patron, et pas plus de 20.
local SERIES_MAX = 20
-- Série : une action disparue de la file avant ce degré d'avancement a été
-- annulée (déplacement, Échap…) ; au-delà, elle est finie et l'on attend l'usure
-- du patron, synchronisée par le serveur en MP.
local SERIES_FINISHED_DELTA = 0.9
-- Attente maximale de cette usure, en minutes de JEU : le temps du jeu avance au
-- rythme du serveur, donc une latence MP n'arrête pas la série.
local SERIES_WAIT_MINUTES = 10
-- Images d'attente avant la pièce suivante (inventaire à jour), sans horloge réelle.
local SERIES_SETTLE_TICKS = 15
local SIZE_COMBO_WIDTH = 150
local QUANTITY_COMBO_WIDTH = 60

-- Identifiant du dernier patron cousu, par joueur local (durée de la session).
local lastPatternIds = {}

MTIR_MachineTabPattern.ACTION_TYPES = { MTIR_SewPatternAction = true }

--- Largeur minimale de l'onglet : les deux étiquettes (selon la langue et la
--- taille de police) et les deux listes tiennent sur une ligne.
function MTIR_MachineTabPattern.minWidth()
    local measure = getTextManager()
    local size = measure:MeasureStringX(UIFont.Small, getText("IGUI_MTIR_Machine_Size"))
    local quantity = measure:MeasureStringX(UIFont.Small, getText("IGUI_MTIR_Machine_Quantity"))
    return PAD + size + PAD + SIZE_COMBO_WIDTH + PAD * 2 + quantity + PAD + QUANTITY_COMBO_WIDTH + PAD
end

--- Patron de vêtement encore utilisable (les chaussures se cousent à la main).
local function isMachinePattern(item)
    local data = MTIR.getPatternData(item)
    return data ~= nil and data.kind ~= "shoe" and (data.uses or 0) > 0 and MTIR.patternModelExists(data)
end

local function patternLabel(item)
    local data = MTIR.getPatternData(item)
    return item:getName() .. " (" .. (data and data.uses or 0) .. "/" .. MTIR.opt("PatternMaxUses") .. ")"
end

local function gameMinutes()
    return getGameTime():getWorldAgeHours() * 60
end

-- ----------------------------------------------------------------------------
-- Emplacement du patron
-- ----------------------------------------------------------------------------

function MTIR_MachineTabPattern:verifyPattern(item)
    return isMachinePattern(item)
end

function MTIR_MachineTabPattern:onPatternDropped(items)
    for _, item in ipairs(items) do
        if isMachinePattern(item) then
            self:setPattern(item)
            return
        end
    end
end

function MTIR_MachineTabPattern:onPatternRemoved()
    self:setPattern(nil)
end

function MTIR_MachineTabPattern:choosePattern(box)
    local player = self.window.player
    UI.openChooser(box, player, UI.collectItems(player, isMachinePattern), patternLabel,
        "IGUI_MTIR_Machine_NoPattern", self, MTIR_MachineTabPattern.setPattern)
end

-- ----------------------------------------------------------------------------
-- Construction
-- ----------------------------------------------------------------------------

function MTIR_MachineTabPattern:createChildren()
    self.slot = UI.newSlot(self, PAD, 0, {
        player = self.window.player,
        onDrop = MTIR_MachineTabPattern.onPatternDropped,
        onRemove = MTIR_MachineTabPattern.onPatternRemoved,
        verify = MTIR_MachineTabPattern.verifyPattern,
        onChoose = MTIR_MachineTabPattern.choosePattern,
        tooltipKey = "IGUI_MTIR_Machine_SlotTooltip",
        tooltipItemKey = "IGUI_MTIR_Machine_SlotTooltipItem",
    })

    local comboY = SLOT + PAD
    local comboHeight = FONT_HGT + 6
    local sizeLabel = getTextManager():MeasureStringX(UIFont.Small, self.texts.size) + PAD
    self.sizeCombo = ISComboBox:new(PAD + sizeLabel, comboY, SIZE_COMBO_WIDTH, comboHeight, self,
        MTIR_MachineTabPattern.onChoiceChanged)
    self.sizeCombo:initialise()
    self:addChild(self.sizeCombo)

    self.quantityLabelX = self.sizeCombo:getRight() + PAD * 2
    local quantityLabel = getTextManager():MeasureStringX(UIFont.Small, self.texts.quantity) + PAD
    self.quantityCombo = ISComboBox:new(self.quantityLabelX + quantityLabel, comboY, QUANTITY_COMBO_WIDTH,
        comboHeight, self, MTIR_MachineTabPattern.onChoiceChanged)
    self.quantityCombo:initialise()
    self:addChild(self.quantityCombo)

    self.details = UI.newDetails(self, comboY + comboHeight + PAD)
    self.button = UI.newActionButton(self, self.labels.idle, MTIR_MachineTabPattern.onSew)
    self:setPattern(self:findLastPattern())
end

--- Dernier patron cousu par ce joueur, s'il est encore dans l'inventaire et utilisable.
function MTIR_MachineTabPattern:findLastPattern()
    local player = self.window.player
    local id = lastPatternIds[player:getPlayerNum()]
    local item = id and player:getInventory():getItemById(id)
    return item and isMachinePattern(item) and item or nil
end

--- Bouton sous le texte des besoins ; hauteur de l'onglet ajustée. maxHeight
--- (facultatif) : place disponible ; au-delà, le texte des besoins défile.
function MTIR_MachineTabPattern:layout(maxHeight)
    local fixed = self.details:getY() + PAD + self.button:getHeight()
    local detailsHeight = UI.fitDetails(self.details, maxHeight and maxHeight - fixed or nil)
    local buttonY = self.details:getY() + detailsHeight + PAD
    self.button:setY(buttonY)
    self:setHeight(buttonY + self.button:getHeight())
end

-- ----------------------------------------------------------------------------
-- État
-- ----------------------------------------------------------------------------

--- Quantités 1..N (N = utilisations restantes), en gardant le choix courant si possible.
function MTIR_MachineTabPattern:fillQuantity(uses)
    local previous = self:selectedQuantity()
    local count = math.max(1, math.min(uses or 1, SERIES_MAX))
    self.quantityCombo:clear()
    for i = 1, count do
        self.quantityCombo:addOptionWithData(tostring(i), i)
    end
    self.quantityCombo.selected = math.min(previous, count)
    self.quantityUses = uses
end

function MTIR_MachineTabPattern:setPattern(item)
    self.pattern = item
    self.slot:setStoredItem(item)
    self.sizeCombo:clear()
    self.sizeCombo.selected = 0
    local data = item and MTIR.getPatternData(item)
    if data then
        local player = self.window.player
        for _, size in ipairs(MTIR.getPatternSizes(data)) do
            self.sizeCombo:addOptionWithData(MTIR.SewUI.sizeLabel(player, data, size), size)
        end
        self.sizeCombo:selectData(MTIR.getPlayerSize(player).name)
    end
    self:fillQuantity(data and data.uses or 1)
    self:refresh()
end

function MTIR_MachineTabPattern:onChoiceChanged()
    self:refresh()
end

function MTIR_MachineTabPattern:selectedSize()
    local index = self.sizeCombo.selected
    return index and index > 0 and self.sizeCombo:getOptionData(index) or nil
end

function MTIR_MachineTabPattern:selectedQuantity()
    local index = self.quantityCombo.selected
    return index and index > 0 and self.quantityCombo:getOptionData(index) or 1
end

--- Retrouve le patron par son identifiant (instance remplacée en MP) ; l'oublie
--- s'il a quitté l'inventaire ou s'il est usé. Vrai si le patron a été oublié.
function MTIR_MachineTabPattern:dropLostPattern()
    if not self.pattern then
        return false
    end
    local current = UI.resolveCarried(self.window.player, self.pattern)
    if current and isMachinePattern(current) then
        if current ~= self.pattern then
            self.pattern = current
            self.slot:setStoredItem(current)
        end
        return false
    end
    self:setPattern(nil)
    return true
end

--- Recalcule besoins, texte et bouton.
function MTIR_MachineTabPattern:refresh()
    if self:dropLostPattern() then
        return
    end
    local window = self.window
    local data = self.pattern and MTIR.getPatternData(self.pattern)
    local size = data and self:selectedSize()
    -- Pendant une série, la liste reste telle quelle (pas de « 2/5 » tronqué).
    if data and data.uses ~= self.quantityUses and not self.series then
        self:fillQuantity(data.uses)
    end
    local text = ""
    self.request = nil
    if not data then
        text = getText("IGUI_MTIR_Machine_Help")
    elseif size then
        local req = MTIR.getSewRequirements(window.player, data, size, MTIR.getMachineMods(window.machine))
        self.request = req
        text = MTIR.SewUI.describeSew(data, req)
            .. UI.consumedText({ req = req, fabric = data.fabric, pattern = self.pattern })
    end
    if UI.setDetails(self.details, text) then
        window:layout()
    end
    -- Sans personnage : « Coudre » fait marcher jusqu'à la machine, l'autorité revérifie.
    local problem = MTIR.getSewingMachineProblem(nil, window.machine, data)
    self.button.tooltip = problem and getText(problem) or nil
    self.canRun = self.request ~= nil and self.request.ready and problem == nil
end

-- ----------------------------------------------------------------------------
-- Couture et série
-- ----------------------------------------------------------------------------

function MTIR_MachineTabPattern:queueOne()
    local data = MTIR.getPatternData(self.pattern)
    local series = self.series
    series.patternId = self.pattern:getID()
    series.usesBefore = data and data.uses or 0
    series.completed = false
    series.lastDelta = nil
    series.waitStart = nil
    series.settle = 0
    lastPatternIds[self.window.player:getPlayerNum()] = series.patternId
    MTIR.SewUI.queueSew(self.window.player, self.pattern, self.request, self:selectedSize(), self.window.machine)
end

--- Vrai si l'on peut lancer une pièce maintenant ; besoins recalculés juste avant.
function MTIR_MachineTabPattern:readyToQueue()
    if self.window.busy or not self.window:checkMachine() then
        return false
    end
    self:refresh()
    return self.canRun and self.pattern ~= nil and self:selectedSize() ~= nil
end

function MTIR_MachineTabPattern:onSew()
    if self.series or not self:readyToQueue() then
        return
    end
    self.series = { total = self:selectedQuantity(), done = 0 }
    self:queueOne()
end

--- Fin de série : la liste des quantités reprend les utilisations restantes.
function MTIR_MachineTabPattern:endSeries()
    self.series = nil
    self:refresh()
end

--- Vrai quand la couture lancée a usé le patron (ou l'a fait disparaître).
local function patternWorn(player, series)
    local pattern = player:getInventory():getItemById(series.patternId)
    if not pattern then
        return true
    end
    local data = MTIR.getPatternData(pattern)
    return data == nil or (data.uses or 0) < series.usesBefore
end

--- Action disparue de la file : pièce comptée quand le patron est usé ; série
--- arrêtée si l'action a été annulée, ou après une longue attente en temps de jeu.
function MTIR_MachineTabPattern:awaitCompletion(series)
    if patternWorn(self.window.player, series) then
        series.completed = true
        series.done = series.done + 1
        series.settle = 0
        return
    end
    if (series.lastDelta or 0) < SERIES_FINISHED_DELTA then
        self:endSeries()
        return
    end
    local now = gameMinutes()
    series.waitStart = series.waitStart or now
    if now - series.waitStart > SERIES_WAIT_MINUTES then
        self:endSeries()
    end
end

--- Pièce suivante, après quelques images, si tout est encore prêt.
function MTIR_MachineTabPattern:queueNext(series)
    if series.done >= series.total then
        self:endSeries()
        return
    end
    series.settle = series.settle + 1
    if series.settle < SERIES_SETTLE_TICKS then
        return
    end
    if self:readyToQueue() and self.pattern:getID() == series.patternId then
        self:queueOne()
    else
        self:endSeries()
    end
end

--- Appelé à chaque image par la fenêtre, avec la couture de ce joueur sur la machine (ou nil).
function MTIR_MachineTabPattern:tickSeries(action, running)
    local series = self.series
    if not series then
        return
    end
    if action then
        if running then
            series.lastDelta = action:getJobDelta()
        end
        return
    end
    if series.total <= 1 then
        -- Pièce unique : rien à enchaîner.
        self:endSeries()
    elseif not series.completed then
        self:awaitCompletion(series)
    else
        self:queueNext(series)
    end
end

--- Libellés « Couture 2/5... », « Préparation 3/5... », reconstruits au changement de pièce.
function MTIR_MachineTabPattern:seriesLabels(series)
    local index = math.min(series.total, series.done + 1)
    local cache = self.seriesCache
    if cache and cache.index == index and cache.total == series.total then
        return cache.labels
    end
    local indexText, totalText = tostring(index), tostring(series.total)
    local preparing = getText("IGUI_MTIR_Machine_PreparingSeries", indexText, totalText)
    local labels = {
        -- Entre deux pièces, le bouton annonce la suivante.
        idle = preparing,
        preparing = preparing,
        working = function(percent)
            return getText("IGUI_MTIR_Machine_SewingSeries", indexText, totalText, percent)
        end,
    }
    self.seriesCache = { index = index, total = series.total, labels = labels }
    return labels
end

--- Bouton : « Coudre », « Couture 2/5... 45 % », « Préparation 3/5... ».
function MTIR_MachineTabPattern:showProgress(action, running, busy)
    local series = self.series
    if series and series.total > 1 then
        -- Entre deux pièces, le bouton reste occupé (canRun faux).
        UI.showProgress(self.button, action, running, false, self:seriesLabels(series))
        return
    end
    UI.showProgress(self.button, action, running, self.canRun and not busy, self.labels)
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

--- Nom, utilisations et précision du patron ; icône du vêtement qui sera cousu.
function MTIR_MachineTabPattern:render()
    ISPanel.render(self)
    local infoX = PAD + SLOT + PAD
    local data = self.pattern and MTIR.getPatternData(self.pattern)
    local texts = self.texts
    if not data then
        self:drawText(texts.dropHere, infoX, (SLOT - FONT_HGT) / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    else
        local product = self:productOf(data.fullType)
        self:drawText(product.name, infoX, 0, 1, 1, 1, 1, UIFont.Medium)
        self:drawText(texts.uses .. (data.uses or 0) .. "/" .. MTIR.opt("PatternMaxUses"),
            infoX, UI.FONT_HGT_MEDIUM + 4, UI.DIM.r, UI.DIM.g, UI.DIM.b, 1, UIFont.Small)
        self:drawText(texts.precision .. tostring(data.precision or 0),
            infoX, UI.FONT_HGT_MEDIUM + FONT_HGT + 6, UI.DIM.r, UI.DIM.g, UI.DIM.b, 1, UIFont.Small)
        self:renderProduct(product.texture)
    end
    local labelY = self.sizeCombo:getY() + 3
    self:drawText(texts.size, PAD, labelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(texts.quantity, self.quantityLabelX, labelY, 1, 1, 1, 1, UIFont.Small)
end

--- Nom et icône du vêtement produit, gardés tant que le type ne change pas.
function MTIR_MachineTabPattern:productOf(fullType)
    local product = self.product
    if not product or product.fullType ~= fullType then
        product = { fullType = fullType, name = getItemNameFromFullType(fullType),
            texture = UI.scriptTexture(fullType) }
        self.product = product
    end
    return product
end

function MTIR_MachineTabPattern:renderProduct(texture)
    if not texture then
        return
    end
    local x = self.width - PAD - ICON
    local y = (SLOT - ICON) / 2
    self:drawRect(x - 2, y - 2, ICON + 4, ICON + 4, 0.6, 0, 0, 0)
    self:drawRectBorder(x - 2, y - 2, ICON + 4, ICON + 4, 1, 0.4, 0.4, 0.4)
    self:drawTextureScaledAspect(texture, x, y, ICON, ICON, 1, 1, 1, 1)
end

function MTIR_MachineTabPattern:new(x, y, width, window)
    local o = ISPanel.new(self, x, y, width, SLOT)
    o.window = window
    o.background = false
    o.canRun = false
    o.series = nil
    o.labels = UI.progressLabels("IGUI_MTIR_Machine_Sew", "IGUI_MTIR_Machine_Preparing",
        "IGUI_MTIR_Machine_Sewing")
    o.texts = {
        size = getText("IGUI_MTIR_Machine_Size"),
        quantity = getText("IGUI_MTIR_Machine_Quantity"),
        dropHere = getText("IGUI_MTIR_Machine_DropHere"),
        uses = getText("IGUI_MTIR_Pattern_Uses") .. " : ",
        precision = getText("IGUI_MTIR_Pattern_Precision") .. " : ",
    }
    return o
end
