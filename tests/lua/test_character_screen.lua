-- MTIR_ClientUI : taille « (L) » après le poids de l'écran Personnage, et
-- coexistence avec un mod qui cache la ligne du poids en enveloppant render
-- (même technique qu'Immersive Weighing : le texte qui suit le libellé est masqué),
-- ou qui peint son propre cadre après le poids (Nutrition Makes Sense).

local T = {}

local ACTIVE_MODS

function T.setup()
    ACTIVE_MODS = { "batman_MyTailorIsRich" }
    OPTIONS = { ShowPlayerSize = true, EnableShoeSizes = false }
    DRAWN = {}
    TEXT_X = {}
    WEIGHT_ICON = false
    SIZE_WARNING, SIZE_TARGET = nil, nil

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
        getSizeWarning = function() return SIZE_WARNING, SIZE_TARGET end,
    }
    ISInventoryPane = {}
    ISWidgetOutput = {}
    ISInventoryPaneContextMenu = {}

    -- Rendu vanilla réduit à la ligne du poids (ISCharacterScreen.lua l.116-128) et à la suivante.
    ISCharacterScreen = {}
    function ISCharacterScreen:drawTextRight(text) table.insert(DRAWN, "right:" .. text) end
    function ISCharacterScreen:drawText(text, x)
        table.insert(DRAWN, "text:" .. text)
        TEXT_X[text] = x
    end
    function ISCharacterScreen:drawRect(x, _, w) table.insert(DRAWN, "rect:" .. x .. "+" .. w) end
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

    loadMod("client/MyTailorIsRich/WeightRow/MTIR_WeightRow.lua")
    loadMod("client/MyTailorIsRich/WeightRow/MTIR_WeightRowImmersiveWeighing.lua")
    loadMod("client/MyTailorIsRich/WeightRow/MTIR_WeightRowNutritionMakesSense.lua")
    loadMod("client/MyTailorIsRich/MTIR_ClientUI.lua")
end

--- Nutrition Makes Sense 2.0.2, posé au chargement de ses fichiers : après le rendu,
--- un cadre plein à la place de la flèche puis la variation de poids dedans
--- (xOffset = 100, valeur à xOffset + 10 ; cadre à xOffset + largeur + 13).
local function installNutritionFrame()
    local render = ISCharacterScreen.render
    ISCharacterScreen.render = function(self)
        render(self)
        local frameX = 100 + getTextManager():MeasureStringX(UIFont.Small, "80") + 13
        local frameWidth = getTextManager():MeasureStringX(UIFont.Small, "+0.00 kg/wk") + 8
        self:drawRect(frameX, 10, frameWidth, 12)
        self:drawText("-0.35 kg/wk", frameX, 10)
    end
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

T["près d'une borne : la taille à venir après une flèche"] = function()
    SIZE_WARNING, SIZE_TARGET = "down", { name = "M" }
    assertEq(renderScreen(), "right:Weight text:80 text:(L -> M) right:Height text:180", "bientôt du M")
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

T["Nutrition Makes Sense : la taille passe après son cadre"] = function()
    ACTIVE_MODS = { "batman_MyTailorIsRich", "\\NutritionMakesSense" }
    installNutritionFrame()
    local frameEnd = 100 + 14 + 13 + 77 + 8
    for _, icon in ipairs({ false, true }) do
        WEIGHT_ICON = icon
        local drawn = renderScreen()
        assertEq(select(2, drawn:gsub("%(L%)", "")), 1, "taille dessinée une seule fois")
        assertTrue(TEXT_X["(L)"] >= frameEnd, "après le cadre (" .. tostring(TEXT_X["(L)"]) .. ")")
    end
end

T["sans Nutrition Makes Sense : la taille reste collée au poids"] = function()
    renderScreen()
    assertEq(TEXT_X["(L)"], 110 + 14 + 2, "juste après la valeur")
end

return T
