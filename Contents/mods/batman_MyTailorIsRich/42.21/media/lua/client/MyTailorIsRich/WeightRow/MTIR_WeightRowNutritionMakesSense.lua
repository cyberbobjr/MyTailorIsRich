-- Nutrition Makes Sense (Workshop 3690404044, 2.0.2) : après le rendu vanilla, il
-- peint un cadre plein à la place de la flèche du poids et y écrit la variation
-- (« -0.35 kg/wk »). Le cadre commence 3 pixels après la valeur du poids
-- (xOffset + largeur + 13, la valeur étant à xOffset + 10) et mesure
-- « +0.00 kg/wk » + 8 pixels (NutritionMakesSense_WeightDisplayHook.lua l.31-35).
-- Peint après notre taille, il l'effacerait : la taille se place au-delà.

require "MyTailorIsRich/WeightRow/MTIR_WeightRow"

local FRAME_OFFSET = 3
local FRAME_PADDING = 8
local FRAME_SAMPLE = "+0.00 kg/wk"

MTIR.WeightRow.register({
    modId = "NutritionMakesSense",
    -- Leur cadre est toujours mesuré en petite police, quelle que soit la nôtre.
    occupiedWidth = function()
        return FRAME_OFFSET + getTextManager():MeasureStringX(UIFont.Small, FRAME_SAMPLE) + FRAME_PADDING
    end,
})
