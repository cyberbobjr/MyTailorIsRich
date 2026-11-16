-- ============================================================================
-- My Tailor Is Rich — fenêtre de l'album de patrons (client, ADR-001)
--
-- Album ancien en deux volets :
--   * à gauche, une page de classeur à pochettes (3 × 3 par page, comme un
--     classeur de cartes) : chaque patron est une photo glissée dans une
--     pochette (icône du vêtement, nom, utilisations) ; barre de recherche au-
--     dessus (nom, catégorie, matériau : MTIR.PatternAlbum.filter), pages
--     tournées par les flèches ou la molette ; on dépose des patrons de
--     l'inventaire directement sur la page pour les ranger ;
--   * à droite, l'aperçu 3D du patron choisi porté par le personnage
--     (MTIR_PatternPreviewPanel), son nom, puis les besoins de couture à la main
--     pour la taille du personnage, et les boutons.
--
-- Tailles adaptatives (MTIR.UIScale, même méthode que Live Wire) : dessinée pour
-- la police 1080p, la fenêtre grandit avec la taille de police du jeu (4K) et
-- reste dans l'écran ; les hauteurs de texte se lisent sur les polices réelles.
-- Style : MTIR.VintageStyle.
--
-- La fenêtre ne sait pas d'où viennent les patrons ni quoi faire d'un choix : la
-- spécification passée à open() le dit.
--   spec.title         : titre ;
--   spec.collect(spec) : sources { item, entryId? } (MTIR.PatternAlbum.sources) ;
--   spec.accept        : facultatif, garde un patron d'après ses données ;
--   spec.binder        : classeur consulté (dépôt sur la page, « Sortir »,
--                        couture) ; suivi par identifiant (transfert MP) ;
--   spec.onChoose      : facultatif, mode « choisir » : appelé avec la fiche
--                        choisie, puis la fenêtre se ferme (onglet Patron).
-- Lecture seule : ranger, sortir et coudre passent par les actions existantes
-- (MTIR.BinderUI, MTIR.SewUI, fenêtre de la machine).
-- Souris : clic choisit, double-clic choisit (mode « choisir »), molette tourne
-- les pages, glisser la couverture déplace la fenêtre, glisser la poignée du coin
-- bas-droit agrandit tout l'album (pochettes, aperçu, textes) ; la taille choisie
-- est retenue (ModData globale MTIR_ClientUI, côté client). Manette : flèches dans
-- la page, LB/RB tournent les pages, A action principale, Y « garder mes
-- vêtements », B ferme.
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "ISUI/ISMouseDrag"
require "MyTailorIsRich/MTIR_PatternAlbum"
require "MyTailorIsRich/MTIR_MachineUIUtil"
require "MyTailorIsRich/MTIR_PatternPreview"
require "MyTailorIsRich/MTIR_UIScale"
require "MyTailorIsRich/MTIR_VintageStyle"

local UI = MTIR.MachineUI
local Album = MTIR.PatternAlbum
local Scale = MTIR.UIScale
local Style = MTIR.VintageStyle
local C = Style.COLORS

MTIR_PatternAlbumWindow = ISPanel:derive("MTIR_PatternAlbumWindow")
MTIR_PatternAlbumPage = ISPanel:derive("MTIR_PatternAlbumPage")

local COLUMNS = 3
local ROWS = 3
local PER_PAGE = COLUMNS * ROWS
-- Tailles de référence (pixels 1080p, police de 19 px), mises à l'échelle à l'ouverture.
local BASE = {
    pad = 14, gap = 8, cardW = 112, cardH = 150, cardGap = 6, cardPad = 7, icon = 60, rightW = 300,
    avatarH = 300, seam = 6, dash = 6, dashGap = 4, thread = 2, corner = 9, shadow = 2, close = 22,
    buttonGap = 5, textGap = 3, pagerW = 34, detailsMin = 90, grip = 16,
}
-- Hauteurs de texte de référence, pour estimer la taille de base de la fenêtre.
local REF_TEXT = 19
local REF_NAME = 24
local REF_TITLE = 28
-- Images entre deux relectures des sources (contenu du classeur, inventaire).
local REFRESH_TICKS = 30
local PATTERN_ICON = "Base.MTIR_TailorPattern"

local instances = {}

