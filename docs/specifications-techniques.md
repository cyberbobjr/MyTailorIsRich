# Spécifications techniques — My Tailor Is Rich

Contrats du mod 0.4.7 pour Project Zomboid **Build 42.21** (`versionMin=42.21`, une seule variante `42.21/`). Vérifiés dans le code du dépôt (`Contents/mods/**`) ; aucun test 42.22+ n'est implicite. Organisation générale : [architecture.md](architecture.md).

Toute la logique est dans la table globale `MTIR`. Le module réseau et la clé ModData de base valent `"MTIR"` (`MTIR.NET_MODULE`, `MTIR.DATA_KEY`). L'autorité est `not isClient()` (solo ou serveur).

## Objets et scripts

### Objets (`module Base`)

| Type complet | Fichier | Rôle | Points notables |
|---|---|---|---|
| `Base.MTIR_TailorPattern` | `MTIR_items.txt` | Patron tracé ou copié | `DisplayCategory = RecipeResource`, 0,2 kg, ModData `MTIR_Pattern`, nom personnalisé posé par l'autorité |
| `Base.MTIR_PrintedPattern` | `MTIR_items.txt` | Patron du commerce | `OnCreate = MTIR.onCreatePrintedPattern` (tirage du modèle) |
| `Base.MTIR_PatternBinder` | `MTIR_patternbinder.txt` | Classeur à patrons | 0,3 kg de base, poids réel par `setCustomWeight` (0,3 + 0,1 × patrons) |
| `Base.Mov_MTIR_SewingMachine` | `MTIR_items.txt` | Machine électrique ramassée | `ItemType = base:moveable`, `WorldObjectSprite = mtir_sewing_01_0` |
| `Base.Mov_MTIR_TreadleMachine` | `MTIR_items.txt` | Machine à pédale ramassée | `WorldObjectSprite = mtir_treadle_01_0` |

### Recette

`MTIR_MakePatternBinder` (`craftRecipe`, `category = Tailoring`, `timedAction = SewingCloth`, `time = 150`, `Tags = AnySurfaceCraft`, `xpAward = Tailoring:5`) : ciseaux `tags[base:scissors]` gardés (`SharpnessCheck;IsNotDull`), aiguille `tags[base:sewingneedle]` gardée, 1 `tags[base:thread]`, 2 parmi `Base.RippedSheets;Base.DenimStrips;Base.LeatherStrips`, 2 `Base.SheetPaper2` → 1 `Base.MTIR_PatternBinder`.

### Entités et tuiles (`MTIR_entities.txt`)

| Entité | Style UI | Tuiles | Remarques |
|---|---|---|---|
| `Base.MTIR_SewingMachine` | `ES_MTIR_SewingMachine` (`DisplayName = IGUI_MTIR_Machine_Title`) | `mtir_sewing_01_0..3`, faces S/E/N/W | Objet de table, courant requis |
| `Base.MTIR_TreadleMachine` | `ES_MTIR_TreadleMachine` (`IGUI_MTIR_Treadle_Title`) | `mtir_treadle_01_0..3` | Meuble au sol, sert aussi de table de travail |

Les entités restent dans `module Base` (`EntityScriptName` résolu sans module). Leurs composants `SpriteConfig` sont enregistrés dans `WorldDictionary.bin` de la sauvegarde : d'où le mod de désinstallation qui les redéclare à l'identique (contrôlé par `tests/run_tests.py`). Tuiles : `pack=`/`tiledef=` `mtir_sewing_01 7171`, `mtir_treadle_01 7172` (fichiers `.tiles`, `.pack`, `tileGeometry.txt` et cartes de profondeur dans `common/media`). Détection en Lua : préfixe du nom de sprite (`MTIR.MACHINE_KINDS[*].prefix`).

