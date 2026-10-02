-- Collecte réelle du menu et file vanilla : retrait, accès, hints et autorité.
local T = {}
if not hasVanilla then T.skip = "Lua vanilla absent (test de la file 42.21)" end

local function javaList(values)
    local list = { values = values or {} }
    function list:size() return #self.values end
    function list:get(i) return self.values[i + 1] end
    function list:contains(value)
        for _, entry in ipairs(self.values) do if entry == value then return true end end
        return false
    end
    return list
end

local function square(x, y, z)
    local sq = { x = x, y = y, z = z or 0, objects = javaList(), reachable = true }
    function sq:getX() return self.x end
    function sq:getY() return self.y end
    function sq:getZ() return self.z end
    function sq:getStaticMovingObjects() return self.objects end
    function sq:canReachTo(other)
        return other.reachable and math.abs(self.x - other.x) <= 1
            and math.abs(self.y - other.y) <= 1 and self.z == other.z
    end
    SQUARES[x .. ":" .. y .. ":" .. sq.z] = sq
    return sq
end

local function corpse(sq, animal)
    local parent = { class = "IsoDeadBody", square = sq, animal = animal }
    function parent:getSquare() return self.square end
    function parent:isAnimal() return self.animal == true end
    local container = { parent = parent, items = javaList(), accessible = true }
    function container:getParent() return self.parent end
    function container:getType() return "corpse" end
    function container:getItems() return self.items end
    function container:getContainingItem() return nil end
    function container:getVehiclePart() return nil end
    function container:isInCharacterInventory(character) return self.owner == character end
    function parent:getContainer() return container end
    table.insert(sq.objects.values, parent)
    return container
end

local function garment(container, data, shoe)
    NEXT_ID = NEXT_ID + 1
    local item = { id = NEXT_ID, container = container, data = data, shoe = shoe, sized = true }
    function item:getID() return self.id end
    function item:getContainer() return self.container end
    if container then table.insert(container.items.values, item) end
    return item
end

local function remove(item)
    local values = item.container.items.values
    for i, value in ipairs(values) do
        if value == item then table.remove(values, i) break end
    end
    item.container = nil
end

local function context()
    local ctx = { options = {} }
    function ctx:addOption(name, target, callback, arg)
        local option = { name = name, target = target, callback = callback, arg = arg }
        table.insert(self.options, option)
        return option
    end
    function ctx:getNew() return context() end
    function ctx:addSubMenu(option, sub) option.subMenu = sub end
    return ctx
end

