-- MTIR_Reach : lecture d'étiquette sur soi, sur place (cadavre, meuble,
-- véhicule) à portée, jamais au sol ni chez un autre personnage.

local T = {}

local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
end

local function object(class, sq)
    return { class = class, getSquare = function() return sq end }
end

local function container(opts)
    local c = {}
    function c:getType() return opts.type or "crate" end
    function c:getParent() return opts.parent end
    function c:getContainingItem() return opts.containingItem end
    function c:getVehiclePart() return opts.part end
    function c:isInCharacterInventory(chr) return opts.owner ~= nil and opts.owner == chr end
    return c
end

local function item(c)
    return { getContainer = function() return c end }
end

function T.setup()
    instanceof = function(obj, class)
        return type(obj) == "table" and (obj.class == class
            or (class == "IsoGameCharacter" and (obj.class == "IsoPlayer" or obj.class == "IsoZombie")))
    end
    LOCKED = false
    PLAYER = {
        class = "IsoPlayer", x = 10.5, y = 10.5, z = 0,
        getX = function(self) return self.x end,
        getY = function(self) return self.y end,
        getZ = function(self) return self.z end,
        getVehicle = function(self) return self.vehicle end,
        canAccessContainer = function() return not LOCKED end,
    }
    MTIR = {}
    loadMod("shared/MyTailorIsRich/MTIR_Reach.lua")
end

T["vêtement porté sur soi (sac compris) : toujours lisible"] = function()
    local bag = container({ owner = PLAYER })
    assertTrue(MTIR.isCarried(PLAYER, item(bag)), "porté")
    PLAYER.x = 500
    assertTrue(MTIR.canReachItem(PLAYER, item(bag)), "lisible de loin")
end

T["cadavre à portée : lisible sur place, pas trop loin"] = function()
    local corpse = container({ parent = object("IsoDeadBody", square(11, 11, 0)) })
    local clothes = item(corpse)
    assertEq(MTIR.isCarried(PLAYER, clothes), false, "non porté")
    assertTrue(MTIR.getInPlaceContainer(clothes) == corpse, "sur place")
    assertTrue(MTIR.canReachItem(PLAYER, clothes), "à portée")
    PLAYER.x = 14.5
    assertEq(MTIR.canReachItem(PLAYER, clothes), false, "trop loin")
    PLAYER.x, PLAYER.z = 10.5, 1
    assertEq(MTIR.canReachItem(PLAYER, clothes), false, "autre étage")
end

T["meuble verrouillé : illisible"] = function()
    local crate = container({ parent = object("IsoObject", square(10, 11, 0)) })
    assertTrue(MTIR.canReachItem(PLAYER, item(crate)), "ouvert")
    LOCKED = true
    assertEq(MTIR.canReachItem(PLAYER, item(crate)), false, "verrouillé")
end

T["sol, sac posé, autre personnage : pas de lecture sur place"] = function()
    local floor = container({ type = "floor" })
    local worldBag = container({ parent = object("IsoObject", square(10, 10, 0)), containingItem = {} })
    local other = container({ parent = { class = "IsoPlayer" } })
    local orphan = container({})
    for name, c in pairs({ floor = floor, worldBag = worldBag, other = other, orphan = orphan }) do
        assertEq(MTIR.getInPlaceContainer(item(c)), nil, name)
        assertEq(MTIR.canReachItem(PLAYER, item(c)), false, name)
    end
    assertEq(MTIR.canReachItem(PLAYER, item(nil)), false, "sans conteneur")
    assertEq(MTIR.canReachItem(PLAYER, nil), false, "sans objet")
end

T["véhicule : accès du coffre et garde-fou de distance"] = function()
    local access = true
    local vehicle = {
        class = "BaseVehicle",
        getX = function() return 14 end, getY = function() return 10 end, getZ = function() return 0 end,
        canAccessContainer = function() return access end,
    }
    local part = { getVehicle = function() return vehicle end, getIndex = function() return 3 end }
    local trunk = item(container({ parent = vehicle, part = part }))
    assertTrue(MTIR.canReachItem(PLAYER, trunk), "coffre accessible")
    access = false
    assertEq(MTIR.canReachItem(PLAYER, trunk), false, "coffre inaccessible")
    access = true
    PLAYER.x = 40
    assertEq(MTIR.canReachItem(PLAYER, trunk), false, "trop loin")
    PLAYER.vehicle = vehicle
    assertTrue(MTIR.canReachItem(PLAYER, trunk), "assis dans le véhicule")
end

return T