**Rotation des machines posées.** Les quatre sprites `_0` à `_3` sont les faces S, E, N, W. Un meuble
ne tourne que si chaque sprite déclare, en plus de `Facing`, les décalages `Noffset`, `Soffset`,
`Woffset` et `Eoffset` vers ses sœurs : `ISMoveableSpriteProps:hasFaces()` rend faux sans eux, et le
curseur de pose garde alors le sprite de l'objet d'inventaire quelle que soit la face choisie
(`media/lua/shared/Moveables/ISMoveableSpriteProps.lua:258-311`, 42.21). pz-sprite-forge n'écrit que
`Facing` : `source/fix_tile_facings.py` complète les `.tiles` après chaque génération, et
`tests/run_tests.py` vérifie les douze décalages de chaque tuile à quatre faces.

### Sons (`MTIR_sounds.txt`)

`MTIR_ResizeClothes`, `MTIR_ResizeFailed`, `MTIR_CheckSize`, `MTIR_TightClothesRip` (repris de Realistic Clothes, hors licence MIT), `MTIR_SewingMachineElectric`, `MTIR_SewingMachineTreadle` (boucles).

## Actions chronométrées

Toutes dans `media/lua/shared/TimedActions/`, dérivées d'`ISBaseTimedAction`, exécutées en MP par le système réseau vanilla (le serveur appelle `complete()` sans `isValid()` : chaque `complete()` revérifie). Listes d'objets : `ArrayList`. Machine : `machinePos` = `"x,y,z"` (`MTIR.encodeMachinePos`), `""` à la main. Table : `tablePos` (même format).

| Action | Constructeur `new(...)` |
|---|---|
| `MTIR_CheckSizeAction` | `character, item, corpseContainer` |
| `MTIR_ChooseSizeAction` | `character, item, size` |
| `MTIR_DebugSizeAction` | `character, item, mode ("clothes"/"shoe"/"clear"), size` |
| `MTIR_ResizeAction` | `character, item, needle, scissors, threads, materials, upsize, machinePos` |
| `MTIR_ReconditionAction` | `character, item, needle, scissors, threads, strips, machinePos` |
| `MTIR_ReconditionSpareAction` | `character, item, needle, scissors, threads, spareItem, machinePos` |
| `MTIR_TracePatternAction` | `character, item, scissors, pen, papers, tablePos` |
| `MTIR_SewPatternAction` | `character, pattern, needle, scissors, threads, materials, size, machinePos, awl, glue, entryId` (`pattern` = classeur si `entryId`) |
| `MTIR_CopyPatternAction` | `character, pattern, scissors, pen, papers, tablePos` |
| `MTIR_BinderStoreAction` | `character, binder, pattern` |
| `MTIR_BinderTakeAction` | `character, binder, entryId` |
| `MTIR_DyeAction` | `character, item, dye, water` |
| `MTIR_EmbroiderAction` | `character, item, needle, threads, text, newName` |
| `MTIR_UnpickEmbroideryAction` | `character, item, scissors` |
| `MTIR_MachineEmbroiderAction` | `character, item, needle, threads, text, newName, machinePos` |
| `MTIR_MachineMaintenanceAction` | `character, machinePos, screwdriver, oil` |

### Actions vanilla enveloppées (`MTIR_VanillaHooks.lua`)

| Fonction | Changement |
|---|---|
| `ISWearClothing:isValid` / `:complete` | Refus : chaussure à −3 ou moins, vêtement à −3 ou moins, taille à choisir ; refus refait au début de `complete()` côté serveur. |
| `ISWearClothing:getDuration` | Plus long pour un vêtement trop petit. |
| `ISUnequipAction:perform` / `:complete` | Stats d'origine rendues. |
| `ISRepairClothing.complete`, `ISRemovePatch.complete` | État du vêtement conservé s'il s'use avec le mod. |
| `ISFitnessAction:exeLooped` | Raideur supplémentaire en vêtement serré (autorité). |
| `ISHandcraftAction:performRecipe` | `Actions.addOrDropItem` remplacé le temps de la recette : taille choisie (vêtement) ou pointure de l'artisan (chaussure), révélée. |

Client (`MTIR_ClientUI.lua`) : `ISCharacterScreen:render` (taille après le poids), `ISWidgetOutput:createScriptValues` / `updateScriptValues` / `calculateLayout` (bouton de taille), nom en inventaire et indice de l'option « Enfiler ».

## Commandes réseau

