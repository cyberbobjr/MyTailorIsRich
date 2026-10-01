-- MTIR_Dyeing : vêtements teintables (clothingItem ou tag vanilla), bain de
-- teinture (teinture pure, quantités, eau), couleur appliquée comme la recette
-- vanilla, et nom approché des couleurs des teintures vanilla.

local T = {}

local OPTIONS

local function newVisual()
    local visual = {}
    function visual:setTint(color) self.tint = color end
    return visual
end

--- Vêtement simulé : tint = clothingItem teintable ; tags ; slot (difficulté) ; equipped.
local function clothing(opts)
    local item = {
        class = "Clothing", id = opts.id or 1, tint = opts.tint, tags = opts.tags or {},
        slot = opts.slot, equipped = opts.equipped, visual = newVisual(),
    }
    function item:allowRandomTint() return self.tint == true end
    function item:hasTag(tag) return self.tags[tag] == true end
    function item:isEquipped() return self.equipped == true end
    function item:getID() return self.id end
    function item:setColorRed(v) self.r = v end
    function item:setColorGreen(v) self.g = v end
    function item:setColorBlue(v) self.b = v end
    function item:setColor(c) self.color = c end
    function item:setCustomColor(v) self.custom = v end
    function item:getVisual() return self.visual end
    return item
end

--- Récipient simulé : fluids = { { fluid = "Dye", categories = { Dyes = true }, amount = 2 }, ... }.
local function bottle(id, fluids, color)
    local fc = { fluids = fluids, color = color or { 1, 0, 0 } }
    function fc:getAmount()
        local total = 0
        for _, f in ipairs(self.fluids) do
            total = total + f.amount
        end
        return total
    end
    function fc:isEmpty() return self:getAmount() <= 0 end
    function fc:contains(fluid)
        for _, f in ipairs(self.fluids) do
            if f.fluid == fluid then
                return true
            end
        end
        return false
    end
    function fc:isAllCategory(category)
        for _, f in ipairs(self.fluids) do
            if not f.categories[category] then
                return false
            end
        end
        return true
    end
    function fc:getColor()
        local c = self.color
        return { getR = function() return c[1] end, getG = function() return c[2] end, getB = function() return c[3] end }
    end
    function fc:adjustAmount(amount)
        -- Comme le jeu : la quantité totale est fixée, le mélange garde ses proportions.
        local total = self:getAmount()
        for _, f in ipairs(self.fluids) do
            f.amount = total > 0 and f.amount * amount / total or 0
        end
    end
    local container = { id = id, fc = fc }
    function container:getFluidContainer() return self.fc end
    function container:getID() return self.id end
    return container
end

local DYE = { Dyes = true, Colors = true }
local HAIR = { HairDyes = true }
local WATER = { Water = true }

local function industrialDye(id, amount, color)
    return bottle(id, { { fluid = "Dye", categories = DYE, amount = amount } }, color)
end

local function waterBucket(id, amount)
    return bottle(id, { { fluid = "Water", categories = WATER, amount = amount } })
end

