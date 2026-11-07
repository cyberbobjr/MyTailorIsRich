-- MTIR_Effects : raideur due aux vêtements serrés. Le banc reproduit le moteur :
-- baisse de 0,002 x multiplicateur à chaque mise à jour (BodyPart.update, 42.21,
-- hors exercice en cours), passage de MTIR.applyStiffness tous les 30 ticks.

local T = {}

local PASS_TICKS = 30
local DECAY = 0.002

local PARTS = { "UpperLeg_L", "UpperLeg_R", "LowerLeg_L", "LowerLeg_R", "Foot_L", "Foot_R", "Torso_Upper" }

function T.setup()
    SandboxVars = { MyTailorIsRich = {} }
    BodyPartType = {}
    for _, name in ipairs(PARTS) do
        BodyPartType[name] = name
    end
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R = "ForeArm_L", "ForeArm_R"
    BodyPartType.UpperArm_L, BodyPartType.UpperArm_R = "UpperArm_L", "UpperArm_R"
    BodyPartType.Torso_Lower = "Torso_Lower"
    luautils = { split = function() return {} end }
    isServer = function() return false end
    isClient = function() return false end
    MTIR = nil
    loadMod("shared/MyTailorIsRich/MTIR_Core.lua")
    loadMod("shared/MyTailorIsRich/MTIR_Effects.lua")
    MTIR.getFeetParts = function() return { BodyPartType.Foot_L, BodyPartType.Foot_R } end
end

--- Joueur simulé : diffs = écart de taille par partie, pace = nil (immobile),
--- "walk", "run" ou "sprint".
local function newPlayer(diffs, pace)
    local player = { key = "p", pace = pace, exercising = false, parts = {}, list = {} }
    for _, name in ipairs(PARTS) do
        local part = { type = name, stiffness = 0 }
        function part:getType() return self.type end
        function part:getStiffness() return self.stiffness end
        function part:setStiffness(value) self.stiffness = math.max(0, math.min(100, value)) end
        player.parts[name] = part
        player.list[#player.list + 1] = part
    end
    MTIR.BodyDiffs.p0 = diffs
    function player:getPlayerNum() return 0 end
    function player:getBodyDamage()
        local owner = self
        return {
            getBodyParts = function()
                return { size = function() return #owner.list end, get = function(_, i) return owner.list[i + 1] end }
            end,
            getBodyPart = function(_, bodyPartType) return owner.parts[bodyPartType] end,
        }
    end
    function player:getFitness()
        local owner = self
        return { onGoingStiffness = function() return owner.exercising end }
    end
    function player:isPlayerMoving() return self.pace ~= nil end
    function player:isRunning() return self.pace == "run" end
    function player:isSprinting() return self.pace == "sprint" end
    return player
end

--- Avance de `ticks` mises à jour à multiplicateur 1 ; rappelle chaque valeur vue.
local function run(player, ticks, part)
    local seen = {}
    local elapsed = 0
    for _ = 1, ticks do
        if not player.exercising then
            for _, bodyPart in ipairs(player.list) do
                if bodyPart.stiffness > 0 then
                    bodyPart:setStiffness(bodyPart.stiffness - DECAY)
                end
            end
        end
        elapsed = elapsed + 1
        if elapsed >= PASS_TICKS then
            MTIR.applyStiffness(player, elapsed)
            elapsed = 0
        end
        seen[#seen + 1] = player.parts[part].stiffness
    end
    return seen
end

T["bas trop petit d'une taille, en marchant : aucune raideur qui clignote"] = function()
    local player = newPlayer({ UpperLeg_L = -1, UpperLeg_R = -1, LowerLeg_L = -1, LowerLeg_R = -1 }, "walk")
    for i, value in ipairs(run(player, 600, "UpperLeg_L")) do
        assertEq(value, 0, "raideur au tick " .. i)
    end
end

T["bas trop petit de deux tailles, en courant : la raideur s'installe sans retomber"] = function()
    local player = newPlayer({ LowerLeg_L = -2 }, "run")
    local seen = run(player, 3000, "LowerLeg_L")
    -- Démarrage : tant que la raideur reste sous la baisse d'un passage (0,06), le
    -- moteur la ramène à 0 entre deux passages ; ensuite elle ne retombe plus.
    for i = 600, #seen do
        assertTrue(seen[i] > 0, "retombée à 0 au tick " .. i)
    end
    -- Une fois installée : course 0,00225 + guérison ralentie 0,001 - baisse 0,002
    -- = 0,00125 par tick, soit environ 3,7 sur 3000 ticks moins le démarrage.
    assertTrue(seen[3000] > 3.3 and seen[3000] < 3.8, "raideur après 3000 ticks : " .. seen[3000])
end

T["sprint en bas trop petit d'une taille : la raideur monte"] = function()
    local player = newPlayer({ UpperLeg_R = -1 }, "sprint")
    local seen = run(player, 3000, "UpperLeg_R")
    assertTrue(seen[3000] > 0.5, "raideur après un long sprint : " .. seen[3000])
end

T["guérison ralentie mais jamais bloquée sous un bas serré"] = function()
    local player = newPlayer({ UpperLeg_L = -1 }, nil)
    player.parts.UpperLeg_L.stiffness = 5
    local seen = run(player, 4000, "UpperLeg_L")
    -- Sans MTIR : 2500 ticks ; avec un écart de 1 : 0,0015 par tick, environ 3333 ticks.
    assertTrue(seen[3000] > 0, "guérison ralentie")
    assertEq(seen[4000], 0, "raideur guérie")
end

T["grand écart : la guérison reste au moins à moitié"] = function()
    local player = newPlayer({ Torso_Upper = -4 }, nil)
    player.parts.Torso_Upper.stiffness = 5
    local seen = run(player, 5100, "Torso_Upper")
    assertEq(seen[5100], 0, "raideur guérie en deux fois le temps vanilla")
end

T["bonne taille : MTIR ne touche pas la raideur"] = function()
    local player = newPlayer({ UpperLeg_L = 0 }, "sprint")
    player.parts.UpperLeg_L.stiffness = 1
    local seen = run(player, 600, "UpperLeg_L")
    assertEq(seen[600], 0, "baisse vanilla seule")
end

T["exercice en cours : la marche ajoute tout son taux"] = function()
    local player = newPlayer({ LowerLeg_R = -1 }, "walk")
    player.exercising = true
    local seen = run(player, 300, "LowerLeg_R")
    assertTrue(math.abs(seen[300] - 300 * 0.00075) < 1e-6, "raideur pendant l'exercice : " .. seen[300])
end

return T
