-- MTIR_Alterations : formules des retouches et des remises en état (C17, zone sans
-- test). À la main ou sur machine, les bonus changent la durée, le niveau retenu, la
-- chance de réussite et le fil consommé ; le reste décide de la taille visée et de
-- l'exemplaire de rechange.

local T = {}

local ELECTRIC, TREADLE, PLAYER
local machineAt, garment

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemType = { CLOTHING = "clothing" }
    Perks = { Tailoring = "tailoring", Maintenance = "maintenance", Electricity = "electricity" }
    ScriptManager = { instance = { getItem = function() return nil end } }
    luautils = {
        trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end,
        split = function(s, sep)
            local result = {}
            for part in string.gmatch(s, "[^" .. sep .. "]+") do result[#result + 1] = part end
            return result
        end,
    }
    instanceof = function(o, class)
        return type(o) == "table" and (o.class == class
            or (class == "InventoryItem" and o.class == "Clothing"))
    end
    isClient = function() return false end
    isServer = function() return false end
    getWorld = function() return { getFreeEmitter = function() return {} end } end
    getTimestampMs = function() return 0 end
    getCell = function() return { getGridSquare = function() return nil end } end
    sendClientCommand = function() end

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    -- Travail à la main et profil du vêtement : fournis par MTIR_Patterns et
    -- MTIR_Sizing, non chargés ici.
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    MTIR.getSlot = function() return { difficulty = 1 } end
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")
    loadMod("shared/MyTailorIsRich/MTIR_MachineSound.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Alterations.lua")

    ELECTRIC = machineAt("mtir_sewing_01_")
    TREADLE = machineAt("mtir_treadle_01_")
    PLAYER = { tailoring = 4 }
    function PLAYER:getPerkLevel() return self.tailoring end
end

--- Machine posée : nom de tuile et état (ModData movableData), ou neuve.
machineAt = function(prefix, condition)
    local modData = condition and { movableData = { mtirCondition = condition } } or nil
    return {
        getSprite = function() return { getName = function() return prefix .. "0" end } end,
        hasModData = function() return modData ~= nil end,
        getModData = function() return modData end,
    }
end

local function mods(machine)
    if not machine then
        return MTIR.SEW_BY_HAND
    end
    return MTIR.getMachineMods(machine)
end

T["fil : facteur de la machine, arrondi au-dessus, jamais zéro"] = function()
    assertEq(MTIR.applyThreadFactor(10, nil), 10, "à la main : inchangé")
    assertEq(MTIR.applyThreadFactor(10, mods(ELECTRIC)), 7, "électrique : 10 x 0,7")
    assertEq(MTIR.applyThreadFactor(3, mods(ELECTRIC)), 3, "3 x 0,7 = 2,1 arrondi à 3")
    assertEq(MTIR.applyThreadFactor(1, mods(ELECTRIC)), 1, "jamais moins d'une utilisation")
    assertEq(MTIR.applyThreadFactor(0, mods(ELECTRIC)), 1, "jamais zéro")
end

T["niveau retenu : compétence plus le bonus de la machine"] = function()
    assertEq(MTIR.getEffectiveTailoring(PLAYER, nil), 4, "à la main : la compétence")
    assertEq(MTIR.getEffectiveTailoring(PLAYER, mods(ELECTRIC)), 6, "électrique : +2")
    assertTrue(MTIR.getEffectiveTailoring(PLAYER, mods(TREADLE))
        < MTIR.getEffectiveTailoring(PLAYER, mods(ELECTRIC)), "pédale : moins que l'électrique")
end

T["chance de réussite : malus d'une machine usée, bornée entre 0 et 1"] = function()
    assertEq(MTIR.applySuccessMalus(0.8, nil), 0.8, "à la main : inchangée")
    assertEq(MTIR.applySuccessMalus(1.5, nil), 1, "jamais plus de 1")
    assertEq(MTIR.applySuccessMalus(-0.2, nil), 0, "jamais moins de 0")
    local worn = mods(machineAt("mtir_sewing_01_", 5))
    assertTrue(MTIR.applySuccessMalus(0.8, worn) < 0.8, "machine presque cassée : malus")
    assertEq(MTIR.applySuccessMalus(0.01, worn), 0, "malus plus grand que la chance : zéro")
end

T["durée : facteur de la machine, au moins un tick"] = function()
    local item = garment()
    local byHand = MTIR.getResizeDurationWith(item, true, nil)
    local onMachine = MTIR.getResizeDurationWith(item, true, mods(ELECTRIC))
    assertTrue(byHand > 0, "durée à la main")
    assertEq(onMachine, byHand * 0.5, "électrique : moitié du temps")
    assertTrue(MTIR.getReconditionDurationWith(item, mods(ELECTRIC))
        < MTIR.getReconditionDurationWith(item, nil), "remise en état aussi")

    SandboxVars.MyTailorIsRich.ActionTimeMultiplier = 0
    assertEq(MTIR.getResizeDurationWith(item, true, mods(ELECTRIC)), 1, "au moins un tick")
end

T["matériaux d'une retouche : bandes pour agrandir, trombones pour rétrécir"] = function()
    local item = garment()
    local upType, upCount = MTIR.getResizeMaterial(item, true)
    local downType, downCount = MTIR.getResizeMaterial(item, false)
    assertEq(upType, "Base.RippedSheets", "coton : bandes de tissu")
    assertTrue(upCount >= 1, "au moins une bande")
    assertEq(downType, "Base.Paperclip", "rétrécir : des trombones")
    assertTrue(downCount >= 1, "au moins un trombone")
end

T["taille visée : refusée si la taille est inconnue, déjà retouchée ou le vêtement cassé"] = function()
    local item = garment()
    item.modData.MTIR = { size = "M", reveal = true, resized = 0 }
    assertEq(MTIR.getResizeTarget(item, true).name, "L", "agrandir : taille suivante")
    assertEq(MTIR.getResizeTarget(item, false).name, "S", "rétrécir : taille précédente")

    item.modData.MTIR.reveal = false
    assertEq(MTIR.getResizeTarget(item, true), nil, "étiquette pas encore lue")
    item.modData.MTIR.reveal = true
    item.modData.MTIR.resized = 1
    assertEq(MTIR.getResizeTarget(item, true), nil, "déjà retouché")
    item.modData.MTIR.resized = 0
    item.broken = true
    assertEq(MTIR.getResizeTarget(item, true), nil, "vêtement cassé")
    item.broken = false
    item.modData.MTIR.size = nil
    assertEq(MTIR.getResizeTarget(item, true), nil, "taille à choisir")
end

T["exemplaire de rechange : même type, autre objet, ni porté ni en main"] = function()
    local item = garment()
    local spare = garment()
    assertTrue(MTIR.isValidSpare(item, spare), "deux t-shirts du même type")
    assertEq(MTIR.isValidSpare(item, item), false, "pas lui-même")
    assertEq(MTIR.isValidSpare(item, garment("Base.Trousers")), false, "type différent")
    spare.worn = true
    assertEq(MTIR.isValidSpare(item, spare), false, "porté")
    spare.worn = false
    spare.inHand = true
    assertEq(MTIR.isValidSpare(item, spare), false, "tenu en main")
    assertEq(MTIR.isValidSpare(item, nil), false, "aucun exemplaire")
end

--- Vêtement simulé : t-shirt en coton, avec ses données de taille.
local nextId = 0
garment = function(fullType)
    nextId = nextId + 1
    local item = { class = "Clothing", modData = {}, id = nextId }
    function item:getFullType() return fullType or "Base.Tshirt_White" end
    function item:getID() return self.id end
    function item:getModData() return self.modData end
    function item:hasModData() return true end
    function item:isBroken() return self.broken == true end
    function item:getCondition() return 50 end
    function item:getConditionMax() return 100 end
    function item:isEquipped() return self.worn == true or self.inHand == true end
    function item:getBodyLocation() return "Tshirt" end
    function item:getFabricType() return "Cotton" end
    function item:getScriptItem() return self end
    function item:getItemType() return ItemType.CLOTHING end
    function item:isCosmetic() return false end
    function item:getFullName() return self:getFullType() end
    function item:getBloodClothingType() return nil end
    return item
end

return T