-- Agrandissement choisi par le joueur (1 = taille d'origine), retenu entre deux ouvertures.
local ZOOM_KEY = "MTIR_ClientUI"

local function savedZoom()
    local data = ModData.getOrCreate(ZOOM_KEY)
    return math.max(1, tonumber(data.albumZoom) or 1)
end

local function saveZoom(zoom)
    ModData.getOrCreate(ZOOM_KEY).albumZoom = zoom
end

-- ----------------------------------------------------------------------------
-- Mise en page
-- ----------------------------------------------------------------------------

local function fontHeight(font)
    return getTextManager():getFontHeight(font)
end

--- Dimensions de la fenêtre pour une échelle (L) et des hauteurs de texte données.
local function measure(L, textH, nameH, titleH)
    local buttonH = math.max(Scale.px(28, L.k), textH + L.gap)
    local headerH = titleH + L.gap * 2
    local pageW = COLUMNS * L.cardW + (COLUMNS - 1) * L.cardGap + L.cardGap * 2
    local pageH = ROWS * L.cardH + (ROWS - 1) * L.cardGap + L.cardGap * 2
    local left = buttonH + L.gap + pageH + L.gap + buttonH + L.gap + textH
    local previewH = L.avatarH + math.floor(textH / 2) + textH + 6
    -- La poignée de redimensionnement garde le coin bas-droit libre sous les boutons.
    local right = previewH + L.gap + nameH + textH + L.gap + L.detailsMin + L.gap + buttonH * 2 + L.buttonGap
        + L.grip
    return {
        buttonH = buttonH, headerH = headerH, pageW = pageW, pageH = pageH,
        width = L.pad * 3 + pageW + L.rightW,
        height = headerH + L.pad + math.max(left, right) + L.pad,
    }
end

--- Mise en page complète : facteur d'après la taille de base et l'agrandissement
--- choisi, puis tailles réelles.
local function computeLayout(zoom)
    local base = measure(Scale.layout(1, BASE), REF_TEXT, REF_NAME, REF_TITLE)
    local L = Scale.layout(Scale.factor(base.width, base.height, zoom), BASE)
    L.textH = fontHeight(UIFont.Small)
    L.nameH = fontHeight(UIFont.Medium)
    L.titleH = fontHeight(Style.TITLE_FONT)
    L.icon = math.min(L.icon, L.cardH - L.cardPad * 3 - L.textH * 3)
    for key, value in pairs(measure(L, L.textH, L.nameH, L.titleH)) do
        L[key] = value
    end
    L.rightW = math.max(L.rightW, MTIR_PatternPreviewPanel.minWidth(L.avatarH))
    L.width = L.pad * 3 + L.pageW + L.rightW
    return L
end

-- ----------------------------------------------------------------------------
-- Textes
-- ----------------------------------------------------------------------------

local function textWidth(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, text)
end

--- Texte raccourci avec « ... » pour tenir dans `width` pixels.
local function fitText(text, width, font)
    if textWidth(text, font) <= width then
        return text
    end
    local cut = string.len(text)
    while cut > 0 and textWidth(string.sub(text, 1, cut) .. "...", font) > width do
        cut = cut - 1
    end
    return string.sub(text, 1, cut) .. "..."
end

--- Deux lignes au plus : coupure au dernier espace qui tient, puis « ... ».
local function wrapTwoLines(text, width, font)
    if textWidth(text, font) <= width then
        return { text }
    end
    local best = nil
    for position in string.gmatch(text, "() ") do
        if textWidth(string.sub(text, 1, position - 1), font) <= width then
            best = position
        end
    end
    if not best then
        return { fitText(text, width, font) }
    end
    return { string.sub(text, 1, best - 1), fitText(string.sub(text, best + 1), width, font) }
end

local function usesText(data)
    return tostring(data.uses or 0) .. "/" .. tostring(MTIR.opt("PatternMaxUses"))
end

local function cardTexture(card)
    return UI.scriptTexture(card.data.fullType) or UI.scriptTexture(PATTERN_ICON)
end

--- Taille montrée dans la fiche : celle du personnage si le patron la propose.
local function ownSize(player, data)
    local wanted
    if data.kind == "glove" then
        wanted = MTIR.GLOVE_PATTERN_SIZE
    elseif data.kind == "shoe" then
        wanted = tostring(MTIR.getPlayerShoeSize(player))
    else
        wanted = MTIR.getPlayerSize(player).name
    end
    if MTIR.isValidPatternSize(data, wanted) then
        return wanted
    end
    return MTIR.getPatternSizes(data)[1]
end

local function isSewable(data)
    return MTIR.patternModelExists(data) and (data.uses or 0) > 0
end

local function drawText(ui, text, x, y, color, font)
    ui:drawText(text, x, y, color[1], color[2], color[3], 1, font or UIFont.Small)
end

local function drawTextCentre(ui, text, x, y, color, font)
    ui:drawTextCentre(text, x, y, color[1], color[2], color[3], 1, font or UIFont.Small)
end

--- Objets glissés depuis l'inventaire et acceptés par `accept` (même lecture que
--- ISItemDropBox:onMouseUp : objets seuls ou piles, le premier d'une pile étant
--- son représentant).
local function draggedItems(accept)
    local items = {}
    for _, dragged in ipairs(ISMouseDrag.dragging or {}) do
        if instanceof(dragged, "InventoryItem") then
            if accept(dragged) then
                table.insert(items, dragged)
            end
        elseif type(dragged) == "table" and type(dragged.items) == "table" then
            for index, item in ipairs(dragged.items) do
                if index > 1 and instanceof(item, "InventoryItem") and accept(item) then
                    table.insert(items, item)
                end
            end
        end
    end
    return items
