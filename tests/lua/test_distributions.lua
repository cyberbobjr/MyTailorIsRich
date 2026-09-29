-- MTIR_Distributions sur les vraies tables vanilla (jeu installé requis) :
-- entrées ajoutées, pas de doublon quand on réapplique, retrait à 0.

local T = {}

T.skip = not hasVanilla and "jeu absent : définir PZ_MEDIA" or nil

local VANILLA_FILES = {
    "Distribution_BinJunk.lua", "Distribution_ClosetJunk.lua", "Distribution_CounterJunk.lua",
    "Distribution_DeskJunk.lua", "Distribution_ShelfJunk.lua", "Distribution_SideTableJunk.lua",
    "Distribution_BagsAndContainers.lua", "ProceduralDistributions.lua", "Distributions.lua",
    "SuburbsDistributions.lua",
}

local ELECTRIC = "Mov_MTIR_SewingMachine"
local TREADLE = "Mov_MTIR_TreadleMachine"
local PATTERN = "MTIR_PrintedPattern"

function T.setup()
    Distributions = {}
    MULTIPLIER = 1
    MTIR = {
        MACHINE_KINDS = {
            electric = { item = "Base." .. ELECTRIC },
            treadle = { item = "Base." .. TREADLE },
        },
        PRINTED_PATTERN_ITEM = "Base." .. PATTERN,
        opt = function() return MULTIPLIER end,
    }
    isClient = function() return false end
    parsed = 0
    ItemPickerJava = { Parse = function() parsed = parsed + 1 end }
    for _, file in ipairs(VANILLA_FILES) do
        assertTrue(loadVanilla("server/Items/" .. file), "vanilla manquant : " .. file)
    end
    loadMod("server/Items/MTIR_Distributions.lua")
    triggerEvent("OnPostDistributionMerge")
end

--- Nombre de listes procédurales contenant l'objet.
local function listsWith(item)
    local n = 0
    for _, list in pairs(ProceduralDistributions.list) do
        local items = list.items or {}
        for i = 1, #items - 1, 2 do
            if items[i] == item then
                n = n + 1
            end
        end
    end
    return n
end

--- Conteneurs de pièces qui tirent la liste des machines.
local function storageSlots()
    local n = 0
    for _, room in pairs(SuburbsDistributions) do
        if type(room) == "table" then
            for _, container in pairs(room) do
                if type(container) == "table" and type(container.procList) == "table" then
                    for _, entry in ipairs(container.procList) do
                        if type(entry) == "table" and entry.name == "MTIR_SewingMachines" then
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    return n
end

T["machines et patrons ajoutés"] = function()
    assertTrue(listsWith(ELECTRIC) >= 20, "machine électrique dans " .. listsWith(ELECTRIC) .. " listes")
    assertTrue(listsWith(TREADLE) >= 3, "machine à pédale dans " .. listsWith(TREADLE) .. " listes")
    assertTrue(listsWith(PATTERN) >= 2, "patrons dans " .. listsWith(PATTERN) .. " listes")
    assertTrue(storageSlots() >= 10, "emplacements de rangement : " .. storageSlots())
end

T["réappliquer ne crée pas de doublon"] = function()
    local electric, slots = listsWith(ELECTRIC), storageSlots()
    MULTIPLIER = 2
    triggerEvent("OnInitGlobalModData")
    assertEq(listsWith(ELECTRIC), electric, "listes avec la machine électrique")
    assertEq(storageSlots(), slots, "emplacements de rangement")
    assertTrue(parsed >= 1, "ItemPickerJava.Parse rappelé")
end

T["rareté à 0 : tout est retiré"] = function()
    MULTIPLIER = 0
    triggerEvent("OnInitGlobalModData")
    assertEq(listsWith(ELECTRIC), 0, "machine électrique")
    assertEq(listsWith(TREADLE), 0, "machine à pédale")
    assertEq(listsWith(PATTERN), 0, "patrons")
    assertEq(storageSlots(), 0, "emplacements de rangement")
end

return T
