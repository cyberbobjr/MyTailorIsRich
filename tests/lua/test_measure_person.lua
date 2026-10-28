-- MTIR_MeasurePersonAction : prendre les mesures au mètre ruban (I01).
-- Le ruban ne fait qu'informer : la taille et la pointure de la cible sont dites au
-- joueur qui mesure, rien n'est enregistré. L'autorité revérifie ruban, cible vivante
-- et distance, car le serveur n'appelle jamais isValid.

local T = {}
if not hasVanilla then T.skip = "Lua vanilla absent (ISBaseTimedAction 42.21)" end

local MEASURER, SAID, ONLINE, SERVER

--- Personnage simulé : position, pointure et taille fournies par le banc.
local function character(name, x, y, z, onlineId, playerNum)
    local o = { name = name, x = x or 0, y = y or 0, z = z or 0,
        onlineId = onlineId or -1, playerNum = playerNum or 0, dead = false,
        size = "M", shoeSize = 42, inventory = {} }
    function o:getX() return self.x end
    function o:getY() return self.y end
    function o:getZ() return self.z end
    function o:isDead() return self.dead end
    function o:getOnlineID() return self.onlineId end
    function o:getPlayerNum() return self.playerNum end
    function o:getDisplayName() return self.name end
    function o:faceThisObject() end
    function o:isTimedActionInstant() return false end
    function o:getInventory() return { items = self.inventory } end
    return o
end

function T.setup()
    SAID = {}
    SERVER = false
    ONLINE = {}
    isServer = function() return SERVER end
    isClient = function() return false end
    getNumActivePlayers = function() return 1 end
    getSpecificPlayer = function(i) return i == 0 and MEASURER or nil end
    getOnlinePlayers = function()
        return {
            size = function() return #ONLINE end,
            get = function(_, i) return ONLINE[i + 1] end,
        }
    end
    instanceof = function(o, class) return type(o) == "table" and o.class == class end
    CharacterActionAnims = { Craft = "Craft" }
    ISBaseObject = {}
    function ISBaseObject:derive(name)
        local derived = { Type = name }
        self.__index = self
        return setmetatable(derived, self)
    end
    LuaTimedActionNew = { new = function() return {} end }

    MTIR = {
        MEASURE_REACH = 2,
        MEASURE_PERSON_DURATION = 60,
        opt = function() return 1 end,
        resolveItem = function(_, item) return item end,
        predicateMeasuringTape = function(item) return item ~= nil and item.tape == true end,
        getPlayerSize = function(player) return { name = player.size } end,
        getPlayerShoeSize = function(player) return player.shoeSize end,
        tell = function(_, fx) table.insert(SAID, fx.say) end,
    }
    assertTrue(loadVanilla("shared/TimedActions/ISBaseTimedAction.lua"))
    loadMod("shared/MyTailorIsRich/MTIR_ActionBase.lua")
    loadMod("shared/TimedActions/MTIR_MeasurePersonAction.lua")

    MEASURER = character("Benjamin", 10, 10, 0, 1, 0)
end

local function tape()
    local item = { tape = true }
    function item:setJobType() end
    function item:setJobDelta() end
    return item
end

local function measure(target, withTape)
    local action = MTIR_MeasurePersonAction:new(MEASURER, withTape ~= false and tape() or {}, target)
    return action, action:complete()
end

T["se mesurer soi-même : taille et pointure dites"] = function()
    MEASURER.size, MEASURER.shoeSize = "L", 44
    local _, done = measure(MEASURER)
    assertTrue(done, "mesure faite")
    assertEq(#SAID, 1, "une réplique")
    assertEq(SAID[1].key, "IGUI_MTIR_Say_Measured_Self", "réplique pour soi")
    assertEq(SAID[1].arg, "L", "taille")
    assertEq(SAID[1].arg2, "44", "pointure")
end

T["mesurer un voisin : son nom, sa taille et sa pointure"] = function()
    local friend = character("Ami", 11, 10, 0, 2, 1)
    friend.size, friend.shoeSize = "S", 39
    getNumActivePlayers = function() return 2 end
    getSpecificPlayer = function(i)
        if i == 0 then return MEASURER end
        return i == 1 and friend or nil
    end
    local _, done = measure(friend)
    assertTrue(done, "mesure faite")
    assertEq(SAID[1].key, "IGUI_MTIR_Say_Measured_Other", "réplique pour un tiers")
    assertEq(SAID[1].arg, "Ami", "nom")
    assertEq(SAID[1].arg2, "S", "taille")
    assertEq(SAID[1].arg3, "39", "pointure")
end

T["serveur : la cible est retrouvée par son identifiant de connexion"] = function()
    SERVER = true
    local friend = character("Ami", 11, 10, 0, 7, 0)
    friend.size, friend.shoeSize = "XL", 46
    ONLINE = { MEASURER, friend }
    local _, done = measure(friend)
    assertTrue(done, "mesure faite sur le serveur")
    assertEq(SAID[1].arg2, "XL", "taille de la cible, pas celle du mesureur")
end

T["cible partie, trop loin, morte ou à un autre étage : rien"] = function()
    SERVER = true
    local friend = character("Ami", 11, 10, 0, 7, 0)
    ONLINE = {}
    local _, gone = measure(friend)
    assertEq(gone, false, "cible déconnectée")

    ONLINE = { friend }
    friend.x = 14
    assertEq(select(2, measure(friend)), false, "trop loin")
    friend.x, friend.z = 11, 1
    assertEq(select(2, measure(friend)), false, "autre étage")
    friend.z = 0
    friend.dead = true
    assertEq(select(2, measure(friend)), false, "cible morte")
    assertEq(#SAID, 0, "aucune réplique")
end

T["sans mètre ruban : la mesure est refusée"] = function()
    assertEq(select(2, measure(MEASURER, false)), false, "objet qui n'est pas un ruban")
    assertEq(#SAID, 0, "aucune réplique")
end

T["durée : le multiplicateur du bac à sable s'applique"] = function()
    local action = MTIR_MeasurePersonAction:new(MEASURER, tape(), MEASURER)
    assertEq(action:getDuration(), 60, "durée de base")
    MTIR.opt = function() return 0 end
    assertEq(action:getDuration(), 1, "jamais moins d'un tick")
end

return T