function T.setup()
    SQUARES, NEXT_ID, CLIENT, SERVER, XP, SYNCS, TELLS = {}, 0, false, false, 0, 0, 0
    OPTIONS = { NeedTailoringLevel = true, TailoringXpMultiplier = 1 }
    Perks = { Tailoring = "Tailoring" }
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    instanceof = function(value, class)
        return value and (value.class == class or (class == "IsoGameCharacter" and value.class == "IsoPlayer"))
    end
    SafeHouse = { isSafehouseAllowLoot = function(sq) return not sq.protected end }
    getCell = function()
        return { getGridSquare = function(_, x, y, z) return SQUARES[x .. ":" .. y .. ":" .. z] end }
    end
    getText = function(key) return key end
    addXp = function(_, _, amount) XP = XP + amount end
    PLAYER = { class = "IsoPlayer", x = 10.5, y = 10.5, z = 0, level = 0, begins = 0 }
    PLAYER.square = square(10, 10)
    function PLAYER:getX() return self.x end
    function PLAYER:getY() return self.y end
    function PLAYER:getZ() return self.z end
    function PLAYER:getCurrentSquare() return self.square end
    function PLAYER:canAccessContainer(c) return c.accessible end
    function PLAYER:getPerkLevel() return self.level end
    function PLAYER:isTimedActionInstant() return true end
    function PLAYER:isAsleep() return false end
    function PLAYER:isLocalPlayer() return false end
    function PLAYER:isFarming() return false end
    function PLAYER:setTimedActionToRetrigger() end
    function PLAYER:StartAction() self.begins = self.begins + 1 end
    MTIR = {
        canShoeHaveSize = function(item) return item and item.sized and item.shoe == true end,
        canClothesHaveSize = function(item) return item and item.sized and not item.shoe end,
        getShoeData = function(item) return item.data end,
        getData = function(item) return item.data end,
        opt = function(key) return OPTIONS[key] end,
        getRequiredLevelToCheck = function(item) return item.requiredLevel or 0 end,
        resolveItem = function(_, item) return item end,
        syncItem = function() SYNCS = SYNCS + 1 end,
        tell = function() TELLS = TELLS + 1 end,
        ensureData = function(item)
            item.data = item.data or { size = "M", reveal = false }
            return item.data
        end,
        ensureShoeData = function(item)
            item.data = item.data or { size = 42, reveal = false }
            return item.data
        end,
        getClothesSizeFromName = function(name) return { name = name } end,
        getPlayerSize = function() return {} end,
        getSizeDiff = function() return 0 end,
        getPlayerShoeSize = function() return 42 end,
        getShoeDiff = function() return 0 end,
        pickLabelSay = function() return {} end,
        pickHintSay = function() return {} end,
        pickShoeLabelSay = function() return {} end,
    }
    ISBaseObject = {}
    function ISBaseObject:derive(name)
        local derived = { Type = name }
        self.__index = self
        return setmetatable(derived, self)
    end
    LuaTimedActionNew = { new = function() return {} end }
    local state = { instance = function() return {} end }
    ClimbThroughWindowState, ClimbOverFenceState, ClimbOverWallState = state, state, state
    ClimbSheetRopeState, ClimbDownSheetRopeState, CloseWindowState, OpenWindowState = state, state, state, state
    assertTrue(loadVanilla("shared/TimedActions/ISBaseTimedAction.lua"))
    assertTrue(loadVanilla("client/TimedActions/ISTimedActionQueue.lua"))
    loadMod("shared/MyTailorIsRich/MTIR_Reach.lua")
    loadMod("shared/MyTailorIsRich/MTIR_LabelCheck.lua")
    loadMod("shared/TimedActions/MTIR_CheckSizeAction.lua")
    loadMod("client/MyTailorIsRich/MTIR_CheckSizeMenu.lua")
end

