-- ============================================================================
-- My Tailor Is Rich — outils d'interface du panneau de machine à coudre (client)
-- Partagés par la fenêtre (MTIR_SewingMachineWindow) et ses onglets
-- (MTIR_MachineTabPattern, MTIR_MachineTabAlter) : emplacement où glisser un
-- objet, choix par menu, texte des besoins (défilant s'il est trop haut),
-- bouton avec progression, liste exacte des objets consommés. Lecture seule.
-- ============================================================================

require "ISUI/ISButton"
require "ISUI/ISRichTextPanel"
require "ISUI/ISContextMenu"
require "RadioCom/ISUIRadio/ISItemDropBox"

local UI = {}
MTIR.MachineUI = UI

UI.FONT_HGT = getTextManager():getFontHeight(UIFont.Small)
UI.FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
UI.PAD = 10
UI.SLOT = 64
UI.GOOD = { r = 0.4, g = 0.9, b = 0.4 }
UI.BAD = { r = 0.95, g = 0.35, b = 0.3 }
UI.BONUS = { r = 0.6, g = 0.85, b = 1 }
UI.DIM = { r = 0.8, g = 0.8, b = 0.8 }
local PROGRESS = { r = 0.25, g = 0.6, b = 0.3, a = 0.55 }
-- Largeur de la barre de défilement vanilla (ISScrollBar:instantiate) et marge du texte.
local SCROLLBAR_WIDTH = 17
-- Hauteur minimale du texte des besoins quand il doit défiler.
local DETAILS_MIN_LINES = 3

-- ----------------------------------------------------------------------------
-- Objets
-- ----------------------------------------------------------------------------

--- Objets de l'inventaire (sacs compris) acceptés par le prédicat, en table Lua.
function UI.collectItems(player, predicate)
    local found = player:getInventory():getAllEvalRecurse(predicate)
    local list = {}
    for i = 0, found:size() - 1 do
        table.insert(list, found:get(i))
    end
    return list
end

--- Instance actuelle d'un objet de l'inventaire (sacs compris), retrouvée par son
--- identifiant, ou nil s'il n'y est plus. En MP, un transfert peut remplacer
--- l'instance Lua : on compare les ID, comme ISRepairClothing (getItemById).
function UI.resolveCarried(player, item)
    if not item then
        return nil
    end
    return player:getInventory():getItemById(item:getID())
end

--- Vrai si les deux objets ont le même identifiant (ou sont tous deux nil).
function UI.sameId(a, b)
    if a == nil or b == nil then
        return a == b
    end
    return a:getID() == b:getID()
end

-- Icônes des scripts d'objets, par type complet (false = aucune icône).
local textureCache = {}

local function lookupTexture(fullType)
    local script = ScriptManager.instance:getItem(fullType)
    if not script then
        return nil
    end
    local texture = script:getNormalTexture()
    if not texture and script:getIcon() then
        texture = getTexture("Item_" .. script:getIcon())
    end
    return texture
end

--- Icône d'un type d'objet d'après son script (sans instance), ou nil. Mise en cache.
function UI.scriptTexture(fullType)
    if not fullType then
        return nil
    end
    local cached = textureCache[fullType]
    if cached == nil then
        cached = lookupTexture(fullType) or false
        textureCache[fullType] = cached
    end
    return cached or nil
end

-- ----------------------------------------------------------------------------
-- Contrôles
-- ----------------------------------------------------------------------------

--- Emplacement où glisser un objet ; un clic ouvre `onChoose(target, box)`.
--- Un dépôt remplace l'objet déjà présent (allowDropAlways).
function UI.newSlot(parent, x, y, spec)
    local box = ISItemDropBox:new(x, y, UI.SLOT, UI.SLOT, true, parent, spec.onDrop, spec.onRemove, spec.verify)
    box.player = spec.player
    box.allowDropAlways = true
    box.onMouseDown = function(self)
        spec.onChoose(parent, self)
    end
    box:initialise()
    box:setToolTip(true, getText(spec.tooltipKey))
    box.toolTipTextItem = getText(spec.tooltipItemKey)
    parent:addChild(box)
    return box
end

--- Menu de choix sous l'emplacement : un objet par ligne, ou une ligne grisée.
--- À la manette, le menu reçoit le focus et le rend à l'élément d'origine
--- (comme ISFluidContainerPanel.clickedDropBox).
function UI.openChooser(box, player, items, labelOf, emptyKey, target, onPick)
    local playerNum = player:getPlayerNum()
    local joypad = JoypadState.players[playerNum + 1]
    local oldFocus = joypad and joypad.focus or nil
    local context = ISContextMenu.get(playerNum, box:getAbsoluteX() + box:getWidth(), box:getAbsoluteY())
    if #items == 0 then
        local option = context:addOption(getText(emptyKey))
        option.notAvailable = true
    end
    for _, item in ipairs(items) do
        context:addOption(labelOf(item), target, onPick, item)
    end
    context:bringToTop()
    if oldFocus then
        context.origin = oldFocus
        context.mouseOver = 1
        setJoypadFocus(playerNum, context)
    end
end

--- Choix suivant (delta 1) ou précédent (-1) d'une liste déroulante ; vrai si changé.
function UI.cycleCombo(combo, delta)
    local count = #combo.options
    if count == 0 then
        return false
    end
    local index = math.max(1, math.min(count, (combo.selected or 0) + delta))
    if index == combo.selected then
        return false
    end
    combo.selected = index
    return true
end

--- Texte riche des besoins. Sa hauteur est fixée par UI.fitDetails : au-delà de la
--- place disponible, il défile (barre vanilla, molette), comme ISModalRichText.
function UI.newDetails(parent, y)
    local details = ISRichTextPanel:new(UI.PAD, y, parent.width - UI.PAD * 2, UI.FONT_HGT)
    details:initialise()
    details:instantiate()
    details.autosetheight = false
    details.background = false
    details.clip = true
    details.marginRight = SCROLLBAR_WIDTH + 4
    parent:addChild(details)
    details:addScrollBars()
    -- Hauteur de la barre réglée à la main (UI.fitDetails) : l'ancrage en bas
    -- perdrait des écarts si la hauteur change deux fois dans la même image
    -- (UIElement.setHeight écrase lastheight, UIElement.java:1419-1425).
    details.vscroll:setAnchorBottom(false)
    return details
end

--- Change le texte ; vrai si la hauteur du contenu a pu changer (mise en page à refaire).
function UI.setDetails(details, text)
    if text == details.text then
        return false
    end
    details:setText(text)
    details:paginate()
    return true
end

--- Hauteur du texte : tout le contenu, ou au plus maxHeight (au moins quelques
--- lignes) avec défilement. Rend la hauteur retenue.
function UI.fitDetails(details, maxHeight)
    local content = math.max(details:getScrollHeight(), UI.FONT_HGT)
    local height = content
    if maxHeight then
        height = math.min(content, math.max(maxHeight, UI.FONT_HGT * DETAILS_MIN_LINES))
    end
    height = math.floor(height)
    if details:getHeight() ~= height then
        details:setHeight(height)
        details.vscroll:setHeight(height)
    end
    -- Borne le défilement à la nouvelle hauteur (ISUIElement:setYScroll).
    details:setYScroll(details:getYScroll())
    return height
end

--- Fond du bouton, puis barre de progression (le titre est dessiné par-dessus).
function UI.renderProgressBackground(button)
    ISButton.prerender(button)
    if button.mtirProgress then
        button:drawRect(1, 1, (button.width - 2) * button.mtirProgress, button.height - 2,
            PROGRESS.a, PROGRESS.r, PROGRESS.g, PROGRESS.b)
    end
end

--- Bouton d'action pleine largeur, avec barre de progression.
function UI.newActionButton(parent, title, onClick)
    local button = ISButton:new(UI.PAD, 0, parent.width - UI.PAD * 2, UI.FONT_HGT + 10, title, parent, onClick)
    button:initialise()
    button.prerender = UI.renderProgressBackground
    parent:addChild(button)
    return button
end

--- Libellés d'un bouton de travail, construits une fois par onglet :
--- idle, preparing (textes) et working(percent) (texte selon le pourcentage).
function UI.progressLabels(idleKey, preparingKey, workingKey)
    return {
        idle = getText(idleKey),
        preparing = getText(preparingKey),
        working = function(percent)
            return getText(workingKey, percent)
        end,
    }
end

--- Titre du travail en cours ; recalculé seulement quand le pourcentage ou les libellés changent.
local function workingTitle(button, action, labels)
    local delta = math.max(0, math.min(1, action:getJobDelta()))
    local percent = math.floor(delta * 100)
    if button.mtirPercent ~= percent or button.mtirWorking ~= labels.working then
        button.mtirPercent = percent
        button.mtirWorking = labels.working
        button.mtirWorkingTitle = labels.working(tostring(percent))
    end
    return delta, button.mtirWorkingTitle
end

--- État du bouton : travail en cours (barre et pourcentage), attente, ou repos.
--- labels : UI.progressLabels ; titre et activation ne changent que si nécessaire.
function UI.showProgress(button, action, running, canRun, labels)
    local title, progress, enable
    if action and running then
        progress, title = workingTitle(button, action, labels)
        enable = false
    elseif action then
        progress, title, enable = 0, labels.preparing, false
    else
        title, enable = labels.idle, canRun == true
    end
    button.mtirProgress = progress
    if button.title ~= title then
        button:setTitle(title)
    end
    -- ISButton:setEnable réapplique ses couleurs à chaque appel (ISButton.lua:416).
    if button.enable ~= enable then
        button:setEnable(enable)
    end
end

-- ----------------------------------------------------------------------------
-- Objets consommés
-- ----------------------------------------------------------------------------

local function addEntry(list, name, count, uses)
    for _, entry in ipairs(list) do
        if entry.name == name then
            entry.count = entry.count + count
            entry.uses = entry.uses + uses
            return
        end
    end
    table.insert(list, { name = name, count = count, uses = uses })
end

--- Fil : utilisations prélevées dans l'ordre de la liste (comme MTIR.consumeThreads).
local function addThreads(list, threads, required)
    local left = tonumber(required) or 0
    if not threads then
        return
    end
    for i = 0, threads:size() - 1 do
        local thread = threads:get(i)
        local take = math.min(left, thread:getCurrentUses())
        if take > 0 then
            addEntry(list, thread:getDisplayName(), 0, take)
            left = left - take
        end
    end
end

-- Liste d'un seul objet, réutilisée (MTIR.countMaterialUnits attend une ArrayList
-- et ne la garde pas) : aucune allocation par objet de tissu.
local singleItem = nil