function T.setup()
    OPTIONS = {}
    SandboxVars = { MyTailorIsRich = OPTIONS }
    instanceof = function(obj, class) return type(obj) == "table" and obj.class == class end
    ItemTag = { CAN_BE_DYED = "base:canbedyed" }
    Fluid = { Dye = "Dye", HairDye = "HairDye", Water = "Water" }
    FluidCategory = { Dyes = "Dyes", HairDyes = "HairDyes", Water = "Water" }
    Color = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
    ImmutableColor = { new = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
    getText = function(key) return key end
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    -- MTIR_Sizing simulé : profil d'effets porté par l'objet.
    MTIR.getSlot = function(item) return item.slot end
    loadMod("shared/MyTailorIsRich/MTIR_Dyeing.lua")
end

T["teintable : clothingItem AllowRandomTint ou tag vanilla, sinon non"] = function()
    assertTrue(MTIR.canTintClothing(clothing({ tint = true })), "AllowRandomTint")
    assertTrue(MTIR.canTintClothing(clothing({ tags = { ["base:canbedyed"] = true } })), "tag base:canbedyed")
    assertEq(MTIR.canTintClothing(clothing({})), false, "texture colorée : teinte ignorée")
    assertEq(MTIR.canTintClothing({ class = "InventoryContainer" }), false, "pas un vêtement")
end

T["bain : colorant industriel, quantités selon le volume du vêtement"] = function()
    local shirt = clothing({ tint = true })
    local dress = clothing({ tint = true, slot = { difficulty = 3 } })
    local water = waterBucket(20, 10)
    local kind = MTIR.checkDyeBath(shirt, industrialDye(10, 0.2), water)
    assertTrue(kind ~= nil and kind.fluid == "Dye", "0,2 L suffisent pour un haut")
    assertEq(MTIR.checkDyeBath(dress, industrialDye(11, 0.4), water), nil, "une robe demande 0,6 L")
    assertTrue(MTIR.checkDyeBath(dress, industrialDye(12, 0.6), water) ~= nil, "0,6 L pour une robe")
    assertEq(MTIR.checkDyeBath(dress, industrialDye(13, 2), waterBucket(21, 5)), nil, "6 L d'eau pour une robe")
end

T["bain : teinture pour cheveux acceptée, mélanges et eau sale refusés"] = function()
    local shirt = clothing({ tint = true })
    local water = waterBucket(20, 10)
    local hair = bottle(10, { { fluid = "HairDye", categories = HAIR, amount = 1 } })
    local kind = MTIR.checkDyeBath(shirt, hair, water)
    assertTrue(kind ~= nil and kind.fluid == "HairDye", "teinture pour cheveux")
    assertEq(MTIR.getDyeLitres(shirt, kind), 0.25, "0,25 L par unité")
    local mixed = bottle(11, { { fluid = "Dye", categories = DYE, amount = 1 },
        { fluid = "Water", categories = WATER, amount = 1 } })
    assertEq(MTIR.checkDyeBath(shirt, mixed, water), nil, "teinture diluée : impure")
    local juice = bottle(12, { { fluid = "Juice", categories = { Beverage = true }, amount = 1 } })
    assertEq(MTIR.checkDyeBath(shirt, juice, water), nil, "pas une teinture")
    local soup = bottle(21, { { fluid = "Water", categories = WATER, amount = 5 },
        { fluid = "Broth", categories = { Food = true }, amount = 1 } })
    assertEq(MTIR.checkDyeBath(shirt, industrialDye(13, 1), soup), nil, "eau mêlée à autre chose")
end

T["bain : vêtement porté, non teintable, même récipient ou option coupée"] = function()
    local dye = industrialDye(10, 1)
    local water = waterBucket(20, 10)
    assertEq(MTIR.checkDyeBath(clothing({ tint = true, equipped = true }), dye, water), nil, "porté")
    assertEq(MTIR.checkDyeBath(clothing({}), dye, water), nil, "non teintable")
    assertEq(MTIR.checkDyeBath(clothing({ tint = true }), dye, dye), nil, "même récipient")
    OPTIONS.EnableDyeing = false
    assertEq(MTIR.checkDyeBath(clothing({ tint = true }), dye, water), nil, "option désactivée")
end

T["couleur appliquée comme la recette vanilla, bornée"] = function()
    local item = clothing({ tint = true })
    MTIR.applyDyeColor(item, 0.69, 0.08, 1.4)
    assertEq(item.r, 0.69, "rouge")
    assertEq(item.b, 1, "bleu borné")
    assertEq(item.custom, true, "couleur personnalisée")
    assertEq(item.color.g, 0.08, "couleur de l'objet")
    assertEq(item.visual.tint.r, 0.69, "teinte du visuel")
end

T["fluides consommés"] = function()
    local dye = industrialDye(10, 2)
    MTIR.drainFluid(dye, 0.6)
    assertTrue(math.abs(MTIR.getFluidLitres(dye) - 1.4) < 1e-6, "2 - 0,6 L")
    MTIR.drainFluid(dye, 5)
    assertEq(MTIR.getFluidLitres(dye), 0, "jamais négatif")
end

-- Couleurs tirées des scripts vanilla (IndustrialDye, HairDye*, peintures).
local NAMED = {
    { 0.69, 0.08, 0.11, "Red" }, { 0.56, 0.02, 0.11, "Red" }, { 1.0, 0.4, 0.2, "Orange" },
    { 1.0, 0.93, 0.02, "Yellow" }, { 0.06, 0.16, 0.04, "Green" }, { 0.2, 0.4, 0.09, "Green" },
    { 0.0, 0.16, 0.49, "Blue" }, { 0.02, 0.42, 0.92, "Blue" }, { 0.23, 0.92, 0.9, "Cyan" },
    { 0.25, 0.01, 0.23, "Purple" }, { 0.57, 0.0, 0.98, "Purple" }, { 0.96, 0.32, 0.59, "Pink" },
    { 1.0, 0.18, 0.4, "Pink" }, { 0.45, 0.23, 0.11, "Brown" }, { 0.59, 0.23, 0.03, "Brown" },
    { 1.0, 0.84, 0.45, "Beige" }, { 0.02, 0.02, 0.02, "Black" }, { 0.1, 0.09, 0.08, "Black" },
    { 1.0, 1.0, 1.0, "White" }, { 0.79, 0.78, 0.75, "White" }, { 0.5, 0.5, 0.5, "Grey" },
    { 0.19, 0.24, 0.25, "Grey" },
}

T["noms de couleur des teintures vanilla"] = function()
    for _, c in ipairs(NAMED) do
        assertEq(MTIR.getColorNameKey(c[1], c[2], c[3]), c[4], string.format("%.2f %.2f %.2f", c[1], c[2], c[3]))
    end
end

T["chaque nom de couleur possible est traduit en anglais"] = function()
    local english = readModFile("shared/Translate/EN/IG_UI.json")
    local seen = {}
    for r = 0, 10 do
        for g = 0, 10 do
            for b = 0, 10 do
                seen[MTIR.getColorNameKey(r / 10, g / 10, b / 10)] = true
            end
        end
    end
    for key in pairs(seen) do
        assertTrue(string.find(english, '"IGUI_MTIR_Color_' .. key .. '"', 1, true) ~= nil, "clé manquante : " .. key)
    end
end

return T
