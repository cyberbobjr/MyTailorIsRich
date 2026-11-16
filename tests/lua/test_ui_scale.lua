-- MTIR_UIScale : un facteur d'échelle pour les fenêtres du mod (même méthode que
-- LiveWire LW_UIScale) : hauteur de la petite police comparée à la référence 1080p
-- (19 px), jamais sous 1, abaissé pour que la fenêtre tienne à l'écran.

local T = {}

local FONT_H, SCREEN_W, SCREEN_H

function T.setup()
    FONT_H, SCREEN_W, SCREEN_H = 19, 1920, 1080
    UIFont = { Small = "Small" }
    isServer = function() return false end
    getTextManager = function()
        return { getFontHeight = function() return FONT_H end }
    end
    getCore = function()
        return {
            getScreenWidth = function() return SCREEN_W end,
            getScreenHeight = function() return SCREEN_H end,
        }
    end
    MTIR = {}
    loadMod("client/MyTailorIsRich/MTIR_UIScale.lua")
end

T["police de référence : facteur 1, tailles d'origine"] = function()
    local k = MTIR.UIScale.factor(800, 500)
    assertEq(k, 1, "1080p, police 19 px")
    local L = MTIR.UIScale.layout(k, { pad = 10, cell = 104 })
    assertEq(L.pad, 10, "marge inchangée")
    assertEq(L.cell, 104, "case inchangée")
end

T["grande police (4K) : tout grandit du même facteur"] = function()
    FONT_H, SCREEN_W, SCREEN_H = 38, 3840, 2160
    local k = MTIR.UIScale.factor(800, 500)
    assertEq(k, 2, "police deux fois plus haute")
    assertEq(MTIR.UIScale.layout(k, { pad = 10 }).pad, 20, "marge doublée")
end

T["facteur abaissé pour tenir dans l'écran, jamais sous 1"] = function()
    FONT_H, SCREEN_W, SCREEN_H = 38, 1280, 720
    local k = MTIR.UIScale.factor(800, 500)
    assertTrue(k < 2 and k >= 1, "plafonné par l'écran : " .. tostring(k))
    assertEq(math.floor(500 * k) <= 720 - 2 * MTIR.UIScale.MARGIN, true, "la hauteur tient")
    FONT_H = 12
    assertEq(MTIR.UIScale.factor(800, 500), 1, "petite police : jamais sous 1")
end

T["agrandissement choisi par le joueur : multiplie la police, borné à l'écran"] = function()
    assertEq(MTIR.UIScale.factor(800, 500, 1.5), 1.5, "1080p : une fois et demie")
    FONT_H, SCREEN_W, SCREEN_H = 38, 3840, 2160
    assertEq(MTIR.UIScale.factor(800, 500, 1.25), 2.5, "4K : la police puis l'agrandissement")
    local k = MTIR.UIScale.factor(800, 500, 10)
    assertEq(math.floor(800 * k) <= 3840 - 2 * MTIR.UIScale.MARGIN, true, "jamais plus large que l'écran")
    assertEq(MTIR.UIScale.factor(800, 500, 0.2), 2, "jamais plus petit que la taille d'origine")
end

T["fenêtre ramenée dans l'écran"] = function()
    local x, y, w, h = MTIR.UIScale.fit(1800, -40, 400, 300)
    assertEq(x, 1520, "bord droit")
    assertEq(y, 0, "bord haut")
    assertEq(w, 400, "largeur gardée")
    assertEq(h, 300, "hauteur gardée")
end

return T
