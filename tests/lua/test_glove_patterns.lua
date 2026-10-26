-- Glove patterns: real sizing, model, material, copy and binder code;
-- Java objects are simulated, so these checks do not establish game compatibility.
local T = {}

local function list(values)
    local o = { values = values or {} }
    function o:size() return #self.values end
    function o:isEmpty() return #self.values == 0 end
    function o:get(i) return self.values[i + 1] end
    function o:add(value) self.values[#self.values + 1] = value end
    return o
end

local function script(name, fabric, location)
    local o = { name = name, fabric = fabric, location = location or "base:hands" }
    function o:getFullName() return self.name end
    function o:getFabricType() return self.fabric end
    function o:getBodyLocation() return self.location end
    function o:getItemType() return ItemType.CLOTHING end
    function o:isCosmetic() return self.cosmetic == true end
    function o:isHidden() return false end
    function o:getObsolete() return false end
    function o:getBloodClothingType() return nil end
    return o
end

local function item(def)
    local o = { class = "Clothing", def = def, md = {}, condition = 100 }
    function o:getScriptItem() return self.def end
    function o:getFullType() return self.def:getFullName() end
    function o:getBulletDefense() return self.ballistic and 10 or 0 end
    function o:getModData() return self.md end
    function o:hasModData() return true end
    function o:setName(name) self.name = name end
    function o:getName() return self.name end
    function o:setCustomName(value) self.customName = value end
    function o:getConditionMax() return 100 end
    function o:getCondition() return self.condition end
    function o:setCondition(value) self.condition = value end
    function o:isBroken() return self.condition <= 0 end
    function o:synchWithVisual() self.synced = true end
    function o:isFavorite() return self.favorite == true end
    return o
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing" }
    Perks = { Tailoring = "tailoring" }
    ArrayList = { new = function() return list() end }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class)
        return o ~= nil and (o.class == class or (class == "InventoryItem" and o.class == "Clothing"))
    end
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SHOE_DATA_KEY = "MTIR_Shoe"
    loadMod("shared/MyTailorIsRich/MTIR_Sizing.lua")
    MTIR.canShoeHaveSize = function() return false end
    loadMod("shared/MyTailorIsRich/MTIR_Patterns.lua")
    loadMod("shared/MyTailorIsRich/MTIR_PrintedPatterns.lua")
    loadMod("shared/MyTailorIsRich/MTIR_PatternBinder.lua")
    loadMod("shared/MyTailorIsRich/MTIR_PatternCopy.lua")
    getTextOrNull = function() return nil end
    getItemNameFromFullType = function(fullType) return fullType end
    sendAddItemToContainer = function() end
    created = {}
    instanceItem = function(fullType)
        return item(script(fullType))
    end
    player = {
        getInventory = function() return { AddItem = function(_, obj) created[#created + 1] = obj end } end,
        getPerkLevel = function() return 6 end,
    }
end

T["trace and printed models agree on cotton, denim and leather without adding sizes"] = function()
    for _, fabric in ipairs({ "Cotton", "Denim", "Leather" }) do
        local def = script("Example.Gloves_" .. fabric, fabric)
        local glove = item(def)
        assertEq(MTIR.canClothesHaveSize(glove), false, "gloves stay unsized")
        local model = MTIR.describeModel(glove)
        local printed = MTIR.describeScriptModel(def)
        assertEq(model.kind, "glove", "trace kind")
        assertEq(model.fabric, fabric, "trace material")
        assertEq(printed.kind, model.kind, "printed kind")
        assertEq(printed.fabric, model.fabric, "printed material")
        assertEq(printed.difficulty, model.difficulty, "same difficulty")
        assertEq(MTIR.getRequiredLevelToSew(model), 1 + MTIR.FABRIC_DIFFICULTY[fabric], "fabric affects level")
        assertEq(MTIR.getRequiredPaper(model), 1, "one paper")
    end
end

T["missing vanilla fingerless fabrics have explicit fallbacks"] = function()
    local cases = {
        ["Base.Gloves_FingerlessGloves"] = "Cotton",
        ["Base.Gloves_FingerlessLeatherGloves"] = "Leather",
        ["Base.Gloves_FingerlessLeatherGloves_Black"] = "Leather",
        ["Base.Gloves_FingerlessLeatherGloves_Brown"] = "Leather",
    }
    for fullType, fabric in pairs(cases) do
        assertEq(MTIR.describeModel(item(script(fullType))).fabric, fabric, fullType)
    end
    assertEq(MTIR.getGloveMaterial(script("Base.Gloves_FingerlessGloves", "Denim")), "Denim",
        "declared fabric takes priority")
end

T["unknown, rubber, metal, ballistic, cosmetic and excluded models are refused"] = function()
    for _, name in ipairs({ "Gloves_Dish", "Gloves_Surgical", "Gloves_BoxingRed", "Gloves_BoneGloves",
        "Gloves_IceHockeyGloves", "Chainmail_Hand_L", "UnknownGlove" }) do
        local def = script("Base." .. name)
        assertEq(MTIR.describeModel(item(def)), nil, "no guessed fabric: " .. name)
        assertEq(MTIR.describeScriptModel(def), nil, "no printed pattern: " .. name)
    end
    assertEq(MTIR.describeModel(item(script("Example.Glove", "Rubber"))), nil, "unsupported fabric")
    local ballistic = item(script("Example.Ballistic", "Leather"))
    ballistic.ballistic = true
    local kind, reason = MTIR.getTraceKind(ballistic)
    assertEq(kind, nil, "ballistic refused")
    assertEq(reason, "IGUI_MTIR_Pattern_NoBallistic", "reason")
    local cosmetic = script("Example.Cosmetic", "Cotton")
    cosmetic.cosmetic = true
    assertEq(MTIR.describeModel(item(cosmetic)), nil, "cosmetic refused")
    SandboxVars.MyTailorIsRich.ListExcludedClothes = "Example.Excluded"
    local excluded = script("Example.Excluded", "Leather")
    assertEq(MTIR.describeModel(item(excluded)), nil, "excluded trace")
    assertEq(MTIR.describeScriptModel(excluded), nil, "excluded print")
end

T["left and right gloves are supported but other accessories stay excluded"] = function()
    for _, loc in ipairs({ "base:handsleft", "base:handsright" }) do
        assertEq(MTIR.describeModel(item(script("Example.SingleGlove", "Leather", loc))).kind, "glove", loc)
    end
    assertEq(MTIR.describeModel(item(script("Example.Hat", "Cotton", "base:hat"))), nil, "hat")
end

T["trace data survives copying and binder storage then creates the exact glove model"] = function()
    local glove = item(script("Base.Gloves_LeatherGloves", "Leather"))
    local pattern = MTIR.createPattern(player, glove, MTIR.describeModel(glove))
    local data = MTIR.getPatternData(pattern)
    assertEq(data.fabric, "Leather", "recorded material")
    assertEq(data.kind, "glove", "recorded kind")
    local copy = MTIR.makePatternCopyData(data, 1, 5)
    local binder = MTIR.binderNewData()
    local id = MTIR.binderAddEntry(binder, { type = MTIR.PATTERN_ITEM,
        modData = { [MTIR.PATTERN_DATA_KEY] = copy } }, 20)
    local saved = MTIR.binderEntryPattern(MTIR.binderFindEntry(binder, id))
    assertEq(saved.fabric, "Leather", "stored fabric")
    local sewn = MTIR.createFromPattern(player, saved, MTIR.GLOVE_PATTERN_SIZE, 3)
    assertEq(sewn:getFullType(), "Base.Gloves_LeatherGloves", "exact model recreated")
    assertEq(sewn:getModData()[MTIR.DATA_KEY], nil, "no clothing size data")
    assertEq(sewn:getModData()[MTIR.SHOE_DATA_KEY or "MTIR_Shoe"], nil, "no shoe data")
    assertEq(sewn.condition, 100, "condition follows sewing quality")
    assertTrue(sewn.synced, "visual synchronized")
end

T["one size only and no offset risk even for a low precision copy"] = function()
    local data = { kind = "glove", precision = 0, difficulty = 1, fabric = "Cotton" }
    local sizes = MTIR.getPatternSizes(data)
    assertEq(#sizes, 1, "single choice")
    assertTrue(MTIR.isValidPatternSize(data, sizes[1]), "valid choice")
    assertEq(MTIR.isValidPatternSize(data, "M"), false, "clothing sizes refused")
    assertEq(MTIR.getPatternOffChance(data, 0), 0, "no offset")
    ZombRandFloat = function() return 0 end
    assertEq(MTIR.rollPatternSize(data, sizes[1], 0), sizes[1], "size kept")
    assertEq(MTIR.getPatternMaterialUnits(data, sizes[1]), 2, "two material units")
    assertEq(MTIR.patternNeedsGlue(data), false, "no shoe glue")
end

T["leather pattern cannot be supplied with cotton or favourite leather"] = function()
    local cotton = item(script("Base.RippedSheets"))
    local leather = item(script("Base.LeatherStrips"))
    local favourite = item(script("Base.LeatherStrips"))
    favourite.favorite = true
    assertEq(MTIR.countMaterialUnits("Leather", list({ cotton })), 0, "cotton refused")
    assertEq(MTIR.countMaterialUnits("Leather", list({ favourite })), 0, "favourite protected")
    assertEq(MTIR.countMaterialUnits("Leather", list({ leather, cotton, favourite })), 1, "only leather counts")
    local available, picked = MTIR.pickPatternMaterials({ getItemsFromFullType = function(_, fullType)
        return fullType == "Base.LeatherStrips" and list({ leather, favourite }) or list()
    end }, "Leather", 2)
    assertEq(available, 1, "available leather")
    assertEq(picked, nil, "not enough material")
end

T["existing clothes and shoe patterns keep their size data and material costs"] = function()
    local clothes = { fullType = "Base.Shirt_Denim", kind = "clothes", fabric = "Denim", difficulty = 2 }
    local shoes = { fullType = "Base.Shoes_Black", kind = "shoe", fabric = "Leather", difficulty = 3 }
    assertEq(MTIR.getPatternMaterialUnits(clothes, "M"), 8, "clothes cost unchanged")
    assertEq(MTIR.getPatternMaterialUnits(shoes, "40"), 6, "shoe cost unchanged")
    local sewn = MTIR.createFromPattern(player, clothes, "M", 0)
    assertEq(sewn:getModData()[MTIR.DATA_KEY].size, "M", "clothing size stored")
    local pair = MTIR.createFromPattern(player, shoes, "40", 0)
    assertEq(pair:getModData()[MTIR.SHOE_DATA_KEY].size, 40, "shoe size stored")
    assertEq(MTIR.isValidPatternSize(clothes, "M"), true, "old clothing size accepted")
end

return T
