-- ============================================================================
-- My Tailor Is Rich — aperçu 3D d'un vêtement de patron sur le personnage (client)
--
-- Panneau réutilisable MTIR_PatternPreviewPanel : modèle 3D du joueur qui porte
-- le vêtement (ou les chaussures) d'un patron, boutons de rotation, case « garder
-- mes vêtements ». Intégré à l'album de patrons (MTIR_PatternAlbumWindow) et à la
-- fenêtre « Aperçu sur moi » (MTIR_PatternPreviewWindow, menus du patron et de la
-- machine). Purement local : l'équipement réel n'est jamais touché.
--
-- Principe (Java 42.21) : ISUI3DModel:setSurvivorDesc → AnimatedModel.setSurvivorDesc
-- (AnimatedModel.java:266-275) lit la HumanVisual et les objets portés d'un
-- SurvivorDesc, puis les copie dans le modèle (setModelData, :296-345).
--   * SurvivorDesc.new(desc) : constructeur de copie (SurvivorDesc.java:200-221) ;
--     contrairement à SurvivorFactory.CreateSurvivor, il n'inscrit le descripteur
--     ni dans IsoWorld.survivorDescriptors ni dans la table des survivants ;
--   * HumanVisual:copyFrom (peau, cheveux, barbe, sang, saleté, trous) ;
--   * objets portés recopiés un à un dans le WornItems du descripteur
--     (WornItems.setItem, WornItems.java:57-80 : retire l'objet du même
--     emplacement et ceux des emplacements exclusifs). Les objets du joueur
--     sont seulement référencés, jamais modifiés ;
--   * le vêtement du patron est un objet local (instanceItem), jamais ajouté à
--     un conteneur ; son ItemVisual est créé par getVisual (InventoryItem.java:2068-2080),
--     y compris pour un vêtement de mod, si son ClothingItem est chargé.
-- Rotation : glisser sur le modèle (ISUI3DModel) ou boutons fléchés ; fenêtre à
-- la manette : LB/RB tournent, A coche « garder mes vêtements », B ferme.
-- Tailles : MTIR.UIScale (grande police, écrans 4K).
-- ============================================================================

require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISUI3DModel"
require "MyTailorIsRich/MTIR_UIScale"

local Scale = MTIR.UIScale

MTIR_PatternPreviewPanel = ISPanel:derive("MTIR_PatternPreviewPanel")
MTIR_PatternPreviewWindow = ISCollapsableWindow:derive("MTIR_PatternPreviewWindow")

-- Proportions de l'aperçu de la création de personnage (largeur = hauteur / 2).
local AVATAR_RATIO = 0.5
-- Tailles de référence de la fenêtre seule (pixels 1080p), mises à l'échelle.
local WINDOW_BASE = { pad = 10, avatarH = 360, titleButtons = 60, titleMax = 520 }
local NOTE_COLOR = { r = 0.75, g = 0.75, b = 0.75 }

local instances = {}

