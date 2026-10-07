-- ============================================================================
-- My Tailor Is Rich — traductions du mod sur un serveur MP (dédié ou hébergé)
--
-- Un serveur MP lit les traductions avant de charger les mods
-- (GameServer.java:637-639, loadMods à :1355) et ne les relit jamais : getText
-- y renvoie les clés du mod brutes. Or le nom d'un patron (tracé, copié, ou
-- tiré dans le butin) est composé sur le serveur et enregistré dans l'objet.
-- Quand ce fichier s'exécute, les mods sont chargés (loadMods précède
-- LuaManager.init, :1355-1356) : un rechargement, comme le menu de debug
-- vanilla (ISDebugMenu.lua:283), ajoute leurs traductions. Les noms restent
-- dans la langue du serveur.
-- Solo : traductions déjà présentes, rien à faire.
--
-- Migration (patrons nommés « IGUI_MTIR_… » avant la 0.4.5) : toutes les dix
-- minutes de jeu, les inventaires des joueurs connectés (sacs compris) sont
-- parcourus ; les noms en clé brute des patrons et des entrées de classeur
-- sont recalculés d'après leurs données, puis synchronisés (syncItemFields).
-- Un patron resté dans un conteneur du monde est corrigé une fois ramassé.
-- ============================================================================

if isClient() then
    return
end

require "MyTailorIsRich/MTIR_Patterns"
require "MyTailorIsRich/MTIR_PatternBinder"

local ServerTranslations = {}
MTIR.ServerTranslations = ServerTranslations

-- Clé sans paramètre : getTextOrNull ne signale aucun argument manquant.
ServerTranslations.PROBE_KEY = "IGUI_MTIR_Hint_Fit"

--- Recharge les traductions si celles du mod manquent ; vrai si rechargées.
function ServerTranslations.ensure()
    if getTextOrNull(ServerTranslations.PROBE_KEY) ~= nil then
        return false
    end
    if not (Translator and Translator.loadFiles) then
        print("[MTIR] mod translations missing on the server and Translator.loadFiles unavailable")
        return false
    end
    Translator.loadFiles()
    local loaded = getTextOrNull(ServerTranslations.PROBE_KEY) ~= nil
    print(loaded and "[MTIR] mod translations reloaded on the server"
        or "[MTIR] mod translations still missing on the server after reload")
    return loaded
end

ServerTranslations.ensure()

-- ----------------------------------------------------------------------------
-- Migration des noms en clé brute
-- ----------------------------------------------------------------------------

local function hasRawName(item)
    return MTIR.hasRawPatternName(item)
end

--- Corrige les patrons et classeurs de l'inventaire de `player` ; rend le nombre d'objets corrigés.
function ServerTranslations.repairPlayer(player)
    local inventory = player and player:getInventory()
    if not inventory then
        return 0
    end
    local items = inventory:getAllEvalRecurse(hasRawName)
    local repaired = 0
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if MTIR.repairPatternNames(item) then
            MTIR.syncItem(player, item)
            repaired = repaired + 1
        end
    end
    return repaired
end

local function onEveryTenMinutes()
    local players = getOnlinePlayers()
    for i = 0, (players and players:size() or 0) - 1 do
        local player = players:get(i)
        if player and not player:isDead() then
            local repaired = ServerTranslations.repairPlayer(player)
            if repaired > 0 then
                print("[MTIR] repaired " .. tostring(repaired) .. " pattern name(s) for "
                    .. tostring(player:getUsername()))
            end
        end
    end
end

if isServer() then
    Events.EveryTenMinutes.Add(onEveryTenMinutes)
end
