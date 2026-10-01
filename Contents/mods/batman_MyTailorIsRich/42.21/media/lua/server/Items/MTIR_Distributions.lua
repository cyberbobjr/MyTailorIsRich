-- ============================================================================
-- My Tailor Is Rich — butin : machines à coudre et patrons du commerce
-- Même mécanisme que les meubles vanilla trouvables (Mov_Microwave) : les objets
-- sont ajoutés à des listes procédurales. Le butin d'un conteneur se décide par
-- le couple salle × type de conteneur (ItemPickerJava.fillContainerInternal) :
-- salle[type], sinon salle.other, sinon salle.all, sinon la table globale all.
-- Un conteneur procédural tire UNE seule table de sa procList (weightChance,
-- max par pièce), puis chaque objet a (poids × 0,6 %) de chance par tirage
-- (type de butin « Other », option otherLootNew).
--
-- 1. Listes directes : TailoringTools (étagères des ateliers de couture),
--    SewingStoreTools (merceries), CrateTailoring (caisses de couture),
--    GigamartBedding (rayon linge des supermarchés et magasins généraux),
--    Antiques (machine à pédale, aussi en vitrine de prêteur sur gages),
--    TailoringLiterature, BookstoreFashion (patrons) ; classeurs à patrons dans
--    TailoringLiterature et SewingStoreTools.
--    Et partout où le jeu (ou un mod) pose un kit de couture (SewingKit :
--    salles de bain, commodes, placards, cuisines, buanderies…) : machine
--    électrique à SEWING_KIT_RATIO du poids du kit. Pas de machine à pédale dans
--    ces petits meubles : c'est un meuble entier de 30 kg.
-- 2. Table propre MTIR_SewingMachines insérée dans la procList de couples
--    salle × conteneur choisis (OnPostDistributionMerge) : garages séparés
--    (garagestorage), box de stockage (storageunit), greniers (attic), abris
--    (shed), réserves (storage), placards (closet), magasins de vêtements
--    (clothingstore, clothingstorage), grands magasins (departmentstore) et
--    réserve des merceries (tailoringstore.other).
-- 3. Garages attenants d'une maison : pièce « garage », alias de « mechanic »
--    (l'atelier de réparation automobile, SuburbsDistributions.lua:167). On NE
--    touche PAS à la table mechanic : un tirage à OnFillContainer ne vise que
--    les pièces « garage » d'un bâtiment d'habitation (chambre, cuisine…).
-- Relevé 42.21 (carte vanilla) : 1 496 garagestorage, 588 garage (406 dans une
-- maison), 668 storageunit, 60 attic, 102 shed, 347 storage, 5 397 closet.
-- Poids × option SewingLootMultiplier ; rien n'est ajouté si elle vaut 0.
--
-- Ordre du moteur (IsoWorld.init:1791-1805, 42.21) : OnPreDistributionMerge,
-- OnDistributionMerge, OnPostDistributionMerge, puis SandboxOptions.load()
-- (options de la partie), puis ItemPickerJava.Parse(). Tout est posé à
-- OnPostDistributionMerge, après les ajouts des autres mods (leurs listes à kit
-- de couture comprises). En solo, les options sandbox du mod n'y sont PAS encore
-- connues (valeur par défaut de MTIR.opt). OnInitGlobalModData
-- (même init, après Parse et avant le remplissage des conteneurs) corrige les
-- poids si le multiplicateur réel diffère, puis relit les listes
-- (ItemPickerJava.Parse, idempotent : il vide ses tables avant lecture).
-- ============================================================================

require "Items/ProceduralDistributions"
require "MyTailorIsRich/MTIR_SewingMachine"
require "MyTailorIsRich/MTIR_PatternBinder"

-- Les listes procédurales attendent le type sans module.
local function shortType(fullType)
    return (string.gsub(fullType, "^Base%.", ""))
end

local ELECTRIC = shortType(MTIR.MACHINE_KINDS.electric.item)
local TREADLE = shortType(MTIR.MACHINE_KINDS.treadle.item)
local PATTERN = shortType(MTIR.PRINTED_PATTERN_ITEM)
local BINDER = shortType(MTIR.BINDER_ITEM)

local SPAWNS = {
    { list = "TailoringTools", item = ELECTRIC, weight = 6 },
    { list = "TailoringTools", item = TREADLE, weight = 1.5 },
    { list = "SewingStoreTools", item = ELECTRIC, weight = 8 },
    { list = "SewingStoreTools", item = TREADLE, weight = 2 },
    { list = "CrateTailoring", item = ELECTRIC, weight = 3 },
    { list = "CrateTailoring", item = TREADLE, weight = 1 },
    { list = "GigamartBedding", item = ELECTRIC, weight = 1 },
    { list = "Antiques", item = TREADLE, weight = 0.3 },
    { list = "TailoringLiterature", item = PATTERN, weight = 20 },
    { list = "SewingStoreTools", item = PATTERN, weight = 10 },
    { list = "BookstoreFashion", item = PATTERN, weight = 4 },
    { list = "TailoringLiterature", item = BINDER, weight = 4 },
    { list = "SewingStoreTools", item = BINDER, weight = 3 },
}

--- Kit de couture : une liste qui en contient reçoit une machine électrique à
--- ce rapport du poids du kit (4 → 0,2, soit ~0,12 % par tirage en butin normal).
--- Les listes de SPAWNS gardent leurs poids propres.
local SEWING_KIT_ITEMS = { SewingKit = true, ["Base.SewingKit"] = true }
local SEWING_KIT_RATIO = 0.05

--- Table propre aux lieux de stockage : une fois choisie pour un conteneur,
--- ~30 % de machine électrique et ~9 % de machine à pédale (butin normal).
local STORAGE_LIST = "MTIR_SewingMachines"
local STORAGE_ITEMS = { { item = ELECTRIC, weight = 50 }, { item = TREADLE, weight = 15 } }

--- Couples salle × conteneur (procéduraux en 42.21) et poids de choix de la table
--- (à comparer à la somme des weightChance de la procList, entre 230 et 2 700).
local STORAGE_SLOTS = {
    { room = "garagestorage", container = "crate", weightChance = 15 },
    { room = "garagestorage", container = "other", weightChance = 15 },
    { room = "storageunit", container = "other", weightChance = 6 },
    { room = "attic", container = "cardboardbox", weightChance = 10 },
    { room = "attic", container = "crate", weightChance = 10 },
    { room = "attic", container = "other", weightChance = 10 },
    { room = "shed", container = "other", weightChance = 8 },
    { room = "storage", container = "other", weightChance = 5 },
    { room = "closet", container = "other", weightChance = 8 },
    { room = "clothingstore", container = "shelves", weightChance = 4 },
    { room = "clothingstore", container = "counter", weightChance = 4 },
    { room = "clothingstorage", container = "other", weightChance = 6 },
    { room = "departmentstore", container = "shelves", weightChance = 4 },
    { room = "departmentstore", container = "other", weightChance = 4 },
    { room = "tailoringstore", container = "other", weightChance = 15 },
}

-- Multiplicateur appliqué (nil tant que rien n'a été fait).
local appliedMultiplier = nil

local function getMultiplier()
    return math.max(0, tonumber(MTIR.opt("SewingLootMultiplier")) or 0)
end

local function getItems(listName)
    local entry = ProceduralDistributions.list[listName]
    return entry and entry.items or nil
end

local OUR_ITEMS = { [ELECTRIC] = true, [TREADLE] = true, [PATTERN] = true, [BINDER] = true }

--- Retire de `items` les paires (objet, poids) posées par ce fichier.
local function removeOurEntries(items)
    for i = #items - 1, 1, -2 do
        if OUR_ITEMS[items[i]] then
            table.remove(items, i + 1)
            table.remove(items, i)
        end
    end
end

--- Poids du kit de couture le plus probable de `items`, ou nil.
local function sewingKitWeight(items)
    local best = nil
    for i = 1, #items - 1, 2 do
        local weight = tonumber(items[i + 1])
        if SEWING_KIT_ITEMS[items[i]] and weight and (not best or weight > best) then
            best = weight
        end
    end
    return best
end

--- Listes à kit de couture, hors SPAWNS : machine électrique au prorata du kit.
local function applySewingKitSpawns(multiplier)
    local explicit = {}
    for _, spawn in ipairs(SPAWNS) do
        explicit[spawn.list] = true
    end
    local count = 0
    for name, entry in pairs(ProceduralDistributions.list) do
        local items = type(entry) == "table" and entry.items or nil
        local kitWeight = not explicit[name] and type(items) == "table" and sewingKitWeight(items)
        if kitWeight and kitWeight > 0 then
            table.insert(items, ELECTRIC)
            table.insert(items, kitWeight * SEWING_KIT_RATIO * multiplier)
            count = count + 1
        end
    end
    return count
end

--- Listes directes et listes à kit : pose (ou repose) les entrées avec le multiplicateur.
--- Tout ce que ce fichier a posé est d'abord retiré : pas de doublon au recalage.
local function applySpawns(multiplier)
    for _, entry in pairs(ProceduralDistributions.list) do
        if type(entry) == "table" and type(entry.items) == "table" then
            removeOurEntries(entry.items)
        end
    end
    if multiplier > 0 then
        print("[MTIR] machines à coudre ajoutées à " .. applySewingKitSpawns(multiplier)
            .. " listes à kit de couture")
    end
    for _, spawn in ipairs(SPAWNS) do
        local items = getItems(spawn.list)
        if not items then
            print("[MTIR] liste de butin absente : " .. spawn.list)
        elseif multiplier > 0 then
            table.insert(items, spawn.item)
            table.insert(items, spawn.weight * multiplier)
        end
    end
end

--- Table propre : poids des machines × multiplicateur (vide si 0).
local function applyStorageList(multiplier)
    local items = {}
    if multiplier > 0 then
        for _, entry in ipairs(STORAGE_ITEMS) do
            table.insert(items, entry.item)
            table.insert(items, entry.weight * multiplier)
        end
    end
    ProceduralDistributions.list[STORAGE_LIST] = { rolls = 1, items = items, junk = { rolls = 1, items = {} } }
end

--- procList d'un couple salle × conteneur procédural, ou nil (absent, non procédural).
local function getProcList(roomName, containerName)
    local room = SuburbsDistributions and SuburbsDistributions[roomName]
    local container = type(room) == "table" and room[containerName] or nil
    if type(container) ~= "table" or not container.procedural or type(container.procList) ~= "table" then
        return nil
    end
    return container.procList
end

--- Retire puis, si le multiplicateur le permet, repose la table dans chaque procList.
--- Retrait préalable : pas de doublon si la fonction est rappelée (recalage des options).
local function applyStorageSlots(multiplier)
    for _, slot in ipairs(STORAGE_SLOTS) do
        local procList = getProcList(slot.room, slot.container)
        if not procList then
            print("[MTIR] conteneur procédural absent : " .. slot.room .. "." .. slot.container)
        else
            for i = #procList, 1, -1 do
                if type(procList[i]) == "table" and procList[i].name == STORAGE_LIST then
                    table.remove(procList, i)
                end
            end
            if multiplier > 0 then
                table.insert(procList, { name = STORAGE_LIST, min = 0, max = 1, weightChance = slot.weightChance })
            end
        end
    end
end

--- Après fusion des tables de salles et après les ajouts des autres mods
--- (OnPreDistributionMerge compris), avant ItemPickerJava.Parse.
local function onPostDistributionMerge()
    local multiplier = getMultiplier()
    applySpawns(multiplier)
    applyStorageList(multiplier)
    applyStorageSlots(multiplier)
    appliedMultiplier = multiplier
end

--- Options de la partie désormais chargées : corrige les poids si besoin.
local function onInitGlobalModData()
    if isClient() or appliedMultiplier == nil then
        return
    end
    local multiplier = getMultiplier()
    if multiplier == appliedMultiplier then
        return
    end
    applySpawns(multiplier)
    applyStorageList(multiplier)
    applyStorageSlots(multiplier)
    appliedMultiplier = multiplier
    ItemPickerJava.Parse()
    print("[MTIR] butin de couture : multiplicateur " .. tostring(multiplier))
end

-- ----------------------------------------------------------------------------
-- Garages attenants d'une maison (pièce « garage » d'un bâtiment habité)
-- ----------------------------------------------------------------------------

local ATTACHED_GARAGE_ROOM = "garage"
--- Conteneurs de rangement d'un garage (ni frigo, ni four, ni établi à outils).
local ATTACHED_GARAGE_CONTAINERS = {
    other = true, crate = true, cardboardbox = true, metal_shelves = true, shelves = true,
}
--- Pièces qui signent une habitation (test vanilla : IsoBuilding:getRandomRoom).
local HOME_ROOMS = { "bedroom", "kitchen", "livingroom" }
--- Chance par conteneur, alignée sur garagestorage (≈ 0,3 % électrique, 0,1 % pédale).
local ATTACHED_CHANCES = { { item = "Base.Mov_MTIR_SewingMachine", chance = 0.003 },
    { item = "Base.Mov_MTIR_TreadleMachine", chance = 0.001 } }

local function isHome(building)
    if not building then
        return false
    end
    for _, name in ipairs(HOME_ROOMS) do
        if building:getRandomRoom(name) ~= nil then
            return true
        end
    end
    return false
end

--- Au plus une machine par pièce, comme max = 1 dans une procList. Table Lua de
--- session : un conteneur n'est rempli qu'une fois (drapeau « exploré »), et on
--- n'écrit pas dans la HashMap<String, Integer> Java (un nombre Lua y serait un Double).
local garagesWithMachine = {}

local function roomAlreadyHasMachine(room)
    local roomDef = room and room:getRoomDef()
    if not roomDef then
        return true
    end
    local key = tostring(roomDef:getID())
    if garagesWithMachine[key] then
        return true
    end
    garagesWithMachine[key] = true
    return false
end

local function onFillContainer(roomName, containerType, container)
    if roomName ~= ATTACHED_GARAGE_ROOM or not ATTACHED_GARAGE_CONTAINERS[containerType]
        or not instanceof(container, "ItemContainer") then
        return
    end
    local multiplier = appliedMultiplier or getMultiplier()
    local square = container:getSourceGrid()
    if multiplier <= 0 or not square or not isHome(square:getBuilding()) then
        return
    end
    local draw = ZombRandFloat(0, 1)
    for _, entry in ipairs(ATTACHED_CHANCES) do
        if draw < entry.chance * multiplier then
            if not roomAlreadyHasMachine(square:getRoom()) then
                container:AddItem(entry.item)
            end
            return
        end
        draw = draw - entry.chance * multiplier
    end
end

Events.OnFillContainer.Add(onFillContainer)
Events.OnPostDistributionMerge.Add(onPostDistributionMerge)
Events.OnInitGlobalModData.Add(onInitGlobalModData)