local function textWidth(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

local function fontHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

-- ----------------------------------------------------------------------------
-- Descripteur temporaire
-- ----------------------------------------------------------------------------

--- Vêtement local du type `fullType`, ou nil s'il n'a pas de modèle 3D.
local function previewItem(fullType)
    local item = fullType and instanceItem(fullType) or nil
    if not item or not instanceof(item, "Clothing") or item:getBodyLocation() == nil then
        return nil
    end
    if item:getVisual() == nil then
        return nil
    end
    return item
end

--- SurvivorDesc temporaire : apparence du joueur, ses vêtements (si keepClothes)
--- et le vêtement du patron à son emplacement.
local function buildDesc(player, item, keepClothes)
    local desc = SurvivorDesc.new(player:getDescriptor())
    desc:setFemale(player:isFemale())
    desc:getHumanVisual():copyFrom(player:getHumanVisual())
    desc:getWornItems():clear()
    if keepClothes then
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local wornItem = worn:get(i)
            if wornItem:getItem() ~= nil then
                desc:setWornItem(wornItem:getLocation(), wornItem:getItem())
            end
        end
    end
    -- Dynamic Body Shape Redux : sur un corps gros ou obèse, le vêtement essayé prend
    -- la même version élargie que ceux que le joueur porte (objet local seulement).
    local shaped = MTIR.getBodyShapeVisualType(item:getFullType(), player:getNutrition():getWeight())
    if shaped then
        item:getVisual():setItemType(shaped)
    end
    desc:setWornItem(item:getBodyLocation(), item)
    return desc
end

--- Vrai si le type d'objet peut être montré porté (vêtement avec modèle 3D).
local function canPreview(fullType)
    local script = fullType and ScriptManager.instance:getItem(fullType) or nil
    return script ~= nil and script:getClothingItem() ~= nil and script:getClothingItem() ~= ""
end

-- ----------------------------------------------------------------------------
-- Panneau réutilisable
-- ----------------------------------------------------------------------------

--- Hauteur totale d'un panneau dont le modèle mesure `avatarH` pixels de haut.
function MTIR_PatternPreviewPanel.heightFor(avatarH)
    return avatarH + math.floor(fontHeight() / 2) + fontHeight() + 6
end

--- Panneau de `width` × heightFor(avatarH) ; le modèle (avatarH / 2 de large) est centré.
function MTIR_PatternPreviewPanel:new(x, y, width, avatarH, player)
    local o = ISPanel.new(self, x, y, width, MTIR_PatternPreviewPanel.heightFor(avatarH))
    o.background = false
    o.player = player
    o.avatarH = avatarH
    o.avatarW = math.floor(avatarH * AVATAR_RATIO)
    o.avatarX = math.floor((width - o.avatarW) / 2)
    o.keepClothes = true
    o.keepText = getText("IGUI_MTIR_Preview_KeepClothes")
    o.noModelText = getText("IGUI_MTIR_Preview_NoModel")
    o.background3D = getTexture("media/ui/avatarBackgroundWhite.png")
    return o
end

--- Largeur minimale pour que la case « garder mes vêtements » tienne.
function MTIR_PatternPreviewPanel.minWidth(avatarH)
    local buttonH = fontHeight() + 6
    return math.max(math.floor(avatarH * AVATAR_RATIO), buttonH + 12 + textWidth(getText("IGUI_MTIR_Preview_KeepClothes")))
end

function MTIR_PatternPreviewPanel:createChildren()
    ISPanel.createChildren(self)
    local buttonH = fontHeight() + 6
    self.avatar = ISUI3DModel:new(self.avatarX, 0, self.avatarW, self.avatarH)
    self.avatar:initialise()
    self.avatar:instantiate()
    self:addChild(self.avatar)
    self.avatar:setState("idle")
    self.avatar:setDirection(IsoDirections.S)
    self.avatar:setIsometric(false)
    self.avatar:setDoRandomExtAnimations(false)

    local buttonY = self.avatarH - buttonH
    self.turnLeft = self:addTurnButton(self.avatarX, buttonY, buttonH, "media/ui/ArrowLeft.png", -1)
    self.turnRight = self:addTurnButton(self.avatarX + self.avatarW - buttonH, buttonY, buttonH,
        "media/ui/ArrowRight.png", 1)

    local tickY = self.avatarH + math.floor(fontHeight() / 2)
    self.keepTick = ISTickBox:new(0, tickY, self.width, buttonH, "", self, MTIR_PatternPreviewPanel.onKeepClothes)
    self.keepTick:initialise()
    self:addChild(self.keepTick)
    self.keepTick:addOption(self.keepText)
    self.keepTick:setSelected(1, self.keepClothes)
    self:applyDesc()
end

function MTIR_PatternPreviewPanel:addTurnButton(x, y, size, texturePath, step)
    local button = ISButton:new(x, y, size, size, "", self, MTIR_PatternPreviewPanel.onTurn)
    button.internal = step
    button:initialise()
    button:instantiate()
    button:setImage(getTexture(texturePath))
    self:addChild(button)
    return button
end

--- Montre le vêtement de `fullType` (nil : rien à montrer).
function MTIR_PatternPreviewPanel:setFullType(fullType)
    if fullType == self.fullType then
        return
    end
    self.fullType = fullType
    self.item = fullType and previewItem(fullType) or nil
    self:applyDesc()
end

--- (Re)construit le descripteur et l'applique au modèle 3D.
function MTIR_PatternPreviewPanel:applyDesc()
    if not self.avatar then
        return
    end
    local visible = self.item ~= nil
    self.avatar:setVisible(visible)
    self.turnLeft:setVisible(visible)
    self.turnRight:setVisible(visible)
    if visible then
        self.avatar:setSurvivorDesc(buildDesc(self.player, self.item, self.keepClothes))
    end
end

function MTIR_PatternPreviewPanel:onKeepClothes(index, selected)
    self.keepClothes = selected == true
    self:applyDesc()
end

--- Coche ou décoche « garder mes vêtements » (manette).
function MTIR_PatternPreviewPanel:toggleKeepClothes()
    self.keepTick:setSelected(1, not self.keepClothes)
    self:onKeepClothes(1, not self.keepClothes)
end

function MTIR_PatternPreviewPanel:onTurn(button)
    self:turn(button.internal)
end

--- Tourne le modèle d'un huitième de tour (même sens que la création de personnage).
function MTIR_PatternPreviewPanel:turn(step)
    local direction = self.avatar:getDirection()
    direction = step < 0 and direction:RotRight() or direction:RotLeft()
    self.avatar:setDirection(direction)
end

function MTIR_PatternPreviewPanel:prerender()
    local x, y = self.avatarX, 0
    self:drawRectBorder(x - 2, y - 2, self.avatarW + 4, self.avatarH + 4, 1, 0.3, 0.3, 0.3)
    if self.background3D then
        self:drawTextureScaled(self.background3D, x, y, self.avatarW, self.avatarH, 1, 0.4, 0.4, 0.4)
    end
end

function MTIR_PatternPreviewPanel:render()
    ISPanel.render(self)
    if self.fullType and not self.item then
        self:drawTextCentre(self.noModelText, self.width / 2, self.avatarH / 2 - fontHeight() / 2,
            1, 0.6, 0.5, 1, UIFont.Small)
    end
end

-- ----------------------------------------------------------------------------
-- Fenêtre « Aperçu sur moi »
-- ----------------------------------------------------------------------------

function MTIR_PatternPreviewWindow:new(x, y, player, fullType)
    local L = Scale.layout(Scale.factor(nil, WINDOW_BASE.avatarH + 120), WINDOW_BASE)
    local title = getText("IGUI_MTIR_Preview_Title", getItemNameFromFullType(fullType))
    local note = getText("IGUI_MTIR_Preview_Note")
    local width = MTIR_PatternPreviewPanel.minWidth(L.avatarH) + L.pad * 2
    width = math.max(width, L.pad * 2 + textWidth(note))
    width = math.max(width, math.min(L.titleMax, textWidth(title) + L.titleButtons))
    local o = ISCollapsableWindow.new(self, x, y, math.ceil(width), L.avatarH + 120)
    o.L = L
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.fullType = fullType
    o.note = note
    o.title = title
    o.resizable = false
    o:setWantKeyEvents(true)
    return o
end

function MTIR_PatternPreviewWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local L = self.L
    local top = self:titleBarHeight() + L.pad
    self.preview = MTIR_PatternPreviewPanel:new(L.pad, top, self.width - L.pad * 2, L.avatarH, self.player)
    self.preview:initialise()
    self.preview:instantiate()
    self:addChild(self.preview)
    self.preview:setFullType(self.fullType)
    self.noteY = top + self.preview:getHeight() + L.pad
    self:setHeight(self.noteY + fontHeight() + L.pad)
end

function MTIR_PatternPreviewWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    self:drawText(self.note, self.L.pad, self.noteY, NOTE_COLOR.r, NOTE_COLOR.g, NOTE_COLOR.b, 1, UIFont.Small)
end

function MTIR_PatternPreviewWindow:update()
    ISCollapsableWindow.update(self)
    if not self.closed and self.player:isDead() then
        self:close()
    end
end

-- ----------------------------------------------------------------------------
-- Clavier et manette
-- ----------------------------------------------------------------------------

--- Échap ferme l'aperçu. UIManager.onKeyRelease (UIManager.java:1357-1363) donne la
--- touche à l'élément le plus haut d'abord et s'arrête au premier qui la consomme :
--- un panneau ouvert dessous (machine à coudre) reste ouvert.
function MTIR_PatternPreviewWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function MTIR_PatternPreviewWindow:onKeyRelease(key)
    if self:isVisible() and key == Keyboard.KEY_ESCAPE then
        self:close()
    end
end

function MTIR_PatternPreviewWindow:onJoypadDown(button)
    if button == Joypad.BButton then
        self:close()
    elseif button == Joypad.AButton then
        self.preview:toggleKeepClothes()
    elseif button == Joypad.LBumper then
        self.preview:turn(-1)
    elseif button == Joypad.RBumper then
        self.preview:turn(1)
    end
end

function MTIR_PatternPreviewWindow:onGainJoypadFocus(joypadData)
    ISCollapsableWindow.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
end

function MTIR_PatternPreviewWindow:onLoseJoypadFocus(joypadData)
    ISCollapsableWindow.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
end

--- Manette : focus à l'aperçu, rendu à l'élément précédent à la fermeture.
function MTIR_PatternPreviewWindow:takeJoypadFocus()
    local joypad = JoypadState.players[self.playerNum + 1]
    if not joypad then
        return
    end
    if joypad.focus ~= self then
        self.previousFocus = joypad.focus
    end
    setJoypadFocus(self.playerNum, self)
end

-- ----------------------------------------------------------------------------
-- Ouverture et fermeture
-- ----------------------------------------------------------------------------

--- ISCollapsableWindow:close ne fait que masquer : retrait de l'interface et oubli.
function MTIR_PatternPreviewWindow:close()
    if self.closed then
        return
    end
    self.closed = true
    ISCollapsableWindow.close(self)
    local playerNum = self.playerNum
    if JoypadState.players[playerNum + 1] and isJoypadFocusOnElementOrDescendant(playerNum, self) then
        local previous = self.previousFocus
        if previous and previous:isVisible() then
            setJoypadFocus(playerNum, previous)
        else
            setJoypadFocus(playerNum, nil)
        end
    end
    self:removeFromUIManager()
    if instances[playerNum] == self then
        instances[playerNum] = nil
    end
end

--- Ouvre l'aperçu de `fullType` pour ce joueur (remplace l'aperçu déjà ouvert).
local function open(player, fullType)
    if not player or not fullType then
        return nil
    end
    local playerNum = player:getPlayerNum()
    local current = instances[playerNum]
    local previousFocus = nil
    if current then
        previousFocus = current.previousFocus
        current:close()
    end
    local window = MTIR_PatternPreviewWindow:new(0, 0, player, fullType)
    window:initialise()
    -- createChildren (appelé par addToUIManager) fixe la hauteur : centrer ensuite.
    window:addToUIManager()
    local x, y = Scale.fit(
        getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - window:getWidth()) / 2,
        getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - window:getHeight()) / 2,
        window:getWidth(), window:getHeight())
    window:setX(x)
    window:setY(y)
    window.previousFocus = previousFocus
    instances[playerNum] = window
    window:takeJoypadFocus()
    return window
end

--- open(player, fullType) ; canPreview(fullType) avant d'offrir l'option.
MTIR.PatternPreview = { open = open, canPreview = canPreview }
