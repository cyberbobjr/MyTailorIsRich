-- ============================================================================
-- My Tailor Is Rich — panneau de la machine à coudre (client)
-- Les machines posées (électrique et à pédale) sont des entités B42
-- (scripts/MTIR_entities.txt) : ISEntityUI ouvre ce panneau par LuaOpenWindow,
-- au clic direct ou par l'option vanilla du menu contextuel, avec le verrou
-- « déjà utilisée » (setUsingPlayer, synchronisé en MP).
-- Bandeau : courant (électrique seulement), bonus réels de la machine,
-- illustration. Puis l'état de la machine et « Entretenir » (si l'entretien est
-- activé), et trois onglets : Patron | Retouche | Remise en état
-- (MTIR_MachineTabPattern, MTIR_MachineTabAlter). Les boutons marchent jusqu'à
-- la machine et lancent les actions avec sa position ; l'autorité revérifie
-- tout. Lecture seule, sauf la file d'actions.
-- Cycle de vie calqué sur ISBaseEntityWindow : focus manette à l'ouverture,
-- Échap ou B ferme, fermeture automatique (machine retirée, joueur trop loin,
-- autre étage, en véhicule, mort, verrou perdu), verrou relâché à chaque fermeture.
-- ============================================================================

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "Entity/ISEntityUI"
require "TimedActions/ISTimedActionQueue"
require "MyTailorIsRich/MTIR_SewingMachine"
require "MyTailorIsRich/MTIR_MachineUIUtil"
require "MyTailorIsRich/MTIR_MachineTabPattern"
require "MyTailorIsRich/MTIR_MachineTabAlter"

MTIR_SewingMachineWindow = ISCollapsableWindow:derive("MTIR_SewingMachineWindow")