Module `MTIR`. Le serveur ignore toute commande dont `args` n'est pas une table.

| Commande | Sens | Arguments | Contrôles et effet |
|---|---|---|---|
| `setCraftSize` | client → serveur | `fullType` (chaîne), `size` (`XS`…`XXL`) | Ignorée si la taille est inconnue. Mémorisée dans `MTIR.ServerCraftSize[clé joueur][fullType]` (non sauvegardé). |
| `climb` | client → serveur | `kind` (`wall`, `window`, `fence`, `fenceRun`, `fenceSprint`), `fell` (booléen) | `kind` chaîne ; une par 500 ms et par joueur. Tirage des déchirures, puis perte de chaussure (`fall` si `fell`). |
| `fall` | client → serveur | — | Une par 1 500 ms et par joueur (une chute déjà comptée à l'escalade n'est pas recomptée). Perte de chaussure. |
| `machineSound` | client → serveur | `x`, `y`, `z` (nombres), `on` (booléen), `sound` | Marche : une par 500 ms, son égal à celui de la machine trouvée en `x,y,z`, machine à portée du joueur. Arrêt : toujours relayé. Relais aux autres joueurs à 30 cases ou moins. |
| `machineSound` | serveur → client | `x`, `y`, `z`, `on`, `sound` (si `on`) | Joue ou arrête la boucle locale (expiration après 10 s sans nouvelle). |
| `fx` | serveur → client | `say = {key, arg}`, `sound`, `halo = {itemType, good}`, `refresh`, `resetModel`, `playerOnlineId` | Effets visibles du joueur visé (écran partagé : `playerOnlineId`). En solo, `MTIR.tell` appelle `MTIR.applyFx` directement. |
| `embroideryRemoved` | serveur → client | `playerOnlineId`, `itemId`, `prevName` | Le client du propriétaire efface la broderie et rétablit le nom dans sa langue. |

Clé joueur côté serveur : `"u" .. getUsername()` (`MTIR.playerKey`), `"p" .. getPlayerNum()` en solo.

### Synchronisation

`MTIR.syncItem` → `syncItemFields` (serveur seulement : ModData remplacée, état, nom, poids). Raideur : `syncBodyPart(part, MTIR.BD_STIFFNESS)` (`1099511627776`, `BodyPartSyncPacket.BD_stiffness` en 42.21). Trous de déchirure : `syncVisuals`. Endurance : `syncPlayerStats`. Machine : `transmitModData` après `MTIR.setMachineCondition`.

## ModData

| Porteur | Clé | Format | Écrit par |
|---|---|---|---|
| Vêtement | `MTIR` | `{ size = "XS".."XXL", reveal = bool, hint = bool, resized = -1/0/1 }` | Autorité (`MTIR.createData`, `ensureData`, actions) |
| Chaussure | `MTIR_Shoe` | `{ size = 35..47, reveal = bool, hint = bool }` | Autorité |
| Patron | `MTIR_Pattern` | `{ fullType, kind ("clothes"/"shoe"/"glove"), fabric ("Cotton"/"Denim"/"Leather"), difficulty, precision, uses, copies? }` | `createPattern`, `onCreatePrintedPattern`, copie |
| Classeur | `MTIR_Binder` | `{ nextId = n, entries = { { id, type, name, modData }, … } }` (`id` immuable, `modData` = ModData complète du patron rangé) | Actions du classeur, couture |
| Vêtement brodé | `MTIR_Embroidery` | `{ text, prevName? }` | Broderie (`setName` + `setCustomName(true)`) |
| Machine posée (`IsoObject`) | `movableData.mtirCondition` | entier 0–100 (absent = 100) | `MTIR.setMachineCondition` |

`resized ≠ 0` interdit une nouvelle retouche. `reveal` = taille exacte connue ; `hint` = indice déjà donné. `movableData` est recopiée par le vanilla au ramassage et à la pose (`ISMoveableSpriteProps`). Aucune ModData de joueur ni ModData globale. Pointure du pied : hachage djb2 de `prénom nom` modulo la somme des poids de la répartition du sexe (stable sur toutes les machines, sans stockage).