end

-- ----------------------------------------------------------------------------
-- Page de pochettes
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumPage:new(x, y, window)
    local L = window.L
    local o = ISPanel.new(self, x, y, L.pageW, L.pageH)
    o.window = window
    o.background = false
    return o
end

--- Position de la pochette `slot` (1..PER_PAGE) dans la page.
function MTIR_PatternAlbumPage:slotRect(slot)
    local L = self.window.L
    local column = (slot - 1) % COLUMNS
    local row = math.floor((slot - 1) / COLUMNS)
    return L.cardGap + column * (L.cardW + L.cardGap), L.cardGap + row * (L.cardH + L.cardGap), L.cardW, L.cardH
end

function MTIR_PatternAlbumPage:slotAt(x, y)
    for slot = 1, PER_PAGE do
        local sx, sy, sw, sh = self:slotRect(slot)
        if x >= sx and x < sx + sw and y >= sy and y < sy + sh then
            return slot
        end
    end
    return nil
end

function MTIR_PatternAlbumPage:cardAt(x, y)
    local slot = self:slotAt(x, y)
    return slot and self.window:cardOnPage(slot) or nil
end

function MTIR_PatternAlbumPage:drawCard(card, x, y, w, h, selected)
    local L = self.window.L
    Style.photo(self, x + L.cardPad, y + L.cardPad, w - L.cardPad * 2, h - L.cardPad * 2, L, selected)
    local texture = cardTexture(card)
    local iconY = y + L.cardPad * 2
    if texture then
        self:drawTextureScaledAspect(texture, x + (w - L.icon) / 2, iconY, L.icon, L.icon, 1, 1, 1, 1)
    end
    local textY = iconY + L.icon + L.textGap
    for index, line in ipairs(card.nameLines) do
        drawTextCentre(self, line, x + w / 2, textY + (index - 1) * L.textH, C.ink)
    end
    drawTextCentre(self, usesText(card.data), x + w / 2, y + h - L.cardPad * 2 - L.textH,
        isSewable(card.data) and C.inkDim or C.worn)
end

function MTIR_PatternAlbumPage:prerender()
    Style.rect(self, 0, 0, self.width, self.height, C.page)
    Style.border(self, 0, 0, self.width, self.height, C.leatherDark)
    local selected = self.window.selected
    for slot = 1, PER_PAGE do
        local x, y, w, h = self:slotRect(slot)
        -- Pochette transparente : reflet clair et bord fin, pleine ou vide.
        Style.rect(self, x, y, w, h, C.photo, 0.25)
        Style.border(self, x, y, w, h, C.inkDim, 0.35)
        local card = self.window:cardOnPage(slot)
        if card then
            self:drawCard(card, x, y, w, h, selected ~= nil and card.key == selected.key)
        end
    end
    if self.dropHover then
        Style.stitch(self, 2, 2, self.width - 4, self.height - 4, self.window.L.dash, self.window.L.dashGap,
            self.window.L.thread, C.selected)
    end
end

function MTIR_PatternAlbumPage:onMouseDown(x, y)
    local card = self:cardAt(x, y)
    if card then
        getSoundManager():playUISound("UISelectListItem")
        self.window:select(card)
    end
    return true
end

function MTIR_PatternAlbumPage:onMouseDoubleClick(x, y)
    local card = self:cardAt(x, y)
    if card then
        self.window:select(card)
        self.window:primaryAction()
    end
    return true
