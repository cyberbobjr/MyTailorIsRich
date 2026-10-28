-- MTIR_Effects : prévenir avant un changement de taille (I06).
-- Un vêtement trop petit de plus de deux tailles est retiré sans un mot : l'autorité
-- suit le poids, prévient à moins d'un kilo d'une borne, puis annonce la nouvelle
-- taille au franchissement.

local T = {}

local SAID

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

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Effects.lua")
    SAID = {}
    MTIR.tell = function(_, fx) table.insert(SAID, fx.say) end
end

--- Joueur simulé, de poids réglable (kilos).
local function player(weight, num)
    local o = { weight = weight, num = num or 0 }
    function o:getNutrition()
        local owner = self
        return { getWeight = function() return owner.weight end }
    end
    function o:getPlayerNum() return self.num end
    return o
end

local function keys()
    local n = 0
    for _ in pairs(SAID) do n = n + 1 end
    return n
end

T["distance à la prochaine taille, bornes comprises"] = function()
    local drift = MTIR.getSizeDrift(70)
    assertEq(drift.size.name, "M", "70 kg : taille M")
    assertEq(drift.up, 5, "5 kg avant le L")
    assertEq(drift.down, 5, "5 kg avant le S")

    local light = MTIR.getSizeDrift(40)
    assertEq(light.size.name, "XS", "40 kg : XS")
    assertEq(light.down, nil, "rien en dessous de XS")
    assertEq(light.up, 10, "10 kg avant le S")

    local heavy = MTIR.getSizeDrift(120)
    assertEq(heavy.size.name, "XXL", "120 kg : XXL")
    assertEq(heavy.up, nil, "rien au-dessus de XXL")
end

T["première passe : la taille est retenue sans rien dire"] = function()
    local p = player(70)
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 0, "aucune réplique au premier passage")
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 0, "ni au suivant, le poids n'a pas bougé")
end

T["approche d'une borne : prévenu une seule fois"] = function()
    local p = player(70)
    MTIR.checkSizeDrift(p)
    p.weight = 74.5
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 1, "prévenu à moins d'un kilo")
    assertEq(SAID[1].key, "IGUI_MTIR_Say_SizeNearUp", "ça commence à serrer")
    p.weight = 74.8
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 1, "pas répété")
    p.weight = 72
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 1, "rien en s'éloignant")
    p.weight = 74.6
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 2, "prévenu de nouveau après être redescendu")
end

T["maigrir : prévenu puis annonce de la nouvelle taille"] = function()
    local p = player(70)
    MTIR.checkSizeDrift(p)
    p.weight = 65.5
    MTIR.checkSizeDrift(p)
    assertEq(SAID[1].key, "IGUI_MTIR_Say_SizeNearDown", "ça commence à flotter")
    p.weight = 64
    MTIR.checkSizeDrift(p)
    assertEq(SAID[2].key, "IGUI_MTIR_Say_SizeDown", "nouvelle taille annoncée")
    assertEq(SAID[2].arg, "S", "la taille atteinte")
end

T["grossir d'un coup : l'annonce suffit, sans avertissement préalable"] = function()
    local p = player(70)
    MTIR.checkSizeDrift(p)
    p.weight = 90
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 1, "une seule réplique")
    assertEq(SAID[1].key, "IGUI_MTIR_Say_SizeUp", "taille au-dessus")
    assertEq(SAID[1].arg, "XL", "XL à 90 kg")
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 1, "pas répété au passage suivant")
end

T["chaque joueur a sa propre surveillance"] = function()
    local first, second = player(70, 0), player(70, 1)
    MTIR.checkSizeDrift(first)
    MTIR.checkSizeDrift(second)
    first.weight = 80
    MTIR.checkSizeDrift(first)
    assertEq(keys(), 1, "seul le premier a changé de taille")
    MTIR.checkSizeDrift(second)
    assertEq(keys(), 1, "le second n'a rien à dire")
end

T["l'oubli d'un joueur efface sa surveillance"] = function()
    local p = player(70)
    MTIR.checkSizeDrift(p)
    MTIR.forgetPlayerEffects(p)
    p.weight = 80
    MTIR.checkSizeDrift(p)
    assertEq(keys(), 0, "personnage neuf : on repart de sa taille, sans rien dire")
end

T["l'infobulle sait quand le poids approche d'une borne"] = function()
    assertEq(MTIR.getSizeWarning(player(70)), nil, "au milieu de la taille")
    assertEq(MTIR.getSizeWarning(player(74.5)), "up", "près de la borne haute")
    assertEq(MTIR.getSizeWarning(player(65.5)), "down", "près de la borne basse")
    assertEq(MTIR.getSizeWarning(player(40)), nil, "XS : aucune borne basse")
end

return T
