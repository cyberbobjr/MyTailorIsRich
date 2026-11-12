-- Dynamic Body Shape Redux (facultatif) : la tenue d'un zombie prend la taille de sa
-- silhouette, tirée comme le fait ce mod (newrandom semé par l'identifiant de tenue),
-- et l'aperçu d'un patron prend la version élargie du vêtement sur un corps gros.
-- DBSR est simulé avec les mêmes fonctions publiques que sa version 0.4.0.

local T = {}

local seeds

--- Faux DBSR : le tirage renvoie la silhouette inscrite pour la graine reçue.
local function fakeDbsr(shapeBySeed)
    seeds = {}
    newrandom = function()
        local rand = {}
        function rand:seed(n)
            self.n = n
            table.insert(seeds, n)
        end
        function rand:random() return self.n end
        return rand
    end
    DBSR = {
        NORMAL = 3,
        SUFFIX = { [4] = "_Fat", [5] = "_Obese" },
        trueId = function(id)
            if math.floor(id / 32768) % 2 == 1 then return id - 32768 end
            return id
        end,
        zombieLevel = function(roll) return shapeBySeed[roll] end,
        levelForWeight = function(w)
            if w <= 65 then return 1 end
            if w <= 75 then return 2 end
            if w <= 85 then return 3 end
            if w <= 100 then return 4 end
            return 5
        end,
    }
end

local function zombie(outfitId, opts)
    opts = opts or {}
    local z = {}
    function z:getPersistentOutfitID() return outfitId end
    function z:isFemale() return false end
    function z:isReanimatedPlayer() return opts.reanimated == true end
    function z:isSkeleton() return false end
    return z
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    MTIR = nil
    DBSR = nil
    BridgeCompanion = nil
    ZombRand = function() return 0 end
    local scripts = { ["Base.Jacket_Padded_Fat"] = true, ["Base.Jacket_Padded_Obese"] = true }
    getScriptManager = function()
        return { FindItem = function(_, fullType) return scripts[fullType] end }
    end
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
end

T["sans Dynamic Body Shape Redux : tirage habituel"] = function()
    assertEq(MTIR.getZombieBodyShape(zombie(100)), nil, "pas de silhouette")
    assertEq(MTIR.getZombieClothesSize(zombie(100)), MTIR.getRandomClothesSize(), "taille habituelle")
end

T["chaque silhouette donne la taille de la même plage de poids"] = function()
    fakeDbsr({ [11] = 2, [12] = 3, [13] = 4, [14] = 5 })
    assertEq(MTIR.getZombieClothesSize(zombie(11)).name, "M", "maigre")
    assertEq(MTIR.getZombieClothesSize(zombie(12)).name, "L", "normal")
    assertEq(MTIR.getZombieClothesSize(zombie(13)).name, "XL", "gros")
    assertEq(MTIR.getZombieClothesSize(zombie(14)).name, "XXL", "obèse")
end

T["émacié : XS ou S selon leurs chances"] = function()
    fakeDbsr({ [10] = 1 })
    ZombRand = function() return 0 end
    assertEq(MTIR.getZombieClothesSize(zombie(10)).name, "XS", "premier tirage")
    ZombRand = function(n) return n - 1 end
    assertEq(MTIR.getZombieClothesSize(zombie(10)).name, "S", "dernier tirage")
end

T["graine : identifiant de tenue sans le bit 15, comme DBSR"] = function()
    fakeDbsr({ [5] = 4 })
    assertEq(MTIR.getZombieBodyShape(zombie(5 + 32768)), 4, "bit 15 retiré")
    assertEq(seeds[1], 5, "graine")
end

T["joueur réanimé et tenue inconnue : tirage habituel"] = function()
    fakeDbsr({ [7] = 5 })
    assertEq(MTIR.getZombieBodyShape(zombie(7, { reanimated = true })), nil, "réanimé")
    assertEq(MTIR.getZombieBodyShape(zombie(0)), nil, "tenue inconnue")
end

T["compagne de Stay With Me : silhouette normale"] = function()
    fakeDbsr({ [8] = 5 })
    local z = zombie(8)
    BridgeCompanion = { isBody = function(o) return o == z end }
    assertEq(MTIR.getZombieClothesSize(z).name, "L", "compagne")
end

T["aperçu : version élargie selon le poids, si elle existe"] = function()
    assertEq(MTIR.getBodyShapeVisualType("Base.Jacket_Padded", 110), nil, "sans DBSR")
    fakeDbsr({})
    assertEq(MTIR.getBodyShapeVisualType("Base.Jacket_Padded", 80), nil, "poids normal")
    assertEq(MTIR.getBodyShapeVisualType("Base.Jacket_Padded", 95), "Base.Jacket_Padded_Fat", "gros")
    assertEq(MTIR.getBodyShapeVisualType("Base.Jacket_Padded", 110), "Base.Jacket_Padded_Obese", "obèse")
    assertEq(MTIR.getBodyShapeVisualType("Base.Hat_Modded", 110), nil, "vêtement sans version élargie")
end

return T