local UI = MTIR.MachineUI
local PAD, FONT_HGT = UI.PAD, UI.FONT_HGT
-- Largeur minimale ; élargie d'après les textes (langue, taille de police), voir computeLayout.
local WIDTH = 440
-- Hauteur de départ, recalculée d'après l'onglet actif (MTIR_SewingMachineWindow:layout).
local HEIGHT = 560
-- Bandeau : illustration 384x256 réduite (source/*/build_*.py), assez haut pour
-- la ligne du courant et jusqu'à six lignes de bonus quelle que soit la police.
local BONUS_LINES_MAX = 6
local BANNER_HEIGHT = math.max(150, PAD * 2 + FONT_HGT + 6 + BONUS_LINES_MAX * (FONT_HGT + 2))
local ART_WIDTH = 225
local ART_ELECTRIC = "media/textures/MTIR_SewingMachinePanel.png"
local ART_BY_KIND = { electric = ART_ELECTRIC, treadle = "media/textures/MTIR_TreadleMachinePanel.png" }
local ROW_HEIGHT = FONT_HGT + 8
local MAINTAIN_WIDTH = 120
-- Marge d'un bouton autour de son texte, écart entre onglets, barre d'état minimale.
local BUTTON_TEXT_MARGIN = 16
local TAB_GAP = 4
local CONDITION_BAR_MIN = 80
-- Décalage du texte de courant, après le carré témoin.
local POWER_TEXT_OFFSET = 14
-- Valeur la plus large mise à la place de %1 pour mesurer un texte.
local SAMPLE_VALUE = "100"
local REFRESH_TICKS = 30
-- Distance de fermeture des fenêtres d'entité vanilla (ISBaseEntityWindow.panelCloseDistance,
-- mesurée par DistToProper, sans l'étage : l'étage est testé à part).
local CLOSE_DISTANCE = 4
-- Ouvert de plus loin (menu contextuel) : la limite se resserre à mesure que le
-- joueur s'approche, avec cette marge pour les détours du chemin.
local CLOSE_MARGIN = 1.5
-- Marge laissée autour de la fenêtre dans l'écran du joueur.
local SCREEN_MARGIN = 10
local TAB_KEYS = { "IGUI_MTIR_Machine_TabPattern", "IGUI_MTIR_Machine_TabResize", "IGUI_MTIR_Machine_TabRecondition" }
local MAINTENANCE_TYPES = { MTIR_MachineMaintenanceAction = true }
-- Textes mesurés pour la mise en page : { clé, vrai si elle prend une valeur %1 }.
local MAINTAIN_TEXTS = {
    { "IGUI_MTIR_Machine_Maintain" }, { "IGUI_MTIR_Machine_Preparing" }, { "IGUI_MTIR_Machine_Maintaining", true },
}
local POWER_TEXTS = { { "IGUI_MTIR_Machine_Powered" }, { "IGUI_MTIR_Machine_Unpowered" } }
local BONUS_TEXTS = {
    { "IGUI_MTIR_Machine_BonusSpeedValue", true }, { "IGUI_MTIR_Machine_BonusLevelValue", true },
    { "IGUI_MTIR_Machine_BonusPrecisionValue", true }, { "IGUI_MTIR_Machine_BonusThreadValue", true },
    { "IGUI_MTIR_Machine_BonusNoThimble" },
}
local MALUS_TEXTS = { { "IGUI_MTIR_Machine_WearMalus", true } }

local instances = {}

-- ----------------------------------------------------------------------------
-- Mise en page d'après les textes
-- ----------------------------------------------------------------------------

local function textWidth(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

--- Largeur du plus long des textes, précédés de prefix.
local function widest(entries, prefix)
    local result = 0
    for _, entry in ipairs(entries) do
        local text = entry[2] and getText(entry[1], SAMPLE_VALUE) or getText(entry[1])
        result = math.max(result, textWidth((prefix or "") .. text))
    end
    return result
end

--- Largeur de la fenêtre et du bouton d'entretien. Les textes traduits, ou une
--- police agrandie dans les options, élargissent la fenêtre au lieu de déborder
--- des onglets, du bandeau ou du bouton.
local function computeLayout()
    local maintainWidth = math.max(MAINTAIN_WIDTH, widest(MAINTAIN_TEXTS) + BUTTON_TEXT_MARGIN)
    local tabWidth = 0
    for _, key in ipairs(TAB_KEYS) do
        tabWidth = math.max(tabWidth, textWidth(getText(key)) + BUTTON_TEXT_MARGIN)
    end
    local tabs = PAD * 2 + #TAB_KEYS * tabWidth + TAB_GAP * (#TAB_KEYS - 1)
    local bannerText = math.max(POWER_TEXT_OFFSET + widest(POWER_TEXTS), widest(BONUS_TEXTS, "+ "),
        widest(MALUS_TEXTS))
    local banner = PAD + bannerText + PAD + ART_WIDTH + 2
    local condition = PAD + textWidth(getText("IGUI_MTIR_Machine_Condition")) + PAD + CONDITION_BAR_MIN
        + PAD + maintainWidth + PAD
    local width = math.max(WIDTH, tabs, banner, condition, MTIR_MachineTabPattern.minWidth())
    return math.ceil(width), maintainWidth
end

-- ----------------------------------------------------------------------------
-- Construction
-- ----------------------------------------------------------------------------

function MTIR_SewingMachineWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local kindName = MTIR.getMachineKindName(self.machine)
    self.art = getTexture(ART_BY_KIND[kindName] or ART_ELECTRIC) or getTexture(ART_ELECTRIC)
    local y = self:titleBarHeight() + BANNER_HEIGHT + PAD
    if MTIR.isMaintenanceEnabled() then
        self.conditionY = y
        self.maintainButton = ISButton:new(self.width - PAD - self.maintainWidth, y, self.maintainWidth, ROW_HEIGHT,
            getText("IGUI_MTIR_Machine_Maintain"), self, MTIR_SewingMachineWindow.onMaintain)
        self.maintainButton:initialise()
        self.maintainButton.prerender = UI.renderProgressBackground
        self:addChild(self.maintainButton)
        y = y + ROW_HEIGHT + PAD
    end
    self:createTabButtons(y)
    y = y + ROW_HEIGHT + PAD
    self.tabs = {
        MTIR_MachineTabPattern:new(0, y, self.width, self),
        MTIR_MachineTabAlter:new(0, y, self.width, self, "resize"),
        MTIR_MachineTabAlter:new(0, y, self.width, self, "recondition"),
    }
    self.patternTab = self.tabs[1]
    for _, tab in ipairs(self.tabs) do
        tab:initialise()
        tab:instantiate()
        tab:setVisible(false)
        self:addChild(tab)
    end
    self:selectTab(1)
end

function MTIR_SewingMachineWindow:createTabButtons(y)
    local gap = TAB_GAP
    local width = (self.width - PAD * 2 - gap * (#TAB_KEYS - 1)) / #TAB_KEYS
    self.tabButtons = {}
    for index, key in ipairs(TAB_KEYS) do
        local button = ISButton:new(PAD + (index - 1) * (width + gap), y, width, ROW_HEIGHT, getText(key),
            self, MTIR_SewingMachineWindow.onTabClicked)
        button.internal = index
        button:initialise()
        self:addChild(button)
        self.tabButtons[index] = button
    end
end

function MTIR_SewingMachineWindow:onTabClicked(button)
    self:selectTab(button.internal)
end

--- Affiche un onglet ; l'onglet actif est éclairé, les autres assombris.
function MTIR_SewingMachineWindow:selectTab(index)
    for i, tab in ipairs(self.tabs) do
        local active = i == index
        tab:setVisible(active)
        local button = self.tabButtons[i]
        if active then
            button:setBackgroundRGBA(0.3, 0.25, 0.18, 1)
            button:setBorderRGBA(0.85, 0.7, 0.45, 1)
            button.textColor = { r = 1, g = 0.9, b = 0.7, a = 1 }
        else
            button:setBackgroundRGBA(0, 0, 0, 1)
            button:setBorderRGBA(0.4, 0.4, 0.4, 1)
            button.textColor = { r = 0.75, g = 0.75, b = 0.75, a = 1 }
        end
    end
    self.activeTab = self.tabs[index]
    self.activeTabIndex = index
    self:refresh()
    self:layout()
    self:updateJoypadHints()
end

--- Onglet actif sous les boutons d'onglets, fenêtre ajustée à son contenu mais
--- jamais plus haute que l'écran du joueur : au-delà, le texte des besoins défile.
function MTIR_SewingMachineWindow:layout()
    local tab = self.activeTab
    if not tab then
        return
    end
    local maxHeight = getPlayerScreenHeight(self.playerNum) - SCREEN_MARGIN * 2
    tab:layout(maxHeight - tab:getY() - PAD)
    self:setHeight(tab:getY() + tab:getHeight() + PAD)
    self:keepOnScreen()
end

--- Garde la fenêtre dans l'écran du joueur (écran partagé compris).
function MTIR_SewingMachineWindow:keepOnScreen()
    local playerNum = self.playerNum
    local left, top = getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum)
    local right = left + getPlayerScreenWidth(playerNum)
    local bottom = top + getPlayerScreenHeight(playerNum)
    self:setX(math.max(left, math.min(self:getX(), right - self:getWidth())))
    self:setY(math.max(top, math.min(self:getY(), bottom - self:getHeight())))
end

-- ----------------------------------------------------------------------------
-- Travail en cours sur cette machine
-- ----------------------------------------------------------------------------

--- Action de ce joueur sur cette machine dans la file : action et vrai si en cours.
function MTIR_SewingMachineWindow:findWork()
    local queue = ISTimedActionQueue.queues[self.player]
    if not queue or not queue.queue then
        return nil, false
    end
    for index, action in ipairs(queue.queue) do
        if action.machinePos == self.machinePos and self:ownerOf(action) then
            return action, index == 1 and action.action ~= nil
        end
    end
    return nil, false
end

--- Onglet (ou "maintenance") auquel appartient une action, ou nil.
function MTIR_SewingMachineWindow:ownerOf(action)
    if MAINTENANCE_TYPES[action.Type] then
        return "maintenance"
    end
    for _, tab in ipairs(self.tabs) do
        if tab.ACTION_TYPES[action.Type] then
            return tab
        end
    end
    return nil
end

--- À chaque image : bouton de l'onglet visible et de l'entretien, enchaînement de
--- la série. Les onglets masqués ne sont pas mis à jour (ils le sont à leur affichage).
--- À la fin d'un travail, tout est recalculé (fil, tissu et patron consommés).
function MTIR_SewingMachineWindow:updateProgress()
    local action, running = self:findWork()
    local owner = action and self:ownerOf(action)
    local wasBusy = self.busy
    self.busy = action ~= nil
    local tab = self.activeTab
    tab:showProgress(owner == tab and action or nil, running, self.busy)
    self:showMaintenanceProgress(owner == "maintenance" and action or nil, running)
    local sewing = owner == self.patternTab
    self.patternTab:tickSeries(sewing and action or nil, sewing and running)
    if wasBusy and not self.busy then
        self:refresh()
    end
end

-- ----------------------------------------------------------------------------
-- Entretien
-- ----------------------------------------------------------------------------

--- Infobulle des besoins de l'entretien (état, gain, tournevis, huile, compétence),
--- texte de MTIR.AlterUI.describeMaintenance ; mention si la machine est à 100 %.
local function maintenanceTooltip(req)
    local text = MTIR.AlterUI.describeMaintenance(req)
    if req.condition >= 100 then
        text = text .. " <LINE> <LINE> " .. ISInventoryPaneContextMenu.ghs .. getText("IGUI_MTIR_Maintenance_Full")
    end
    return text
end

function MTIR_SewingMachineWindow:refreshMaintenance()
    if not self.maintainButton then
        return
    end
    self.canMaintain = false
    local api = MTIR.AlterUI
    if not MTIR.getMaintenanceRequirements or not api or not api.describeMaintenance or not api.queueMaintenance then
        return
    end
    local req = MTIR.getMaintenanceRequirements(self.player, self.machine)
    self.maintainButton.tooltip = maintenanceTooltip(req)
    self.canMaintain = req.ready == true
end

function MTIR_SewingMachineWindow:showMaintenanceProgress(action, running)
    if not self.maintainButton then
        return
    end
    UI.showProgress(self.maintainButton, action, running, self.canMaintain and not self.busy,
        self.maintainLabels)
end

--- Besoins recalculés juste avant de lancer l'entretien.
function MTIR_SewingMachineWindow:onMaintain()
    if self.busy or not self:checkMachine() then
        return
    end
    self:refreshMaintenance()
    if not self.canMaintain then
        return
    end
    MTIR.AlterUI.queueMaintenance(self.player, self.machine)
end

-- ----------------------------------------------------------------------------
-- État
-- ----------------------------------------------------------------------------

local function percentOf(factor)
    return math.floor((1 - factor) * 100 + 0.5)
end

--- Lignes de bonus d'après les valeurs réelles (options et usure comprises).
local function bonusLines(mods)
    local lines = {}
    local function add(key, value, color)
        -- « + » devant un bonus ; le malus d'usure porte déjà son signe.
        local text = value ~= nil and getText(key, tostring(value)) or getText(key)
        table.insert(lines, { text = text, color = color or UI.BONUS, prefix = color == UI.BAD and "" or "+ " })
    end
    if percentOf(mods.durationFactor) > 0 then add("IGUI_MTIR_Machine_BonusSpeedValue", percentOf(mods.durationFactor)) end
    if mods.levelBonus > 0 then add("IGUI_MTIR_Machine_BonusLevelValue", mods.levelBonus) end
    if mods.precisionBonus > 0 then add("IGUI_MTIR_Machine_BonusPrecisionValue", mods.precisionBonus) end
    if percentOf(mods.threadFactor) > 0 then add("IGUI_MTIR_Machine_BonusThreadValue", percentOf(mods.threadFactor)) end
    if MTIR.opt("RequireThimble") == true then add("IGUI_MTIR_Machine_BonusNoThimble") end
    local malus = math.floor((mods.successMalus or 0) * 100 + 0.5)
    if malus > 0 then add("IGUI_MTIR_Machine_WearMalus", malus, UI.BAD) end
    return lines
end

--- Vrai si la machine est toujours posée. Un objet ramassé ou détruit garde sa
--- case (IsoObject.java:4252-4257) : tester son index, comme
--- ISBaseEntityWindow:wasEntityRemoved.
function MTIR_SewingMachineWindow:machinePresent()
    local machine = self.machine
    return MTIR.isSewingMachine(machine) and machine:getSquare() ~= nil and machine:getObjectIndex() ~= -1
end

--- Vrai si la machine est encore là ; sinon ferme le panneau (aucune action lancée).
function MTIR_SewingMachineWindow:checkMachine()
    if self.closed then
        return false
    end
    if not self:machinePresent() then
        self:close()
        return false
    end
    return true
end

--- Couleur et texte de la barre d'état (ColorInfo réutilisé), calculés au rafraîchissement.
function MTIR_SewingMachineWindow:refreshConditionColor()
    local ratio = math.max(0, math.min(1, (self.condition or 100) / 100))
    getCore():getBadHighlitedColor():interp(getCore():getGoodHighlitedColor(), ratio, self.conditionColor)
    self.conditionRatio = ratio
    self.conditionText = ratio <= 0 and getText("IGUI_MTIR_Machine_Jammed_Short")
        or (math.floor(ratio * 100 + 0.5) .. " %")
end

--- Recalcule machine, bonus, entretien et onglet actif. Ferme le panneau si la machine a disparu.
function MTIR_SewingMachineWindow:refresh()
    if not self:checkMachine() then
        return
    end
    self.kind = MTIR.getMachineKind(self.machine)
    self.powered = MTIR.hasSewingPower(self.machine:getSquare())
    self.powerText = getText(self.powered and "IGUI_MTIR_Machine_Powered" or "IGUI_MTIR_Machine_Unpowered")
    self.condition = MTIR.getMachineCondition(self.machine)
    self:refreshConditionColor()
    self.bonusLines = bonusLines(MTIR.getMachineMods(self.machine))
    self:refreshMaintenance()
    if self.activeTab then
        self.activeTab:refresh()
    end
end

-- ----------------------------------------------------------------------------
-- Rendu
-- ----------------------------------------------------------------------------

--- Trop loin ou à un autre étage. Pendant un travail sur cette machine, le joueur
--- y marche ou y travaille : pas de fermeture (le chemin peut faire un détour).
function MTIR_SewingMachineWindow:isTooFar()
    if self.busy then
        return false
    end
    local machine = self.machine
    if math.abs(self.player:getZ() - machine:getZ()) >= 1 then
        return true
    end
    local distance = self.player:DistToProper(machine)
    self.closeDistance = math.max(CLOSE_DISTANCE, math.min(self.closeDistance, distance + CLOSE_MARGIN))
    return distance > self.closeDistance
end

--- Conditions de ISBaseEntityWindow:shouldAutoClose, plus la mort et l'étage.
function MTIR_SewingMachineWindow:shouldAutoClose()
    local player = self.player
    return not self:machinePresent() or player:isDead() or player:getVehicle() ~= nil
        or self.machine:getUsingPlayer() ~= player or self:isTooFar()
end

function MTIR_SewingMachineWindow:update()
    ISCollapsableWindow.update(self)
    if self.closed then
        return
    end
    if self:shouldAutoClose() then
        self:close()
        return
    end
    self:updateProgress()
    self.ticks = (self.ticks or 0) + 1
    if self.ticks < REFRESH_TICKS then
        return
    end
    self.ticks = 0
    self:refresh()
end

--- Bandeau : courant (électrique seulement) et bonus à gauche, illustration à droite.
function MTIR_SewingMachineWindow:renderBanner()
    local top = self:titleBarHeight()
    self:drawRect(0, top, self.width, BANNER_HEIGHT, 1, 0.09, 0.085, 0.08)
    self:drawRect(0, top + BANNER_HEIGHT - 1, self.width, 1, 1, 0.35, 0.3, 0.25)
    if self.art then
        local artHeight = ART_WIDTH * self.art:getHeight() / self.art:getWidth()
        self:drawTextureScaled(self.art, self.width - ART_WIDTH - 2, top + (BANNER_HEIGHT - artHeight) / 2,
            ART_WIDTH, artHeight, 1, 1, 1, 1)
    end
    local y = top + PAD
    if self.kind and self.kind.needsPower then
        local power = self.powered and UI.GOOD or UI.BAD
        self:drawRect(PAD, y + (FONT_HGT - 8) / 2, 8, 8, 1, power.r, power.g, power.b)
        self:drawText(self.powerText or "", PAD + POWER_TEXT_OFFSET, y, power.r, power.g, power.b, 1, UIFont.Small)
        y = y + FONT_HGT + 6
    end
    for _, line in ipairs(self.bonusLines or {}) do
        self:drawText(line.prefix .. line.text, PAD, y, line.color.r, line.color.g, line.color.b, 1, UIFont.Small)
        y = y + FONT_HGT + 2
    end
end

--- État de la machine : barre de 0 à 100 %, « Bloquée » à 0.
function MTIR_SewingMachineWindow:renderCondition()
    local y = self.conditionY
    self:drawText(self.conditionLabel, PAD, y + (ROW_HEIGHT - FONT_HGT) / 2, 1, 1, 1, 1, UIFont.Small)
    local x = PAD + self.conditionLabelWidth + PAD
    local width = self.maintainButton:getX() - PAD - x
    local ratio = self.conditionRatio or 1
    local color = self.conditionColor
    self:drawRect(x, y, width, ROW_HEIGHT, 0.8, 0.05, 0.05, 0.05)
    self:drawRect(x + 1, y + 1, (width - 2) * ratio, ROW_HEIGHT - 2, 0.7, color:getR(), color:getG(), color:getB())
    self:drawRectBorder(x, y, width, ROW_HEIGHT, 1, 0.4, 0.4, 0.4)
    self:drawTextCentre(self.conditionText or "", x + width / 2, y + (ROW_HEIGHT - FONT_HGT) / 2,
        1, 1, 1, 1, UIFont.Small)
end

function MTIR_SewingMachineWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    self:renderBanner()
    if self.maintainButton then
        self:renderCondition()
    end
end

-- ----------------------------------------------------------------------------
-- Clavier et manette
-- ----------------------------------------------------------------------------

--- Échap ne rouvre pas le menu du jeu : il ferme le panneau (ISBaseEntityWindow:isKeyConsumed).
function MTIR_SewingMachineWindow:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
end

function MTIR_SewingMachineWindow:onKeyRelease(key)
    if self:isVisible() and (key == Keyboard.KEY_ESCAPE or getCore():isKey(KeybindId.CRAFTING_UI, key)) then
        self:close()
    end
end

--- Icônes des boutons de la manette : A sur l'action de l'onglet, Y sur l'entretien.
function MTIR_SewingMachineWindow:updateJoypadHints()
    local focused = self.joyfocus ~= nil
    for _, tab in ipairs(self.tabs or {}) do
        if focused and tab == self.activeTab then
            tab.button:setJoypadButton(Joypad.Texture.AButton)
        else
            tab.button:clearJoypadButton()
        end
    end
    if self.maintainButton then
        if focused then
            self.maintainButton:setJoypadButton(Joypad.Texture.YButton)
        else
            self.maintainButton:clearJoypadButton()
        end
    end
end

function MTIR_SewingMachineWindow:onGainJoypadFocus(joypadData)
    ISCollapsableWindow.onGainJoypadFocus(self, joypadData)
    self.drawJoypadFocus = true
    self:updateJoypadHints()
end

function MTIR_SewingMachineWindow:onLoseJoypadFocus(joypadData)
    ISCollapsableWindow.onLoseJoypadFocus(self, joypadData)
    self.drawJoypadFocus = false
    self:updateJoypadHints()
end

--- B ferme, A lance l'action de l'onglet, X choisit l'objet, Y entretient, LB/RB changent d'onglet.
function MTIR_SewingMachineWindow:onJoypadDown(button)
    local tab = self.activeTab
    if button == Joypad.BButton then
        self:close()
    elseif button == Joypad.AButton then
        tab.button:forceClick()
    elseif button == Joypad.XButton then
        tab.slot.onMouseDown(tab.slot)
    elseif button == Joypad.YButton and self.maintainButton then
        self.maintainButton:forceClick()
    elseif button == Joypad.LBumper or button == Joypad.RBumper then
        local step = button == Joypad.LBumper and -1 or 1
        self:selectTab((self.activeTabIndex - 1 + step) % #self.tabs + 1)
    end
end

--- Croix gauche/droite : première liste de l'onglet (taille, option) ; haut/bas : quantité.
function MTIR_SewingMachineWindow:cycleTabCombo(comboName, delta)
    local tab = self.activeTab
    local combo = tab[comboName]
    if combo and UI.cycleCombo(combo, delta) then
        tab:onChoiceChanged()
    end
end

function MTIR_SewingMachineWindow:onJoypadDirLeft()
    self:cycleTabCombo(self.activeTab.sizeCombo and "sizeCombo" or "choiceCombo", -1)
end

function MTIR_SewingMachineWindow:onJoypadDirRight()
    self:cycleTabCombo(self.activeTab.sizeCombo and "sizeCombo" or "choiceCombo", 1)
end

function MTIR_SewingMachineWindow:onJoypadDirUp()
    self:cycleTabCombo("quantityCombo", 1)
end

function MTIR_SewingMachineWindow:onJoypadDirDown()
    self:cycleTabCombo("quantityCombo", -1)
end

--- Focus manette à l'ouverture, comme createWindow (ISEntityUI.lua:420-426).
function MTIR_SewingMachineWindow:takeJoypadFocus()
    local playerNum = self.playerNum
    if not JoypadState.players[playerNum + 1] then
        return
    end
    local focus = getFocusForPlayer(playerNum)
    if focus then
        focus:setVisible(false)
    end
    if getPlayerInventory(playerNum) then
        getPlayerInventory(playerNum):close()
    end
    if getPlayerLoot(playerNum) then
        getPlayerLoot(playerNum):close()
    end
    setJoypadFocus(playerNum, self)
end

-- ----------------------------------------------------------------------------
-- Ouverture et fermeture
-- ----------------------------------------------------------------------------

--- Toutes les fermetures passent ici (croix, Échap, B, fermeture automatique,
--- ouverture d'une autre machine) : focus manette rendu, verrou relâché.
function MTIR_SewingMachineWindow:close()
    if self.closed then
        return
    end
    self.closed = true
    ISCollapsableWindow.close(self)
    local playerNum = self.playerNum
    if JoypadState.players[playerNum + 1] and isJoypadFocusOnElementOrDescendant(playerNum, self) then
        setJoypadFocus(playerNum, nil)
    end
    if self.machine:getUsingPlayer() == self.player then
        self.machine:setUsingPlayer(nil)
    end
    self:removeFromUIManager()
    if instances[playerNum] == self then
        instances[playerNum] = nil
    end
end

function MTIR_SewingMachineWindow:new(x, y, player, machine)
    local width, maintainWidth = computeLayout()
    local o = ISCollapsableWindow.new(self, x, y, width, HEIGHT)
    o.maintainWidth = maintainWidth
    local kind = MTIR.getMachineKind(machine)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.machine = machine
    o.kind = kind
    o.title = getText(kind and kind.titleKey or "IGUI_MTIR_Machine_Title")
    o.resizable = false
    o.powered = false
    o.busy = false
    o.condition = 100
    o.canMaintain = false
    o.machinePos = MTIR.encodeMachinePos(machine)
    o.closeDistance = math.max(CLOSE_DISTANCE, player:DistToProper(machine) + CLOSE_MARGIN)
    o.conditionColor = ColorInfo.new(0, 0, 0, 1)
    o.conditionLabel = getText("IGUI_MTIR_Machine_Condition")
    o.conditionLabelWidth = getTextManager():MeasureStringX(UIFont.Small, o.conditionLabel)
    o.maintainLabels = UI.progressLabels("IGUI_MTIR_Machine_Maintain", "IGUI_MTIR_Machine_Preparing",
        "IGUI_MTIR_Machine_Maintaining")
    o:setWantKeyEvents(true)
    -- Un seul joueur à la fois (ISBaseEntityWindow fait de même) ; synchronisé en MP.
    machine:setUsingPlayer(player)
    return o
end

--- Ouvre (ou ramène au premier plan) le panneau d'un joueur pour cette machine.
function MTIR_SewingMachineWindow.open(player, machine)
    local user = machine:getUsingPlayer()
    if user ~= nil and user ~= player then
        player:Say(getText("IGUI_ObjectAlreadyUsedSayMessage"))
        return nil
    end
    local playerNum = player:getPlayerNum()
    local current = instances[playerNum]
    if current then
        if current.machine == machine then
            current:bringToTop()
            current:takeJoypadFocus()
            return current
        end
        current:close()
    end
    local y = getPlayerScreenTop(playerNum) + (getPlayerScreenHeight(playerNum) - HEIGHT) / 2
    local window = MTIR_SewingMachineWindow:new(0, y, player, machine)
    window:setX(getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - window:getWidth()) / 2)
    window:initialise()
    window:addToUIManager()
    instances[playerNum] = window
    window:takeJoypadFocus()
    return window
end

--- Appelé par ISEntityUI.CanOpenWindowFor via LuaWindowClass. ISEntityWindow refuserait
--- (il exige des panneaux de composants d'artisanat, que la machine n'a pas).
function MTIR_SewingMachineWindow.CanOpenWindowFor(player, entity)
    return player ~= nil and MTIR.isSewingMachine(entity)
end

--- Appelé par ISEntityUI.OpenWindow (LuaOpenWindow du style ES_MTIR_SewingMachine),
--- après ses propres vérifications (interface activée, verrou d'usage). Ce chemin
--- ne passe pas par createWindow : le focus manette est donné par open().
function MTIR_SewingMachineWindow.openFromEntity(player, entity)
    MTIR_SewingMachineWindow.open(player, entity)
end
