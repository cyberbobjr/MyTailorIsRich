-- ============================================================================
-- My Tailor Is Rich — teinture des vêtements (logique partagée)
--
-- Ce que le moteur 42.21 permet (voir .claude/pz-knowledge, teinte des vêtements) :
--   * le rendu multiplie la texture du vêtement par une couleur (ItemVisual.getTint) ;
--   * sans m_AllowRandomTint dans le clothingItem, la teinte du visuel est remise
--     à blanc et les autres joueurs ne voient jamais de couleur (SyncClothing ne
--     transmet que la teinte du visuel) : on ne propose donc la teinture qu'aux
--     vêtements teintables, qu'ils viennent du jeu ou d'un mod ;
--   * le tag vanilla base:canbedyed (recette « Dye Clothes ») ajoute quelques
--     vêtements blancs non teintables : couleur visible par leur porteur seulement
--     en MP, comme avec la recette vanilla.
-- On applique la couleur comme la recette vanilla (RecipeCodeHelper.setColor) :
-- couleur d'objet personnalisée (sauvegardée, transmise par syncItemFields) ET
-- teinte du visuel (sauvegardée, transmise aux autres joueurs à l'enfilage).
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"
require "MyTailorIsRich/MTIR_Sizing"

-- Teintures acceptées : fluide vanilla, catégorie qui garantit un contenu pur
-- (ces fluides ne se mélangent qu'entre teintures), litres par unité de volume.
-- Colorant industriel : 0,2 L par vêtement dans la recette vanilla (bouteille de 2 L).
-- Teinture pour cheveux : 0,5 L par teinture de cheveux (bouteille de 1 L).
MTIR.DYE_KINDS = {
    { fluid = "Dye", category = "Dyes", litres = 0.2 },
    { fluid = "HairDye", category = "HairDyes", litres = 0.25 },
}

-- Eau du bain de teinture, par unité de volume (la recette vanilla demande 10 L).
MTIR.DYE_WATER_LITRES = 2
-- Marge des comparaisons de volumes (flottants).
local EPSILON = 0.0001

function MTIR.isDyeingEnabled()
    return MTIR.opt("EnableDyeing") ~= false
end

--- Vrai si le rendu affichera une teinte : clothingItem teintable (m_AllowRandomTint),
--- ou vêtement marqué teignable par le jeu (tag base:canbedyed).
function MTIR.canTintClothing(item)
    if not item or not instanceof(item, "Clothing") then
        return false
    end
    if item:allowRandomTint() then
        return true
    end
    return item:hasTag(ItemTag.CAN_BE_DYED) == true
end

--- Volume relatif du vêtement (1 à 3) : difficulté d'un vêtement taillé, 1 sinon
--- (accessoires, chaussures).
function MTIR.getDyeBulk(item)
    local slot = MTIR.getSlot(item)
    local difficulty = slot and slot.difficulty or 1
    return math.max(1, math.min(3, difficulty))
end

local function fluidContainer(container)
    local fc = container and container.getFluidContainer and container:getFluidContainer() or nil
    if not fc or fc:isEmpty() then
        return nil
    end
    return fc
end

--- Sorte de teinture contenue (entrée de MTIR.DYE_KINDS), ou nil.
function MTIR.getDyeKind(container)
    local fc = fluidContainer(container)
    if not fc then
        return nil
    end
    for _, kind in ipairs(MTIR.DYE_KINDS) do
        if fc:contains(Fluid[kind.fluid]) and fc:isAllCategory(FluidCategory[kind.category]) then
            return kind
        end
    end
    return nil
end

function MTIR.getDyeLitres(item, kind)
    return kind.litres * MTIR.getDyeBulk(item)
end

function MTIR.getDyeWaterLitres(item)
    return MTIR.DYE_WATER_LITRES * MTIR.getDyeBulk(item)
end

--- Litres contenus (0 si vide ou sans récipient).
function MTIR.getFluidLitres(container)
    local fc = fluidContainer(container)
    return fc and fc:getAmount() or 0
end

--- Récipient qui ne contient que de l'eau (potable ou non).
function MTIR.isWaterContainer(container)
    local fc = fluidContainer(container)
    return fc ~= nil and fc:isAllCategory(FluidCategory.Water)
end

--- Couleur d'une teinture : celle du mélange, comme la teinture des cheveux vanilla.
function MTIR.getDyeColor(container)
    local color = container:getFluidContainer():getColor()
    return color:getR(), color:getG(), color:getB()
end

local function enough(amount, needed)
    return amount + EPSILON >= needed
end

--- Autorité et client : contrôle complet d'un bain de teinture, sans la possession
--- (vérifiée à part). Rend la sorte de teinture si tout est bon, sinon nil.
function MTIR.checkDyeBath(item, dye, water)
    if not MTIR.isDyeingEnabled() or not MTIR.canTintClothing(item) or item:isEquipped() then
        return nil
    end
    if not dye or not water or dye:getID() == water:getID() then
        return nil
    end
    local kind = MTIR.getDyeKind(dye)
    if not kind or not enough(MTIR.getFluidLitres(dye), MTIR.getDyeLitres(item, kind)) then
        return nil
    end
    if not MTIR.isWaterContainer(water) or not enough(MTIR.getFluidLitres(water), MTIR.getDyeWaterLitres(item)) then
        return nil
    end
    return kind
end

local function clamp01(value)
    return math.max(0, math.min(1, tonumber(value) or 1))
end

--- Autorité : couleur appliquée comme la recette vanilla (RecipeCodeHelper.setColor).
function MTIR.applyDyeColor(item, r, g, b)
    r, g, b = clamp01(r), clamp01(g), clamp01(b)
    item:setColorRed(r)
    item:setColorGreen(g)
    item:setColorBlue(b)
    item:setColor(Color.new(r, g, b, 1))
    item:setCustomColor(true)
    local visual = item:getVisual()
    if visual then
        visual:setTint(ImmutableColor.new(r, g, b, 1))
    end
end

--- Autorité : retire `litres` d'un récipient (adjustAmount fixe la quantité totale).
function MTIR.drainFluid(container, litres)
    local fc = container:getFluidContainer()
    fc:adjustAmount(math.max(0, fc:getAmount() - litres))
end

function MTIR.getDyeDuration(item)
    return math.max(1, (100 + 50 * MTIR.getDyeBulk(item)) * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getDyeXp(item)
    return 2 * MTIR.getDyeBulk(item) * MTIR.opt("TailoringXpMultiplier")
end

-- ----------------------------------------------------------------------------
-- Nom approché d'une couleur (menu : « Colorant industriel (rouge) »)
-- ----------------------------------------------------------------------------

--- Teinte (0-360), saturation et valeur (0-1).
local function toHsv(r, g, b)
    local maxC = math.max(r, g, b)
    local minC = math.min(r, g, b)
    local delta = maxC - minC
    local hue = 0
    if delta > 0 then
        if maxC == r then
            -- Pas de `%` : il tronque vers zéro dans Kahlua (résultat négatif).
            hue = 60 * ((g - b) / delta)
            if hue < 0 then
                hue = hue + 360
            end
        elseif maxC == g then
            hue = 60 * ((b - r) / delta + 2)
        else
            hue = 60 * ((r - g) / delta + 4)
        end
    end
    local saturation = maxC > 0 and delta / maxC or 0
    return hue, saturation, maxC
end

local function warmColorName(hue, saturation, value)
    if value < 0.6 then
        return "Brown"
    end
    if saturation < 0.6 then
        return "Beige"
    end
    return hue < 40 and "Orange" or "Yellow"
end

local function hueColorName(hue, saturation, value)
    if hue < 15 or hue >= 345 then
        return (saturation < 0.5 and value > 0.6) and "Pink" or "Red"
    end
    if hue < 70 then
        return warmColorName(hue, saturation, value)
    end
    if hue < 165 then
        return "Green"
    end
    if hue < 200 then
        return "Cyan"
    end
    if hue < 260 then
        return "Blue"
    end
    if hue < 290 then
        return "Purple"
    end
    -- 290-345 : magenta et rose vif.
    return value < 0.5 and "Purple" or "Pink"
end

--- Suffixe de clé IGUI_MTIR_Color_* le plus proche d'une couleur.
function MTIR.getColorNameKey(r, g, b)
    local hue, saturation, value = toHsv(clamp01(r), clamp01(g), clamp01(b))
    if value < 0.13 then
        return "Black"
    end
    if saturation < 0.18 or (saturation < 0.3 and value < 0.35) then
        if value >= 0.75 then
            return "White"
        end
        return value < 0.25 and "Black" or "Grey"
    end
    return hueColorName(hue, saturation, value)
end

function MTIR.getColorName(r, g, b)
    return getText("IGUI_MTIR_Color_" .. MTIR.getColorNameKey(r, g, b))
end

return MTIR