### Valeurs clés

- Tailles : XS ≤ 50 kg, S ≤ 65, M ≤ 75, L < 85, XL < 100, XXL ≥ 100 ; poids de tirage 5/10/25/35/15/10 ; tirage près d'une référence : −1 (25), 0 (60), +1 (15), pondéré par la fréquence ; 10 % de vêtements déjà retouchés.
- Lecture : niveau `max(difficulté − 1, 0)` ; durée `difficulté × 50 × ActionTimeMultiplier` ; chaussure 30.
- Papier des patrons : feuille vierge, non favorite, non renommée, non verrouillée ; nom identique au script. Les ModData inconnues protègent les documents de mods. Seule exception : une entrée vanilla `customName` égale au nom normal avec `isCustomName() == false` n'empêche pas le tracé ou la copie (`setCustomName(false)` laisse cette entrée en Java). Même prédicat dans les menus et les contrôles d'autorité.
- Retouche : niveau `difficulté + tissu (+1 agrandir)` ; réussite `0,5 + 0,25 × (niveau − requis)` ; durée `difficulté × 150 + tissu × 75 (+300)` ; matériaux et fil `difficulté × 2` ; trombones (`Base.Paperclip`) pour rétrécir.
- Patron : fil `difficulté × 2 + 1` (chaussure 5) ; durée `300 + difficulté × 150` (chaussure 750) ; décalage `0,5 − 0,05 × (précision + niveau + bonus machine)`, borné 0–0,5 ; chaussure : difficulté 3, 1 utilisation de colle, alêne ; tracé : état ≥ 50 %.
- Gants : `kind = "glove"`, difficulté 1, taille réseau `"OneSize"` (affichage traduit), aucun décalage ni ModData de taille sur l'objet cousu. Tracé : 1 feuille ; couture : 2 unités de tissu, 3 utilisations de fil à la main. `FabricType` reconnu prioritaire ; repli explicite pour `Base.Gloves_FingerlessGloves` (coton) et `Base.Gloves_FingerlessLeatherGloves`, `_Black`, `_Brown` (cuir). Emplacements `hands`, `handsleft`, `handsright` ; cosmétiques et `ListExcludedClothes` exclus. La même matière est conservée dans les patrons tracés, imprimés, copiés et rangés. Couture à la main ou sur machine par les actions existantes, qui revérifient les matériaux sur l'autorité. Aucun changement des anciens patrons.
- Machines (`MTIR.MACHINE_KINDS`) : électrique durée × 0,5, +2 niveaux, +4 précision, fil × 0,7, bruit rayon/volume 12, usure 2–4 ; pédale × 0,75, +1, +2, × 0,85, bruit 5/6, usure 1–3 ; malus de réussite `(50 − état)/100` sous 50 % ; casse d'aiguille `0,04 + (100 − état)/1000` ; entretien `20 + 8 × niveau` (Électricité / Mécanique), 3 utilisations d'huile (`base:oil`), durée 300 ; portée 1,6 case.
- Broderie : 24 caractères (nom composé ≤ 64), Couture 1, 1 fil, durée 60 ; pédale : Couture 3 réelle.
- Teinture : `Dye` 0,2 L et `HairDye` 0,25 L par unité de volume, eau 2 L par unité.
- Classeur : capacité par défaut 20, 0,3 kg + 0,1 kg par patron.

## Options sandbox

Page `MyTailorIsRich`, clés `SandboxVars.MyTailorIsRich.<Nom>`, lues à chaque usage par `MTIR.opt` (repli sur les défauts de `MTIR_Core.lua`).

