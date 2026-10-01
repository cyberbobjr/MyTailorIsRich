-- ============================================================================
-- My Tailor Is Rich — coudre un vêtement ou des chaussures d'après un patron
-- Ciseaux (ou couteau pour le cuir et les chaussures) en main principale,
-- aiguille (ou alêne pour un vêtement en cuir) dans l'autre ; chaussures : alêne
-- ET colle en plus. complete() décide sur l'autorité : réussite, écart de taille
-- éventuel, consommation des matériaux et usure du patron. Le serveur n'appelle
-- jamais isValid (NetTimedAction.isValid) : complete() refait toute la
-- validation (possession, doublons, types, outils en main).
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ;
-- `threads` et `materials` sont des ArrayList ; `awl` et `glue` sont nil hors
-- chaussures ; `size` est un texte
-- (XS..XXL ou pointure) ; `machinePos` vaut "x,y,z" sur une machine à coudre,
-- "" à la main : l'autorité retrouve la machine et revérifie courant, état et
-- distance (MTIR.resolveWorkMods) ; à la main, le dé à coudre (RequireThimble).
-- `entryId` (nombre, ou nil) : le patron est rangé dans un classeur à patrons ;
-- `pattern` désigne alors le classeur et l'usure porte sur l'entrée
-- (MTIR_PatternBinder.lua), synchronisée avec le classeur.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Alterations"
require "MyTailorIsRich/MTIR_PatternBinder"

MTIR_SewPatternAction = ISBaseTimedAction:derive("MTIR_SewPatternAction")

--- Outils de coupe et de couture du bon type (alêne et colle pour les chaussures).
local function toolsOk(self, data)
    if not self.needle or not self.scissors then
        return false
    end
    local needleOk = MTIR.predicatePatternNeedle(data.fabric, data.kind)
    local cutterOk = MTIR.predicatePatternCutter(data.fabric, data.kind)
    if not needleOk(self.needle) or not cutterOk(self.scissors) then
        return false
    end
    if MTIR.patternNeedsAwl(data) and not (self.awl and MTIR.predicateAwl(self.awl)) then
        return false
    end
    return not MTIR.patternNeedsGlue(data) or (self.glue ~= nil and MTIR.predicateGlue(self.glue))
end

--- Données du patron et bonus si la couture est possible, sinon nil.
local function canSew(self)
    local data = MTIR.getSourcePatternData(self.pattern, self.entryId)
    if not data or (data.uses or 0) <= 0 or not MTIR.patternModelExists(data) then
        return nil
    end
    if not MTIR.isValidPatternSize(data, self.size) then
        return nil
    end
    local character = self.character
    local mods = MTIR.resolveWorkMods(character, self.machinePos, data)
    if not mods or not MTIR.hasThimbleFor(character, mods) then
        return nil
    end
    if MTIR.getEffectiveTailoring(character, mods) < MTIR.getRequiredLevelToSew(data) then
        return nil
    end
    if MTIR.getRemainingThread(self.threads) < MTIR.getPatternThread(data, mods) then
        return nil
    end
    -- Seuls les matériaux du tissu du patron comptent (MTIR.countMaterialUnits).
    if MTIR.countMaterialUnits(data.fabric, self.materials) < MTIR.getPatternMaterialUnits(data, self.size) then
        return nil
    end
    if not toolsOk(self, data) then
        return nil
    end
    return data, mods
end

--- Possession de tout ce que le client a désigné (listes sans doublon, fil
--- vérifié, outils en main, alêne et colle dans l'inventaire).
local function ownsEverything(self)
    local character = self.character
    return MTIR.hasItem(character, self.pattern)
        and MTIR.hasThreads(character, self.threads)
        and MTIR.hasAllItems(character, self.materials)
        and MTIR.holdsTools(character, self.scissors, self.needle)
        and (self.awl == nil or MTIR.hasItem(character, self.awl))
        and (self.glue == nil or MTIR.hasItem(character, self.glue))
end

--- Validation partagée par isValid et complete (seul contrôle côté serveur).
local function validate(self)
    if not ownsEverything(self) then
        return nil
    end
    return canSew(self)
end

function MTIR_SewPatternAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_SewPatternAction:waitToStart()
    return MTIR.MachineWork.waitToStart(self)
end

function MTIR_SewPatternAction:start()
    self.pattern = MTIR.resolveItem(self.character, self.pattern)
    self.needle = MTIR.resolveItem(self.character, self.needle)
    self.scissors = MTIR.resolveItem(self.character, self.scissors)
    self.started = true
    self.pattern:setJobType(getText("IGUI_MTIR_JobType_SewPattern"))
    self.pattern:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scissors, self.needle)
    MTIR.MachineWork.start(self, "MTIR_ResizeClothes")
end

function MTIR_SewPatternAction:update()
    self.pattern:setJobDelta(self:getJobDelta())
    MTIR.MachineWork.update(self)
end

function MTIR_SewPatternAction:stop()
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_SewPatternAction:perform()
    MTIR.MachineWork.stopSound(self)
    self.started = false
    self.pattern:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

