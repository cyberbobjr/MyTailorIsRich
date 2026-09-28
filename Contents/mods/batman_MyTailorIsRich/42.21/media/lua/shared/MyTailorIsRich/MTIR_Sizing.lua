-- ============================================================================
-- My Tailor Is Rich — quels vêtements ont une taille (vanilla et mods)
--
-- Ordre de décision, par type d'objet (résultat mis en cache) :
--   1. cosmétique (maquillage, cheveux, blessures) ou exclu par l'option : aucune taille ;
--   2. emplacement « shoes » : pointure ; emplacement vêtement connu : profil connu ;
--   3. cité dans ListCustomClothes ou emplacement cité dans ExtraSizedLocations :
--      taille, profil déduit de ce qu'il couvre, difficulté donnée ;
--   4. emplacement d'accessoire (chapeau, masque, gants, bijoux, ceinture...) : aucune taille ;
--   5. tout autre vêtement, y compris un emplacement créé par un mod : déduit des
--      parties du corps qu'il couvre (BloodLocation du script) :
--      torse + bassin/cuisses -> tenue complète ; torse ou deux bras -> haut ;
--      bassin ou deux cuisses -> bas ; pieds seuls -> chaussure ; sinon rien.
-- Les profils déduits n'ont pas l'effet « le vêtement tombe » (réservé aux vrais
-- pantalons et jupes) : une pièce d'armure de cuisse ne doit pas glisser.
-- ============================================================================

require "MyTailorIsRich/MTIR_Core"

local ACCESSORY_LOCATIONS = {
    hat = true, fullhat = true, headextra = true, headextrahair = true,
    mask = true, maskeyes = true, maskfull = true, face = true,
    eyes = true, lefteye = true, righteye = true, ears = true, eartop = true, nose = true,
    neck = true, neckextra = true, neck_texture = true, necklace = true, necklace_long = true,
    scarf = true, belt = true, beltextra = true, back = true,
    hands = true, handsleft = true, handsright = true,
    ammostrap = true, gorget = true, scba = true, scbanotank = true,
    shoulderpadleft = true, shoulderpadright = true,
    sportshoulderpad = true, sportshoulderpadontop = true, codpiece = true,
    wound = true, zeddmg = true, bandage = true, bellybutton = true, tail = true, socks = true,
    -- Sous-vêtements : hors gestion des tailles (forçables via ExtraSizedLocations).
    underwear = true, underweartop = true, underwearbottom = true,
    underwearextra1 = true, underwearextra2 = true,
}
local ACCESSORY_PATTERNS = { "makeup", "finger", "wrist", "holster", "sheath", "patch" }

local function profile(fields)
    local result = {
        canRip = true, canDrop = false, insulationMod = true,
        combatMod = false, incTrip = false, incStiffness = true, difficulty = 1,
    }
    for key, value in pairs(fields) do
        result[key] = value
    end
    return result
end

local DEDUCED = {
    top = profile({ combatMod = true, difficulty = 2 }),
    bottom = profile({ incTrip = true, difficulty = 1 }),
    full = profile({ combatMod = true, incTrip = true, difficulty = 3 }),
    -- Rien de déclaré : seulement la taille, sans effet de zone.
    plain = profile({ canRip = false, insulationMod = false, incStiffness = false, difficulty = 1 }),
}

local function withDifficulty(base, difficulty)
    local result = {}
    for key, value in pairs(base) do
        result[key] = value
    end
    result.difficulty = difficulty
    return result
end

local function isAccessoryLocation(key)
    if ACCESSORY_LOCATIONS[key] then
        return true
    end
    for _, pattern in ipairs(ACCESSORY_PATTERNS) do
        if string.find(key, pattern, 1, true) then
            return true
        end
    end
    return false
end

-- ----------------------------------------------------------------------------
-- Options texte
-- ----------------------------------------------------------------------------

--- "a,b:2" ou "a;b:2" -> { a = 1, b = 2 } (clés en minuscules si lowerKeys).
--- « ; » est accepté car une virgule termine la valeur par défaut dans sandbox-options.txt.
local function parseList(raw, lowerKeys)
    local result = {}
    local normalized = string.gsub(raw or "", ";", ",")
    for _, entry in ipairs(luautils.split(normalized, ",")) do
        local parts = luautils.split(luautils.trim(entry), ":")
        local name = luautils.trim(parts[1] or "")
        if name ~= "" then
            local difficulty = tonumber(parts[2] and luautils.trim(parts[2]) or "") or 1
            difficulty = math.max(1, math.min(3, math.floor(difficulty)))
            result[lowerKeys and string.lower(name) or name] = difficulty
        end
    end
    return result
end

