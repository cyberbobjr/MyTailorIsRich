-- ============================================================================
-- My Tailor Is Rich — ligne d'infobulle via TooltipLib (prérequis)
-- Remplace le hook ISToolTipInv.render d'origine : TooltipLib mesure et
-- dessine la ligne avec le reste de l'infobulle, sans conflit.
-- Gauche : taille (ou indice) ; droite : usure estimée du vêtement porté.
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Patterns"
require "TooltipLib/Core"

if not TooltipLib or type(TooltipLib.registerProvider) ~= "function" then
    print("[MTIR] TooltipLib absent : pas de ligne de taille dans les infobulles")
    return
end

local WHITE = { 1, 1, 1, 1 }
local UNCHOSEN = { 0.9, 0.8, 0.4, 1 }

local DEGRADE_BUCKETS = {
    { limit = 0.2, key = "IGUI_MTIR_RapidDegrading" },
    { limit = 0.4, key = "IGUI_MTIR_FastDegrading" },
    { limit = 0.6, key = "IGUI_MTIR_NormallyDegrading" },
    { limit = 0.8, key = "IGUI_MTIR_SlowlyDegrading" },
}

local function shoeLine(item, player)
    local data = MTIR.getShoeData(item)
    if not data or not data.size then
        return "???", WHITE
    end
    local diff = MTIR.getShoeDiff(item, MTIR.getPlayerShoeSize(player))
    if data.reveal then
        return getText("IGUI_MTIR_ShoeSize", tostring(data.size)) .. " " .. MTIR.getShoeHintText(diff), WHITE
    end
    if data.hint then
        return MTIR.getShoeHintText(diff), WHITE
    end
    return "???", WHITE
end

local function sizeLine(item, player)
    if MTIR.canShoeHaveSize(item) then
        return shoeLine(item, player)
    end
    if not MTIR.canClothesHaveSize(item) then
        return nil
    end
    local data = MTIR.getData(item)
    if not data then
        return "???", WHITE
    end
    if not data.size then
        return getText("IGUI_MTIR_Say_Unchosen_Clothes_Size"), UNCHOSEN
    end
    local clothesSize = MTIR.getClothesSizeFromName(data.size)
    local diff = MTIR.getSizeDiff(clothesSize, MTIR.getPlayerSize(player))
    if data.reveal then
        return clothesSize.name .. (data.resized ~= 0 and "*" or "") .. " " .. MTIR.getHintText(diff), WHITE
    end
    if data.hint then
        return MTIR.getHintText(diff), WHITE
    end
    return "???", WHITE
end

local function degradeText(item, player, days, maintained)
    if player:getPerkLevel(Perks.Tailoring) >= MTIR.getRequiredLevelToRecondition(item) then
        return getText("IGUI_MTIR_DaysRemaining", tostring(math.ceil(days)))
    end
    for _, bucket in ipairs(DEGRADE_BUCKETS) do
        if maintained < bucket.limit then
            return getText(bucket.key)
        end
    end
    return getText("IGUI_MTIR_BarelyDegrading")
end

local function degradeLine(item, player)
    if not MTIR.canClothesDegrade(item) or not player:isEquippedClothing(item) then
        return nil
    end
    local params = MTIR.getDegradeParams()
    if params.minDays >= params.maxDays then
        return nil
    end
    local chance = MTIR.DegradingChance[item:getID()] or MTIR.calcDegradeChance(item, player)
    if not chance or chance <= 0 then
        return nil
    end
    local days = 1 / chance / 24 * item:getCondition()
    local maintained = (days - params.minDays) / (params.maxDays - params.minDays)
    local color = ColorInfo.new(0, 0, 0, 1)
    getCore():getBadHighlitedColor():interp(getCore():getGoodHighlitedColor(), math.max(0, math.min(1, maintained)), color)
    return degradeText(item, player, days, maintained), { color:getR(), color:getG(), color:getB(), 1 }
end

TooltipLib.registerProvider({
    id = "MTIR_Clothing",
    target = "item",
    description = "IGUI_MTIR_TooltipProvider",
    enabled = function(item)
        return instanceof(item, "Clothing")
            and (MTIR.canClothesHaveSize(item) or MTIR.canShoeHaveSize(item) or MTIR.canClothesDegrade(item))
    end,
    callback = function(ctx)
        local player = ctx.player or getPlayer()
        local item = ctx.item
        if not player or not item then
            return
        end
        local sizeText, sizeColor = sizeLine(item, player)
        local wearText, wearColor = degradeLine(item, player)
        if sizeText and wearText then
            ctx:addKeyValue(sizeText, wearText, sizeColor, wearColor)
        elseif sizeText then
            ctx:addLabel(sizeText, sizeColor)
        elseif wearText then
            ctx:addLabel(wearText, wearColor)
        end
    end,
})

-- Patron tracé : modèle, utilisations restantes, précision du traceur.
local PATTERN_WORN = { 0.9, 0.5, 0.4, 1 }

TooltipLib.registerProvider({
    id = "MTIR_Pattern",
    target = "item",
    description = "IGUI_MTIR_TooltipProviderPattern",
    enabled = function(item)
        return MTIR.isPattern(item)
    end,
    callback = function(ctx)
        local data = MTIR.getPatternData(ctx.item)
        if not data then
            return
        end
        ctx:addLabel(getItemNameFromFullType(data.fullType), WHITE)
        local uses = data.uses or 0
        ctx:addKeyValue(getText("IGUI_MTIR_Pattern_Uses"), uses .. "/" .. MTIR.opt("PatternMaxUses"),
            WHITE, uses > 1 and WHITE or PATTERN_WORN)
        ctx:addKeyValue(getText("IGUI_MTIR_Pattern_Precision"), tostring(data.precision or 0), WHITE, WHITE)
        -- Copie d'un patron (MTIR_PatternCopy.lua) : 1 = copie de l'original, 2 = copie de copie…
        if (tonumber(data.copies) or 0) > 0 then
            ctx:addKeyValue(getText("IGUI_MTIR_Pattern_CopyGeneration"), tostring(data.copies), WHITE, WHITE)
        end
        ctx:addKeyValue(getText("IGUI_MTIR_Pattern_Level"), tostring(MTIR.getRequiredLevelToSew(data)), WHITE, WHITE)
    end,
})