--- Une couture (réussie ou non) use le patron ; usé jusqu'au bout, il disparaît
--- (rangé dans un classeur : son entrée est retirée du classeur).
local function wearPattern(character, pattern, data, entryId)
    if entryId ~= nil then
        return MTIR.wearBinderPattern(character, pattern, entryId)
    end
    data.uses = (data.uses or 1) - 1
    if data.uses <= 0 then
        MTIR.removeItem(pattern)
        return true
    end
    MTIR.syncItem(character, pattern)
    return false
end

local function sayForOffset(data, asked, obtained)
    if asked == obtained then
        return nil
    end
    local bigger
    if data.kind == "shoe" then
        bigger = tonumber(obtained) > tonumber(asked)
    else
        bigger = MTIR.getSizeIndex(obtained) > MTIR.getSizeIndex(asked)
    end
    return { key = bigger and "IGUI_MTIR_Say_PatternBigger" or "IGUI_MTIR_Say_PatternSmaller", arg = obtained }
end

--- Réussite : crée l'exemplaire (écart de taille éventuel). Faux si l'objet n'a pas pu être créé.
local function sewSuccess(self, data, mods, fx)
    local character = self.character
    local tailoring = character:getPerkLevel(Perks.Tailoring)
    local margin = MTIR.getEffectiveTailoring(character, mods) - MTIR.getRequiredLevelToSew(data)
    local obtained = MTIR.rollPatternSize(data, self.size, tailoring + mods.precisionBonus)
    if not MTIR.createFromPattern(character, data, obtained, margin) then
        return false
    end
    addXp(character, Perks.Tailoring, MTIR.getSewXp(data, true))
    fx.halo = { itemType = data.fullType, good = true }
    fx.say = sayForOffset(data, self.size, obtained)
    return true
end

function MTIR_SewPatternAction:complete()
    local data, mods = validate(self)
    if not data then
        return false
    end
    local character = self.character
    local effective = MTIR.getEffectiveTailoring(character, mods)
    local requiredLevel = MTIR.getRequiredLevelToSew(data)
    local threadUses = MTIR.getPatternThread(data, mods)
    local materialUnits = MTIR.getPatternMaterialUnits(data, self.size)
    local fx = { refresh = true }
    local broke = MTIR.MachineWork.rollBreak(mods)
    local chance = MTIR.applySuccessMalus(MTIR.getSuccessChanceForChange(effective, requiredLevel), mods)

    if not broke and ZombRandFloat(0, 1) < chance then
        -- Objet non créé : rien n'est consommé et la machine ne s'use pas.
        if not sewSuccess(self, data, mods, fx) then
            return false
        end
    else
        addXp(character, Perks.Tailoring, MTIR.getSewXp(data, false))
        -- Un échec (ou une aiguille cassée) gâche la moitié du fil et du tissu.
        threadUses = math.ceil(threadUses / 2)
        materialUnits = math.ceil(materialUnits / 2)
        fx.sound = "MTIR_ResizeFailed"
        fx.say = { key = broke and "IGUI_MTIR_Say_NeedleBroke" or "IGUI_MTIR_Say_PatternFailed" }
    end

    MTIR.MachineWork.applyWear(self, mods, broke)
    MTIR.consumeThreads(self.threads, threadUses)
    MTIR.consumeMaterials(data.fabric, self.materials, materialUnits)
    if MTIR.patternNeedsGlue(data) then
        MTIR.consumeGlue(self.glue, MTIR.SHOE_GLUE_USES)
    end
    if wearPattern(character, self.pattern, data, self.entryId) then
        fx.say = fx.say or { key = "IGUI_MTIR_Say_PatternWornOut" }
    end
    MTIR.tell(character, fx)
    return true
end

function MTIR_SewPatternAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    local data = MTIR.getSourcePatternData(self.pattern, self.entryId)
    if not data then
        return 1
    end
    return MTIR.getSewDuration(data, MTIR.MachineWork.durationMods(self))
end

--- machinePos : "x,y,z" d'une machine à coudre (MTIR.encodeMachinePos), ou nil/"" à la main.
--- awl, glue : alêne et colle (chaussures seulement, nil sinon) ; en dernier pour que
--- leur absence ne décale pas les autres paramètres réseau.
--- entryId : id de l'entrée quand `pattern` est un classeur à patrons, sinon nil.
function MTIR_SewPatternAction:new(character, pattern, needle, scissors, threads, materials, size, machinePos, awl, glue,
                                   entryId)
    local o = ISBaseTimedAction.new(self, character)
    o.pattern = pattern
    o.needle = needle
    o.scissors = scissors
    o.threads = threads
    o.materials = materials
    o.size = tostring(size)
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    o.awl = awl
    o.glue = glue
    o.entryId = tonumber(entryId)
    -- Sur une machine, s'éloigner interrompt le travail ; à la main, on coud en marchant.
    o.stopOnWalk = o.machinePos ~= ""
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
