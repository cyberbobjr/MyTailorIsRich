-- MTIR_ClientUI : taille « (L) » après le poids de l'écran Personnage, et
-- coexistence avec un mod qui cache la ligne du poids en enveloppant render
-- (même technique qu'Immersive Weighing : le texte qui suit le libellé est masqué).

local T = {}

local ACTIVE_MODS

function T.setup()
    ACTIVE_MODS = { "batman_MyTailorIsRich" }
    OPTIONS = { ShowPlayerSize = true, EnableShoeSizes = false }
    DRAWN = {}
    WEIGHT_ICON = false

    UIFont = { Small = "Small" }
    function getText(key)
        return key == "IGUI_char_Weight" and "Weight" or key
    end
    function getTextManager()
        return { MeasureStringX = function(_, _, text) return #text * 7 end }
    end
    function getActivatedMods()
        return {
            size = function() return #ACTIVE_MODS end,
            get = function(_, i) return ACTIVE_MODS[i + 1] end,
        }
    end

    MTIR = {
        opt = function(name) return OPTIONS[name] end,
        getPlayerSize = function() return { name = "L" } end,
    }
    ISInventoryPane = {}
    ISWidgetOutput = {}
    ISInventoryPaneContextMenu = {}

    -- Rendu vanilla réduit à la ligne du poids (ISCharacterScreen.lua l.116-128) et à la suivante.
    ISCharacterScreen = {}
    function ISCharacterScreen:drawTextRight(text) table.insert(DRAWN, "right:" .. text) end
    function ISCharacterScreen:drawText(text) table.insert(DRAWN, "text:" .. text) end
    function ISCharacterScreen:drawTexture(texture) table.insert(DRAWN, "icon:" .. texture) end
    function ISCharacterScreen:render()
        self:drawTextRight(getText("IGUI_char_Weight"), 100, 10, 1, 1, 1, 1, UIFont.Small)
        self:drawText("80", 110, 10, 1, 1, 1, 0.5, UIFont.Small)
        if WEIGHT_ICON then
            self:drawTexture(self.weightIncTexture, 130, 13, 1, 0.8, 0.8, 0.8)
        end
        self:drawTextRight("Height", 100, 30, 1, 1, 1, 1, UIFont.Small)
        self:drawText("180", 110, 30, 1, 1, 1, 0.5, UIFont.Small)
    end

    loadMod("client/MyTailorIsRich/MTIR_ClientUI.lua")
end

--- Enveloppe posée à OnGameStart, donc au-dessus de celle de MTIR : masque le
--- libellé du poids, le texte suivant et les chevrons.
local function installWeightHider()
    local render = ISCharacterScreen.render
    ISCharacterScreen.render = function(self)
        local drawTextRight, drawText, drawTexture = self.drawTextRight, self.drawText, self.drawTexture
        local hideValue, hideIcons = false, false
        self.drawTextRight = function(panel, text, ...)
            if text == getText("IGUI_char_Weight") then
                hideValue, hideIcons = true, true
                return
            end
            return drawTextRight(panel, text, ...)
        end
        self.drawText = function(panel, ...)
            if hideValue then
                hideValue = false
                return
            end
            return drawText(panel, ...)
        end
        self.drawTexture = function(panel, texture, ...)
            if hideIcons then
                if texture == self.weightIncTexture then
                    return
                end
                hideIcons = false
            end
            return drawTexture(panel, texture, ...)
        end
        render(self)
        self.drawTextRight, self.drawText, self.drawTexture = drawTextRight, drawText, drawTexture
    end
end

local function renderScreen()
    DRAWN = {}
    local nutrition = {
        isIncWeight = function() return WEIGHT_ICON end,
        isIncWeightLot = function() return false end,
        isDecWeight = function() return false end,
    }
    local screen = setmetatable({
        char = { getNutrition = function() return nutrition end },
        weightIncTexture = "chevron_up",
    }, { __index = ISCharacterScreen })
    screen:render()
    return table.concat(DRAWN, " ")
end

T["taille après le poids"] = function()
    assertEq(renderScreen(), "right:Weight text:80 text:(L) right:Height text:180", "sans chevron")
    WEIGHT_ICON = true
    assertEq(renderScreen(), "right:Weight text:80 text:(L) icon:chevron_up right:Height text:180", "avec chevron")
end

T["option désactivée : écran vanilla"] = function()
    OPTIONS.ShowPlayerSize = false
    assertEq(renderScreen(), "right:Weight text:80 right:Height text:180", "taille cachée")
end

T["poids caché par un autre mod : ni poids ni taille"] = function()
    ACTIVE_MODS = { "batman_MyTailorIsRich", "\\ImmersiveWeighing" }
    installWeightHider()
    assertEq(renderScreen(), "right:Height text:180", "sans chevron")
    WEIGHT_ICON = true
    assertEq(renderScreen(), "right:Height text:180", "avec chevron")
end

T["enveloppe externe inconnue : la valeur du poids lui parvient en premier"] = function()
    installWeightHider()
    assertEq(renderScreen(), "text:(L) right:Height text:180", "le poids reste caché")
    WEIGHT_ICON = true
    assertEq(renderScreen(), "text:(L) right:Height text:180", "chevron caché aussi")
end

return T