| Option | Type | Défaut | Bornes | Effet |
|---|---|---|---|---|
| `NeedTailoringLevel` | booléen | vrai | — | Niveau de Couture exigé pour lire et retoucher (sinon 0). |
| `TailoringXpMultiplier` | réel | 1,0 | 0–100 | XP de Couture des lectures, retouches, remises en état, patrons. |
| `ActionTimeMultiplier` | réel | 1,0 | 0–100 | Durée des actions du mod. |
| `RipChanceMultiplier` | réel | 1,0 | 0–100 | Déchirure d'un vêtement serré en escaladant. |
| `DropChanceMultiplier` | réel | 1,0 | 0–100 | Chute d'un bas trop grand sans ceinture, mains occupées. |
| `InsulationReduceMultiplier` | réel | 1,0 | 0–100 | Perte d'isolation d'un vêtement trop grand (jusqu'à 50 %). |
| `CombatSpeedReduceMultiplier` | réel | 1,0 | 0–100 | Ralentissement du combat par un haut trop grand. |
| `IncreaseTripChanceMultiplier` | réel | 1,0 | 0–100 | Trébuchement à la réception d'une clôture. |
| `IncreaseStiffnessMultiplier` | réel | 1,0 | 0–100 | Raideur due aux vêtements serrés. |
| `EnableClothesDegrading` | booléen | vrai | — | Usure des vêtements portés. |
| `MinDaysToDegrade` | entier | 30 | 1–720 | Jours d'usure complète dans le pire cas. |
| `MaxDaysToDegrade` | entier | 360 | 1–720 | Jours d'usure complète dans le meilleur cas (si min > max : 30/360). |
| `ChanceToDegradeOnFailure` | réel | 0,5 | 0–1 | Usure sur une retouche ou remise en état ratée. |
| `ProtectionLossEachCondition` | réel | 2,5 | 0–100 | % de protection (griffure, morsure, balle) perdu par point d'état. |
| `ResistanceLossEachCondition` | réel | 5,0 | 0–100 | % de résistance (vent, eau) perdu par point d'état. |
| `ListCustomClothes` | texte | `""` | — | `Type[:difficulté 1–3]`, séparés par des virgules : vêtements à tailler. |
| `EnableShoeSizes` | booléen | vrai | — | Pointures des chaussures. |
| `ShowPlayerSize` | booléen | vrai | — | Taille et pointure sur l'écran Personnage (masquées si Immersive Weighing est actif). |
| `ShoeEffectMultiplier` | réel | 1,0 | 0–10 | Ampoules, endurance, perte de chaussure ; 0 coupe aussi l'inconfort. |
| `ExtraSizedLocations` | texte | `""` | — | Emplacements à tailler même sans parties couvertes, `nom[:difficulté]`, séparés par `,` ou `;`. |
| `ListExcludedClothes` | texte | `""` | — | Types complets jamais taillés, séparés par des virgules. |
| `PatternMaxUses` | entier | 5 | 1–50 | Utilisations d'un patron. |
| `ShoePatternLevel` | entier | 8 | 0–10 | Niveau pour coudre des chaussures (tracé : un de moins). |
| `EnablePatternCopy` | booléen | vrai | — | Copie de patron. |
| `PatternCopyPrecisionLoss` | entier | 1 | 0–10 | Niveaux de précision perdus par copie. |
| `PatternBinderCapacity` | entier | 20 | 1–100 | Patrons par classeur. |
| `RequireThimble` | booléen | vrai | — | Dé à coudre pour coudre à la main. |
| `MachineBonusMultiplier` | réel | 1,0 | 0–2 | Échelle de tous les bonus de machine. |
| `MachineNoiseMultiplier` | réel | 1,0 | 0–3 | Portée du bruit des machines (0 = silencieuses). |
| `EnableMachineMaintenance` | booléen | vrai | — | Usure, casse d'aiguille, blocage et entretien des machines. |
| `SewingLootMultiplier` | réel | 1,0 | 0–10 | Fréquence des machines, patrons du commerce et classeurs dans le butin (0 = jamais). |
| `EnableDyeing` | booléen | vrai | — | Teinture. |
| `EnableEmbroidery` | booléen | vrai | — | Broderie (et onglet de la machine). |

## Butin

`server/Items/MTIR_Distributions.lua`, poids × `SewingLootMultiplier` (rien si 0) :

- Listes procédurales : `TailoringTools` (électrique 6, pédale 1,5), `SewingStoreTools` (8, 2, patron 10, classeur 3), `CrateTailoring` (3, 1), `GigamartBedding` (électrique 1), `Antiques` (pédale 0,3), `TailoringLiterature` (patron 20, classeur 4), `BookstoreFashion` (patron 4).
- Toute liste qui contient `SewingKit` : machine électrique à 5 % du poids du kit.
- Table `MTIR_SewingMachines` (électrique 50, pédale 15) insérée dans les `procList` de `garagestorage`, `storageunit`, `attic`, `shed`, `storage`, `closet`, `clothingstore`, `clothingstorage`, `departmentstore`, `tailoringstore.other`.
- Garages attenants (pièce `garage` d'un bâtiment habité) : tirage à `OnFillContainer`, une machine au plus par garage.
- Ordre : ajouts à `OnPostDistributionMerge` ; en solo, les options de la partie ne sont connues qu'après : `OnInitGlobalModData` corrige les poids puis relance `ItemPickerJava.Parse()`. Les entrées du mod sont retirées avant réécriture (idempotent).

## Traductions

Fichiers JSON `media/lua/shared/Translate/<LANGUE>/` : `IG_UI.json` (préfixe `IGUI_MTIR_` : `Machine`, `Say`, `JobType`, `Pattern`, `Color`, `Debug`, `Binder`, `Hint`, `Embroider`, `Preview`, `Dye`, `CheckSize`, `Maintenance`…), `ItemName.json` (types complets), `Moveables.json` (`Electric_Sewing_Machine`, `Treadle_Sewing_Machine`), `Recipes.json` (`MTIR_MakePatternBinder`), `Sandbox.json` (`Sandbox_MyTailorIsRich_<Option>` et `_tooltip`). Langues : EN, FR, DE, ES, PT, PTBR, RU, CN, TR (le mod de désinstallation : `IG_UI`, `ItemName`, `Moveables`). Mêmes clés et mêmes paramètres `%1` que l'anglais (contrôlé par `tests/run_tests.py`).

Textes vus par le joueur : clés résolues sur le client (répliques `fx.say`). Exception : le nom d'un patron est composé par l'autorité et enregistré dans l'objet, donc dans la langue du serveur ; `MTIR_ServerTranslations.lua` recharge les traductions des mods sur un serveur MP (sinon `getText` y rend la clé). Messages de console en anglais, préfixe `[MTIR]`.

## API Lua utilisable par d'autres mods

Aucune API publique stabilisée. Fonctions lisibles sans risque : `MTIR.getData(item)`, `MTIR.getShoeData(item)`, `MTIR.getPatternData(item)`, `MTIR.getPlayerSize(player)`, `MTIR.getPlayerShoeSize(player)`, `MTIR.canClothesHaveSize(item)`, `MTIR.canShoeHaveSize(item)`. Toute écriture doit passer par l'autorité.

## Compatibilités vérifiées dans le code

| Mod | Relation | Mécanisme |
|---|---|---|
| TooltipLib (`\TooltipLib`, Workshop 3694097672) | Prérequis (`require=`) | `TooltipLib.registerProvider` ; sans lui, aucune ligne d'infobulle (message console). |
| Realistic Clothes (`\RealisticClothes`, 3491510356) | Incompatible | `incompatible=` ; même fonction, ce mod en est la réécriture. |
| Immersive Weighing (3791897755) | Compatible | ID `ImmersiveWeighing` détecté dans `getActivatedMods()` : taille masquée sur l'écran Personnage. |
| Mods de vêtements | Compatibles | Taille déduite par emplacement et `BloodLocation` ; options d'ajout et d'exclusion. |
| Mods de butin ajoutant des kits de couture | Compatibles | Traités à `OnPostDistributionMerge`. |

## Contraintes de version

- Build 42.21 : `ItemBodyLocation` comparé par clé texte (`MTIR.locKey`), `getItemType() == ItemType.CLOTHING`, `hasTrait(CharacterTrait.X)` (Lucky/Unlucky absents), `instanceItem`, `OnPlayerUpdate` absent côté serveur (d'où `OnTick`), `RunSpeedModifier` des vêtements jamais appliqué.
- Les données sont dans la ModData des objets : changer un nom de clé ou un format demande une migration.
