# My Tailor Is Rich — améliorations de code et idées de fonctionnalités

| | |
|---|---|
| Mod | My Tailor Is Rich (nom affiché `batman_My Tailor Is Rich`) |
| `id` | `batman_MyTailorIsRich` (+ `batman_MyTailorIsRich_Uninstall`) |
| Workshop | 3810122988 |
| Version analysée | 0.4.5 (`mod.info`, `CHANGELOG.md`), variante `Contents/mods/batman_MyTailorIsRich/42.21` |
| Build cible | 42.21 (`versionMin=42.21`) ; sources consultées : Lua vanilla installé, Java décompilé `E:\pz-decompiled\42.21.0` |
| Date | 2026-10-21 ; **avancement mis à jour le 2026-10-23** (version publiée : 0.4.6, tag `v0.4.6`, commit `83e4ce5`) |
| Périmètre | Lecture statique de tout le Lua (`shared`, `client`, `server`), des scripts (`MTIR_items.txt`, `MTIR_entities.txt`, `MTIR_patternbinder.txt`, `MTIR_sounds.txt`), de `sandbox-options.txt`, des traductions EN, du `README.md`, du `CHANGELOG.md`, des descriptions Steam, des tests (`tests/`) et de la CI. Rien n'a été testé en jeu pour l'analyse initiale (voir le tableau de bord pour les vérifications faites depuis). |

Statut des constats :

- **confirmé statiquement** : le code lu montre le comportement, avec ses références ;
- **à vérifier en jeu** : le constat repose sur une hypothèse moteur ou un scénario non reproduit.

Les numéros de ligne renvoient aux fichiers sous `Contents/mods/batman_MyTailorIsRich/42.21/media/lua/` (préfixes `shared/`, `client/`, `server/`), sauf mention contraire.

