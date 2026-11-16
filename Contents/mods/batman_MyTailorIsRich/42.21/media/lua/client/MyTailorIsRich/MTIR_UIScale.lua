-- ============================================================================
-- My Tailor Is Rich — échelle des fenêtres (client)
--
-- Même méthode que Live Wire (LW_UIScale.lua, C27) : les fenêtres sont dessinées
-- en pixels pour la police de référence 1080p (UIFont.Small haute de 19 px, la
-- référence des fenêtres vanilla de construction, ISWidgetBuildControl.lua:7).
-- Avec une plus grande taille de police (écrans 4K), tailles, marges et boutons
-- grandissent du même facteur, jamais sous 1, et la fenêtre reste dans l'écran.
-- Calculé à l'ouverture d'une fenêtre, jamais à chaque image : le réglage de
-- police ne s'applique qu'après un redémarrage.
-- ============================================================================

MTIR = MTIR or {}

local Scale = {}
MTIR.UIScale = Scale

Scale.REF_FONT_H = 19
--- Place laissée libre autour d'une fenêtre, au bord de l'écran.
Scale.MARGIN = 16

local function screen()
    local core = getCore()
    return core:getScreenWidth(), core:getScreenHeight()
end

--- Hauteur de la petite police rapportée à la référence, au moins 1.
function Scale.fontScale()
    local height = tonumber(getTextManager():getFontHeight(UIFont.Small)) or Scale.REF_FONT_H
    return math.max(1, height / Scale.REF_FONT_H)
end

--- Facteur d'une fenêtre conçue en baseW × baseH : celui de la police, multiplié par
--- l'agrandissement choisi par le joueur (`zoom`, facultatif, au moins 1), abaissé
--- pour que la fenêtre agrandie tienne à l'écran, jamais sous 1.
function Scale.factor(baseW, baseH, zoom)
    local k = Scale.fontScale() * math.max(1, tonumber(zoom) or 1)
    local screenW, screenH = screen()
    if baseW and baseW > 0 then
        k = math.min(k, (screenW - 2 * Scale.MARGIN) / baseW)
    end
    if baseH and baseH > 0 then
        k = math.min(k, (screenH - 2 * Scale.MARGIN) / baseH)
    end
    return math.max(1, k)
end

function Scale.px(value, k)
    return math.floor(value * k + 0.5)
end

--- Copie mise à l'échelle d'une table de tailles de référence ; `k` y est gardé.
function Scale.layout(k, base)
    local scaled = { k = k }
    for name, value in pairs(base) do
        scaled[name] = Scale.px(value, k)
    end
    return scaled
end

--- Taille bornée à l'écran, puis position ramenée pour que toute la fenêtre soit
--- visible. Rend x, y, w, h.
function Scale.fit(x, y, w, h)
    local screenW, screenH = screen()
    w = math.min(w, screenW)
    h = math.min(h, screenH)
    x = math.max(0, math.min(x, screenW - w))
    y = math.max(0, math.min(y, screenH - h))
    return math.floor(x), math.floor(y), math.floor(w), math.floor(h)
end

return Scale
