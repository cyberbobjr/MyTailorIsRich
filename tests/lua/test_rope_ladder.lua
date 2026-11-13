-- Corde de draps et échelle (42.22 : ClimbState monte, ClimbDownState descend).
-- Départ : un seul tirage d'accrocs et de chaussure par l'autorité, même si le
-- personnage change de sens. Sortie d'échelle : pied qui glisse (chaussures trop
-- grandes, chaussettes seules). Haut de corde : pantalon trop grand sans ceinture qui
-- fait trébucher à l'arrivée par la fenêtre. Chaussure perdue : elle tombe en bas.

local T = {}

local PLAYER, SENT, ROLL

local function state(class)
    return { class = class }
end

local CLIMB_UP, CLIMB_DOWN = state("ClimbState"), state("ClimbDownState")
local WINDOW, IDLE = state("ClimbThroughWindowState"), state("IdleState")

local function item(location, diff, opts)
    opts = opts or {}
    return { location = location, diff = diff, drop = opts.drop == true }
end

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    ItemBodyLocation = { SHOES = "shoes" }
    instanceof = function(o, class) return type(o) == "table" and o.class == class end
    isServer = function() return false end
    isClient = function() return false end
    isDebugEnabled = function() return false end
    getText = function(key) return key end
    ZombRand = function() return 0 end
    ROLL = 0
    ZombRandFloat = function() return ROLL end
    SENT = {}
    sendClientCommand = function(_, module, command, args)
        table.insert(SENT, { module = module, command = command, args = args })
    end
    ISInventoryTransferAction = { perform = function() end }

    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    MTIR.locKey = function(i) return i.location end
    MTIR.getPlayerSize = function() return MTIR.SIZES.L end
    MTIR.canClothesHaveSize = function(i) return i.diff ~= nil end
    MTIR.canClothesDrop = function(i) return i.drop end
    MTIR.increasesTrip = function() return false end
    MTIR.getItemDiff = function(i) return i.diff end
    MTIR.getShoeTripChance = function(p) return p.shoeTrip or 0 end
    MTIR.isInSocksOnly = function(p) return p.socksOnly == true end
    loadMod("client/MyTailorIsRich/MTIR_ClientEvents.lua")

    PLAYER = { class = "IsoPlayer", worn = {}, said = {}, tripped = 0, ladder = false }
    function PLAYER:isLocalPlayer() return true end
    function PLAYER:getPlayerNum() return 0 end
    function PLAYER:isDead() return false end
    function PLAYER:isClimbingLadder() return self.ladder end
    function PLAYER:isClimbingDownLadder() return self.ladder end
    function PLAYER:getVariableString() return nil end
    function PLAYER:getVariableBoolean() return false end
    function PLAYER:getWornItems()
        local worn = self.worn
        return {
            size = function() return #worn end,
            getItemByIndex = function(_, i) return worn[i + 1] end,
        }
    end
    function PLAYER:Say(text) table.insert(self.said, text) end
    function PLAYER:setVariable() end
    function PLAYER:clearVariable() end
    function PLAYER:setBumpType() end
    function PLAYER:setBumpFall() end
    function PLAYER:setBumpFallType() end
    function PLAYER:reportEvent(event)
        if event == "wasBumped" then self.tripped = self.tripped + 1 end
    end
end

local function change(newState, previousState)
    triggerEvent("OnAIStateChange", PLAYER, newState, previousState)
end

local function climbCommands()
    local out = {}
    for _, sent in ipairs(SENT) do
        if sent.command == "climb" then table.insert(out, sent.args.kind) end
    end
    return out
end

T["corde et échelle : un seul tirage au départ, à la montée comme à la descente"] = function()
    change(CLIMB_UP, IDLE)
    change(CLIMB_DOWN, CLIMB_UP)
    change(IDLE, CLIMB_DOWN)
    PLAYER.ladder = true
    change(CLIMB_DOWN, IDLE)
    local kinds = climbCommands()
    assertEq(#kinds, 2, "deux escalades")
    assertEq(kinds[1], "rope", "corde à la montée")
    assertEq(kinds[2], "ladderDown", "échelle à la descente")
end

T["pantalon trop grand sans ceinture : trébuchement à l'arrivée par la fenêtre"] = function()
    PLAYER.worn = { item("pants", 2, { drop = true }) }
    assertEq(MTIR.getClimbTripChance(PLAYER, "ropeTop"), 5, "5 % par cran, moitié moins")
    change(CLIMB_UP, IDLE)
    change(WINDOW, CLIMB_UP)
    assertEq(PLAYER.tripped, 0, "pas pendant la fenêtre")
    change(IDLE, WINDOW)
    assertEq(PLAYER.tripped, 1, "à l'arrivée")
    assertEq(PLAYER.said[1], "IGUI_MTIR_Say_RopePants0", "phrase du pantalon")
end

T["pantalon : une ceinture ou la bonne taille, aucun risque"] = function()
    PLAYER.worn = { item("pants", 2, { drop = true }), item("belt") }
    assertEq(MTIR.getClimbTripChance(PLAYER, "ropeTop"), 0, "ceinture")
    PLAYER.worn = { item("pants", 0, { drop = true }) }
    assertEq(MTIR.getClimbTripChance(PLAYER, "ropeTop"), 0, "bonne taille")
    PLAYER.worn = { item("tshirt", 2) }
    assertEq(MTIR.getClimbTripChance(PLAYER, "ropeTop"), 0, "un haut ne glisse pas")
end

T["descente de corde : pas de trébuchement à l'arrivée"] = function()
    PLAYER.worn = { item("pants", 3, { drop = true }) }
    change(CLIMB_DOWN, IDLE)
    change(IDLE, CLIMB_DOWN)
    assertEq(PLAYER.tripped, 0, "aucun")
end

T["échelle : chaussures trop grandes ou chaussettes seules font glisser le pied"] = function()
    assertEq(MTIR.getClimbTripChance(PLAYER, "ladder"), 0, "bien chaussé")
    PLAYER.shoeTrip = 10
    assertEq(MTIR.getClimbTripChance(PLAYER, "ladder"), 5, "chaussures : moitié du risque")
    PLAYER.shoeTrip = 0
    PLAYER.socksOnly = true
    assertEq(MTIR.getClimbTripChance(PLAYER, "ladderDown"), 2.5, "chaussettes seules")
    PLAYER.ladder = true
    change(CLIMB_UP, IDLE)
    change(IDLE, CLIMB_UP)
    assertEq(PLAYER.tripped, 1, "trébuche en quittant l'échelle")
    assertEq(PLAYER.said[1], "IGUI_MTIR_Say_LadderSlip0", "phrase de l'échelle")
end

T["échelle : changer de sens ne fait pas trébucher"] = function()
    PLAYER.socksOnly = true
    PLAYER.ladder = true
    change(CLIMB_UP, IDLE)
    change(CLIMB_DOWN, CLIMB_UP)
    assertEq(PLAYER.tripped, 0, "toujours sur l'échelle")
end

return T
