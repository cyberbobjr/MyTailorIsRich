-- ============================================================================
-- My Tailor Is Rich — aperçu 3D d'un vêtement de patron sur le personnage (client)
--
-- Fenêtre avec le modèle 3D du joueur qui porte le vêtement (ou les chaussures)
-- d'un patron. Purement local : l'équipement réel n'est jamais touché.
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
-- Rotation : glisser sur le modèle (ISUI3DModel) ou boutons fléchés ; manette :
-- LB/RB tournent, A coche « garder mes vêtements », B ferme.
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISUI3DModel"

MTIR_PatternPreviewWindow = ISCollapsableWindow:derive("MTIR_PatternPreviewWindow")

local PAD = 10
local FONT_HGT = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT + 6
-- Proportions de l'aperçu de la création de personnage (largeur = hauteur / 2).
local AVATAR_WIDTH = 180
local AVATAR_HEIGHT = 360
-- Largeur réservée aux boutons de la barre de titre (fermer, replier).
local TITLE_BUTTONS = 60
local TITLE_MAX_WIDTH = 520
local NOTE_COLOR = { r = 0.75, g = 0.75, b = 0.75 }

local instances = {}

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
    desc:setWornItem(item:getBodyLocation(), item)
    return desc
end

-- ----------------------------------------------------------------------------
-- Mise en page
-- ----------------------------------------------------------------------------

