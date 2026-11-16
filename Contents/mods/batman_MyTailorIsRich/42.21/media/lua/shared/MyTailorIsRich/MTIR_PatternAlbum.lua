-- ============================================================================
-- My Tailor Is Rich — modèle de l'album de patrons (ADR-001)
--
-- Sans interface ni réseau : à partir des patrons isolés et des entrées de
-- classeurs, construit des fiches, les cherche et les trie. La fenêtre
-- (client/MyTailorIsRich/MTIR_PatternAlbumWindow.lua) n'affiche que ce que ce
-- module rend.
--
-- Source : { item = patron } ou { item = classeur, entryId = id de l'entrée }.
-- Fiche : { item, entryId, data, name, binderName, category, categoryLabel,
--           fabric, fabricLabel, searchText }.
-- ============================================================================

require "MyTailorIsRich/MTIR_PatternBinder"

MTIR = MTIR or {}
local Album = {}
MTIR.PatternAlbum = Album

--- Catégorie -> clé de traduction. Chaussures et gants viennent du patron (`kind`),
--- les autres du groupe de l'emplacement du vêtement (slot.group de MTIR.getSizing).
Album.CATEGORY_KEYS = {
    top = "IGUI_MTIR_Album_Cat_Top",
    bottom = "IGUI_MTIR_Album_Cat_Bottom",
    full = "IGUI_MTIR_Album_Cat_Full",
    glove = "IGUI_MTIR_Album_Cat_Glove",
    shoe = "IGUI_MTIR_Album_Cat_Shoe",
    other = "IGUI_MTIR_Album_Cat_Other",
}

--- Patrons dont la catégorie est le genre lui-même.
local KIND_CATEGORIES = { glove = "glove", shoe = "shoe" }

Album.FABRIC_KEYS = {
    Cotton = "IGUI_MTIR_Album_Fabric_Cotton",
    Denim = "IGUI_MTIR_Album_Fabric_Denim",
    Leather = "IGUI_MTIR_Album_Fabric_Leather",
}

--- Catégorie d'un patron : genre, sinon groupe de l'emplacement du vêtement, sinon "other".
function Album.category(data)
    local byKind = KIND_CATEGORIES[data.kind]
    if byKind then
        return byKind
    end
    local script = data.fullType and ScriptManager.instance:getItem(data.fullType) or nil
    local sizing = script and MTIR.getSizing(script) or nil
    local group = sizing and sizing.slot and sizing.slot.group or nil
    return Album.CATEGORY_KEYS[group] and group or "other"
end

--- Patrons isolés d'abord, puis chaque entrée de chaque classeur.
function Album.sources(binders, patterns)
    local sources = {}
    for _, item in ipairs(patterns or {}) do
        table.insert(sources, { item = item })
    end
    for _, binder in ipairs(binders or {}) do
        for _, entry in ipairs(MTIR.getBinderEntries(binder)) do
            table.insert(sources, { item = binder, entryId = entry.id })
        end
    end
    return sources
end

local function newCard(source)
    local data = MTIR.getSourcePatternData(source.item, source.entryId)
    if not data then
        return nil
    end
    local category = Album.category(data)
    local fabricKey = Album.FABRIC_KEYS[data.fabric]
    local card = {
        item = source.item,
        entryId = source.entryId,
        data = data,
        name = MTIR.getSourcePatternName(source.item, source.entryId) or "",
        binderName = source.entryId ~= nil and source.item:getName() or nil,
        category = category,
        categoryLabel = getText(Album.CATEGORY_KEYS[category]),
        fabric = data.fabric,
        fabricLabel = fabricKey and getText(fabricKey) or "",
    }
    card.searchText = string.lower(card.name .. " " .. card.categoryLabel .. " " .. card.fabricLabel)
    card.sortKey = string.lower(card.name)
    return card
end

local function byName(a, b)
    return a.sortKey < b.sortKey
end

--- Fiches des sources lisibles, triées par nom.
function Album.cards(sources)
    local cards = {}
    for _, source in ipairs(sources) do
        local card = newCard(source)
        if card then
            table.insert(cards, card)
        end
    end
    table.sort(cards, byName)
    return cards
end

local function words(query)
    local list = {}
    for word in string.gmatch(string.lower(query or ""), "%S+") do
        table.insert(list, word)
    end
    return list
end

local function matches(card, queryWords)
    for _, word in ipairs(queryWords) do
        if not string.find(card.searchText, word, 1, true) then
            return false
        end
    end
    return true
end

--- Fiches dont chaque mot de `query` apparaît dans le nom, la catégorie ou le
--- matériau, et que `accept(data)` garde (facultatif). L'ordre est conservé.
function Album.filter(cards, query, accept)
    local queryWords = words(query)
    local found = {}
    for _, card in ipairs(cards) do
        if (not accept or accept(card.data)) and matches(card, queryWords) then
            table.insert(found, card)
        end
    end
    return found
end

return Album
