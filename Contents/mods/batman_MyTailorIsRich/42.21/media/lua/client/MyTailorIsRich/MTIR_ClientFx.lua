-- ============================================================================
-- My Tailor Is Rich — effets côté client et choix de taille d'artisanat
--
-- MTIR.applyFx est appelé directement en solo (MTIR.tell) et, en MP, par la
-- commande serveur "fx" (sendServerCommand n'agit pas en solo).
-- ============================================================================

require "MyTailorIsRich/MTIR_Effects"

local function resolveSay(say)
    if type(say) ~= "table" or type(say.key) ~= "string" then
        return nil
    end
    if say.arg ~= nil then
        return getText(say.key, tostring(say.arg))
    end
    return getText(say.key)
end

function MTIR.applyFx(player, fx)
    if not player or type(fx) ~= "table" then
        return
    end

    local text = resolveSay(fx.say)
    if text then
        player:Say(text)
    end

    if type(fx.sound) == "string" then
        player:getEmitter():playSound(fx.sound)
    end

    if type(fx.halo) == "table" and type(fx.halo.itemType) == "string" then
        local good = fx.halo.good == true
        local color = good and HaloTextHelper.getColorGreen() or HaloTextHelper.getColorRed()
        HaloTextHelper.addTextWithArrow(player, getItemNameFromFullType(fx.halo.itemType), good, color)
    end

    if fx.resetModel then
        player:resetModelNextFrame()
    end

    if fx.refresh then
        local inventory = player:getInventory()
        if inventory then
            inventory:setDrawDirty(true)
        end
        if ISInventoryPage then
            ISInventoryPage.renderDirty = true
        end
    end
end

--- Joueur local visé par le serveur (écran partagé), à défaut le joueur principal.
--- Partagée par les fichiers client qui reçoivent une commande serveur.
function MTIR.findLocalPlayer(onlineId)
    if onlineId ~= nil then
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player and player:getOnlineID() == onlineId then
                return player
            end
        end
    end
    return getPlayer()
end

local function onServerCommand(module, command, args)
    if module ~= MTIR.NET_MODULE or command ~= "fx" or type(args) ~= "table" then
        return
    end
    MTIR.applyFx(MTIR.findLocalPlayer(args.playerOnlineId), args)
end

Events.OnServerCommand.Add(onServerCommand)

-- ----------------------------------------------------------------------------
-- Taille choisie dans l'interface d'artisanat (par type de vêtement).
-- Chaque changement est envoyé à l'autorité, qui l'applique à la fabrication.
-- ----------------------------------------------------------------------------

MTIR.UICraftSize = MTIR.UICraftSize or {}

function MTIR.setUICraftSize(fullType, sizeName)
    if MTIR.UICraftSize[fullType] == sizeName then
        return
    end
    MTIR.UICraftSize[fullType] = sizeName
    local player = getPlayer()
    if player then
        sendClientCommand(player, MTIR.NET_MODULE, "setCraftSize", { fullType = fullType, size = sizeName })
    end
end

--- Taille courante ; à défaut, la taille par défaut proposée (celle du personnage).
function MTIR.getUICraftSize(fullType, defaultSize)
    if not MTIR.UICraftSize[fullType] and defaultSize then
        MTIR.setUICraftSize(fullType, defaultSize)
    end
    return MTIR.UICraftSize[fullType]
end

--- Oublie les tailles choisies dans les fenêtres d'artisanat : un personnage neuf ne
--- coud pas dans la taille retenue par le précédent.
function MTIR.forgetUICraftSizes()
    MTIR.UICraftSize = {}
end

--- Passe à la taille suivante (XXL revient à XS).
function MTIR.cycleUICraftSize(fullType, defaultSize)
    local current = MTIR.getUICraftSize(fullType, defaultSize)
    local index = MTIR.getSizeIndex(current) or 0
    index = index + 1
    if index > #MTIR.SIZE_LIST then
        index = 1
    end
    local nextSize = MTIR.SIZE_LIST[index].name
    MTIR.setUICraftSize(fullType, nextSize)
    return nextSize
end

-- ----------------------------------------------------------------------------
-- Taille renvoyée au début de la fabrication
--
-- La taille n'est envoyée qu'à son changement, et une commande Lua n'est pas
-- ordonnée par rapport aux paquets de l'action (base moteur, multiplayer.md) :
-- changer de taille puis lancer la couture aussitôt pouvait coudre l'ancienne
-- taille. Renvoyée au début de l'action, elle précède de toute la durée de
-- l'action la création du vêtement par l'autorité.
-- ----------------------------------------------------------------------------

--- Renvoie la taille déjà choisie pour ce type, même inchangée. Rien à renvoyer si
--- le joueur n'en a jamais choisi : l'autorité laissera la taille à choisir, comme
--- aujourd'hui.
function MTIR.resendCraftSize(player, fullType)
    local sizeName = player and MTIR.UICraftSize[fullType]
    if not sizeName then
        return
    end
    sendClientCommand(player, MTIR.NET_MODULE, "setCraftSize", { fullType = fullType, size = sizeName })
end

--- Tailles des vêtements que cette recette peut produire (mêmes contrôles que le
--- bouton de taille de la fenêtre de fabrication).
local function resendRecipeCraftSizes(player, recipe)
    local outputs = recipe and recipe:getOutputs()
    for i = 0, (outputs and outputs:size() or 0) - 1 do
        local script = outputs:get(i)
        if script and script:getResourceType() == ResourceType.Item then
            local results = script:getPossibleResultItems()
            for j = 0, (results and results:size() or 0) - 1 do
                local output = results:get(j)
                if output and output:getItemType() == ItemType.CLOTHING
                    and MTIR.canOutputHaveSize(output) then
                    MTIR.resendCraftSize(player, output:getFullName())
                end
            end
        end
    end
end

local handcraftStart = ISHandcraftAction.start
function ISHandcraftAction:start(...)
    if self.character and self.character:isLocalPlayer() then
        resendRecipeCraftSizes(self.character, self.craftRecipe)
    end
    return handcraftStart(self, ...)
end