Échelles : **priorité** haute / moyenne / basse ; **effort** S (moins d'une demi-journée), M (une à deux journées), L (plusieurs jours, ressources ou traductions nouvelles).

---

## Tableau de bord — ce qui est fait et ce qui reste

**Légende** : ✅ fait · 🟡 fait en partie · ⬜ pas commencé · ❌ annulé. « Publié » = présent dans une version du Workshop ; « non publié » = sur `main`, pas encore dans une version publiée du `CHANGELOG.md`. Détail de chaque point dans les parties 1 et 2 ; protocole des tests en jeu automatiques dans `docs/annexes/tests/autotest.md`.

**Bilan** : améliorations de code **5 faites, 0 en partie, 9 à faire, 4 annulées** (sur 18 ; annulées : C05, C06 et C07 le 2026-10-27, C09 le 2026-10-28) ; idées de fonctionnalités **0 faite, 0 en partie, 20 à faire** (sur 20).

### Améliorations de code

| ID | Sujet | État | Testé | Publié | Commit | Ce qui reste |
|---|---|---|---|---|---|---|
| C01 | Feuilles écrites et favoris consommés comme matériaux | ✅ Corrigé | hors jeu (lupa) ; pz-autotest solo et MP du 2026-10-21 (contrôles C01 verts) | 0.4.6 | `00cd2e7` | Vérifier les menus à l'œil (tracé, copie) ; `Base.GraphPaper` non ajouté (à décider) |
| C02 | Fil cherché par type ou par tag selon l'action | ✅ Corrigé | hors jeu (lupa) | 0.4.6 | `00cd2e7` | Vérifier en jeu (fil aramide en retouche ou couture) |
| C03 | Usure estimée figée dans l'infobulle d'un client MP | ✅ Corrigé | — | 0.4.6 | `00cd2e7` | Vérifier en jeu sur un client MP |
| C04 | Effets des chaussures limités à l'emplacement `shoes` | ✅ Corrigé | hors jeu (lupa) | 0.4.6 | `00cd2e7` | Vérifier en jeu avec une chaussure de mod |
| C05 | Copie de patron sans coût pour l'original | ❌ Annulé | — | — | — | Rien : équilibrage voulu, pas un bug (décision du 2026-10-27) |
| C06 | Infobulle « Enfiler » qui révèle l'ajustement | ❌ Annulé | — | — | — | Rien : confort voulu, aucune gêne constatée en jeu (décision du 2026-10-27) |
| C07 | Clé joueur serveur = compte seul (écran partagé) | ❌ Annulé | — | — | — | Rien : aucun jeu en écran partagé (décision du 2026-10-27) |
| C08 | Tables par joueur jamais purgées | ✅ Corrigé | hors jeu (lupa, luacheck) | non publié | `58d56f4` | Vérifier en jeu : mourir, revenir, jauge d'ampoules à zéro |
| C09 | Usure comptée par événement horaire | ❌ Annulé | — | — | — | Rien : aucune heure ne peut être sautée (décision du 2026-10-28) |
| C10 | Noms de patrons dans la langue du serveur | ⬜ À faire | — | — | — | Tout |
| C11 | Taille d'artisanat : envoi unique, voies non couvertes | ⬜ À faire | — | — | — | Vérifier en jeu, puis corriger |
| C12 | `instanceItem` pour lire les stats d'origine | ⬜ À faire | — | — | — | Relevé des getters 42.21, puis correction |
| C13 | Stats non rétablies quand une option passe à 0 | ⬜ À faire | — | — | — | Tout |
| C14 | Deux analyseurs de listes sandbox | ⬜ À faire | — | — | — | Tout |
| C15 | Peau entière consommée pour une unité | ⬜ À faire | — | — | — | Tout |
| C16 | Portée machine / table sans test de mur | ⬜ À faire | — | — | — | Tout |
| C17 | Duplications, incohérences d'actions, trous de tests | ⬜ À faire | — | — | — | Tout |
| C18 | Descriptions Steam proches de 8 000 octets | ⬜ À faire | — | — | — | Tout |

### Idées de fonctionnalités

| ID | Idée | État | Remarque |
|---|---|---|---|
| I01 | Mètre ruban vanilla | ⬜ Proposée | Rang 5 de la priorisation |
| I02 | Couture sur mesure pour un autre joueur | ⬜ Proposée | Dépend de I01 |
| I03 | Patron qui garde l'apparence du modèle | ⬜ Proposée | |
| I04 | Garnir une chaussure trop grande | ⬜ Proposée | |
| I05 | Chaussettes épaisses | ⬜ Proposée | |
| I06 | Alerte de changement de taille | ⬜ Proposée | |
| I07 | Panneau « Garde-robe » | ⬜ Proposée | Prérequis C03 fait |
| I08 | Pastille d'ajustement dans l'inventaire | ⬜ Proposée | |
| I09 | Blanchir à la javel | ⬜ Proposée | |
| I10 | Teintures naturelles | ⬜ Proposée | |
| I11 | Rétrécir au lavage | ⬜ Proposée | |
| I12 | Retouche temporaire aux trombones | ⬜ Proposée | |
| I13 | Série de travaux sur machine | ⬜ Proposée | |
| I14 | Effilochage des vêtements très usés | ⬜ Proposée | |
| I15 | Écussons et insignes brodés | ⬜ Proposée | |
| I16 | Pièces d'usure des machines | ⬜ Proposée | |
| I17 | Surjeteuse ou machine industrielle | ⬜ Proposée | |
| I18 | Magazines de patronage | ⬜ Proposée | |
| I19 | API publique pour les autres mods | ⬜ Proposée | |
| I20 | Mannequins de vitrine taillés | ⬜ Proposée | |

---

## Partie 1 — Améliorations de code

### Vue d'ensemble

| ID | Sujet | Risque principal | Priorité | Effort | Statut | Avancement |
|---|---|---|---|---|---|---|
| C01 | Feuilles écrites et objets favoris consommés comme matériaux | Bug / perte de données joueur | Haute | S | confirmé statiquement | ✅ 0.4.6 |
| C02 | Fil cherché par type `Thread` ou par tag selon l'action | Bug / compatibilité | Moyenne | S | confirmé statiquement | ✅ 0.4.6 |
| C03 | Usure estimée figée dans l'infobulle d'un client MP | Bug MP | Moyenne | S | confirmé statiquement | ✅ 0.4.6 |
| C04 | Effets continus des chaussures limités à l'emplacement `shoes` | Bug / compatibilité mods | Moyenne | S | confirmé statiquement | ✅ 0.4.6 |
| C05 | Copie de patron sans coût pour l'original | Équilibre | — | — | confirmé statiquement (comportement voulu) | ❌ annulé |
| C06 | Infobulle « Enfiler » qui révèle l'ajustement | Cohérence gameplay | — | — | confirmé statiquement (comportement voulu) | ❌ annulé |
| C07 | Clé joueur serveur = compte seul (écran partagé) | MP | — | — | confirmé statiquement (hors périmètre) | ❌ annulé |
| C08 | Tables par joueur jamais purgées, jauge héritée après la mort | MP / persistance | Basse | S | confirmé statiquement | ✅ non publié |
| C09 | Usure comptée par événement horaire | Simulation | — | — | infondé, confirmé statiquement | ❌ annulé |
| C10 | Noms de patrons figés dans la langue du serveur | Traduction MP | Moyenne | M | confirmé statiquement | ⬜ |
| C11 | Taille d'artisanat : envoi unique, voies de fabrication non couvertes | MP / compatibilité | Basse | M | à vérifier en jeu | ⬜ |
| C12 | `instanceItem` pour lire les stats d'origine | Compatibilité / effets de bord | Basse | S-M | à vérifier en jeu | ⬜ |
| C13 | Stats dérivées non rétablies quand une option passe à 0 | Bug mineur | Basse | S | confirmé statiquement | ⬜ |
| C14 | Deux analyseurs de listes sandbox, règles différentes | Maintenabilité | Basse | S | confirmé statiquement | ⬜ |
| C15 | Peau entière consommée pour une unité | Gameplay | Basse | S | confirmé statiquement | ⬜ |
| C16 | Portée machine / table sans test de mur | Autorité serveur | Basse | S | à vérifier en jeu | ⬜ |
| C17 | Duplications, incohérences d'actions, trous de tests | Maintenabilité | Basse | M | confirmé statiquement | ⬜ |
| C18 | Descriptions Steam presque à la limite de 8 000 octets | Maintenabilité / traduction | Basse | S | confirmé statiquement | ⬜ |

---

### C01 — Feuilles écrites, nommées ou favorites consommées comme papier ou matériau

- **Problème** : le tracé et la copie prennent les N premières `Base.SheetPaper2` de l'inventaire, sacs compris, sans regarder si la feuille porte un texte, un nom ou la marque « favori ». Le même `MTIR.pickItems` choisit aussi les bandes, trombones et exemplaires sans exclure les favoris.
- **Preuves** :
  - `shared/MyTailorIsRich/MTIR_Patterns.lua:296-298` : `predicatePaper` ne teste que le type ;
  - `client/MyTailorIsRich/MTIR_PatternMenu.lua:85-87` et `client/MyTailorIsRich/MTIR_PatternBinderMenu.lua:151-153` : `getItemsFromFullType(..., true)` puis `pickItems` ;
  - `shared/MyTailorIsRich/MTIR_Core.lua:661-670` : `pickItems` prend les premiers objets de la liste ;
  - `shared/TimedActions/MTIR_TracePatternAction.lua:103` : `consumeItems(self.papers, ...)`.
- **Risque** : perte d'une note du joueur, ou d'un document d'un autre mod fondé sur `SheetPaper2` (papier nommé, carnet de quête). Le joueur ne choisit pas les feuilles.
- **Correction** : un prédicat `MTIR.isBlankPaper(item)` qui écarte les favoris, les noms personnalisés (`isCustomName`, ou `getDisplayName() ~= getScriptItem():getDisplayName()`, méthode de la base moteur) et les pages écrites ; l'utiliser dans les menus et dans `validate` côté autorité. Écarter aussi les favoris dans `pickItems` et `pickPatternMaterials`. Accepter `Base.GraphPaper` vierge en plus de `SheetPaper2`.
- **Priorité** : haute. **Effort** : S.
- **Statut** : confirmé statiquement pour la consommation ; nom exact de l'accesseur des pages écrites d'une `Literature` en 42.21 à vérifier dans le Java.
- **Avancement : ✅ corrigé, publié en 0.4.6 (commit 00cd2e7), testé hors jeu et par pz-autotest en solo et en MP (2026-10-21)** — Page écrite détectée par `Literature.isEmptyPages()` (`zombie/inventory/types/Literature.java:465`, 42.21.0), plus `getLockedBy()`, `isCustomName()`, nom affiché ≠ nom du script et ModData présente (`MTIR.isBlankSheet`, contrôlé aussi par `validate` sur l'autorité). Favoris écartés par `pickItems`, `pickPatternMaterials` et les contrôles des actions. `Base.GraphPaper` non ajouté (nouvelle fonctionnalité, à décider).

### C02 — Fil : type `Thread` pour la couture, tag `base:thread` pour la broderie

- **Problème** : couture d'après patron, retouche et remise en état cherchent seulement le type `Thread`. La broderie, elle, et toute la validation d'autorité acceptent le tag `base:thread`.
- **Preuves** :
  - `shared/MyTailorIsRich/MTIR_Alterations.lua:91` et `shared/MyTailorIsRich/MTIR_Patterns.lua:425` : `inventory:getItemsFromType("Thread", true)` ;
  - `shared/MyTailorIsRich/MTIR_Core.lua:630-633` : `predicateThread` accepte le tag ;
  - `client/MyTailorIsRich/MTIR_DecorMenu.lua:156`, `client/MyTailorIsRich/MTIR_MachineTabEmbroider.lua:65` : `getAllEvalRecurse(MTIR.predicateThread)` ;
  - vanilla 42.21 `media/scripts/generated/items/drainable.txt:797-820, 2264-2305, 2408` : `Thread_Aramid`, `Thread_Sinew`, `DentalFloss`, `FishingLine`, `PremiumFishingLine` portent `base:thread`.
- **Risque** : fil aramide ou tendon invisible pour l'interface des retouches et des patrons, alors qu'il sert à broder. Le fil d'un mod qui n'utilise que le tag n'est pas reconnu. Le libellé du besoin est toujours « Fil » (`client/MyTailorIsRich/MTIR_ContextMenu.lua:169-170`).
- **Correction** : une seule collecte, `MTIR.collectThreads(inventory)`, qui place les bobines `Thread` en tête puis les autres objets du tag, dans l'ordre du vanilla (`ISInventoryPaneContextMenu.lua:1489`, cité dans la base moteur). Décider s'il faut exclure le fil de pêche et le fil dentaire pour les vêtements, et le faire dans le prédicat partagé.
- **Priorité** : moyenne. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ✅ corrigé, publié en 0.4.6 (commit 00cd2e7), testé hors jeu, à vérifier en jeu** — Collecte unique `MTIR.collectThreads` (type `Thread` puis tag) ; fil de pêche et fil dentaire toujours acceptés, comme pour la broderie (choix inchangé).

### C03 — Infobulle d'usure figée chez un client MP

- **Problème** : l'infobulle relit `MTIR.DegradingChance[id]` et ne calcule la chance que si la valeur manque. Le cache n'est vidé que par `onEveryHours`, qui n'est inscrit que sur l'autorité.
- **Preuves** : `client/MyTailorIsRich/MTIR_Tooltip.lua:87` ; `shared/MyTailorIsRich/MTIR_Effects.lua:355` (écriture du cache) ; `server/MyTailorIsRich/MTIR_Server.lua:18-20` (`return` sur client) et `:57-58` (remise à zéro horaire).
- **Risque** : sur un client MP, « jours restants » et couleur ne bougent plus après le premier affichage, même si le vêtement devient sale, mouillé ou ensanglanté. La table grandit aussi d'une entrée par objet survolé pendant toute la session.
- **Correction** : côté client, recalculer à chaque affichage (le calcul est léger) ou garder un cache horodaté par `getTimestampMs`, vidé toutes les quelques secondes. Garder le cache horaire sur l'autorité.
- **Priorité** : moyenne. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ✅ corrigé, publié en 0.4.6 (commit 00cd2e7), à vérifier en jeu sur un client MP** — Le client MP recalcule à chaque affichage et ne garde rien en cache.

### C04 — Inconfort, ampoules, endurance et perte limités à l'emplacement `shoes`

- **Problème** : `wornShoe` lit `getWornItem(ItemBodyLocation.SHOES)`. Or `MTIR_Sizing` classe aussi en « chaussure » les vêtements de mod qui ne couvrent que les pieds, quel que soit leur emplacement.
- **Preuves** :
  - `shared/MyTailorIsRich/MTIR_ShoeEffects.lua:84` : emplacement vanilla seul ;
  - `shared/MyTailorIsRich/MTIR_Sizing.lua:152-160, 198-199` : déduction « shoe » pour tout emplacement ;
  - `shared/MyTailorIsRich/MTIR_Effects.lua:186-204` (`applyDerivedStats`) et `shared/MyTailorIsRich/MTIR_Shoes.lua:317-332` (`getShoeTripChance`) parcourent toute la tenue.
- **Risque** : une botte de mod hors `shoes` a une pointure, raidit les pieds et réduit l'écrasement, mais ne donne ni inconfort, ni ampoule, ni endurance, ni perte de chaussure. Le README promet ces effets pour les mods.
- **Correction** : `wornShoe` parcourt `getWornItems()` et rend la première pièce `canShoeHaveSize`, avec un raccourci sur `SHOES`. Ajouter un test lupa avec un emplacement de mod.
- **Priorité** : moyenne. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ✅ corrigé, publié en 0.4.6 (commit 00cd2e7), testé hors jeu, à vérifier en jeu** — `wornShoe` cherche ensuite dans toute la tenue ; test lupa ajouté.

### C05 — Copier un patron ne coûte rien à l'original — ❌ annulé

- **Comportement** : la copie garde l'original intact et reçoit `PatternMaxUses` utilisations neuves. Un original devient une source illimitée de patrons pleins, contre du papier.
- **Preuves** : `shared/MyTailorIsRich/MTIR_PatternCopy.lua:4-9` (en-tête) et `:33-39` (`uses = maxUses`), `:65-79`.
- **Conséquence** : la limite « 5 coutures puis le patron est perdu » ne joue plus pour qui a un original. La perte de précision, une par génération, ne touche pas les copies de première génération.
- **Pistes écartées** : au choix, copier retire une utilisation de l'original ; la copie reçoit les utilisations restantes de l'original au lieu du maximum ; ou une option sandbox `PatternCopyUsesOriginal`.
- **Statut** : comportement confirmé statiquement et **voulu**.
- **Avancement : ❌ annulé (2026-10-27)** — décision de l'auteur : c'est de l'équilibrage, pas un bug. Le comportement reste tel quel ; aucune correction ni option sandbox à prévoir.

### C06 — L'infobulle « Enfiler » donne l'ajustement avant toute lecture — ❌ annulé

- **Comportement** : l'enveloppe de `doWearClothingTooltip` affiche l'indice d'ajustement dès que la taille existe, sans tester `hint` ni `reveal`. L'infobulle d'objet, elle, affiche « ??? » tant que rien n'est connu.
- **Preuves** : `client/MyTailorIsRich/MTIR_ClientUI.lua:298-307` (chaussures) et `:313-329` (vêtements) ; à comparer à `client/MyTailorIsRich/MTIR_Tooltip.lua:33-39, 58-64`.
- **Conséquence** : la lecture d'étiquette sans compétence n'apprend rien de plus qu'un survol du menu « Enfiler ». En MP, la taille est de toute façon présente dans la ModData du client : c'est une limite connue, à ne pas aggraver.
- **Piste écartée** : n'afficher l'indice qu'avec `hint` ou `reveal`, sinon une ligne « Taille inconnue ».
- **Statut** : confirmé statiquement et **voulu**.
- **Avancement : ❌ annulé (2026-10-27)** — décision de l'auteur après une partie où la taille était systématiquement vérifiée avant d'enfiler : aucune gêne ressentie, l'indice au survol est un confort assumé. À revoir seulement si un joueur signale qu'il remplace l'action « Vérifier la taille ».

### C07 — Clé joueur côté serveur : le compte seul — ❌ annulé

- **Comportement** : `MTIR.playerKey` rend `"u" .. username` sur le serveur. Deux joueurs en écran partagé sur une même connexion ont le même compte ; seul `getPlayerNum()` les distingue côté serveur (base moteur, `multiplayer.md`, « `getPlayerNum()` d'un joueur côté serveur »).
- **Preuves** : `shared/MyTailorIsRich/MTIR_Effects.lua:25-31` ; utilisateurs de la clé : `BodyDiffs` (`:186-188`), `Friction` (`shared/MyTailorIsRich/MTIR_ShoeEffects.lua:227-229`), `DiscomfortFloor`, `ServerCraftSize` (`MTIR_Effects.lua:565-576`). Côté client, `MTIR.setUICraftSize` envoie toujours pour `getPlayer()` (`client/MyTailorIsRich/MTIR_ClientFx.lua:89-92`).
- **Conséquence** : raideur, jauge d'ampoules, plancher d'inconfort et tailles d'artisanat mélangés entre les deux joueurs. Rien pour un joueur seul par PC, solo ou en MP.
- **Piste écartée** : `"u" .. username .. "#" .. player:getPlayerNum()` sur le serveur ; passer le joueur du widget d'artisanat (`widget.player`) à `setUICraftSize`. Trois lignes, sans migration (ces tables ne sont qu'en mémoire).
- **Statut** : confirmé statiquement ; **hors périmètre d'usage**.
- **Avancement : ❌ annulé (2026-10-27)** — décision de l'auteur : personne ne joue en écran partagé, le cas ne se produit jamais. À reprendre tel quel si l'écran partagé devient un usage réel.

### C08 — Tables par joueur jamais purgées ; jauge héritée après la mort

- **Problème** : `lastClimb`, `lastFall`, `lastMachineSound`, `MTIR.Friction`, `MTIR.ServerCraftSize` et `MTIR.BodyDiffs` gardent une entrée par compte pour toute la durée du serveur. La jauge de frottement survit à la mort et passe au personnage suivant du même compte.
- **Preuves** : `server/MyTailorIsRich/MTIR_Server.lua:147-148, 190` ; `shared/MyTailorIsRich/MTIR_ShoeEffects.lua:191, 227-229` ; `shared/MyTailorIsRich/MTIR_Effects.lua:15-17`.
- **Risque** : mémoire négligeable, mais un nouveau personnage peut recevoir une ampoule plus tôt que prévu.
- **Correction** : vider les entrées du joueur sur `OnCharacterDeath` côté serveur (événement disponible sur un serveur dédié, contrairement à `OnPlayerDeath`, base moteur) et en solo sur `OnCreatePlayer`.
- **Priorité** : basse. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ✅ corrigé le 2026-10-28 (commit `58d56f4`), sur `main`, non publié, testé hors jeu (lupa + luacheck), à vérifier en jeu** — Deux purges partagées, `MTIR.forgetPlayerEffects` (zones serrées, taille d'artisanat d'autorité) et `MTIR.forgetPlayerShoeState` (jauge de frottement, inconfort à corriger) ; le plancher d'inconfort n'est pas concerné, il est reconstruit à chaque recalcul complet. Côté autorité, `forgetPlayerState` de `MTIR_Server.lua` les appelle et vide aussi ses trois tables de délais (`lastClimb`, `lastFall`, `lastMachineSound`), sur `OnCharacterDeath` (zombies et animaux écartés par `instanceof(IsoPlayer)` et `isAnimal()`) et, en solo, sur `OnCreatePlayer`. Côté client, les tailles choisies dans les fenêtres d'artisanat sont oubliées au personnage neuf (`MTIR.forgetUICraftSizes`, seulement pour le joueur local 0 : la table est commune aux joueurs locaux). Preuves : `Events.OnCharacterDeath` déclenché aussi sur un serveur dédié (`IsoPlayer.OnDeath` appelle `super.OnDeath()` avant le retour `GameServer.server`, `IsoPlayer.java:6093-6097`) et pour tout personnage (`IsoGameCharacter.DoDeath`, `:1812-1815`) ; tests `tests/lua/test_forget_player_state.lua` (5 cas). Reste à faire : une déconnexion ne purge rien (quelques centaines d'octets par compte pour la durée du serveur, volontairement laissés).

### C09 — Usure et effets « par minute » comptés par événement — ❌ annulé

- **Constat de départ** : l'usure horaire et les effets d'autorité de la minute reposent sur `EveryHours` et `EveryOneMinute`. D'après la base moteur (`api-42-21.md`, « `EveryHours` : déclenchement, heures sautées »), ces événements partent une fois par mise à jour, même si plusieurs heures ont passé.
- **Preuves** : `server/MyTailorIsRich/MTIR_Server.lua:53-60, 232-233`. Le même fichier sait déjà compter le temps écoulé (`elapsedGameMinutes`, `:66-72`).
- **Risque supposé** : usure sous-estimée au temps accéléré ; pas de rattrapage après une pause.
- **Pourquoi c'est infondé** : le moteur avance `1 / durée_du_jour_en_minutes / 60 × multiplicateur / 2` heure par mise à jour (`GameTime.java:480`), et le plus gros multiplicateur du jeu est celui du sommeil, `200 × (30 / FPS verrouillés)`, soit 100 à 60 FPS (`GameTime.java:891-893`). Avec la durée de jour par défaut (60 minutes réelles), une mise à jour avance 0,007 minute de jeu en vitesse normale, 0,27 au bouton ×40 et **0,83 en dormant** : sauter une heure demanderait un multiplicateur d'environ 7 200. Aucune heure n'est donc jamais sautée, et l'usure horaire est tirée une fois par heure de jeu, comme prévu.
- **Reste, en théorie** : la **minute** peut sauter si la durée du jour est raccourcie dans le bac à sable (1,7 minute par mise à jour en dormant à 30 minutes par jour, 3,3 à 15). Le seul tirage par minute est la chance qu'un vêtement trop grand tombe (`shared/MyTailorIsRich/MTIR_Effects.lua:300-302`) : l'effet est que les vêtements trop grands tombent moins souvent pendant le sommeil, ce qui est souhaitable.
- **Piste écartée** : compter les heures entières écoulées avec `getWorldAgeHours()` et tirer l'usure autant de fois (borné), comme pour les minutes du tick.
- **Statut** : fait moteur juste (`EveryHours` ne rattrape pas les heures sautées), mais **sans effet ici** ; arithmétique confirmée statiquement sur le Java 42.21.
- **Avancement : ❌ annulé (2026-10-28)** — décision de l'auteur : rien à corriger, le cas chiffré ne se produit pas.

### C10 — Noms de patrons dans la langue du serveur

- **Problème** : le nom d'un patron est composé et enregistré par l'autorité. En MP, un joueur d'une autre langue voit la langue du serveur. La 0.4.5 a corrigé les clés brutes, pas ce point.
- **Preuves** : `shared/MyTailorIsRich/MTIR_Patterns.lua:99-113, 325-326` ; `shared/MyTailorIsRich/MTIR_PatternCopy.lua:73` ; `shared/MyTailorIsRich/MTIR_PrintedPatterns.lua:157` ; repli client limité aux clés brutes : `shared/MyTailorIsRich/MTIR_PatternBinder.lua:196-211`.
- **Risque** : traduction incomplète sur un serveur multilingue.
- **Correction** : recomposer le nom sur le client à l'affichage, avec la technique déjà employée pour les tailles (remplacement temporaire de `getName` pendant le rendu, `client/MyTailorIsRich/MTIR_ClientUI.lua:136-187`) et dans l'infobulle. La clé se déduit déjà du type et des données (`MTIR.getPatternNameKey`). Le nom enregistré reste le repli pour les autres mods.
- **Priorité** : moyenne. **Effort** : M.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

### C11 — Taille d'artisanat : envoi unique et voies non couvertes

- **Problème** :
  - la taille choisie n'est envoyée qu'au changement (`client/MyTailorIsRich/MTIR_ClientFx.lua:84-93`) et vit en mémoire serveur (`shared/MyTailorIsRich/MTIR_Effects.lua:565-576`). Les commandes Lua sont fiables mais non ordonnées par rapport aux paquets d'action (base moteur, `multiplayer.md`). Un changement suivi d'une fabrication immédiate peut donc utiliser l'ancienne taille ;
  - seul `ISHandcraftAction:performRecipe` est enveloppé (`shared/MyTailorIsRich/MTIR_VanillaHooks.lua:248-288`). `ISCraftAction:complete` appelle aussi `Actions.addOrDropItem` (vanilla `shared/TimedActions/ISCraftAction.lua:111`). Les sorties d'établis automatiques ne passent par aucun des deux.
- **Risque** : vêtement fabriqué « taille à choisir » ou à la mauvaise taille ; en solo, rien.
- **Correction** : renvoyer la taille courante au début de l'action côté client (enveloppe de `ISHandcraftAction:start`) ; envelopper aussi `ISCraftAction:complete` si cette voie sert encore en 42.21 ; garder `MTIR_ChooseSizeAction` comme filet.
- **Priorité** : basse. **Effort** : M.
- **Statut** : à vérifier en jeu (fréquence de la course, usage réel d'`ISCraftAction`).
- **Avancement : ⬜ à faire.**

### C12 — `instanceItem` pour lire les valeurs d'origine

- **Problème** : vitesse de combat, défenses, résistances, force d'écrasement et protection balistique sont lues sur une instance créée pour l'occasion.
- **Preuves** : `shared/MyTailorIsRich/MTIR_Effects.lua:80-101` ; `shared/MyTailorIsRich/MTIR_Shoes.lua:273-279` ; `shared/MyTailorIsRich/MTIR_PrintedPatterns.lua:106-114`. L'isolation est déjà lue sur le script (`MTIR_Effects.lua:72-78`).
- **Risque** : chaque instance exécute l'`OnCreate` du script, éventuellement posé par un autre mod (base moteur, `loot-distributions.md`), et consomme un identifiant. Effet de bord peu probable mais invisible.
- **Correction** : lire sur le script (`ScriptManager.instance:getItem(t)`) chaque valeur dont le getter existe en 42.21 ; garder l'instance pour les seules valeurs non exposées, en commentant pourquoi.
- **Priorité** : basse. **Effort** : S à M (relevé des getters `Item` à faire).
- **Statut** : à vérifier (liste des getters du script Item 42.21).
- **Avancement : ⬜ à faire.**

### C13 — Valeurs dérivées non rétablies quand une option passe à 0

- **Problème** : `updateClothesStats` n'écrit défenses et résistances que si la perte configurée est positive. Si un admin passe l'option à 0 en cours de partie, les valeurs déjà réduites restent jusqu'au rechargement.
- **Preuves** : `shared/MyTailorIsRich/MTIR_Effects.lua:140-167`, en particulier `:158-166`. Ces valeurs ne sont pas sauvegardées (`zombie/inventory/types/Clothing.java:594-627` : `save` n'écrit que sprite, saleté, sang, humidité et rustines), d'où un retour à la normale au chargement.
- **Correction** : écrire toujours les valeurs (d'origine si la perte vaut 0).
- **Priorité** : basse. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

### C14 — Deux analyseurs pour les listes sandbox

- **Problème** : `ListCustomClothes` est lue par `MTIR.getCustomClothes` (virgules seules, difficulté entière > 0). `ListExcludedClothes` et `ExtraSizedLocations` passent par `parseList`, qui accepte aussi `;` et arrondit la difficulté.
- **Preuves** : `shared/MyTailorIsRich/MTIR_Core.lua:100-130` ; `shared/MyTailorIsRich/MTIR_Sizing.lua:81-96, 104-115, 187`.
- **Risque** : un admin qui reprend le séparateur `;` de l'exemple d'`ExtraSizedLocations` voit sa liste de vêtements ignorée sans message.
- **Correction** : un seul analyseur pour les trois options, et un `print` en anglais pour chaque type inconnu, une fois par valeur d'option.
- **Priorité** : basse. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

### C15 — Une peau entière consommée pour une unité de cuir

- **Problème** : une peau tannée apporte 3, 6 ou 10 unités, mais elle est retirée entière dès qu'on en prend une. L'ordre de prélèvement suit la liste envoyée par le client.
- **Preuves** : `shared/MyTailorIsRich/MTIR_Patterns.lua:40-54, 521-538`.
- **Risque** : gaspillage, par exemple une grande peau perdue sur un échec qui ne coûte que la moitié des unités.
- **Correction** : sur l'autorité, trier les matériaux du plus petit au plus grand et rendre le reliquat en `Base.LeatherStrips` (`AddItems` + `sendAddItemsToContainer`).
- **Priorité** : basse. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

### C16 — Portée d'une machine ou d'une table sans test de mur

- **Problème** : `MTIR.isWithinReach` compare des distances par axe (1,6 case) sans vérifier qu'un mur sépare le personnage de l'objet. La lecture d'étiquette sur un cadavre le fait, elle (`canReachTo`).
- **Preuves** : `shared/MyTailorIsRich/MTIR_SewingMachine.lua:145-152`, utilisée par la couture, le tracé, la copie et l'entretien ; à comparer à `shared/MyTailorIsRich/MTIR_LabelCheck.lua:35-37`.
- **Risque** : travail à travers un mur si un client forge l'action, ou si la marche s'arrête de l'autre côté d'une cloison.
- **Correction** : ajouter `current == square or current:canReachTo(square)` au test, sur l'autorité comme sur le client.
- **Priorité** : basse (serveur entre amis, anti-triche secondaire). **Effort** : S.
- **Statut** : à vérifier en jeu.
- **Avancement : ⬜ à faire.**

### C17 — Duplications, incohérences entre actions, trous de tests

- **Constats** :
  - `findLocalPlayer` est dupliqué (`client/MyTailorIsRich/MTIR_ClientFx.lua:56-66`, `client/MyTailorIsRich/MTIR_DecorMenu.lua:280-288`) ;
  - le motif `isValid` (`isClient() and self.started`), `validate`, `start/stop/perform` avec `setJobDelta` se répète dans une douzaine d'actions ;
  - la remise en état ne demande pas les outils en main ni d'animation d'outils (`shared/TimedActions/MTIR_ReconditionAction.lua:68-71, 83-89`), contrairement à la retouche (`shared/TimedActions/MTIR_ResizeAction.lua:313-316`) ;
  - `ISCharacterScreen` mesure le poids en `UIFont.Small` quelle que soit la police passée (`client/MyTailorIsRich/MTIR_ClientUI.lua:83`) ;
  - aucun test lupa pour `MTIR_Sizing` (déduction par parties couvertes), la jauge d'ampoules et la perte de chaussure (`MTIR_ShoeEffects`), la taille d'artisanat (`MTIR_VanillaHooks`), les formules de retouche et de remise en état, ni l'usure (`calcDegradeChance`).
- **Correction** : un module `MTIR_ActionBase.lua` (validation commune, barre de progression, sons) et un `MTIR.findLocalPlayer` partagé ; tests ciblés sur les modules listés, en commençant par `Sizing` et `ShoeEffects`, qui touchent les mods tiers.
- **Priorité** : basse. **Effort** : M.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

### C18 — Descriptions Steam presque à la limite

- **Constat** : les neuf `README.steam*` pèsent de 7 724 à 7 898 octets pour une limite de 8 000 (`tests/run_tests.py`, `STEAM_DESCRIPTION_MAX_BYTES`).
- **Risque** : chaque nouvelle fonctionnalité impose de réécrire et de raccourcir neuf langues.
- **Correction** : garder sur Steam un résumé et un tableau des effets, et renvoyer le détail vers une page de documentation (le dossier `docs/` est en cours de réorganisation).
- **Priorité** : basse. **Effort** : S.
- **Statut** : confirmé statiquement.
- **Avancement : ⬜ à faire.**

---

## Partie 2 — Idées de fonctionnalités

| ID | Idée | Intérêt joueur | Effort | Impact MP |
|---|---|---|---|---|
| I01 | Mètre ruban vanilla | Lire une taille sans compétence, mesurer un autre joueur | S | Faible |
| I02 | Couture sur mesure pour un autre joueur | Rôle de tailleur en MP | M | Moyen |
| I03 | Patron qui garde l'apparence du modèle | Reproduire « sa » veste | M | Moyen |
| I04 | Garnir une chaussure trop grande | Sauver une paire à +2 | S | Faible |
| I05 | Chaussettes épaisses | Choix d'équipement utile | S | Faible |
| I06 | Alerte de changement de taille | Éviter la surprise du vêtement retiré | S | Faible |
| I07 | Panneau « Garde-robe » | Vue d'ensemble de la tenue | M | Nul (client) |
| I08 | Pastille d'ajustement dans l'inventaire | Tri rapide du butin | M | Nul (client) |
| I09 | Blanchir à la javel | Teindre en couleur claire | S | Faible |
| I10 | Teintures naturelles | Couleurs sans magasin | L | Moyen |
| I11 | Rétrécir au lavage | Rétrécir sans compétence | M | Moyen |
| I12 | Retouche temporaire aux trombones | Dépannage sans compétence | S | Faible |
| I13 | Série de travaux sur machine (rapiéçage, remise en état) | Moins de clics | M | Moyen |
| I14 | Effilochage des vêtements très usés | Usure visible | S | Faible |
| I15 | Écussons et insignes brodés | Identité de groupe | S | Faible |
| I16 | Pièces d'usure des machines | Entretien plus concret | M | Faible |
| I17 | Surjeteuse ou machine industrielle | Objectif de fin de partie | L | Faible |
| I18 | Magazines de patronage | Progression par la lecture | M | Moyen |
| I19 | API publique pour les autres mods | Compatibilité | S | Faible |
| I20 | Mannequins de vitrine taillés | Butin de magasin cohérent | M | Faible |

### I01 — Mètre ruban (`Base.MeasuringTape`)

- **Description** : avec un mètre ruban dans l'inventaire, « Mesurer » révèle la taille d'un vêtement sans niveau de Couture, plus vite que la lecture d'étiquette. « Prendre les mesures » d'un joueur proche donne sa taille et sa pointure.
- **Intérêt** : l'objet vanilla trouve un usage ; un débutant n'est plus bloqué par les étiquettes illisibles.
- **Faisabilité** : l'objet existe en 42.21 (`media/scripts/generated/items/normal.txt:3738`). Réutiliser `MTIR_CheckSizeAction` avec un drapeau « mesuré » et `getFirstTypeRecurse("MeasuringTape")`. Pour un joueur, la taille découle de `getNutrition():getWeight()` et la pointure de `MTIR.getPlayerShoeSize`.
- **MP** : le serveur fait la mesure (distance, cible vivante) et rend le résultat par `MTIR.tell` ; rien de nouveau n'est stocké.
- **Dépendances** : aucune ; base de I02.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I02 — Couture sur mesure pour un autre joueur

- **Description** : dans l'onglet Patron de la machine, un choix « Pour : moi / joueur mesuré » règle la taille ou la pointure cousue sur ce joueur.
- **Intérêt** : un vrai rôle de tailleur dans un groupe.
- **Faisabilité** : le serveur garde la dernière mesure de chaque couple (tailleur, cible) avec son heure ; `MTIR_SewPatternAction` accepte un `targetUsername` et l'autorité vérifie qu'une mesure récente existe. Les joueurs se retrouvent par `getOnlinePlayers()` (base moteur, `getPlayerFromUsername` est réservé au client).
- **MP** : contrôle d'autorité nécessaire ; en solo, le choix ne sert qu'en écran partagé.
- **Dépendances** : I01.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I03 — Patron qui garde l'apparence du modèle

- **Description** : au tracé, le patron note la variante de texture et la couleur du modèle. À la couture, le joueur choisit « comme le modèle » ou « au hasard ».
- **Intérêt** : reproduire une veste précise plutôt qu'une variante tirée au hasard.
- **Faisabilité** : `ItemVisual:getTextureChoice/setTextureChoice`, `getBaseTexture/setBaseTexture` (`zombie/core/skinnedmodel/visual/ItemVisual.java:665-677`) et la couleur appliquée comme `MTIR.applyDyeColor` (`shared/MyTailorIsRich/MTIR_Dyeing.lua:135-146`). La base moteur (`clothing-and-character-state.md`, « Patron de couture vanilla ») rappelle que `instanceItem(fullType)` ne reproduit que le type.
- **MP** : `syncItemFields` transmet la couleur personnalisée ; les autres joueurs voient la teinte quand le vêtement est enfilé (`SyncClothing`, base moteur `clothing-tint.md`). Textures choisies : transmission à vérifier.
- **Dépendances** : aucune ; données de patron à étendre sans casser les patrons existants (champs facultatifs).
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I04 — Garnir une chaussure trop grande

- **Description** : « Garnir » une paire avec des draps déchirés ou du tissu : la pointure effective baisse d'un cran tant que la garniture tient. Elle s'use à la marche.
- **Intérêt** : les bottes à +2 deviennent portables, comme dans la vraie vie avec du papier journal.
- **Faisabilité** : ModData `MTIR_Shoe.padding` et décalage dans `MTIR.getShoeEffectDiff` (`shared/MyTailorIsRich/MTIR_Shoes.lua:212-223`) ; usure par `applyShoeTick`.
- **MP** : action chronométrée partagée, `syncItemFields`.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I05 — Chaussettes épaisses

- **Description** : des chaussettes portées réduisent la vitesse de remplissage de la jauge d'ampoules ; des chaussettes épaisses (`Base.Socks_Heavy`) compensent en plus une pointure de trop. Mouillées, elles l'accélèrent.
- **Intérêt** : un choix d'équipement simple et lisible.
- **Faisabilité** : emplacement `socks` (déjà connu de `MTIR_Sizing.lua:30`) ; facteur dans `updateFriction` (`shared/MyTailorIsRich/MTIR_ShoeEffects.lua:223-250`) et dans `getShoeEffectDiff`. `getWetness()` est déjà employé pour l'usure.
- **MP** : calcul d'autorité existant ; rien à transmettre en plus.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I06 — Alerte de changement de taille

- **Description** : quand le poids approche d'un seuil de taille (environ 1 kg) ou le franchit, le personnage le dit, et l'infobulle des vêtements portés signale « commence à serrer ».
- **Intérêt** : aujourd'hui le vêtement trop serré est retiré sans prévenir (`MTIR.removeTooTight`).
- **Faisabilité** : comparaison du poids à chaque passage de minute (`server/MyTailorIsRich/MTIR_Server.lua:48-55`), seuils de `MTIR.SIZES`, réplique par `MTIR.tell`.
- **MP** : dernier seuil retenu côté serveur par joueur (clé = compte, voir C07).
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I07 — Panneau « Garde-robe »

- **Description** : une fenêtre liste les vêtements portés et transportés : taille connue, ajustement, état, jours d'usure estimés, retouche possible. Tri par colonne.
- **Intérêt** : vue d'ensemble pour décider quoi retoucher ou jeter.
- **Faisabilité** : `ISScrollingListBox` avec colonnes (base moteur, `ui-windows.md` : en-têtes sans tri, à faire soi-même) ; données en lecture seule déjà calculées (`MTIR_Tooltip.lua`).
- **MP** : client seulement.
- **Dépendances** : C03 pour une estimation d'usure à jour.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.** Prérequis C03 fait (0.4.6).

### I08 — Pastille d'ajustement dans l'inventaire

- **Description** : un petit point vert, orange ou rouge sur l'icône des vêtements dont l'ajustement est connu (option client).
- **Intérêt** : trier un tas de butin sur un cadavre en un coup d'œil.
- **Faisabilité** : `ISInventoryPane.renderdetails` est déjà enveloppé (`client/MyTailorIsRich/MTIR_ClientUI.lua:184-186`) ; dessiner après l'original avec `drawTexture`. Cache de l'ajustement par identifiant d'objet, invalidé à chaque `OnClothingUpdated`.
- **MP** : client seulement.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I09 — Blanchir à la javel

- **Description** : un bain de javel (`Base.Bleach`) ramène un vêtement teintable au blanc, au prix d'un point d'état. Utile avant une teinture claire, puisque la teinte multiplie la texture.
- **Intérêt** : rattraper une teinture ratée.
- **Faisabilité** : même chemin que `MTIR_DyeAction` (`shared/TimedActions/MTIR_DyeAction.lua`) ; couleur blanche par `MTIR.applyDyeColor(item, 1, 1, 1)` ; contrôle du fluide comme `MTIR.getDyeKind`.
- **MP** : `syncItemFields` + `sendItemStats` comme la teinture.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I10 — Teintures naturelles

- **Description** : préparer une teinture à partir de plantes vanilla (baies, oignons…), avec une couleur liée à l'ingrédient.
- **Intérêt** : couleurs en fin de partie sans magasins.
- **Faisabilité** : `craftRecipe` avec sortie dans un récipient à fluide ; la couleur d'un fluide `Dye` vient du mélange (`getFluidContainer():getColor()`). Créer un fluide de mod ou fixer la couleur à la création reste **à vérifier** en 42.21.
- **MP** : recette vanilla, autorité du moteur.
- **Effort** : L (fluides, recettes, traductions).
- **Avancement : ⬜ proposée, pas commencée.**

### I11 — Rétrécir au lavage

- **Description** : un vêtement en coton jamais retouché a une petite chance de rétrécir d'un cran au lavage.
- **Intérêt** : un moyen de rétrécir sans compétence, et un risque crédible.
- **Faisabilité** : le lavage à la main est une action Lua (`media/lua/shared/TimedActions/ISWashClothing.lua`), facile à envelopper. Le lave-linge est en Java (`zombie/iso/objects/ClothingWasherLogic.java`, sans événement Lua) : le couvrir demande un sondage du conteneur. **Hypothèse** à vérifier.
- **MP** : décision sur l'autorité dans `complete`.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I12 — Retouche temporaire aux trombones

- **Description** : sans compétence, resserrer un vêtement trop grand d'un cran avec des trombones. Cela tient quelques jours de jeu, puis lâche (retour à la taille d'origine, petite chance de chute du bas).
- **Intérêt** : dépannage en début de partie.
- **Faisabilité** : ModData `MTIR.tempResize` avec échéance en heures de monde ; lecture dans `MTIR.getItemDiff` ; échéance vérifiée au passage de minute.
- **MP** : autorité et `syncItemFields`.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I13 — Série de travaux sur machine

- **Description** : la série existe pour les patrons (jusqu'à 20 pièces). L'étendre à la remise en état de plusieurs vêtements et au rapiéçage de tous les trous d'un vêtement, avec le bonus de la machine.
- **Intérêt** : moins de clics pour l'entretien d'une garde-robe de groupe.
- **Faisabilité** : réutiliser la logique de série de `client/MyTailorIsRich/MTIR_MachineTabPattern.lua` ; rapiéçage par l'action vanilla `ISRepairClothing` par trou, déjà enveloppée (`shared/MyTailorIsRich/MTIR_VanillaHooks.lua:214-229`).
- **MP** : actions chronométrées existantes.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I14 — Effilochage des vêtements très usés

- **Description** : sous 25 % d'état, une partie des pertes d'usure fait un trou au lieu d'un point d'état.
- **Intérêt** : l'usure devient visible sur le modèle et pousse au rapiéçage.
- **Faisabilité** : `MTIR.ripClothes` existe (`shared/MyTailorIsRich/MTIR_Effects.lua:390-414`) ; appel depuis `degradeWornClothes` ; `syncVisuals` comme pour les déchirures.
- **MP** : déjà traité par `ripClothes` (`syncItemFields`, `syncVisuals`).
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I15 — Écussons et insignes brodés

- **Description** : broder un court insigne ou le nom de sa faction vanilla. Le texte apparaît dans l'infobulle et le nom de l'objet.
- **Intérêt** : identité de groupe en MP.
- **Faisabilité** : réutiliser `MTIR_Embroidery`. Une faction n'a pas d'identifiant stable (base moteur, `multiplayer.md`) : n'enregistrer que le texte. Un dessin sur le modèle 3D n'est pas faisable sans modèles ni textures dédiés.
- **MP** : comme la broderie actuelle.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I16 — Pièces d'usure des machines

- **Description** : à 0 %, la machine électrique demande une aiguille de machine, la machine à pédale une courroie, en plus de l'huile. Les pièces se trouvent en mercerie.
- **Intérêt** : l'entretien devient une petite quête de matériel.
- **Faisabilité** : nouveaux objets de script, butin dans `server/Items/MTIR_Distributions.lua`, test dans `MTIR.getMaintenanceRequirements`.
- **MP** : autorité existante.
- **Dépendances** : traductions en neuf langues ; le mod de désinstallation n'a pas besoin de ces objets (ce ne sont pas des entités).
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I17 — Surjeteuse ou machine industrielle

- **Description** : une troisième machine, trouvée dans les ateliers textiles : trois fois plus rapide, très bruyante, courant obligatoire.
- **Intérêt** : un objectif de base avancée.
- **Faisabilité** : nouvelle tuile, entité `SpriteConfig` et `tiledef` (skill `pz-blender-assets`), entrée dans `MTIR.MACHINE_KINDS`.
- **MP** : toute nouvelle entité doit aussi entrer dans `batman_MyTailorIsRich_Uninstall`, sinon le monde devient injoignable après désinstallation (`README.md`, « Removing the mod from a save ») ; la CI le contrôle déjà.
- **Effort** : L.
- **Avancement : ⬜ proposée, pas commencée.**

### I18 — Magazines de patronage

- **Description** : des magazines à lire qui apprennent une technique : copie sans perte de précision, +1 de précision au tracé, couture de chaussures un niveau plus tôt.
- **Intérêt** : progression par le butin, dans l'esprit des magazines de recettes vanilla.
- **Faisabilité** : objet `literature` ; marque apprise dans la ModData du joueur, écrite par le serveur (sauvegardée côté serveur et renvoyée aux clients proches, base moteur). Une écriture côté client ne serait pas synchronisée.
- **MP** : écriture d'autorité à la fin de la lecture (`ISReadABook:complete`).
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

### I19 — API publique pour les autres mods

- **Description** : `MTIR.API` documentée : lire une taille, forcer ou exclure un type, déclarer la part de pointures masculines d'une chaussure de mod, et événements `MTIR_OnSizeRevealed`, `MTIR_OnResized`.
- **Intérêt** : les mods de vêtements peuvent s'intégrer sans passer par les options sandbox.
- **Faisabilité** : fonctions déjà présentes (`MTIR.getSizing`, `MTIR.SHOE_MALE_SHARE`). D'après la base moteur, `triggerEvent` déclare un événement inconnu, et un événement reste local à chaque machine : le documenter.
- **MP** : aucun changement de protocole.
- **Effort** : S.
- **Avancement : ⬜ proposée, pas commencée.**

### I20 — Mannequins de vitrine taillés

- **Description** : les vêtements posés sur un mannequin vanilla prennent la taille du mannequin (M pour un mannequin d'homme, S pour une femme, par exemple), et leur étiquette se lit plus vite.
- **Intérêt** : butin de magasin cohérent et lisible.
- **Faisabilité** : `IsoMannequin` expose `isFemale()` et `getWornItems()` (`zombie/iso/objects/IsoMannequin.java:142, 936`). Le conteneur et sa détection dans `MTIR.ensureData` restent **à vérifier**.
- **MP** : tailles créées sur l'autorité, comme pour les cadavres.
- **Effort** : M.
- **Avancement : ⬜ proposée, pas commencée.**

---

## Partie 3 — Priorisation : les cinq actions les plus rentables

| Rang | Action | Pourquoi |
|---|---|---|
| 1 | ✅ **C01** — ne plus consommer les feuilles écrites ni les favoris | Seul risque de perte de données joueur trouvé ; correction courte et locale. |
| 2 | ✅ **C04** — effets continus des chaussures pour tous les emplacements | Tient la promesse « mods compris » du README ; une fonction à changer et un test. |
| 3 | ✅ **C02** — collecte du fil unifiée | Supprime une incohérence visible entre broderie et couture ; reconnaît les fils vanilla et de mods. |
| 4 | ✅ **C03** — infobulle d'usure à jour en MP | Bug MP silencieux, correction de quelques lignes côté client. |
| 5 | ⬜ **I01** — mètre ruban | Plus grand gain joueur pour un effort S : objet vanilla déjà dans le butin, action existante à réutiliser, base de I02. |

**Avancement (2026-10-23)** : rangs 1 à 4 faits et publiés en 0.4.6 (commit `00cd2e7`) ; rang 5 (I01) pas commencé.

Les deux choix de conception ont été tranchés le 2026-10-27, tous deux **annulés** : ❌ **C05** (coût de la copie) — équilibrage voulu, pas un bug ; ❌ **C06** (infobulle « Enfiler ») — confort voulu, aucune gêne constatée en jeu. Le prochain point utile est donc le rang 5, ⬜ **I01** (mètre ruban).

---

## Note finale

Ce document est une **proposition**. Il ne modifie aucun fichier du mod. Aucune correction ni fonctionnalité ne doit être implémentée sans validation explicite de l'auteur, et chaque changement retenu devra être vérifié en jeu (solo puis MP) avant publication.

**Mise à jour du 2026-10-23** : C01 à C04 ont été retenus, corrigés (commit `00cd2e7`) et publiés en 0.4.6 ; C01 est couvert par le parcours `pz-autotest` solo et MP, C02 à C04 restent à vérifier en jeu. Les autres points et toutes les idées sont encore des propositions.
