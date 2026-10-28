-- ============================================================================
-- My Tailor Is Rich — squelette commun des actions chronométrées
--
-- Les actions du mod répètent toutes le même squelette :
--   * isValid : sur un client, une action déjà commencée va jusqu'au bout. Le
--     serveur, lui, n'appelle jamais isValid (NetTimedAction) : chaque action
--     refait sa validation complète dans complete() ;
--   * une barre de progression portée par un objet de l'action (setJobType au
--     début, setJobDelta pendant, remise à zéro à l'arrêt comme à la réussite) ;
--   * l'arrêt et la réussite finissent par l'appel vanilla correspondant.
-- Ce module porte ce squelette une fois pour toutes. Ce qui reste propre à une
-- action (validation, animation, sons, matériaux, durée) reste chez elle.
-- ============================================================================

require "TimedActions/ISBaseTimedAction"
require "MyTailorIsRich/MTIR_Core"

MTIR.Action = {}

--- Vrai si l'action tourne déjà chez un client : elle doit alors aboutir, et
--- l'autorité tranchera dans complete().
function MTIR.Action.startedOnClient(self)
    return isClient() and self.started == true
end

--- Début : l'action est en cours et `item` porte la barre de progression, avec le
--- libellé de `jobTypeKey` (clé de traduction, facultative).
function MTIR.Action.startProgress(self, item, jobTypeKey)
    self.started = true
    if jobTypeKey then
        item:setJobType(getText(jobTypeKey))
    end
    item:setJobDelta(0.0)
end

--- Pendant : avancement de la barre.
function MTIR.Action.updateProgress(self, item)
    item:setJobDelta(self:getJobDelta())
end

--- Fin de l'action, réussie ou non : plus rien en cours, barre vidée.
function MTIR.Action.endProgress(self, item)
    self.started = false
    item:setJobDelta(0.0)
end

--- Arrêt (joueur interrompu, action annulée) puis arrêt vanilla.
function MTIR.Action.stop(self, item)
    MTIR.Action.endProgress(self, item)
    ISBaseTimedAction.stop(self)
end

--- Fin du temps imparti puis perform vanilla (complete() suit).
function MTIR.Action.perform(self, item)
    MTIR.Action.endProgress(self, item)
    ISBaseTimedAction.perform(self)
end

return MTIR