local cache = {}
local seenOptions = {}
local excluded = {}
local extraLocations = {}

--- Vide le cache si une option texte a changé (admin, chargement d'une partie).
local function refreshOptions()
    local custom = MTIR.opt("ListCustomClothes")
    local excludedRaw = MTIR.opt("ListExcludedClothes")
    local extraRaw = MTIR.opt("ExtraSizedLocations")
    if seenOptions.custom == custom and seenOptions.excluded == excludedRaw and seenOptions.extra == extraRaw then
        return
    end
    seenOptions = { custom = custom, excluded = excludedRaw, extra = extraRaw }
    excluded = parseList(excludedRaw, false)
    extraLocations = parseList(extraRaw, true)
    cache = {}
end

-- ----------------------------------------------------------------------------
-- Déduction d'après les parties couvertes
-- ----------------------------------------------------------------------------

local function coveredParts(scriptItem)
    local types = scriptItem:getBloodClothingType()
    if not types or types:isEmpty() then
        return nil
    end
    local parts = BloodClothingType.getCoveredParts(types)
    local set = {}
    for i = 0, parts:size() - 1 do
        set[parts:get(i)] = true
    end
    return set
end

local function coverageProfile(parts)
    if not parts then
        return nil
    end
    local B = BloodBodyPartType
    local torso = parts[B.Torso_Upper] or parts[B.Torso_Lower]
    local arms = parts[B.UpperArm_L] and parts[B.UpperArm_R]
    local bottom = parts[B.Groin] or (parts[B.UpperLeg_L] and parts[B.UpperLeg_R])
    if torso and bottom then
        return "full"
    end
    if torso or arms then
        return "top"
    end
    if bottom then
        return "bottom"
    end
    -- Pas de next() dans Kahlua (BaseLib 42.21) : on compte.
    local feet, others = 0, 0
    for part in pairs(parts) do
        if part == B.Foot_L or part == B.Foot_R then
            feet = feet + 1
        else
            others = others + 1
        end
    end
    return (feet > 0 and others == 0) and "shoe" or nil
end

local function sizedAs(kind, slot)
    if kind == "shoe" then
        return { kind = "shoe" }
    end
    return { kind = "clothes", slot = slot }
end

local function resolve(scriptItem)
    if scriptItem:getItemType() ~= ItemType.CLOTHING or scriptItem:isCosmetic() then
        return false
    end
    local fullType = scriptItem:getFullName()
    if excluded[fullType] then
        return false
    end
    local key = MTIR.locKey(scriptItem)
    if key == "shoes" then
        return sizedAs("shoe")
    end
    if key and MTIR.CLOTHES_SLOTS[key] then
        return sizedAs("clothes", MTIR.CLOTHES_SLOTS[key])
    end

    local deduced = coverageProfile(coveredParts(scriptItem))
    local forced = MTIR.getCustomClothes()[fullType] or (key and extraLocations[key])
    if forced then
        if deduced == "shoe" then
            return sizedAs("shoe")
        end
        return sizedAs("clothes", withDifficulty(DEDUCED[deduced or "plain"], forced))
    end

    if not key or isAccessoryLocation(key) or not deduced then
        return false
    end
    if deduced == "shoe" then
        return sizedAs("shoe")
    end
    return sizedAs("clothes", DEDUCED[deduced])
end

-- ----------------------------------------------------------------------------
-- API
-- ----------------------------------------------------------------------------

--- { kind = "clothes", slot } ou { kind = "shoe" } ; nil si pas de taille.
--- source : InventoryItem ou script Item (sortie de recette).
function MTIR.getSizing(source)
    if not source then
        return nil
    end
    local scriptItem = instanceof(source, "InventoryItem") and source:getScriptItem() or source
    if not scriptItem then
        return nil
    end
    refreshOptions()
    local fullType = scriptItem:getFullName()
    local result = cache[fullType]
    if result == nil then
        result = resolve(scriptItem)
        cache[fullType] = result
    end
    return result or nil
end

function MTIR.getSizingKind(source)
    local sizing = MTIR.getSizing(source)
    return sizing and sizing.kind or nil
end

--- Profil d'effets du vêtement (nil pour une chaussure ou sans taille).
function MTIR.getSlot(item)
    local sizing = MTIR.getSizing(item)
    return sizing and sizing.slot or nil
end

function MTIR.canClothesHaveSize(item)
    if not item or not instanceof(item, "Clothing") then
        return false
    end
    return MTIR.getSizingKind(item) == "clothes"
end

--- Même test pour un script Item (sortie de recette).
function MTIR.canOutputHaveSize(scriptItem)
    return MTIR.getSizingKind(scriptItem) == "clothes"
end

return MTIR
