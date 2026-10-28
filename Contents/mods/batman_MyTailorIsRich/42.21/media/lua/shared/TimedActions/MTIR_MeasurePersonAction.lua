-- ============================================================================
-- My Tailor Is Rich — prendre les mesures d'un personnage au mètre ruban
--
-- Le mètre ruban ne donne qu'un renseignement : la taille de vêtement et la
-- pointure de la cible, dites par le personnage qui mesure. Rien n'est
-- enregistré, et la couture reste libre.
--
-- complete() s'exécute sur l'autorité (le serveur ne passe jamais par isValid,
-- NetTimedAction) : ruban, cible vivante et distance y sont revérifiés. La
-- cible voyage par son identifiant de connexion (MP) ou son emplacement local
-- (solo, écran partagé) : un IsoPlayer ne se transmet pas dans une action.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_ActionBase"
require "MyTailorIsRich/MTIR_Effects"
require "MyTailorIsRich/MTIR_Shoes"

MTIR_MeasurePersonAction = ISBaseTimedAction:derive("MTIR_MeasurePersonAction")

--- Cible de la mesure dans le contexte courant, ou nil si elle est partie.
local function resolveTarget(self)
    if self.selfMeasure then
        return self.character
    end
    if isServer() then
        local players = getOnlinePlayers()
        for i = 0, (players and players:size() or 0) - 1 do
            local other = players:get(i)
            if other and other:getOnlineID() == self.targetOnlineId then
                return other
            end
        end
        return nil
    end
    for i = 0, getNumActivePlayers() - 1 do
        local other = getSpecificPlayer(i)
        if other and other:getPlayerNum() == self.targetPlayerNum then
            return other
        end
    end
    return nil
end

--- Cible mesurable : vivante et à portée de bras.
local function canMeasure(self, target)
    if not target or target:isDead() then
        return false
    end
    if target == self.character then
        return true
    end
    if math.abs(target:getZ() - self.character:getZ()) >= 1 then
        return false
    end
    local dx = target:getX() - self.character:getX()
    local dy = target:getY() - self.character:getY()
    return dx * dx + dy * dy <= MTIR.MEASURE_REACH * MTIR.MEASURE_REACH
end

local function validate(self)
    self.tape = MTIR.resolveItem(self.character, self.tape)
    if not self.tape or not MTIR.predicateMeasuringTape(self.tape) then
        return false
    end
    return canMeasure(self, resolveTarget(self))
end

function MTIR_MeasurePersonAction:isValid()
    return MTIR.Action.startedOnClient(self) or validate(self)
end

function MTIR_MeasurePersonAction:start()
    self.tape = MTIR.resolveItem(self.character, self.tape)
    MTIR.Action.startProgress(self, self.tape, "IGUI_MTIR_JobType_Measure")
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.tape, nil)
    local target = resolveTarget(self)
    if target and target ~= self.character then
        self.character:faceThisObject(target)
    end
end

function MTIR_MeasurePersonAction:update()
    MTIR.Action.updateProgress(self, self.tape)
end

function MTIR_MeasurePersonAction:stop()
    MTIR.Action.stop(self, self.tape)
end

function MTIR_MeasurePersonAction:perform()
    MTIR.Action.perform(self, self.tape)
end

function MTIR_MeasurePersonAction:complete()
    if not validate(self) then
        return false
    end
    local target = resolveTarget(self)
    local size = MTIR.getPlayerSize(target).name
    local shoeSize = MTIR.getPlayerShoeSize(target)
    local say
    if target == self.character then
        say = { key = "IGUI_MTIR_Say_Measured_Self", arg = size, arg2 = tostring(shoeSize) }
    else
        say = {
            key = "IGUI_MTIR_Say_Measured_Other",
            arg = target:getDisplayName(),
            arg2 = size,
            arg3 = tostring(shoeSize),
        }
    end
    MTIR.tell(self.character, { say = say })
    return true
end

function MTIR_MeasurePersonAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return math.max(1, MTIR.MEASURE_PERSON_DURATION * MTIR.opt("ActionTimeMultiplier"))
end

function MTIR_MeasurePersonAction:new(character, tape, target)
    local o = ISBaseTimedAction.new(self, character)
    o.tape = tape
    o.selfMeasure = target == character
    o.targetOnlineId = target:getOnlineID()
    o.targetPlayerNum = target:getPlayerNum()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.maxTime = o:getDuration()
    return o
end
