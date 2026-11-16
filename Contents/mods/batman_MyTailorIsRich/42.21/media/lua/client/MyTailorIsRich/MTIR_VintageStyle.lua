-- ============================================================================
-- My Tailor Is Rich — style « album ancien » (client)
--
-- Palette et dessins partagés par les fenêtres au style vintage (album de
-- patrons) : couverture en cuir, couture pointillée, pages crème, photos
-- collées avec des coins photo, boutons en cuir clair. Toutes les longueurs
-- sont déjà mises à l'échelle par l'appelant (MTIR.UIScale) ; aucune taille de
-- police n'est supposée : les hauteurs se lisent sur la police dessinée.
-- ============================================================================

MTIR = MTIR or {}

local Style = {}
MTIR.VintageStyle = Style

--- Couleurs { r, g, b } (alpha à part).
Style.COLORS = {
    leather = { 0.24, 0.15, 0.10 },
    leatherDark = { 0.12, 0.08, 0.05 },
    stitch = { 0.86, 0.74, 0.52 },
    gold = { 0.93, 0.82, 0.58 },
    cream = { 0.92, 0.87, 0.75 },
    creamDim = { 0.78, 0.71, 0.58 },
    page = { 0.90, 0.85, 0.72 },
    photo = { 0.97, 0.95, 0.89 },
    ink = { 0.22, 0.14, 0.08 },
    inkDim = { 0.45, 0.34, 0.24 },
    worn = { 0.70, 0.22, 0.14 },
    selected = { 0.62, 0.20, 0.12 },
    button = { 0.42, 0.27, 0.16 },
    buttonOver = { 0.56, 0.37, 0.21 },
    field = { 0.15, 0.10, 0.07 },
}

local C = Style.COLORS

--- Police du titre : manuscrite si le jeu l'a, sinon moyenne.
Style.TITLE_FONT = UIFont.Handwritten or UIFont.Medium

local function rect(ui, x, y, w, h, color, alpha)
    ui:drawRect(x, y, w, h, alpha or 1, color[1], color[2], color[3])
end
Style.rect = rect

local function border(ui, x, y, w, h, color, alpha)
    ui:drawRectBorder(x, y, w, h, alpha or 1, color[1], color[2], color[3])
end
Style.border = border

--- Couture pointillée le long d'un rectangle (traits de `dash`, écarts de `gap`).
function Style.stitch(ui, x, y, w, h, dash, gap, thickness, color)
    color = color or C.stitch
    local step = dash + gap
    local along = x
    while along < x + w do
        local len = math.min(dash, x + w - along)
        rect(ui, along, y, len, thickness, color)
        rect(ui, along, y + h - thickness, len, thickness, color)
        along = along + step
    end
    along = y
    while along < y + h do
        local len = math.min(dash, y + h - along)
        rect(ui, x, along, thickness, len, color)
        rect(ui, x + w - thickness, along, thickness, len, color)
        along = along + step
    end
end

--- Couverture : cuir, bord sombre, couture à `inset` du bord.
function Style.cover(ui, w, h, s)
    rect(ui, 0, 0, w, h, C.leather)
    border(ui, 0, 0, w, h, C.leatherDark)
    border(ui, 1, 1, w - 2, h - 2, C.leatherDark, 0.6)
    Style.stitch(ui, s.seam, s.seam, w - s.seam * 2, h - s.seam * 2, s.dash, s.dashGap, s.thread)
end

--- Coins photo : un L sombre à chaque angle du rectangle.
local function photoCorners(ui, x, y, w, h, size, thickness)
    local c = C.leatherDark
    rect(ui, x, y, size, thickness, c)
    rect(ui, x, y, thickness, size, c)
    rect(ui, x + w - size, y, size, thickness, c)
    rect(ui, x + w - thickness, y, thickness, size, c)
    rect(ui, x, y + h - thickness, size, thickness, c)
    rect(ui, x, y + h - size, thickness, size, c)
    rect(ui, x + w - size, y + h - thickness, size, thickness, c)
    rect(ui, x + w - thickness, y + h - size, thickness, size, c)
end

--- Photo collée : ombre portée, tirage clair, coins photo ; `selected` l'encadre.
function Style.photo(ui, x, y, w, h, s, selected)
    rect(ui, x + s.shadow, y + s.shadow, w, h, { 0, 0, 0 }, 0.25)
    rect(ui, x, y, w, h, C.photo)
    border(ui, x, y, w, h, C.inkDim, 0.5)
    photoCorners(ui, x, y, w, h, s.corner, s.thread)
    if selected then
        border(ui, x - 1, y - 1, w + 2, h + 2, C.selected)
        border(ui, x - 2, y - 2, w + 4, h + 4, C.selected)
    end
end

local function colorTable(color, alpha)
    return { r = color[1], g = color[2], b = color[3], a = alpha or 1 }
end

--- Bouton en cuir clair, liseré doré, texte crème.
function Style.button(button)
    button.backgroundColor = colorTable(C.button)
    button.backgroundColorMouseOver = colorTable(C.buttonOver)
    button.borderColor = colorTable(C.gold, 0.8)
    button.textColor = colorTable(C.cream)
end

--- Champ de saisie sombre à liseré doré.
function Style.field(entry)
    entry.backgroundColor = colorTable(C.field, 0.9)
    entry.borderColor = colorTable(C.gold, 0.8)
end

--- Page crème (liste, case de dépôt).
function Style.page(panel)
    panel.backgroundColor = colorTable(C.page)
    panel.borderColor = colorTable(C.leatherDark)
end

return Style