local function textWidth(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

function MTIR_PatternPreviewWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + PAD
    local avatarX = (self.width - AVATAR_WIDTH) / 2
    self.avatarX, self.avatarY = avatarX, top

    self.avatar = ISUI3DModel:new(avatarX, top, AVATAR_WIDTH, AVATAR_HEIGHT)
    self.avatar:initialise()
    self.avatar:instantiate()
    self:addChild(self.avatar)
    self.avatar:setState("idle")
    self.avatar:setDirection(IsoDirections.S)
    self.avatar:setIsometric(false)
    self.avatar:setDoRandomExtAnimations(false)

    local buttonY = top + AVATAR_HEIGHT - BUTTON_HGT
    self.turnLeft = self:addTurnButton(avatarX, buttonY, "media/ui/ArrowLeft.png", -1)
    self.turnRight = self:addTurnButton(avatarX + AVATAR_WIDTH - BUTTON_HGT, buttonY, "media/ui/ArrowRight.png", 1)

    local tickY = top + AVATAR_HEIGHT + PAD
    self.keepTick = ISTickBox:new(PAD, tickY, self.width - PAD * 2, BUTTON_HGT, "", self,
        MTIR_PatternPreviewWindow.onKeepClothes)
    self.keepTick:initialise()
    self:addChild(self.keepTick)
    self.keepTick:addOption(self.texts.keep)
    self.keepTick:setSelected(1, self.keepClothes)
    self.noteY = tickY + self.keepTick:getHeight() + PAD
    self:setHeight(self.noteY + FONT_HGT + PAD)

    self:applyDesc()
end

function MTIR_PatternPreviewWindow:addTurnButton(x, y, texturePath, step)
    local button = ISButton:new(x, y, BUTTON_HGT, BUTTON_HGT, "", self, MTIR_PatternPreviewWindow.onTurn)
    button.internal = step
    button:initialise()
    button:instantiate()
    button:setImage(getTexture(texturePath))
    self:addChild(button)
    return button
end

--- Largeur d'après les textes (langue, taille de police) : jamais de débordement.
local function computeWidth(texts)
    local width = AVATAR_WIDTH + PAD * 2
    -- Case à cocher : carré (hauteur de la case) + écart (textGap = 10) + texte.
    width = math.max(width, PAD * 2 + BUTTON_HGT + 12 + textWidth(texts.keep))
    width = math.max(width, PAD * 2 + textWidth(texts.note))
    width = math.max(width, math.min(TITLE_MAX_WIDTH, textWidth(texts.title) + TITLE_BUTTONS))
    return math.ceil(width)
end

-- ----------------------------------------------------------------------------
-- Modèle
-- ----------------------------------------------------------------------------

--- (Re)construit le descripteur et l'applique au modèle 3D.
function MTIR_PatternPreviewWindow:applyDesc()
    if not self.item then
        self.avatar:setVisible(false)
        return
    end
    self.avatar:setSurvivorDesc(buildDesc(self.player, self.item, self.keepClothes))
end

function MTIR_PatternPreviewWindow:onKeepClothes(index, selected)
    self.keepClothes = selected == true
    self:applyDesc()
end

function MTIR_PatternPreviewWindow:onTurn(button)
    self:turn(button.internal)
end

--- Tourne le modèle d'un huitième de tour (même sens que la création de personnage).
function MTIR_PatternPreviewWindow:turn(step)
    local direction = self.avatar:getDirection()
    direction = step < 0 and direction:RotRight() or direction:RotLeft()
    self.avatar:setDirection(direction)
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

function MTIR_PatternPreviewWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.isCollapsed then
        return
    end
    local x, y = self.avatarX, self.avatarY
    self:drawRectBorder(x - 2, y - 2, AVATAR_WIDTH + 4, AVATAR_HEIGHT + 4, 1, 0.3, 0.3, 0.3)
    if self.background3D then
        self:drawTextureScaled(self.background3D, x, y, AVATAR_WIDTH, AVATAR_HEIGHT, 1, 0.4, 0.4, 0.4)
    end
end

function MTIR_PatternPreviewWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    if not self.item then
        self:drawTextCentre(self.texts.noModel, self.width / 2, self.avatarY + AVATAR_HEIGHT / 2 - FONT_HGT / 2,
            1, 0.6, 0.5, 1, UIFont.Small)
    end
    self:drawText(self.texts.note, PAD, self.noteY, NOTE_COLOR.r, NOTE_COLOR.g, NOTE_COLOR.b, 1, UIFont.Small)
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
        self.keepTick:setSelected(1, not self.keepClothes)
        self:onKeepClothes(1, not self.keepClothes)
    elseif button == Joypad.LBumper then
        self:turn(-1)
    elseif button == Joypad.RBumper then
        self:turn(1)
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

function MTIR_PatternPreviewWindow:new(x, y, player, fullType)
    local name = getItemNameFromFullType(fullType)
    local texts = {
        title = getText("IGUI_MTIR_Preview_Title", name),
        keep = getText("IGUI_MTIR_Preview_KeepClothes"),
        note = getText("IGUI_MTIR_Preview_Note"),
        noModel = getText("IGUI_MTIR_Preview_NoModel"),
    }
    local o = ISCollapsableWindow.new(self, x, y, computeWidth(texts), AVATAR_HEIGHT + 120)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.fullType = fullType
    o.item = previewItem(fullType)
    o.keepClothes = true
    o.texts = texts
    o.title = texts.title
    o.resizable = false
    o.background3D = getTexture("media/ui/avatarBackgroundWhite.png")
    o:setWantKeyEvents(true)
    return o
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
    window:setX(getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - window:getWidth()) / 2)
    window:setY(getPlayerScreenTop(playerNum) + math.max(0, (getPlayerScreenHeight(playerNum) - window:getHeight()) / 2))
    window.previousFocus = previousFocus
    instances[playerNum] = window
    window:takeJoypadFocus()
    return window
end

--- Vrai si le type d'objet peut être montré porté (vêtement avec modèle 3D).
local function canPreview(fullType)
    local script = fullType and ScriptManager.instance:getItem(fullType) or nil
    return script ~= nil and script:getClothingItem() ~= nil and script:getClothingItem() ~= ""
end

--- open(player, fullType) ; canPreview(fullType) avant d'offrir l'option.
MTIR.PatternPreview = { open = open, canPreview = canPreview }
