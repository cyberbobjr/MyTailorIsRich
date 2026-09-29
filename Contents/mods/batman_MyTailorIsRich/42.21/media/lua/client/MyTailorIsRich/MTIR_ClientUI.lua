-- ============================================================================
-- My Tailor Is Rich — interface client
--   * Écran Personnage : taille du personnage après le poids.
--   * Inventaire : taille révélée ajoutée au nom du vêtement.
--   * Artisanat : bouton de taille sur la sortie d'une recette de vêtement.
--   * Option « Enfiler » : indice d'ajustement dans l'infobulle.
-- Lecture seule : aucune donnée de jeu n'est écrite ici.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "XpSystem/ISUI/ISCharacterScreen"
require "Entity/ISUI/CraftRecipe/ISWidgetOutput"

if MTIR.clientUIInstalled then
    return
end
MTIR.clientUIInstalled = true

-- ----------------------------------------------------------------------------
-- Écran Personnage : « (L) » après la valeur du poids
-- ----------------------------------------------------------------------------

do
    local screenDrawTextRight = ISCharacterScreen.drawTextRight
    local screenDrawText = ISCharacterScreen.drawText
    local screenDrawTexture = ISCharacterScreen.drawTexture
    local rendering = false
    local hasWeightText = false
    local hasWeightIcon = false
    local savedWidth, savedX, savedY, savedFont

    local function sizeLabel(screen)
        local label = MTIR.getPlayerSize(screen.char).name
        if MTIR.opt("EnableShoeSizes") then
            label = label .. ", " .. tostring(MTIR.getPlayerShoeSize(screen.char))
        end
        return "(" .. label .. ")"
    end

    local function drawTextRight(self, str, x, y, ...)
        if str == getText("IGUI_char_Weight") then
            hasWeightText = true
            local nutrition = self.char:getNutrition()
            if nutrition:isIncWeight() or nutrition:isIncWeightLot() or nutrition:isDecWeight() then
                hasWeightIcon = true
            end
        end
        return screenDrawTextRight(self, str, x, y, ...)
    end

    local function drawText(self, str, x, y, r, g, b, a, font, ...)
        if hasWeightText then
            hasWeightText = false
            local width = getTextManager():MeasureStringX(UIFont.Small, str)
            if hasWeightIcon then
                savedWidth, savedX, savedY, savedFont = width, x, y, font
            else
                screenDrawText(self, sizeLabel(self), x + width + 2, y, 1, 1, 1, 1, font or UIFont.Small, ...)
            end
        end
        return screenDrawText(self, str, x, y, r, g, b, a, font, ...)
    end

    local function drawTexture(self, ...)
        if hasWeightIcon and not hasWeightText then
            hasWeightIcon = false
            screenDrawText(self, sizeLabel(self), savedX + savedWidth + 18, savedY, 1, 1, 1, 1, savedFont or UIFont.Small)
        end
        return screenDrawTexture(self, ...)
    end

    local function restore(self)
        self.drawTextRight = screenDrawTextRight
        self.drawText = screenDrawText
        self.drawTexture = screenDrawTexture
    end

    local screenRender = ISCharacterScreen.render
    function ISCharacterScreen:render()
        if rendering then
            restore(self)
            return screenRender(self)
        end
        hasWeightText, hasWeightIcon = false, false
        screenDrawTextRight, screenDrawText, screenDrawTexture = self.drawTextRight, self.drawText, self.drawTexture
        self.drawTextRight, self.drawText, self.drawTexture = drawTextRight, drawText, drawTexture

        rendering = true
        local ok, result = pcall(screenRender, self)
        rendering = false
        restore(self)

        if not ok then
            error("MTIR: ISCharacterScreen:render - " .. tostring(result))
        end
        return result
    end
end

-- ----------------------------------------------------------------------------
-- Inventaire : « Nom (L) » pour une taille révélée, pendant le rendu seulement
-- ----------------------------------------------------------------------------

do
    local depth = 0
    local clothingIndex = nil
    local clothingGetName = nil

    local function getClothingIndex()
        if not clothingIndex then
            clothingIndex = getmetatable(instanceItem("Base.SpiffoSuit")).__index
        end
        return clothingIndex
    end

    local function patchName()
        local index = getClothingIndex()
        clothingGetName = index.getName
        index.getName = function(self)
            local name = clothingGetName(self)
            local data = MTIR.getData(self) or MTIR.getShoeData(self)
            if data and data.reveal and data.size and (MTIR.canClothesHaveSize(self) or MTIR.canShoeHaveSize(self)) then
                name = name .. " (" .. tostring(data.size) .. ")"
            end
            return name
        end
    end

    local function unpatchName()
        getClothingIndex().getName = clothingGetName
        clothingGetName = nil
    end

    local function withSizedNames(original)
        return function(...)
            if depth == 0 then
                patchName()
            end
            depth = depth + 1
            local ok, result = pcall(original, ...)
            depth = depth - 1
            if depth == 0 then
                unpatchName()
            end
            if not ok then
                error(result)
            end
            return result
        end
    end

    ISInventoryPane.renderdetails = withSizedNames(ISInventoryPane.renderdetails)
    ISInventoryPane.refreshContainer = withSizedNames(ISInventoryPane.refreshContainer)
    ISInventoryPane.drawItemDetails = withSizedNames(ISInventoryPane.drawItemDetails)
end