--- Unités apportées par un seul objet de tissu.
local function unitsOf(fabric, item)
    singleItem = singleItem or ArrayList.new()
    singleItem:clear()
    singleItem:add(item)
    local units = MTIR.countMaterialUnits(fabric, singleItem)
    singleItem:clear()
    return units
end

--- Tissu d'un patron, prélevé comme MTIR.consumeMaterials : un rouleau donne une
--- utilisation par unité, une chute ou une peau est consommée entière.
local function addPatternMaterials(list, materials, fabric, required)
    local left = tonumber(required) or 0
    for i = 0, materials:size() - 1 do
        if left <= 0 then
            return
        end
        local item = materials:get(i)
        local units = unitsOf(fabric, item)
        -- Rouleau : seul matériau dont les unités sont ses utilisations restantes.
        if string.find(item:getFullType(), "FabricRoll", 1, true) then
            local take = math.min(left, units)
            addEntry(list, item:getDisplayName(), 0, take)
            left = left - take
        elseif units > 0 then
            addEntry(list, item:getDisplayName(), 1, 0)
            left = left - units
        end
    end
end

--- Objets consommés en entier (bandes, trombones, vêtement de rechange).
local function addWholeItems(list, items)
    for i = 0, items:size() - 1 do
        addEntry(list, items:get(i):getDisplayName(), 1, 0)
    end
