-- MTIR_Embroidery : texte nettoyé et borné, nom composé revérifié par
-- l'autorité, vêtements brodables, broderie posée puis décousue (nom antérieur
-- rétabli, ou nom du script).

local T = {}

local OPTIONS

--- Vêtement simulé : fabric, kind ("clothes", "shoe" ou nil), tags, broken, name.
local function clothing(opts)
    local item = {
        class = "Clothing", fabric = opts.fabric, kind = opts.kind, tags = opts.tags or {},
        broken = opts.broken, name = opts.name or "Jacket", customName = opts.customName == true,
        modData = {},
    }
    function item:isBroken() return self.broken == true end
    function item:hasTag(tag) return self.tags[tag] == true end
    function item:getScriptItem()
        local owner = self
        return {
            getFabricType = function() return owner.fabric end,
            getDisplayName = function() return "Jacket" end,
        }
    end
    function item:isCustomName() return self.customName end
    function item:getDisplayName() return self.name end
    function item:setName(name) self.name = name end
    function item:setCustomName(value)
        self.customName = value
        self.modData.customName = self.name
    end
    function item:hasModData() return true end
    function item:getModData() return self.modData end
    return item
end

function T.setup()
    OPTIONS = {}
    SandboxVars = { MyTailorIsRich = OPTIONS }
    instanceof = function(obj, class) return type(obj) == "table" and obj.class == class end
    ItemTag = { CAN_BE_DYED = "base:canbedyed" }
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    -- MTIR_Sizing simulé.
    MTIR.getSizingKind = function(item) return item.kind end
    MTIR.canClothesHaveSize = function(item) return item.kind == "clothes" end
    loadMod("shared/MyTailorIsRich/MTIR_Embroidery.lua")
end

T["texte nettoyé : espaces, balises, % et caractères de contrôle"] = function()
    assertEq(MTIR.cleanEmbroideryText("  Bob   le\tBricoleur "), "Bob le Bricoleur", "espaces")
    assertEq(MTIR.cleanEmbroideryText("<RGB:1,0,0>Bob"), "RGB:1,0,0Bob", "balises retirées")
    assertEq(MTIR.cleanEmbroideryText("100% Bob\1"), "100 Bob", "pourcent et contrôle")
    assertEq(MTIR.cleanEmbroideryText("   "), nil, "vide")
    assertEq(MTIR.cleanEmbroideryText(nil), nil, "absent")
    assertEq(MTIR.cleanEmbroideryText(string.rep("a", 25)), nil, "trop long : refusé, jamais tronqué")
    assertEq(MTIR.cleanEmbroideryText(string.rep("a", 24)), string.rep("a", 24), "limite")
    assertEq(MTIR.cleanEmbroideryText("Боб"), "Боб", "cyrillique")
end

T["autorité : texte et nom du client revérifiés"] = function()
    assertTrue(MTIR.isValidEmbroidery("Bob", "Jacket \"Bob\""), "nom composé")
    assertTrue(MTIR.isValidEmbroidery("Bob", "Bob"), "texte seul")
    assertEq(MTIR.isValidEmbroidery("Bob", "Jacket"), false, "le nom doit contenir le texte")
    assertEq(MTIR.isValidEmbroidery("<b>", "Jacket <b>"), false, "texte non nettoyé")
    assertEq(MTIR.isValidEmbroidery(" Bob", "Jacket Bob"), false, "texte non rogné")
    assertEq(MTIR.isValidEmbroidery("Bob", "Bob " .. string.rep("x", 70)), false, "nom trop long")
    assertEq(MTIR.isValidEmbroidery(42, "42"), false, "pas une chaîne")
end

T["vêtements brodables"] = function()
    assertTrue(MTIR.canEmbroider(clothing({ kind = "clothes" })), "vêtement taillé (mods compris)")
    assertTrue(MTIR.canEmbroider(clothing({ fabric = "Cotton" })), "tissu déclaré")
    assertTrue(MTIR.canEmbroider(clothing({ tags = { ["base:canbedyed"] = true } })), "bonnet teignable")
    assertEq(MTIR.canEmbroider(clothing({})), false, "protection rigide sans tissu")
    assertEq(MTIR.canEmbroider(clothing({ kind = "shoe", fabric = "Leather" })), false, "chaussure")
    assertEq(MTIR.canEmbroider(clothing({ kind = "clothes", broken = true })), false, "en lambeaux")
    assertEq(MTIR.canEmbroider({ class = "InventoryItem" }), false, "pas un vêtement")
end

T["broder puis découdre : nom du script rétabli"] = function()
    local item = clothing({ kind = "clothes" })
    MTIR.applyEmbroidery(item, "Bob", "Jacket \"Bob\"")
    assertEq(item.name, "Jacket \"Bob\"", "renommé")
    assertEq(item.customName, true, "nom personnalisé")
    assertEq(MTIR.getEmbroidery(item).text, "Bob", "broderie notée")
    assertEq(MTIR.getEmbroidery(item).prevName, nil, "aucun nom antérieur")
    MTIR.removeEmbroidery(item)
    assertEq(MTIR.getEmbroidery(item), nil, "broderie retirée")
    assertEq(item.name, "Jacket", "nom du script")
    assertEq(item.customName, false, "plus de nom personnalisé")
    assertEq(item.modData.customName, nil, "copie du nom effacée")
end

T["broder puis découdre : nom personnalisé antérieur rétabli"] = function()
    local item = clothing({ kind = "clothes", name = "Lucky jacket", customName = true })
    MTIR.applyEmbroidery(item, "Bob", "Lucky jacket \"Bob\"")
    assertEq(MTIR.getEmbroidery(item).prevName, "Lucky jacket", "nom antérieur mémorisé")
    local prev = MTIR.removeEmbroidery(item)
    assertEq(prev, "Lucky jacket", "nom rendu au client")
    assertEq(item.name, "Lucky jacket", "nom rétabli")
    assertEq(item.customName, true, "toujours personnalisé")
end

T["donnée de broderie invalide ignorée, option coupée"] = function()
    local item = clothing({ kind = "clothes" })
    item.modData[MTIR.EMBROIDERY_KEY] = "Bob"
    assertEq(MTIR.getEmbroidery(item), nil, "pas une table")
    assertEq(MTIR.isEmbroideryEnabled(), true, "activée par défaut")
    OPTIONS.EnableEmbroidery = false
    assertEq(MTIR.isEmbroideryEnabled(), false, "désactivée")
    OPTIONS.NeedTailoringLevel = false
    assertEq(MTIR.getEmbroideryRequiredLevel(), 0, "sans niveau requis")
end

return T
