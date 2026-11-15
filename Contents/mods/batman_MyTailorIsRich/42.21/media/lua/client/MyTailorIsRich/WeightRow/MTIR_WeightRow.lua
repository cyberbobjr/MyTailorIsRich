-- ============================================================================
-- My Tailor Is Rich — voisins de la ligne du poids (écran Personnage)
--
-- D'autres mods écrivent ou cachent quelque chose sur la ligne du poids. Chacun
-- est décrit dans son propre fichier (WeightRow/MTIR_WeightRow<Mod>.lua) et
-- s'inscrit ici ; l'écran Personnage lit seulement la mise en page qui en
-- découle. Ajouter un voisin = ajouter un fichier, sans toucher à l'écran.
--
-- Un voisin : { modId = "IdDuMod",
--               hidesWeight = true,            -- le poids est caché : la taille aussi
--               occupiedWidth = function(font) -- pixels pris après la valeur du poids
--               end }
-- ============================================================================

MTIR = MTIR or {}
MTIR.WeightRow = MTIR.WeightRow or {}

local WeightRow = MTIR.WeightRow
WeightRow.neighbours = WeightRow.neighbours or {}

--- Inscrit un voisin ; une nouvelle inscription du même mod remplace l'ancienne.
function WeightRow.register(neighbour)
    WeightRow.neighbours[neighbour.modId] = neighbour
    WeightRow.activeCache = nil
end

--- Identifiants des mods actifs, sans la barre oblique inverse que B42 ajoute parfois.
local function activeModIds()
    local ids = {}
    local mods = getActivatedMods()
    for i = 0, mods:size() - 1 do
        ids[(string.gsub(tostring(mods:get(i)), "^\\", ""))] = true
    end
    return ids
end

--- Voisins dont le mod est actif. La liste des mods ne change pas en cours de partie.
local function activeNeighbours()
    if not WeightRow.activeCache then
        local ids = activeModIds()
        local active = {}
        for modId, neighbour in pairs(WeightRow.neighbours) do
            if ids[modId] then
                table.insert(active, neighbour)
            end
        end
        WeightRow.activeCache = active
    end
    return WeightRow.activeCache
end

--- Vrai si un mod actif cache le poids : la taille, qui en découle, est cachée aussi.
function WeightRow.isWeightHidden()
    for _, neighbour in ipairs(activeNeighbours()) do
        if neighbour.hidesWeight then
            return true
        end
    end
    return false
end

--- Largeur prise après la valeur du poids par les mods actifs, nil si aucun n'écrit
--- sur la ligne (la taille suit alors le poids ou la flèche vanilla).
function WeightRow.occupiedWidth(font)
    local widest = nil
    for _, neighbour in ipairs(activeNeighbours()) do
        if neighbour.occupiedWidth then
            local width = neighbour.occupiedWidth(font)
            if not widest or width > widest then
                widest = width
            end
        end
    end
    return widest
end

return WeightRow