end

local function entryLine(entry)
    local parts = {}
    if entry.count > 0 then
        table.insert(parts, getText("IGUI_MTIR_Machine_ConsumedCount", tostring(entry.count)))
    end
    if entry.uses > 0 then
        table.insert(parts, getText("IGUI_MTIR_Machine_ConsumedUses", tostring(entry.uses)))
    end
    return " <LINE> <RGB:0.85,0.85,0.85> - " .. entry.name .. " : " .. table.concat(parts, ", ")
end

--- Texte riche : liste exacte des objets utilisés par le travail (en cas de réussite).
--- spec = { req, fabric (couture d'après patron), pattern ou patternName, spare }. Appelé seulement
--- au rafraîchissement des besoins, jamais à chaque image.
function UI.consumedText(spec)
    local req = spec.req
    if not req then
        return ""
    end
    local list = {}
    addThreads(list, req.threads, req.requiredThread)
    local materials = req.materials or req.strips
    if materials and spec.fabric then
        addPatternMaterials(list, materials, spec.fabric, req.requiredUnits)
    elseif spec.spare then
        addEntry(list, spec.spare:getDisplayName(), 1, 0)
    elseif materials then
        addWholeItems(list, materials)
    end
    -- Patron : objet, ou nom seul (patron rangé dans un classeur à patrons).
    if spec.patternName then
        addEntry(list, spec.patternName, 0, 1)
    elseif spec.pattern then
        addEntry(list, spec.pattern:getDisplayName(), 0, 1)
    end
    if #list == 0 then
        return ""
    end
    local text = " <LINE> <LINE> <RGB:1,1,1> " .. getText("IGUI_MTIR_Machine_Consumed")
    for _, entry in ipairs(list) do
        text = text .. entryLine(entry)
    end
    return text
end

return UI
