-- MTIR_Core : feuilles vierges seules consommées, favoris jamais pris comme
-- matériaux, fils du type Thread puis du tag base:thread.

local T = {}

--- ArrayList simulée (index 0), avec add.
local function arrayList(values)
    local list = { values = values or {} }
    function list:size() return #self.values end
    function list:get(i) return self.values[i + 1] end
    function list:add(value) table.insert(self.values, value) end
    return list
end

--- Objet simulé : class, fullType, type, favorite, customName, name, scriptName,
--- pages ("" = vierge), lockedBy, modData (true = présente).
local function newItem(opts)
    local item = {}
    for key, value in pairs(opts) do item[key] = value end
    item.class = item.class or "Literature"
    item.name = item.name or "Sheet of Paper"
    item.scriptName = item.scriptName or "Sheet of Paper"
    function item:isFavorite() return self.favorite == true end
    function item:isCustomName() return self.customName == true end
    function item:hasModData() return self.modData == true or type(self.modData) == "table" end
    function item:getModData() return type(self.modData) == "table" and self.modData or { document = true } end
    function item:getDisplayName() return self.name end
    function item:getScriptItem()
        local owner = self
        return { getDisplayName = function() return owner.scriptName end }
    end
    function item:isEmptyPages() return (self.pages or "") == "" end
    function item:getLockedBy() return self.lockedBy end
    function item:getType() return self.type end
    return item
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ArrayList = { new = function() return arrayList() end }
    instanceof = function(obj, class) return type(obj) == "table" and obj.class == class end
    ItemTag = { THREAD = "base:thread" }
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
end

T["feuille vierge acceptée ; écrite, nommée, favorite, verrouillée ou à ModData refusée"] = function()
    assertEq(MTIR.isBlankSheet(newItem({})), true, "vierge")
    assertEq(MTIR.isBlankSheet(newItem({ pages = "Ma note" })), false, "écrite")
    assertEq(MTIR.isBlankSheet(newItem({ customName = true, name = "Courses" })), false, "renommée")
    assertEq(MTIR.isBlankSheet(newItem({ name = "Note de quête" })), false, "nom différent du script")
    assertEq(MTIR.isBlankSheet(newItem({ favorite = true })), false, "favorite")
    assertEq(MTIR.isBlankSheet(newItem({ lockedBy = "bob" })), false, "verrouillée")
    assertEq(MTIR.isBlankSheet(newItem({ modData = true })), false, "document d'un mod")
end

T["pickItems saute les favoris et échoue s'il n'en reste pas assez"] = function()
    local a, b, c = newItem({ favorite = true }), newItem({}), newItem({})
    local list = arrayList({ a, b, c })
    local picked = MTIR.pickItems(list, 2)
    assertEq(picked:size(), 2, "deux pris")
    assertEq(picked:get(0), b, "premier non favori")
    assertEq(picked:get(1), c, "second non favori")
    assertEq(MTIR.pickItems(list, 3), nil, "le favori ne complète pas")
    assertEq(MTIR.countPickable(list), 2, "favori non compté")
end

T["papier vierge : customName vanilla résiduel égal au nom normal accepté"] = function()
    local name = "Morceau de papier"
    local first = newItem({ name = name, scriptName = name, modData = { customName = name } })
    local second = newItem({ name = name, scriptName = name, modData = { customName = name } })
    assertEq(MTIR.isBlankSheet(first), true, "première feuille")
    assertEq(MTIR.isBlankSheet(second), true, "seconde feuille")
    loadMod("shared/MyTailorIsRich/MTIR_Patterns.lua")
    first.fullType, second.fullType = "Base.SheetPaper2", "Base.SheetPaper2"
    first.getFullType = function(self) return self.fullType end
    second.getFullType = first.getFullType
    assertEq(MTIR.predicatePaper(first), true, "même prédicat pour menu et autorité")
    local picked = MTIR.pickItems(arrayList({ first, second }), 2)
    assertEq(picked:size(), 2, "deux feuilles utilisables")
end

T["customName résiduel ne déprotège ni un document, ni une note, ni un favori"] = function()
    local md = { customName = "Sheet of Paper" }
    assertEq(MTIR.isBlankSheet(newItem({ modData = md, pages = "My note" })), false, "texte protégé")
    assertEq(MTIR.isBlankSheet(newItem({ modData = md, favorite = true })), false, "favori protégé")
    assertEq(MTIR.isBlankSheet(newItem({ modData = md, lockedBy = "reader" })), false, "verrou protégé")
    assertEq(MTIR.isBlankSheet(newItem({ modData = md, customName = true })), false, "nom personnalisé protégé")
    assertEq(MTIR.isBlankSheet(newItem({ modData = { customName = "Old note" } })), false,
        "ancienne marque différente protégée")
    assertEq(MTIR.isBlankSheet(newItem({ modData = { customName = "Sheet of Paper", quest = true } })), false,
        "autres données de document protégées")
end

T["fils : bobines Thread d'abord, puis les autres du tag"] = function()
    local aramid = newItem({ class = "DrainableComboItem", type = "Thread_Aramid" })
    local spool = newItem({ class = "DrainableComboItem", type = "Thread" })
    local found = arrayList({ aramid, spool })
    local inventory = { getAllEvalRecurse = function(_, predicate)
        assertEq(predicate, MTIR.predicateThread, "prédicat partagé")
        return found
    end }
    local threads = MTIR.collectThreads(inventory)
    assertEq(threads:size(), 2, "deux fils")
    assertEq(threads:get(0), spool, "bobine Thread en tête")
    assertEq(threads:get(1), aramid, "fil aramide ensuite")
end

return T