end

function MTIR_PatternAlbumPage:onMouseWheel(delta)
    self.window:turnPage(delta > 0 and 1 or -1)
    return true
end

--- Dépôt de patrons glissés depuis l'inventaire (classeur seulement).
function MTIR_PatternAlbumPage:onMouseUp(x, y)
    self.dropHover = false
    if self.window.spec.binder and ISMouseDrag.dragging then
        local items = draggedItems(MTIR.isPattern)
        if #items > 0 then
            self.window:storePatterns(items)
        end
    end
    return true
end

function MTIR_PatternAlbumPage:onMouseMove()
    self.dropHover = self.window.spec.binder ~= nil and ISMouseDrag.dragging ~= nil
        and #draggedItems(MTIR.isPattern) > 0
end

function MTIR_PatternAlbumPage:onMouseMoveOutside()
    self.dropHover = false
end

-- ----------------------------------------------------------------------------
-- Fenêtre
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:new(player, spec)
    local L = computeLayout(savedZoom())
    local o = ISPanel.new(self, 0, 0, L.width, L.height)
    o.L = L
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.spec = spec
    o.title = spec.title
    o.background = false
    o.moveWithMouse = true
    o.cards = {}
    o.shown = {}
    o.page = 1
    o.selected = nil
    o.fingerprint = nil
    o.ticks = 0
    o:setWantKeyEvents(true)
    return o
end

function MTIR_PatternAlbumWindow:newButton(x, y, w, h, title, onClick)
    local button = ISButton:new(x, y, w, h, title, self, onClick)
    button:initialise()
    button:instantiate()
    Style.button(button)
    self:addChild(button)
    return button
end

--- Boutons sous la fiche, sur deux colonnes, selon le mode.
function MTIR_PatternAlbumWindow:buttonSpecs()
    local W = MTIR_PatternAlbumWindow
    if self.spec.onChoose then
        return { { key = "choose", title = getText("IGUI_MTIR_Album_Choose"), onClick = W.onChoose } }
    end
    return {
        { key = "sewHand", title = getText("IGUI_MTIR_Album_SewHand"), onClick = W.onSewHand },
        { key = "sewMachine", title = getText("IGUI_MTIR_Album_SewMachine"), onClick = W.onSewMachine },
        { key = "takeOut", title = getText("IGUI_MTIR_Binder_TakeOut"), onClick = W.onTakeOut },
    }
end

