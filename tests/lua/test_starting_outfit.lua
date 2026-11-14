-- MTIR_Effects : la tenue portée sans taille (tenue de départ, objet antérieur au mod)
-- prend exactement la taille et la pointure du porteur, quel que soit le tirage.

local T = {}

local SYNCED

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing" }
    Perks = { Tailoring = "tailoring", Maintenance = "maintenance" }
    ScriptManager = { instance = { getItem = function() return nil end } }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class) return type(o) == "table" and o.class == class end
    isServer = function() return false end
    isClient = function() return false end
    instanceItem = function() return {} end
    -- Tirages au plus haut : tout tirage voisin décalerait la taille.
    ZombRand = function(n) return (n or 1) - 1 end
    ZombRandFloat = function() return 0 end

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Effects.lua")
    MTIR.canClothesHaveSize = function(item) return item.clothes == true end
    MTIR.canShoeHaveSize = function(item) return item.shoe == true end
    MTIR.getShoeData = function(item) return item:getModData().shoe end
    MTIR.createShoeData = function(item, size)
        local modData = item:getModData()
        modData.shoe = modData.shoe or { size = size, reveal = false, hint = false }
        return modData.shoe
    end
    MTIR.getPlayerShoeSize = function() return 43 end
    SYNCED = {}
    MTIR.syncItem = function(_, item) table.insert(SYNCED, item) end
end

local function item(kind)
    local o = { modData = {} }
    o[kind] = true
    function o:getModData() return self.modData end
    function o:hasModData() return true end
    return o
end

local function player(weight, items)
    local o = { weight = weight }
    function o:getNutrition()
        local owner = self
        return { getWeight = function() return owner.weight end }
    end
    function o:getWornItems()
        return {
            size = function() return #items end,
            getItemByIndex = function(_, i) return items[i + 1] end,
        }
    end
    return o
end

T["tenue de départ : taille exacte du porteur, retouche possible"] = function()
    local shirt, pants = item("clothes"), item("clothes")
    MTIR.fitUnsizedWornItems(player(70, { shirt, pants }))
    for _, worn in ipairs({ shirt, pants }) do
        local data = MTIR.getData(worn)
        assertEq(data.size, "M", "70 kg : taille M, sans décalage")
        assertEq(data.resized, 0, "jamais marqué comme déjà retouché")
        assertEq(data.hint, true, "le porteur devine la taille")
    end
    assertEq(#SYNCED, 2, "chaque vêtement taillé est synchronisé")
end

T["poids des traits : la taille suit le poids réel"] = function()
    local coat = item("clothes")
    MTIR.fitUnsizedWornItems(player(105, { coat }))
    assertEq(MTIR.getData(coat).size, "XXL", "105 kg : XXL")
end

T["chaussures de départ : pointure exacte"] = function()
    local shoes = item("shoe")
    MTIR.fitUnsizedWornItems(player(70, { shoes }))
    assertEq(shoes.modData.shoe.size, 43, "pointure du personnage, sans voisine")
    assertEq(shoes.modData.shoe.hint, true, "le porteur devine la pointure")
end

T["vêtement déjà taillé : inchangé"] = function()
    local jacket = item("clothes")
    MTIR.createExactData(jacket, "XS")
    MTIR.fitUnsizedWornItems(player(70, { jacket }))
    assertEq(MTIR.getData(jacket).size, "XS", "taille existante conservée")
    assertEq(#SYNCED, 0, "rien à synchroniser")
end

return T
