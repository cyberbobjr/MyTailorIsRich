-- ============================================================================
-- My Tailor Is Rich — broderie d'un nom (logique partagée)
--
-- Le client saisit un texte court et compose le nom de l'objet dans sa langue
-- (« Veste « Bob » ») ; l'autorité revérifie tout (texte nettoyé, longueur,
-- nom qui contient le texte) puis renomme l'objet comme le jeu : setName puis
-- setCustomName(true), transmis au propriétaire par syncItemFields.
-- La broderie est notée dans la ModData de l'objet (clé distincte des tailles)
-- avec, si l'objet portait déjà un nom personnalisé, ce nom à rétablir.
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"
require "MyTailorIsRich/MTIR_Sizing"
require "MyTailorIsRich/MTIR_Shoes"

MTIR.EMBROIDERY_KEY = "MTIR_Embroidery"
-- Longueur du texte brodé (unités UTF-16 en jeu ; le vanilla limite un renommage à 28).
MTIR.EMBROIDERY_MAX_CHARS = 24
-- Longueur du nom complet composé par le client.
MTIR.EMBROIDERY_NAME_MAX = 64
MTIR.EMBROIDERY_LEVEL = 1
MTIR.EMBROIDERY_THREAD = 1

function MTIR.isEmbroideryEnabled()
    return MTIR.opt("EnableEmbroidery") ~= false
end

--- Vêtement en tissu : taillé (vêtements de mods compris), tissu déclaré ou
--- teignable selon le jeu. Les chaussures et les protections rigides sans tissu
--- sont exclues.
function MTIR.canEmbroider(item)
    if not item or not instanceof(item, "Clothing") or item:isBroken() then
        return false
    end
    if MTIR.getSizingKind(item) == "shoe" then
        return false
    end
    return MTIR.canClothesHaveSize(item) or MTIR.getClothesFabricType(item) ~= nil
        or item:hasTag(ItemTag.CAN_BE_DYED) == true
end

--- Lecture seule : { text, prevName } ou nil.
function MTIR.getEmbroidery(item)
    if not item or not item:hasModData() then
        return nil
    end
    local data = item:getModData()[MTIR.EMBROIDERY_KEY]
    if type(data) ~= "table" or type(data.text) ~= "string" then
        return nil
    end
    return data
end

local function trim(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

--- Retire caractères de contrôle, balises de texte riche (< >) et %, réduit les
--- espaces. Rend le texte propre, ou nil s'il est vide ou trop long (jamais tronqué).
function MTIR.cleanEmbroideryText(text, maxChars)
    if type(text) ~= "string" then
        return nil
    end
    -- Blancs (tabulations, retours) d'abord changés en espaces, puis le reste retiré.
    local cleaned = string.gsub(text, "%s+", " ")
    cleaned = trim(string.gsub(cleaned, "[%c<>%%]", ""))
    cleaned = string.gsub(cleaned, "  +", " ")
    if cleaned == "" or #cleaned > (maxChars or MTIR.EMBROIDERY_MAX_CHARS) then
        return nil
    end
    return cleaned
end

--- Autorité : le texte brodé et le nom composé par le client sont acceptables.
function MTIR.isValidEmbroidery(text, name)
    local cleanText = MTIR.cleanEmbroideryText(text, MTIR.EMBROIDERY_MAX_CHARS)
    if not cleanText or cleanText ~= text then
        return false
    end
    local cleanName = MTIR.cleanEmbroideryText(name, MTIR.EMBROIDERY_NAME_MAX)
    if not cleanName or cleanName ~= name then
        return false
    end
    return string.find(name, text, 1, true) ~= nil
end

function MTIR.getEmbroideryRequiredLevel()
    if not MTIR.opt("NeedTailoringLevel") then
        return 0
    end
    return MTIR.EMBROIDERY_LEVEL
end

--- Un peu plus long pour un texte long.
function MTIR.getEmbroideryDuration(text)
    local length = type(text) == "string" and #text or 0
    return math.max(1, (80 + 10 * math.min(length, MTIR.EMBROIDERY_MAX_CHARS)) * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getUnpickDuration()
    return math.max(1, 60 * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR.getEmbroideryXp()
    return 2.5 * MTIR.opt("TailoringXpMultiplier")
end

--- Autorité : brode `text` et renomme l'objet `name`. Mémorise un nom personnalisé
--- antérieur pour le rétablir au décousage.
function MTIR.applyEmbroidery(item, text, name)
    local data = { text = text }
    if item:isCustomName() then
        data.prevName = item:getDisplayName()
    end
    item:setName(name)
    item:setCustomName(true)
    item:getModData()[MTIR.EMBROIDERY_KEY] = data
end

--- Autorité (et client du propriétaire pour l'affichage) : retire la broderie et
--- rétablit le nom antérieur, ou le nom du script dans la langue de la machine.
function MTIR.restoreEmbroideredName(item, prevName)
    if type(prevName) == "string" and prevName ~= "" then
        item:setName(prevName)
        item:setCustomName(true)
    else
        item:setName(item:getScriptItem():getDisplayName())
        item:setCustomName(false)
        -- setCustomName recopie le nom dans la ModData : sans objet ici.
        item:getModData().customName = nil
    end
end

function MTIR.removeEmbroidery(item)
    local data = MTIR.getEmbroidery(item)
    local prevName = data and data.prevName or nil
    item:getModData()[MTIR.EMBROIDERY_KEY] = nil
    MTIR.restoreEmbroideredName(item, prevName)
    return prevName
end

return MTIR