function MTIR_PatternAlbumWindow:createChildren()
    ISPanel.createChildren(self)
    local L = self.L
    local top = L.headerH + L.pad
    self.top = top

    self.closeButton = self:newButton(self.width - L.pad - L.close, math.floor((L.headerH - L.close) / 2) + 2,
        L.close, L.close, "X", MTIR_PatternAlbumWindow.close)

    -- Volet gauche : recherche, page, pagination, consigne de dépôt.
    self.search = ISTextEntryBox:new("", L.pad, top, L.pageW, L.buttonH)
    self.search.font = UIFont.Small
    self.search:initialise()
    self.search:instantiate()
    Style.field(self.search)
    self.search.onTextChange = MTIR_PatternAlbumWindow.onSearchChange
    self.search.target = self
    self.search:setClearButton(true)
    self:addChild(self.search)
    self.searchHint = getText("IGUI_MTIR_Album_Search")

    local pageY = top + L.buttonH + L.gap
    self.pagePanel = MTIR_PatternAlbumPage:new(L.pad, pageY, self)
    self.pagePanel:initialise()
    self.pagePanel:instantiate()
    self:addChild(self.pagePanel)

    self.pagerY = pageY + L.pageH + L.gap
    self.prevButton = self:newButton(L.pad, self.pagerY, L.pagerW, L.buttonH, "<", MTIR_PatternAlbumWindow.onPrevPage)
    self.nextButton = self:newButton(L.pad + L.pageW - L.pagerW, self.pagerY, L.pagerW, L.buttonH, ">",
        MTIR_PatternAlbumWindow.onNextPage)
    self.hintY = self.pagerY + L.buttonH + L.gap
    self.hint = self.spec.binder and getText("IGUI_MTIR_Album_Drop") or nil

    -- Volet droit : aperçu sur moi, nom, besoins, boutons.
    self.rightX = L.pad * 2 + L.pageW
    self.preview = MTIR_PatternPreviewPanel:new(self.rightX, top, L.rightW, L.avatarH, self.player)
    self.preview:initialise()
    self.preview:instantiate()
    self:addChild(self.preview)
    self.nameY = top + self.preview:getHeight() + L.gap

    local specs = self:buttonSpecs()
    local rows = math.ceil(#specs / 2)
    local buttonW = math.floor((L.rightW - L.buttonGap) / 2)
    local buttonsTop = self.height - L.pad - L.grip - rows * L.buttonH - (rows - 1) * L.buttonGap
    self.buttons = {}
    for index, spec in ipairs(specs) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local width = (#specs == 1) and L.rightW or buttonW
        self.buttons[spec.key] = self:newButton(self.rightX + column * (buttonW + L.buttonGap),
            buttonsTop + row * (L.buttonH + L.buttonGap), width, L.buttonH, spec.title, spec.onClick)
    end

    self.detailsY = self.nameY + L.nameH + L.textH + L.gap
    self.details = UI.newDetails(self, self.detailsY, self.rightX, L.rightW)
    self.detailsMax = buttonsTop - L.gap - self.detailsY

    self:rebuild(true)
end

-- ----------------------------------------------------------------------------
-- Données et pages
-- ----------------------------------------------------------------------------

--- Empreinte des sources : change quand un patron entre, sort ou s'use.
local function fingerprint(sources)
    local parts = {}
    for _, source in ipairs(sources) do
        local data = MTIR.getSourcePatternData(source.item, source.entryId)
        table.insert(parts, tostring(source.item:getID()) .. ":" .. tostring(source.entryId)
            .. ":" .. tostring(data and data.uses or "-"))
    end
    return table.concat(parts, ";")
end

local function cardKey(card)
    return tostring(card.item:getID()) .. ":" .. tostring(card.entryId)
end

--- Relit les sources ; reconstruit les fiches si elles ont changé (ou si `force`).
function MTIR_PatternAlbumWindow:rebuild(force)
    local sources = self.spec.collect(self.spec)
    local current = fingerprint(sources)
    if not force and current == self.fingerprint then
        return
    end
    self.fingerprint = current
    self.cards = Album.cards(sources)
    local nameWidth = self.L.cardW - self.L.cardPad * 4
    for _, card in ipairs(self.cards) do
        card.key = cardKey(card)
        card.nameLines = wrapTwoLines(card.name, nameWidth)
    end
    self:applyFilter()
end

function MTIR_PatternAlbumWindow:pageCount()
    return math.max(1, math.ceil(#self.shown / PER_PAGE))
end

function MTIR_PatternAlbumWindow:cardOnPage(slot)
    return self.shown[(self.page - 1) * PER_PAGE + slot]
end

function MTIR_PatternAlbumWindow:indexOf(card)
    if not card then
        return nil
    end
    for index, shown in ipairs(self.shown) do
        if shown.key == card.key then
            return index
        end
    end
    return nil
end

function MTIR_PatternAlbumWindow:applyFilter()
    local query = self.search and self.search:getText() or ""
    self.shown = Album.filter(self.cards, query, self.spec.accept)
    local index = self:indexOf(self.selected)
    self:select(index and self.shown[index] or self.shown[(self.page - 1) * PER_PAGE + 1] or self.shown[1])
end

function MTIR_PatternAlbumWindow:turnPage(step)
    local page = math.max(1, math.min(self:pageCount(), self.page + step))
    if page == self.page then
        return
    end
    self.page = page
    getSoundManager():playUISound("UISelectListItem")
    self:select(self:cardOnPage(1))
end

function MTIR_PatternAlbumWindow:onPrevPage()
    self:turnPage(-1)
end

function MTIR_PatternAlbumWindow:onNextPage()
    self:turnPage(1)
end

function MTIR_PatternAlbumWindow.onSearchChange(box)
    box.target.page = 1
    box.target:applyFilter()
end

-- ----------------------------------------------------------------------------
-- Fiche
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:detailText(card)
    if not card then
        return getText(#self.cards == 0 and "IGUI_MTIR_Album_Empty" or "IGUI_MTIR_Album_NoMatch")
    end
    local data = card.data
    local text = getText("IGUI_MTIR_Album_Stats", tostring(data.precision or 0), usesText(data))
    if card.binderName and not self.spec.binder then
        text = text .. " <LINE> " .. getText("IGUI_MTIR_Album_InBinder", card.binderName)
    end
    if not isSewable(data) then
        return text .. " <LINE> <LINE> " .. ISInventoryPaneContextMenu.bhs .. getText("IGUI_MTIR_Pattern_MissingModel")
    end
    local size = ownSize(self.player, data)
    local req = MTIR.getSewRequirements(self.player, data, size, MTIR.SEW_BY_HAND)
    return text .. " <LINE> <LINE> <RGB:1,1,1> "
        .. getText("IGUI_MTIR_Album_ByHand", MTIR.SewUI.sizeLabel(self.player, data, size))
        .. " <LINE> " .. MTIR.SewUI.describeSew(data, req)
end

function MTIR_PatternAlbumWindow:refreshDetails()
    UI.setDetails(self.details, self:detailText(self.selected))
    UI.fitDetails(self.details, self.detailsMax)
    self:refreshButtons()
end

--- Choisit une fiche (nil : aucune) : page qui la contient, aperçu, besoins.
function MTIR_PatternAlbumWindow:select(card)
    self.selected = card
    local index = self:indexOf(card)
    if index then
        self.page = math.floor((index - 1) / PER_PAGE) + 1
    else
        self.page = math.min(self.page, self:pageCount())
    end
    local fullType = card and card.data.fullType or nil
    self.preview:setFullType((fullType and MTIR.PatternPreview.canPreview(fullType)) and fullType or nil)
    self:refreshDetails()
end

local function setEnabled(button, enabled, tooltipKey)
    if not button then
        return
    end
    button:setEnable(enabled)
    button:setTooltip((not enabled and tooltipKey) and getText(tooltipKey) or nil)
end

function MTIR_PatternAlbumWindow:refreshButtons()
    local card = self.selected
    local data = card and card.data
    local sewable = data ~= nil and isSewable(data)
    local machineSewable = sewable and data.kind ~= "shoe"
    setEnabled(self.buttons.choose, sewable)
    setEnabled(self.buttons.sewHand, sewable)
    setEnabled(self.buttons.takeOut, card ~= nil)
    self.machine = machineSewable and MTIR.findNearestSewingMachine(self.player) or nil
    setEnabled(self.buttons.sewMachine, self.machine ~= nil, machineSewable and "IGUI_MTIR_Album_NoMachine" or nil)
    self.prevButton:setEnable(self.page > 1)
    self.nextButton:setEnable(self.page < self:pageCount())
end

-- ----------------------------------------------------------------------------
-- Gestes
-- ----------------------------------------------------------------------------

--- Double-clic ou A : choisir (mode « choisir »), sinon le menu « Coudre à la main ».
function MTIR_PatternAlbumWindow:primaryAction()
    if self.spec.onChoose then
        self:onChoose()
    elseif self.buttons.sewHand and self.buttons.sewHand:isEnabled() then
        self:onSewHand(self.buttons.sewHand)
    end
end

function MTIR_PatternAlbumWindow:onChoose()
    local card = self.selected
    if not card or not isSewable(card.data) then
        return
    end
    self.spec.onChoose(card)
    self:close()
end

--- Tailles à la main : le même menu que celui du patron (MTIR.SewUI.addSewOption).
function MTIR_PatternAlbumWindow:onSewHand(button)
    local card = self.selected
    if not card then
        return
    end
    local context = ISContextMenu.get(self.playerNum, button:getAbsoluteX(),
        button:getAbsoluteY() + button:getHeight())
    MTIR.SewUI.addSewOption(card.item, self.player, context, card.entryId)
end

--- Ouvre la machine la plus proche, onglet Patron, avec ce patron choisi.
function MTIR_PatternAlbumWindow:onSewMachine()
    local card = self.selected
    local machine = self.machine
    if not card or not machine then
        return
    end
    local window = MTIR_SewingMachineWindow.open(self.player, machine)
    if window then
        window:selectTab(1)
        window.patternTab:setPattern(card.item, card.entryId)
        self:close()
    end
end

function MTIR_PatternAlbumWindow:onTakeOut()
    local card = self.selected
    if card and card.entryId ~= nil then
        MTIR.BinderUI.queueTake(self.player, card.item, card.entryId)
    end
end

--- Patrons déposés sur la page : rangés dans le classeur.
function MTIR_PatternAlbumWindow:storePatterns(items)
    MTIR.BinderUI.queueStoreAll(self.player, self.spec.binder, items)
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:prerender()
    local L = self.L
    Style.cover(self, self.width, self.height, L)
    local titleW = self.width - (L.pad + L.close) * 2
    drawTextCentre(self, fitText(self.title, titleW, Style.TITLE_FONT), self.width / 2, L.gap, C.gold,
        Style.TITLE_FONT)
    Style.rect(self, L.pad, L.headerH, self.width - L.pad * 2, 1, C.gold, 0.6)
    -- Reliure entre les deux volets.
    local spineX = L.pad + L.pageW + math.floor(L.pad / 2)
    Style.rect(self, spineX, L.headerH + L.pad, 1, self.height - L.headerH - L.pad * 2, C.leatherDark)
end

function MTIR_PatternAlbumWindow:render()
    ISPanel.render(self)
    local L = self.L
    self:renderGrip()
    if self.search:getText() == "" and not self.search:isFocused() then
        drawText(self, fitText(self.searchHint, L.pageW - L.gap * 2), L.pad + L.gap,
            self.top + (L.buttonH - L.textH) / 2, C.creamDim)
    end
    local pageText = getText("IGUI_MTIR_Album_Page", tostring(self.page), tostring(self:pageCount()))
    drawTextCentre(self, pageText, L.pad + L.pageW / 2, self.pagerY + (L.buttonH - L.textH) / 2, C.cream)
    if self.hint then
        drawTextCentre(self, fitText(self.hint, L.pageW), L.pad + L.pageW / 2, self.hintY, C.creamDim)
    end
    local card = self.selected
    if card then
        drawTextCentre(self, fitText(card.name, L.rightW, UIFont.Medium), self.rightX + L.rightW / 2, self.nameY,
            C.gold, UIFont.Medium)
        local info = card.categoryLabel .. (card.fabricLabel ~= "" and (" - " .. card.fabricLabel) or "")
        drawTextCentre(self, fitText(info, L.rightW), self.rightX + L.rightW / 2, self.nameY + L.nameH, C.cream)
    end
end

function MTIR_PatternAlbumWindow:update()
    ISPanel.update(self)
    if self.closed then
        return
    end
    if self.player:isDead() then
        self:close()
        return
    end
    self.ticks = self.ticks + 1
    if self.ticks < REFRESH_TICKS then
        return
    end
    self.ticks = 0
    if self.spec.binder then
        self.spec.binder = UI.resolveCarried(self.player, self.spec.binder)
        if not self.spec.binder then
            self:close()
            return
        end
    end
    self:rebuild(false)
    self:refreshDetails()
end

-- ----------------------------------------------------------------------------
-- Redimensionnement : poignée du coin bas-droit
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:inGrip(x, y)
    local grip = self.L.grip + self.L.seam
    return x >= self.width - grip and y >= self.height - grip
end

function MTIR_PatternAlbumWindow:onMouseDown(x, y)
    if self:inGrip(x, y) then
        self.resizing = { mouseX = getMouseX(), width = self.width }
        self.resizeWidth = self.width
        return true
    end
    return ISPanel.onMouseDown(self, x, y)
end

--- Largeur visée pendant le geste : jamais plus petite que la taille d'origine.
function MTIR_PatternAlbumWindow:trackResize()
    local base = computeLayout(1).width
    self.resizeWidth = math.max(base, self.resizing.width + getMouseX() - self.resizing.mouseX)
end

function MTIR_PatternAlbumWindow:onMouseMove(dx, dy)
    if self.resizing then
        self:trackResize()
        return true
    end
    return ISPanel.onMouseMove(self, dx, dy)
end

function MTIR_PatternAlbumWindow:onMouseMoveOutside(dx, dy)
    if self.resizing then
        self:trackResize()
        return true
    end
    return ISPanel.onMouseMoveOutside(self, dx, dy)
end

function MTIR_PatternAlbumWindow:finishResize()
    local width = self.resizeWidth
    self.resizing = nil
    self.resizeWidth = nil
    if width and math.abs(width - self.width) >= 2 then
        local current = self.L.k / Scale.fontScale()
        self:relayout(math.max(1, current * width / self.width))
    end
end

function MTIR_PatternAlbumWindow:onMouseUp(x, y)
    if self.resizing then
        self:finishResize()
        return true
    end
    return ISPanel.onMouseUp(self, x, y)
end

function MTIR_PatternAlbumWindow:onMouseUpOutside(x, y)
    if self.resizing then
        self:finishResize()
        return true
    end
    return ISPanel.onMouseUpOutside(self, x, y)
end

--- Reconstruit l'album à l'agrandissement `zoom` en gardant recherche, page et choix.
function MTIR_PatternAlbumWindow:relayout(zoom)
    saveZoom(zoom)
    local query = self.search:getText()
    local selected = self.selected
    self:clearChildren()
    self.L = computeLayout(zoom)
    self:setWidth(self.L.width)
    self:setHeight(self.L.height)
    local x, y = Scale.fit(self:getX(), self:getY(), self.width, self.height)
    self:setX(x)
    self:setY(y)
    self.selected = nil
    self:createChildren()
    self.search:setText(query)
    self:applyFilter()
    local index = self:indexOf(selected)
    if index then
        self:select(self.shown[index])
    end
end

--- Poignée : trois traits de couture en diagonale ; cadre de la taille visée pendant le geste.
function MTIR_PatternAlbumWindow:renderGrip()
    local L = self.L
    local right, bottom = self.width - L.seam - 2, self.height - L.seam - 2
    for i = 1, 3 do
        local size = math.floor(L.grip * i / 3)
        Style.rect(self, right - size, bottom - L.thread, size, L.thread, C.stitch)
        Style.rect(self, right - L.thread, bottom - size, L.thread, size, C.stitch)
    end
    if self.resizeWidth then
        local height = self.height * self.resizeWidth / self.width
        Style.border(self, 0, 0, self.resizeWidth, height, C.gold)
        Style.border(self, 1, 1, self.resizeWidth - 2, height - 2, C.gold, 0.6)
    end
end

-- ----------------------------------------------------------------------------
-- Clavier et manette
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function MTIR_PatternAlbumWindow:onKeyRelease(key)
    if self:isVisible() and key == Keyboard.KEY_ESCAPE then
        self:close()
    end
end

--- Déplace la sélection de `step` fiches dans la liste affichée.
function MTIR_PatternAlbumWindow:moveSelection(step)
    if #self.shown == 0 then
        return
    end
    local index = self:indexOf(self.selected) or 1
    self:select(self.shown[math.max(1, math.min(#self.shown, index + step))])
end

function MTIR_PatternAlbumWindow:onJoypadDown(button)
    if button == Joypad.BButton then
        self:close()
    elseif button == Joypad.AButton then
        self:primaryAction()
    elseif button == Joypad.YButton then
        self.preview:toggleKeepClothes()
    elseif button == Joypad.LBumper then
        self:turnPage(-1)
    elseif button == Joypad.RBumper then
        self:turnPage(1)
    end
end

function MTIR_PatternAlbumWindow:onJoypadDirLeft()
    self:moveSelection(-1)
end

function MTIR_PatternAlbumWindow:onJoypadDirRight()
    self:moveSelection(1)
end

function MTIR_PatternAlbumWindow:onJoypadDirUp()
    self:moveSelection(-COLUMNS)
end

function MTIR_PatternAlbumWindow:onJoypadDirDown()
    self:moveSelection(COLUMNS)
end

-- ----------------------------------------------------------------------------
-- Ouverture et fermeture
-- ----------------------------------------------------------------------------

function MTIR_PatternAlbumWindow:close()
    if self.closed then
        return
    end
    self.closed = true
    self:setVisible(false)
    local playerNum = self.playerNum
    if JoypadState.players[playerNum + 1] and isJoypadFocusOnElementOrDescendant(playerNum, self) then
        local previous = self.previousFocus
        setJoypadFocus(playerNum, (previous and previous:isVisible()) and previous or nil)
    end
    self:removeFromUIManager()
    if instances[playerNum] == self then
        instances[playerNum] = nil
    end
end

--- Ouvre l'album d'un joueur (remplace celui déjà ouvert). Voir l'en-tête pour `spec`.
local function open(player, spec)
    if not player or not spec then
        return nil
    end
    local playerNum = player:getPlayerNum()
    if instances[playerNum] then
        instances[playerNum]:close()
    end
    local window = MTIR_PatternAlbumWindow:new(player, spec)
    local x, y = Scale.fit(
        getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - window:getWidth()) / 2,
        getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - window:getHeight()) / 2,
        window:getWidth(), window:getHeight())
    window:setX(x)
    window:setY(y)
    window:initialise()
    window:addToUIManager()
    instances[playerNum] = window
    local joypad = JoypadState.players[playerNum + 1]
    if joypad then
        window.previousFocus = joypad.focus
        setJoypadFocus(playerNum, window)
    end
    return window
end

MTIR.PatternAlbumUI = { open = open }
