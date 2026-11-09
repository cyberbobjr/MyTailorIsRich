-- MTIR_SewingMachine : courant de la machine électrique quand LiveWire Extended est
-- chargé (D-38 de Live Wire). Un disjoncteur d'un tableau Extended peut couper la
-- machine alors que sa case a du courant : le test de courant interroge alors
-- LiveWire.Extended.isCut(machine). Sans Live Wire, rien ne change.

local T = {}

local function square(power)
    local sq = { power = power }
    function sq:haveElectricity() return self.power end
    function sq:hasGridPower() return false end
    function sq:getRoom() return nil end
    return sq
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    MTIR = nil
    LiveWire = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.SEW_BY_HAND = { durationFactor = 1, levelBonus = 0, precisionBonus = 0, threadFactor = 1 }
    loadMod("shared/MyTailorIsRich/MTIR_SewingMachine.lua")
end

T["sans Live Wire : le courant de la case suffit"] = function()
    assertTrue(MTIR.hasSewingPower(square(true), {}), "case alimentée")
    assertEq(MTIR.hasSewingPower(square(false), {}), false, "case sans courant")
end

T["Live Wire sans Extended : rien ne change"] = function()
    LiveWire = {}
    assertTrue(MTIR.hasSewingPower(square(true), {}), "case alimentée")
end

T["disjoncteur ouvert : machine sans courant"] = function()
    local machine = {}
    LiveWire = { Extended = { isCut = function(o) return o == machine end } }
    assertEq(MTIR.hasSewingPower(square(true), machine), false, "machine coupée")
    assertTrue(MTIR.hasSewingPower(square(true), {}), "autre machine")
end

T["sans machine désignée : seul le courant de la case compte"] = function()
    LiveWire = { Extended = { isCut = function() return true end } }
    assertTrue(MTIR.hasSewingPower(square(true)), "ancien appel")
end

return T
