-- Broderie sur machine à coudre (MTIR_Embroidery, avec les bonus réels de
-- MTIR_SewingMachine) : niveau requis et niveau retenu selon la machine, fil,
-- durée et chance d'une machine usée.

local T = {}

local OPTIONS

--- Machine posée simulée : nom de tuile et état (ModData movableData), ou neuve.
local function machine(prefix, condition)
    local modData = condition and { movableData = { mtirCondition = condition } } or nil
    return {
        getSprite = function()
            return { getName = function() return prefix .. "0" end }
        end,
        hasModData = function() return modData ~= nil end,
        getModData = function() return modData end,
    }
end

function T.setup()
    OPTIONS = {}
    SandboxVars = { MyTailorIsRich = OPTIONS }
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Embroidery.lua")
    ELECTRIC = machine("mtir_sewing_01_")
    TREADLE = machine("mtir_treadle_01_")
end

local function levels(tailoring, object)
    local kindName = MTIR.getMachineKindName(object)
    local mods = MTIR.getMachineMods(object)
    return MTIR.getMachineEmbroideryLevel(tailoring, kindName, mods), MTIR.getMachineEmbroideryRequiredLevel(kindName)
end

T["électrique : niveau de la main, bonus de la machine compté"] = function()
    local level, required = levels(0, ELECTRIC)
    assertEq(required, MTIR.EMBROIDERY_LEVEL, "seuil de la main")
    assertEq(level, 2, "Couture 0 + bonus 2")
    assertTrue(level >= required, "brode dès Couture 0 grâce au bonus")
    OPTIONS.MachineBonusMultiplier = 0
    level = levels(0, ELECTRIC)
    assertEq(level, 0, "bonus désactivé")
end

T["pédale : Couture 3 au niveau réel, bonus non compté"] = function()
    local level, required = levels(2, TREADLE)
    assertEq(required, 3, "seuil de la machine à pédale")
    assertEq(MTIR.EMBROIDERY_TREADLE_LEVEL, 3, "constante")
    assertEq(level, 2, "le bonus de la machine (1) ne compte pas")
    assertTrue(level < required, "Couture 2 ne suffit pas")
    level = levels(3, TREADLE)
    assertTrue(level >= required, "Couture 3 suffit")
end

T["NeedTailoringLevel désactivée : aucun niveau requis"] = function()
    OPTIONS.NeedTailoringLevel = false
    assertEq(MTIR.getMachineEmbroideryRequiredLevel("treadle"), 0, "pédale")
    assertEq(MTIR.getMachineEmbroideryRequiredLevel("electric"), 0, "électrique")
    assertEq(MTIR.getMachineEmbroideryRequiredLevel(nil), 0, "main")
end

T["fil : formule des autres travaux, au moins une utilisation"] = function()
    local electric = MTIR.getMachineMods(ELECTRIC)
    local treadle = MTIR.getMachineMods(TREADLE)
    assertEq(electric.threadFactor, 0.7, "30 % de fil en moins")
    assertEq(treadle.threadFactor, 0.85, "15 % de fil en moins")
    assertEq(MTIR.getMachineEmbroideryThread(nil), MTIR.EMBROIDERY_THREAD, "main")
    -- La broderie à la main ne coûte qu'une utilisation : arrondie au-dessus, elle reste 1.
    assertEq(MTIR.getMachineEmbroideryThread(electric), 1, "électrique")
    assertEq(MTIR.getMachineEmbroideryThread(treadle), 1, "pédale")
    MTIR.EMBROIDERY_THREAD = 10
    assertEq(MTIR.getMachineEmbroideryThread(electric), 7, "électrique, 10 utilisations")
    assertEq(MTIR.getMachineEmbroideryThread(treadle), 9, "pédale, 10 utilisations (8,5 arrondi)")
end

T["durée : deux fois plus rapide (électrique), 25 % (pédale)"] = function()
    local text = "Bob"
    local hand = MTIR.getEmbroideryDuration(text)
    assertEq(hand, 80 + 10 * 3, "durée à la main")
    assertEq(MTIR.getMachineEmbroideryDuration(text, nil), hand, "main")
    assertEq(MTIR.getMachineEmbroideryDuration(text, MTIR.getMachineMods(ELECTRIC)), hand / 2, "électrique")
    assertEq(MTIR.getMachineEmbroideryDuration(text, MTIR.getMachineMods(TREADLE)), hand * 0.75, "pédale")
    OPTIONS.ActionTimeMultiplier = 2
    assertEq(MTIR.getMachineEmbroideryDuration(text, MTIR.getMachineMods(ELECTRIC)), hand, "option de durée appliquée")
end

T["chance : sûre, sauf machine usée sous 50 %"] = function()
    assertEq(MTIR.getMachineEmbroiderySuccess(nil), 1, "main")
    assertEq(MTIR.getMachineEmbroiderySuccess(MTIR.getMachineMods(ELECTRIC)), 1, "machine neuve")
    OPTIONS.EnableMachineMaintenance = true
    local worn = machine("mtir_sewing_01_", 30)
    local chance = MTIR.getMachineEmbroiderySuccess(MTIR.getMachineMods(worn))
    assertTrue(math.abs(chance - 0.8) < 1e-9, "machine à 30 % : -20 %, obtenu " .. tostring(chance))
    local fine = machine("mtir_treadle_01_", 60)
    assertEq(MTIR.getMachineEmbroiderySuccess(MTIR.getMachineMods(fine)), 1, "au-dessus de 50 % : aucun malus")
end

return T