-- ----------------------------------------------------------------------------
-- Artisanat : bouton de taille sur la sortie principale
-- ----------------------------------------------------------------------------

do
    --- 42.21 : les sorties sont des script Item (getItemType), pas des Fluid/Energy.
    local function scriptHasSizedOutput(script)
        if not script or script:getResourceType() ~= ResourceType.Item then
            return false
        end
        local outputs = script:getPossibleResultItems()
        for i = 0, outputs:size() - 1 do
            local output = outputs:get(i)
            if output and output:getItemType() == ItemType.CLOTHING and MTIR.canOutputHaveSize(output) then
                return true
            end
        end
        return false
    end

    local function currentSizedOutput(widget)
        if not widget.interactiveMode or not widget.logic or not widget.logic:isManualSelectInputs() then
            return nil
        end
        if widget.outputScript:getResourceType() ~= ResourceType.Item then
            return nil
        end
        local output = widget.outputScript:getOutputMapper():getOutputItem(widget.logic:getRecipeData(), true)
        if output and output:getItemType() == ItemType.CLOTHING and MTIR.canOutputHaveSize(output) then
            return output
        end
        return nil
    end

    local function defaultSize(widget)
        return MTIR.getPlayerSize(widget.player or getPlayer()).name
    end

    local function onSizeButton(widget, button)
        local output = currentSizedOutput(widget)
        if not output or widget.logic:isCraftActionInProgress() then
            return
        end
        button:setTitle(MTIR.cycleUICraftSize(output:getFullName(), defaultSize(widget)))
    end

    local function buildSizeButton(widget)
        local iconScale = math.max(1, math.floor(getTextManager():getFontHeight(UIFont.Small) / 19))
        local button = ISXuiSkin.build(widget.xuiSkin, "S_NeedsAStyle", ISButton, 0, 0, 15 * iconScale, 20 * iconScale, "XXX")
        button.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        button.backgroundColor = { r = 0.8, g = 0.8, b = 0.8, a = 1 }
        button.backgroundColorMouseOver = { r = 0.365, g = 0.196, b = 0.125, a = 1 }
        button.textColor = { r = 0, g = 0, b = 0, a = 1 }
        button.font = UIFont.Small
        button.enable = true
        button.target = widget
        button.onclick = onSizeButton
        button:initialise()
        button:instantiate()
        button:setVisible(false)
        widget:addChild(button)
        return button
    end

    local createScriptValues = ISWidgetOutput.createScriptValues
    function ISWidgetOutput:createScriptValues(script, isSecondary, ...)
        local values = createScriptValues(self, script, isSecondary, ...)
        if values and not isSecondary and scriptHasSizedOutput(script) then
            values.mtirSizeButton = buildSizeButton(self)
        end
        return values
    end

    local updateScriptValues = ISWidgetOutput.updateScriptValues
    function ISWidgetOutput:updateScriptValues(values, ...)
        updateScriptValues(self, values, ...)
        local button = values and values.mtirSizeButton
        if not button then
            return
        end
        local output = currentSizedOutput(self)
        button:setVisible(output ~= nil)
        if output then
            button:setTitle(MTIR.getUICraftSize(output:getFullName(), defaultSize(self)))
        end
    end

    local calculateLayout = ISWidgetOutput.calculateLayout
    function ISWidgetOutput:calculateLayout(preferredWidth, preferredHeight, ...)
        calculateLayout(self, preferredWidth, preferredHeight, ...)
        local button = self.primary and self.primary.mtirSizeButton
        if button then
            button:setX(self.iconBorderSizeX - button:getWidth())
            button:setY(0)
        end
    end
end

-- ----------------------------------------------------------------------------
-- Option « Enfiler » : ajustement estimé, ou taille à choisir
-- ----------------------------------------------------------------------------

do
    local doWearClothingTooltip = ISInventoryPaneContextMenu.doWearClothingTooltip
    ISInventoryPaneContextMenu.doWearClothingTooltip = function(player, item, extra, option, ...)
        local result = doWearClothingTooltip(player, item, extra, option, ...)
        if not option then
            return result
        end
        if MTIR.canShoeHaveSize(item) then
            local shoeDiff = MTIR.getShoeDiff(item, MTIR.getPlayerShoeSize(player))
            if shoeDiff then
                if not option.toolTip then
                    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
                    option.toolTip.maxLineWidth = 1000
                end
                option.toolTip.description = (option.toolTip.description or "")
                    .. " <RGB:1,1,1> " .. MTIR.getShoeHintText(shoeDiff) .. " <LINE> "
            end
            return result
        end
        if not MTIR.canClothesHaveSize(item) then
            return result
        end
        local data = MTIR.getData(item)
        if not data then
            return result
        end
        if not option.toolTip then
            option.toolTip = ISInventoryPaneContextMenu.addToolTip()
            option.toolTip.maxLineWidth = 1000
        end
        local description = option.toolTip.description or ""
        if not data.size then
            option.toolTip.description = description .. ISInventoryPaneContextMenu.bhs
                .. getText("IGUI_MTIR_NoSize") .. " <LINE> "
            option.notAvailable = true
        else
            local diff = MTIR.getItemDiff(item, MTIR.getPlayerSize(player))
            option.toolTip.description = description .. " <RGB:1,1,1> " .. MTIR.getHintText(diff) .. " <LINE> "
        end
        return result
    end
end
