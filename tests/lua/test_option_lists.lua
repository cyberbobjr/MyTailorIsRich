-- MTIR_Core : lecture des listes des options texte (C14). Un seul analyseur pour les
-- trois listes, virgule et point-virgule acceptés, et une ligne de console pour une
-- entrée qui ne nomme aucun vêtement (sinon la liste reste sans effet et sans
-- explication).

local T = {}

local LOGGED, KNOWN

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing", NORMAL = "normal" }
    LOGGED = {}
    print = function(message) table.insert(LOGGED, message) end

    -- Scripts chargés dans cette partie : nom complet -> type d'objet.
    KNOWN = {
        ["Base.Tshirt_White"] = ItemType.CLOTHING,
        ["Mod.Jacket1"] = ItemType.CLOTHING,
        ["Mod.Jacket2"] = ItemType.CLOTHING,
        ["Base.Hammer"] = ItemType.NORMAL,
    }
    ScriptManager = {
        instance = {
            getItem = function(_, fullType)
                local itemType = KNOWN[fullType]
                if not itemType then
                    return nil
                end
                return { getItemType = function() return itemType end }
            end,
        },
    }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class) return o ~= nil and o.class == class end
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
end

local function customClothes(raw)
    SandboxVars.MyTailorIsRich.ListCustomClothes = raw
    return MTIR.getCustomClothes()
end

local function count(list)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    return n
end

T["virgule et point-virgule donnent la même liste"] = function()
    local withCommas = MTIR.parseOptionList("Mod.Jacket1,Mod.Jacket2:2", false)
    local withSemicolons = MTIR.parseOptionList("Mod.Jacket1;Mod.Jacket2:2", false)
    assertEq(withCommas["Mod.Jacket1"], 1, "virgule, difficulté par défaut")
    assertEq(withCommas["Mod.Jacket2"], 2, "virgule, difficulté lue")
    assertEq(withSemicolons["Mod.Jacket1"], 1, "point-virgule, difficulté par défaut")
    assertEq(withSemicolons["Mod.Jacket2"], 2, "point-virgule, difficulté lue")
end

T["difficulté arrondie vers le bas et bornée à 1..3"] = function()
    local list = MTIR.parseOptionList("a:0, b:5, c:2.7, d:abc, e", false)
    assertEq(list.a, 1, "zéro remonté à 1")
    assertEq(list.b, 3, "au-delà de 3 ramené à 3")
    assertEq(list.c, 2, "2,7 arrondi à 2")
    assertEq(list.d, 1, "difficulté illisible : 1")
    assertEq(list.e, 1, "sans difficulté : 1")
end

T["espaces et casse"] = function()
    local list = MTIR.parseOptionList("  Mod.Jacket1 : 2 ,  Mod.Jacket2  ", false)
    assertEq(list["Mod.Jacket1"], 2, "espaces autour du nom et de la difficulté")
    assertEq(list["Mod.Jacket2"], 1, "deuxième entrée")
    local lowered = MTIR.parseOptionList("Gorget;KIUC:2", true)
    assertEq(lowered.gorget, 1, "emplacements du corps en minuscules")
    assertEq(lowered.kiuc, 2, "deuxième emplacement")
end

T["liste vide ou absente"] = function()
    assertEq(count(MTIR.parseOptionList("", false)), 0, "chaîne vide")
    assertEq(count(MTIR.parseOptionList(nil, false)), 0, "valeur absente")
    assertEq(count(customClothes("")), 0, "option vide")
    assertEq(#LOGGED, 0, "aucun avertissement")
end

T["le point-virgule marche aussi pour les vêtements de mod"] = function()
    local list = customClothes("Mod.Jacket1;Mod.Jacket2:3")
    assertEq(count(list), 2, "les deux vestes reconnues")
    assertEq(list["Mod.Jacket2"], 3, "difficulté 3")
    assertEq(#LOGGED, 0, "aucun avertissement")
end

T["nom inconnu ou objet qui n'est pas un vêtement : écarté et signalé"] = function()
    local list = customClothes("Mod.Jacket1,Clothing0,Base.Hammer")
    assertEq(count(list), 1, "seule la veste connue est gardée")
    assertEq(list["Mod.Jacket1"], 1, "veste gardée")
    assertEq(#LOGGED, 2, "une ligne par entrée refusée")
    local joined = table.concat(LOGGED, " | ")
    assertTrue(string.find(joined, "Clothing0", 1, true) ~= nil, "nom inconnu nommé")
    assertTrue(string.find(joined, "Base.Hammer", 1, true) ~= nil, "objet non vêtement nommé")
    assertTrue(string.find(joined, "ListCustomClothes", 1, true) ~= nil, "option nommée")
end

T["une valeur d'option n'est analysée et signalée qu'une fois"] = function()
    customClothes("Clothing0")
    assertEq(#LOGGED, 1, "premier appel")
    MTIR.getCustomClothes()
    MTIR.getCustomClothes()
    assertEq(#LOGGED, 1, "liste en cache, pas de nouvel avertissement")
    customClothes("Clothing1")
    assertEq(#LOGGED, 2, "option changée : nouvelle analyse")
end

return T
