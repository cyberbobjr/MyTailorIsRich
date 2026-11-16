-- MTIR_PatternAlbum : fiches de l'album (patrons isolés et rangés), catégorie
-- déduite du vêtement, recherche par nom, catégorie et matériau, tri par nom.

local T = {}

local LABELS = {
    IGUI_MTIR_Album_Cat_Top = "Top",
    IGUI_MTIR_Album_Cat_Bottom = "Bottom",
    IGUI_MTIR_Album_Cat_Full = "Full outfit",
    IGUI_MTIR_Album_Cat_Glove = "Gloves",
    IGUI_MTIR_Album_Cat_Shoe = "Shoes",
    IGUI_MTIR_Album_Cat_Other = "Other",
    IGUI_MTIR_Album_Fabric_Cotton = "Cotton",
    IGUI_MTIR_Album_Fabric_Denim = "Denim",
    IGUI_MTIR_Album_Fabric_Leather = "Leather",
}

-- Groupe de chaque vêtement simulé (slot.group de MTIR.getSizing), nil = sans taille.
local GROUPS = {
    ["Base.Shirt"] = "top",
    ["Base.Jeans"] = "bottom",
    ["Base.Boilersuit"] = "full",
    ["Base.Scarf"] = nil,
}

local function item(name, entries)
    return { name = name, entries = entries, getName = function(self) return self.name end }
end

local function pattern(name, data)
    local o = item(name)
    o.data = data
    return o
end

local function data(fullType, kind, fabric)
    return { fullType = fullType, kind = kind or "clothes", fabric = fabric or "Cotton", uses = 4, precision = 5 }
end

function T.setup()
    getText = function(key) return LABELS[key] or key end
    ScriptManager = { instance = { getItem = function(_, fullType) return { fullType = fullType } end } }
    MTIR = {}
    function MTIR.getSizing(script)
        local group = GROUPS[script.fullType]
        return group and { kind = "clothes", slot = { group = group } } or nil
    end
    function MTIR.getBinderEntries(binder) return binder.entries or {} end
    function MTIR.getSourcePatternData(source, entryId)
        if entryId == nil then return source.data end
        for _, entry in ipairs(source.entries) do
            if entry.id == entryId then return entry.data end
        end
        return nil
    end
    function MTIR.getSourcePatternName(source, entryId)
        if entryId == nil then return source.name end
        for _, entry in ipairs(source.entries) do
            if entry.id == entryId then return entry.name end
        end
        return nil
    end
    loadMod("shared/MyTailorIsRich/MTIR_PatternAlbum.lua")
end

local function names(cards)
    local list = {}
    for _, card in ipairs(cards) do
        table.insert(list, card.name)
    end
    return table.concat(list, ", ")
end

local function sampleCards()
    local binder = item("Binder", {
        { id = 1, name = "Pattern: Jeans", data = data("Base.Jeans", "clothes", "Denim") },
        { id = 2, name = "Pattern: Leather jacket", data = data("Base.Shirt", "clothes", "Leather") },
        { id = 3, name = "Pattern: Boots", data = data("Base.Boots", "shoe", "Leather") },
    })
    local loose = {
        pattern("Pattern: Shirt", data("Base.Shirt")),
        pattern("Pattern: Boilersuit", data("Base.Boilersuit")),
        pattern("Pattern: Scarf", data("Base.Scarf")),
    }
    return MTIR.PatternAlbum.cards(MTIR.PatternAlbum.sources({ binder }, loose))
end

T["sources : patrons isolés puis chaque entrée des classeurs"] = function()
    local binder = item("Binder", { { id = 7 }, { id = 9 } })
    local loose = pattern("Loose")
    local sources = MTIR.PatternAlbum.sources({ binder }, { loose })
    assertEq(#sources, 3, "un isolé et deux rangés")
    assertEq(sources[1].item, loose, "isolé d'abord")
    assertEq(sources[1].entryId, nil, "sans entrée")
    assertEq(sources[2].item, binder, "puis le classeur")
    assertEq(sources[3].entryId, 9, "id de l'entrée gardé")
end

T["fiches triées par nom, nom du classeur pour un patron rangé"] = function()
    local cards = sampleCards()
    assertEq(names(cards), "Pattern: Boilersuit, Pattern: Boots, Pattern: Jeans, Pattern: Leather jacket, "
        .. "Pattern: Scarf, Pattern: Shirt", "ordre alphabétique")
    assertEq(cards[3].binderName, "Binder", "rangé : nom du classeur")
    assertEq(cards[1].binderName, nil, "isolé : aucun classeur")
    assertEq(cards[3].entryId, 1, "entrée gardée")
end

T["catégorie : chaussures, gants, puis groupe du vêtement, sinon Autre"] = function()
    local byName = {}
    for _, card in ipairs(sampleCards()) do
        byName[card.name] = card
    end
    assertEq(byName["Pattern: Boots"].category, "shoe", "chaussures")
    assertEq(byName["Pattern: Jeans"].category, "bottom", "bas")
    assertEq(byName["Pattern: Shirt"].category, "top", "haut")
    assertEq(byName["Pattern: Boilersuit"].category, "full", "tenue complète")
    assertEq(byName["Pattern: Scarf"].category, "other", "emplacement non classé")
    assertEq(byName["Pattern: Jeans"].categoryLabel, "Bottom", "libellé traduit")
    assertEq(byName["Pattern: Jeans"].fabricLabel, "Denim", "matériau traduit")
    local glove = MTIR.PatternAlbum.cards({ { item = pattern("Gloves", data("Base.Gloves", "glove")) } })
    assertEq(glove[1].category, "glove", "gants")
end

T["recherche : chaque mot dans le nom, la catégorie ou le matériau"] = function()
    local cards = sampleCards()
    local filter = MTIR.PatternAlbum.filter
    assertEq(names(filter(cards, "")), names(cards), "recherche vide : tout")
    assertEq(names(filter(cards, "  denim ")), "Pattern: Jeans", "matériau, espaces ignorés")
    assertEq(names(filter(cards, "LEATHER")), "Pattern: Boots, Pattern: Leather jacket", "sans majuscules")
    assertEq(names(filter(cards, "top leather")), "Pattern: Leather jacket", "catégorie et matériau")
    assertEq(names(filter(cards, "shoes")), "Pattern: Boots", "catégorie seule")
    assertEq(names(filter(cards, "shirt")), "Pattern: Shirt", "nom")
    assertEq(#filter(cards, "silk"), 0, "aucun résultat")
    assertEq(names(filter(cards, "(")), "", "caractère spécial cherché tel quel")
end

T["filtre supplémentaire : par exemple, pas de chaussures à la machine"] = function()
    local machine = function(patternData) return patternData.kind ~= "shoe" end
    local found = MTIR.PatternAlbum.filter(sampleCards(), "leather", machine)
    assertEq(names(found), "Pattern: Leather jacket", "les bottes sont écartées")
end

T["patron illisible ignoré"] = function()
    local broken = pattern("Broken", nil)
    assertEq(#MTIR.PatternAlbum.cards({ { item = broken } }), 0, "sans données, pas de fiche")
end

return T
