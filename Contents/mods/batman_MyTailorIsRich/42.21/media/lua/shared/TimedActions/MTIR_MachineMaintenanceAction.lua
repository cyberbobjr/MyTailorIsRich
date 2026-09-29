-- ============================================================================
-- My Tailor Is Rich — entretenir une machine à coudre
-- Tournevis en main, huile alimentaire du jeu (tag base:oil) : l'autorité
-- consomme MTIR.MAINTENANCE_OIL_USES utilisations, rend de l'état à la machine
-- selon la compétence de réparation (Électricité ou Mécanique) et donne de l'XP.
--
-- Paramètres réseau : champs nommés comme les paramètres de new() ;
-- `machinePos` vaut "x,y,z" (MTIR.encodeMachinePos) : l'autorité retrouve la
-- machine et revérifie option, état, distance, tournevis et huile.
-- Le serveur n'appelle jamais isValid (NetTimedAction.isValid) : complete()
-- refait toute la validation (possession, doublons, types, outils en main).
-- Animation et son sur le modèle de ISMoveablesAction (démontage au tournevis) :
-- CharacterActionAnims.Disassemble ; sons vanilla "Dismantle" (électrique,
-- sounds_player_electrical.txt) et "Screwdriver" (pédale, sounds_player_carpentry.txt).
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Alterations"

MTIR_MachineMaintenanceAction = ISBaseTimedAction:derive("MTIR_MachineMaintenanceAction")

local SOUNDS = { electric = "Dismantle", treadle = "Screwdriver" }
local CONDITION_MAX = 100

--- Machine à entretenir si tout est réuni, sinon nil.
local function canMaintain(self)
    local character = self.character
    local machine = MTIR.machineFromPos(self.machinePos)
    if not machine or not MTIR.isMaintenanceEnabled() or MTIR.getMachineCondition(machine) >= CONDITION_MAX then
        return nil
    end
    if not MTIR.isNearSewingMachine(character, machine) then
        return nil
    end
    if not self.screwdriver or not MTIR.predicateScrewdriver(self.screwdriver) then
        return nil
    end
    if not self.oil or not MTIR.predicateMaintenanceOil(self.oil) then
        return nil
    end
    return machine
end

--- Validation partagée par isValid et complete : machine, ou nil.
local function validate(self)
    local character = self.character
    if not MTIR.hasItem(character, self.oil) or not MTIR.sameItem(character:getPrimaryHandItem(), self.screwdriver) then
        return nil
    end
    return canMaintain(self)
end

function MTIR_MachineMaintenanceAction:isValid()
    if isClient() and self.started then
        return true
    end
    return validate(self) ~= nil
end

function MTIR_MachineMaintenanceAction:waitToStart()
    local machine = MTIR.machineFromPos(self.machinePos)
    if not machine then
        return false
    end
    self.character:faceThisObject(machine)
    return self.character:shouldBeTurning()
end

local function playWorkSound(self)
    local sound = self.machine and SOUNDS[MTIR.getMachineKindName(self.machine)]
    if sound then
        self.sound = self.character:getEmitter():playSound(sound)
    end
end

function MTIR_MachineMaintenanceAction:start()
    self.screwdriver = MTIR.resolveItem(self.character, self.screwdriver)
    self.oil = MTIR.resolveItem(self.character, self.oil)
    self.machine = MTIR.machineFromPos(self.machinePos)
    self.started = true
    self.screwdriver:setJobType(getText("IGUI_MTIR_JobType_MachineMaintenance"))
    self.screwdriver:setJobDelta(0.0)
    self:setActionAnim(CharacterActionAnims.Disassemble)
    self:setOverrideHandModels(self.screwdriver, nil)
    if self.machine then
        self.character:faceThisObject(self.machine)
    end
    playWorkSound(self)
end

function MTIR_MachineMaintenanceAction:update()
    self.screwdriver:setJobDelta(self:getJobDelta())
    if self.machine then
        self.character:faceThisObject(self.machine)
    end
    -- Sons vanilla non bouclés : relancés à la fin, comme ISMoveablesAction:update.
    if self.sound and not self.character:getEmitter():isPlaying(self.sound) then
        playWorkSound(self)
    end
    self.character:setMetabolicTarget(Metabolics.UsingTools)
end

local function stopSound(self)
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function MTIR_MachineMaintenanceAction:stop()
    stopSound(self)
    self.started = false
    self.screwdriver:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function MTIR_MachineMaintenanceAction:perform()
    stopSound(self)
    self.started = false
    self.screwdriver:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

--- Autorité : consomme les utilisations d'huile (UseAndSync retire l'objet vide et synchronise).
local function consumeOil(oil)
    for _ = 1, MTIR.MAINTENANCE_OIL_USES do
        if oil:getCurrentUses() <= 0 then
            return
        end
        oil:UseAndSync()
    end
end

function MTIR_MachineMaintenanceAction:complete()
    local machine = validate(self)
    if not machine then
        return false
    end
    local character = self.character
    consumeOil(self.oil)
    local condition = math.min(CONDITION_MAX, MTIR.getMachineCondition(machine) + MTIR.getMaintenanceGain(character, machine))
    MTIR.setMachineCondition(machine, condition)
    addXp(character, MTIR.getMaintenancePerk(machine), MTIR.getMaintenanceXp())
    MTIR.tell(character, {
        refresh = true,
        say = { key = "IGUI_MTIR_Say_MachineMaintained", arg = tostring(math.floor(condition + 0.5)) },
    })
    return true
end

function MTIR_MachineMaintenanceAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return MTIR.getMaintenanceDuration()
end

--- machinePos : "x,y,z" de la machine (MTIR.encodeMachinePos) ; screwdriver tenu en main
--- principale ; oil : huile alimentaire (MTIR.predicateMaintenanceOil).
function MTIR_MachineMaintenanceAction:new(character, machinePos, screwdriver, oil)
    local o = ISBaseTimedAction.new(self, character)
    o.machinePos = type(machinePos) == "string" and machinePos or ""
    o.screwdriver = screwdriver
    o.oil = oil
    o.stopOnWalk = true
    o.stopOnRun = true
    o.started = false
    o.caloriesModifier = 4
    o.maxTime = o:getDuration()
    return o
end