T["cadavre : vêtements et chaussures inconnus, sans doublons ni objets divers"] = function()
    local c = corpse(PLAYER.square)
    local shirt, shoes = garment(c), garment(c, nil, true)
    garment(c, { reveal = true })
    garment(c).sized = false
    local found = MTIR.CheckSizeMenu.collectCorpseItems(PLAYER, { c, c })
    assertEq(#found, 2)
    assertEq(found[1].item, shirt)
    assertEq(found[2].item, shoes)
    assertEq(shirt.container, c, "pas de transfert")
    assertEq(shirt.data, nil, "aucune initialisation client")
end

T["proximité : plusieurs corps accessibles, pas derrière un mur ni loin ni à un autre étage"] = function()
    garment(corpse(PLAYER.square))
    garment(corpse(square(11, 10)), nil, true)
    local blocked = square(10, 11)
    blocked.reachable = false
    garment(corpse(blocked))
    garment(corpse(square(12, 10)))
    garment(corpse(square(10, 10, 1)))
    garment(corpse(square(9, 10), true))
    local locked = corpse(square(10, 9))
    locked.accessible = false
    garment(locked)
    assertEq(#MTIR.CheckSizeMenu.collectNearbyItems(PLAYER), 2)
end

T["zone protégée : exclue en client et par l'autorité serveur"] = function()
    local sq = square(11, 10)
    sq.protected = true
    local c = corpse(sq)
    local item = garment(c)
    CLIENT = true
    assertEq(#MTIR.CheckSizeMenu.collectNearbyItems(PLAYER), 0)
    CLIENT, SERVER = false, true
    assertEq(MTIR_CheckSizeAction:new(PLAYER, item, c):complete(), false)
    assertEq(SYNCS, 0)
end

T["indice : groupe ignoré sans progrès, lecture manuelle permise, reprise après progression"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c, { size = "M", hint = true })
    item.requiredLevel = 2
    assertEq(#MTIR.CheckSizeMenu.collectCorpseItems(PLAYER, { c }), 0)
    assertTrue(MTIR.needsSizeCheck(item), "lecture manuelle")
    PLAYER.level = 2
    assertEq(#MTIR.CheckSizeMenu.collectCorpseItems(PLAYER, { c }), 1)
    PLAYER.level = 0
    OPTIONS.NeedTailoringLevel = false
    assertEq(#MTIR.CheckSizeMenu.collectCorpseItems(PLAYER, { c }), 1)
end

T["menu : trois choix sur cadavre, collecte renouvelée au clic et aucun déplacement"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c)
    local ctx, selection = context(), function() end
    MTIR.CheckSizeMenu.addOptions({ item }, PLAYER, ctx, selection)
    local options = ctx.options[1].subMenu.options
    assertEq(#options, 3)
    assertEq(options[1].callback, selection)
    assertEq(options[2].name, "IGUI_MTIR_CheckSize_Corpse")
    assertEq(options[3].name, "IGUI_MTIR_CheckSize_Nearby")
    remove(item)
    local replacement = garment(c)
    options[2].callback(options[2].target, options[2].arg)
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    assertEq(#queue.queue, 1)
    assertEq(queue.current.item, replacement)
    assertEq(queue.current.corpseContainer, c)
    assertEq(replacement.container, c)
    assertEq(PLAYER.x, 10.5)
end

T["vêtement déjà révélé : permet toujours le menu du cadavre et des alentours"] = function()
    local c = corpse(PLAYER.square)
    local known = garment(c, { reveal = true })
    garment(c)
    local ctx = context()
    MTIR.CheckSizeMenu.addOptions({ known }, PLAYER, ctx, function() end)
    local options = ctx.options[1].subMenu.options
    assertEq(#options, 2)
    assertEq(options[1].name, "IGUI_MTIR_CheckSize_Corpse")
end

T["vêtement hors cadavre : sélection et alentours seulement"] = function()
    local ctx = context()
    MTIR.CheckSizeMenu.addOptions({ garment(nil) }, PLAYER, ctx, function() end)
    local options = ctx.options[1].subMenu.options
    assertEq(#options, 2)
    assertEq(options[2].name, "IGUI_MTIR_CheckSize_Nearby")
    assertTrue(options[2].notAvailable)
end

T["file vanilla : vêtement retiré avant son tour ignoré, le suivant démarre"] = function()
    local c = corpse(PLAYER.square)
    local a, b, d = garment(c), garment(c), garment(c)
    local first = MTIR_CheckSizeAction:new(PLAYER, a, c)
    ISTimedActionQueue.add(first)
    ISTimedActionQueue.add(MTIR_CheckSizeAction:new(PLAYER, b, c))
    local last = MTIR_CheckSizeAction:new(PLAYER, d, c)
    ISTimedActionQueue.add(last)
    remove(b)
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    queue:onCompleted(first)
    assertEq(queue.current, last)
    assertEq(#queue.queue, 1)
    assertEq(PLAYER.begins, 2)
end

T["file vanilla : mille lectures retirées ne provoquent ni récursion ni annulation"] = function()
    local c = corpse(PLAYER.square)
    local first = MTIR_CheckSizeAction:new(PLAYER, garment(c), c)
    ISTimedActionQueue.add(first)
    local removed = {}
    for _ = 1, 1000 do
        local item = garment(c)
        removed[#removed + 1] = item
        ISTimedActionQueue.add(MTIR_CheckSizeAction:new(PLAYER, item, c))
    end
    local last = MTIR_CheckSizeAction:new(PLAYER, garment(c), c)
    ISTimedActionQueue.add(last)
    for _, item in ipairs(removed) do remove(item) end
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    queue:onCompleted(first)
    assertEq(queue.current, last)
    assertEq(#queue.queue, 1)
end

T["retrait avant le premier démarrage : file vide proprement, sans démarrer la lecture"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c)
    local action = MTIR_CheckSizeAction:new(PLAYER, item, c)
    remove(item)
    ISTimedActionQueue.add(action)
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    assertEq(#queue.queue, 0)
    assertEq(queue.current, nil)
    assertEq(PLAYER.begins, 0)
end

T["file vanilla : dernière lecture retirée, fin propre ou poursuite d'une autre action"] = function()
    local c = corpse(PLAYER.square)
    local first = MTIR_CheckSizeAction:new(PLAYER, garment(c), c)
    local removed = garment(c)
    ISTimedActionQueue.add(first)
    ISTimedActionQueue.add(MTIR_CheckSizeAction:new(PLAYER, removed, c))
    remove(removed)
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    queue:onCompleted(first)
    assertEq(#queue.queue, 0)
    assertEq(queue.current, nil)

    first = MTIR_CheckSizeAction:new(PLAYER, garment(c), c)
    removed = garment(c)
    ISTimedActionQueue.add(first)
    ISTimedActionQueue.add(MTIR_CheckSizeAction:new(PLAYER, removed, c))
    local other = { Type = "OtherAction", character = PLAYER, isValidStart = function() return true end }
    function other:begin() self.begun = true end
    ISTimedActionQueue.add(other)
    remove(removed)
    queue:onCompleted(first)
    assertEq(queue.current, other)
    assertTrue(other.begun, "une action indépendante est conservée")
end

T["conteneur de cadavre introuvable au décodage MP : lecture refusée"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c)
    local action = MTIR_CheckSizeAction:new(PLAYER, item, c)
    action.corpseContainer = nil
    assertEq(action:canBeginCheck(), false)
    SERVER = true
    assertEq(action:complete(), false)
    assertEq(SYNCS, 0)
end

T["vêtement changé de conteneur ou disparu de la liste : pas de lecture groupée"] = function()
    local c, other = corpse(PLAYER.square), corpse(square(11, 10))
    local item = garment(c)
    local action = MTIR_CheckSizeAction:new(PLAYER, item, c)
    remove(item)
    item.container = other
    table.insert(other.items.values, item)
    assertEq(action:canBeginCheck(), false)
    assertEq(action:complete(), false)
    item.container = c
    assertEq(action:canBeginCheck(), false, "référence périmée hors liste du conteneur")
end

T["autre joueur révèle avant le tour : lecture ignorée, action suivante conservée"] = function()
    local c = corpse(PLAYER.square)
    local a, b, d = garment(c), garment(c), garment(c)
    local first = MTIR_CheckSizeAction:new(PLAYER, a, c)
    ISTimedActionQueue.add(first)
    ISTimedActionQueue.add(MTIR_CheckSizeAction:new(PLAYER, b, c))
    local last = MTIR_CheckSizeAction:new(PLAYER, d, c)
    ISTimedActionQueue.add(last)
    b.data = { reveal = true }
    local queue = ISTimedActionQueue.getTimedActionQueue(PLAYER)
    queue:onCompleted(first)
    assertEq(queue.current, last)
end

T["retrait pendant l'action MP : aucune révélation ni XP ni notification serveur"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c)
    local action = MTIR_CheckSizeAction:new(PLAYER, item, c)
    CLIENT, action.started = true, true
    remove(item)
    assertTrue(action:isValid(), "le client laisse l'autorité terminer sans vider la file")
    CLIENT, SERVER = false, true
    assertEq(action:complete(), false)
    assertEq(XP, 0)
    assertEq(SYNCS, 0)
    assertEq(TELLS, 0)
end

T["complétion : règles de taille, première XP, indice et pointure conservés"] = function()
    local c = corpse(PLAYER.square)
    local item = garment(c)
    local action = MTIR_CheckSizeAction:new(PLAYER, item, c)
    assertTrue(action:complete())
    assertTrue(item.data.reveal)
    assertEq(XP, 0.5)
    assertTrue(action:complete())
    assertEq(XP, 0.5, "pas d'XP répétée")
    local hard = garment(c)
    hard.requiredLevel = 2
    assertTrue(MTIR_CheckSizeAction:new(PLAYER, hard, c):complete())
    assertTrue(hard.data.hint)
    assertEq(hard.data.reveal, false)
    local shoes = garment(c, nil, true)
    assertTrue(MTIR_CheckSizeAction:new(PLAYER, shoes, c):complete())
    assertTrue(shoes.data.reveal)
    assertEq(XP, 0.5, "chaussures sans XP")
end

return T
