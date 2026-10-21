# Architecture — My Tailor Is Rich

Build 42.21, version du mod 0.4.5. Les contrats détaillés (arguments, clés, options) sont dans [specifications-techniques.md](specifications-techniques.md) ; ce document décrit l'organisation du code.

## Vue d'ensemble

```
            CLIENT (joueur local)                         AUTORITÉ (solo, ou serveur MP)
 ┌──────────────────────────────────────┐        ┌──────────────────────────────────────────┐
 │ Menus contextuels, panneau machine,  │ action │ complete() des actions chronométrées       │
 │ aperçu 3D, infobulles (TooltipLib)   │──────► │ (tailles, retouches, patrons, classeur,    │
 │ Lecture seule des données            │ B42 net│  teinture, broderie, entretien)            │
 │                                      │        │                                            │
 │ Détection escalade / chute ──────────┼──────► │ OnClientCommand : climb, fall,             │
 │ Choix de taille d'artisanat ─────────┼──────► │  setCraftSize, machineSound (relais)       │
 │                                      │        │                                            │
 │ OnServerCommand : fx, machineSound,  │◄────── │ EveryOneMinute / EveryHours / OnTick :     │
 │  embroideryRemoved                   │        │  effets portés, usure, raideur, chaussures │
 │ Stats dérivées recalculées (affich.) │◄────── │ syncItemFields / syncBodyPart / transmitModData
 └──────────────────────────────────────┘        └──────────────────────────────────────────┘
```

Principe : **toute écriture d'état est faite par l'autorité** (`MTIR.isAuthority()` = `not isClient()`). Le client affiche, propose et met en file des actions chronométrées partagées (`media/lua/shared/TimedActions`), que le système réseau vanilla de Build 42 exécute sur le serveur (`complete()`), lequel revérifie tout.

## Arborescence

```
Contents/mods/
├── batman_MyTailorIsRich/               mod principal
│   ├── common/                          exigé en B42
│   │   ├── README.txt
│   │   └── media/ mtir_sewing_01.tiles, mtir_treadle_01.tiles, tileGeometry.txt,
│   │              texturepacks/*.pack, depthmaps/DEPTH_*.png
│   └── 42.21/                           seule variante (versionMin=42.21)
│       ├── mod.info  poster.png  icon.png
│       └── media/
│           ├── sandbox-options.txt
│           ├── scripts/  MTIR_items.txt, MTIR_patternbinder.txt, MTIR_entities.txt, MTIR_sounds.txt
│           ├── sound/    6 sons (.wav, .ogg)
│           └── lua/ shared/ client/ server/  (détail ci-dessous)
└── batman_MyTailorIsRich_Uninstall/     mod de désinstallation, sans code
    ├── common/                          copie octet pour octet des tuiles du mod principal
    └── 42.21/ mod.info, scripts (entités et objets posables des machines), traductions des noms
```

### `mod.info`

| Clé | Mod principal | Mod de désinstallation |
|---|---|---|
| `id` | `batman_MyTailorIsRich` | `batman_MyTailorIsRich_Uninstall` |
| `require` | `\TooltipLib` | — |
| `incompatible` | `\RealisticClothes` | `\batman_MyTailorIsRich` |
| `versionMin` | `42.21` | `42.21` |
| `modversion` | `0.4.5` | `0.4.5` |
| `pack` / `tiledef` | `mtir_sewing_01` 7171, `mtir_treadle_01` 7172 | identiques |

Aucun `loadModAfter` / `loadModBefore`. Objet Workshop : 3810122988 (les deux mods sont livrés ensemble).

## Modules Lua

Tous les modules remplissent la table globale `MTIR` (définie dans `MTIR_Core.lua`). Les fichiers `client` et `server` qui s'enveloppent d'une garde (`MTIR.clientUIInstalled`, `MTIR.vanillaHooksInstalled`…) ne s'installent qu'une fois.

### `shared/MyTailorIsRich/`

| Module | Responsabilité | `require` |
|---|---|---|
| `MTIR_Core` | Options (`MTIR.opt`, valeurs par défaut), tailles XS–XXL et taille du joueur par le poids, profils d'emplacement (`CLOTHES_SLOTS`, `DEGRADE_LOCATIONS`), ModData `MTIR` (création réservée à l'autorité), formules de difficulté, durée, XP, effets, remise en état ; sélection des matériaux. | — |
| `MTIR_Sizing` | Quels vêtements ont une taille (vanilla et mods) : ordre de décision, accessoires exclus, déduction par `BloodLocation`, options `ListCustomClothes`, `ExtraSizedLocations`, `ListExcludedClothes`. | Core |
| `MTIR_Shoes` | Pointures EU 35–47 : pied du personnage (hachage du nom, sans stockage), ModData `MTIR_Shoe`, répartition hommes/femmes, effets statiques (puissance d'écrasement). | Core, Sizing |
| `MTIR_Effects` | Notifications (`MTIR.tell`), synchronisation (`MTIR.syncItem`), stats dérivées (isolation, vitesse de combat, défenses), effets d'autorité (chute du bas, retrait, déchirure, usure, raideur), taille d'artisanat choisie, droits de débogage. | Core, Shoes |
| `MTIR_ShoeEffects` | Effets continus des chaussures : jauge de frottement et ampoules, inconfort, endurance, perte de chaussure. | Effects |
| `MTIR_VanillaHooks` | Enveloppes d'actions vanilla : `ISWearClothing` (refus, durée, effets), `ISUnequipAction`, `ISRepairClothing`/`ISRemovePatch` (état conservé), `ISFitnessAction` (raideur), `ISHandcraftAction.performRecipe` (taille des vêtements fabriqués) ; `OnClothingUpdated`. | Effects |
| `MTIR_Reach`, `MTIR_LabelCheck` | Lecture d'étiquette sur place (cadavre, meuble, véhicule) et filtres des lectures groupées. | Core / Effects |
| `MTIR_Alterations` | Besoins et formules des retouches et remises en état, à la main ou sur machine ; logique commune « travail sur machine » (`MachineWork`) ; besoins de l'entretien. | SewingMachine, MachineSound |
| `MTIR_Patterns` | Patrons : ModData `MTIR_Pattern`, modèle traçable, tissus et matériaux, besoins, risque de taille décalée, nom du patron. | Sizing, Effects |
| `MTIR_PrintedPatterns` | Patron du commerce : `OnCreate` qui tire un vêtement traçable parmi tous les scripts chargés. | Patterns, Shoes |
| `MTIR_PatternBinder` | Classeur : ModData `MTIR_Binder`, entrées à identifiant stable, poids. | Patterns |
| `MTIR_PatternCopy` | Copie d'un patron (précision réduite, utilisations neuves). | Patterns, PatternBinder |
| `MTIR_SewingMachine` | Machines : détection par préfixe de sprite, bonus, courant, état et usure (`movableData.mtirCondition`), bruit, dé à coudre. | Patterns |
| `MTIR_MachineSound` | Boucle sonore de la machine, relais aux joueurs proches. | SewingMachine |
| `MTIR_WorkTable` | Recherche d'une table de travail (propriété `IsTable`, ou machine à pédale). | SewingMachine |
| `MTIR_Dyeing`, `MTIR_Embroidery` | Teinture (fluides `Dye`/`HairDye`, eau, teinte) et broderie (texte, nom, nom antérieur). | Core, Sizing (+ Shoes) |

### `shared/TimedActions/`

Une action par opération, toutes dérivées d'`ISBaseTimedAction` : `MTIR_CheckSizeAction`, `MTIR_ChooseSizeAction`, `MTIR_DebugSizeAction`, `MTIR_ResizeAction`, `MTIR_ReconditionAction` (+ `MTIR_ReconditionSpareAction`), `MTIR_TracePatternAction`, `MTIR_SewPatternAction`, `MTIR_CopyPatternAction`, `MTIR_BinderStoreAction`, `MTIR_BinderTakeAction`, `MTIR_DyeAction`, `MTIR_EmbroiderAction` (+ `MTIR_UnpickEmbroideryAction`), `MTIR_MachineEmbroiderAction`, `MTIR_MachineMaintenanceAction`. Les objets passent par les paramètres de l'action (une `ArrayList` pour les listes : une table Lua arrive vide sur le serveur) ; une machine passe par sa position `"x,y,z"`, une entrée de classeur par son `entryId`.

### `client/MyTailorIsRich/`

| Module | Responsabilité |
|---|---|
| `MTIR_ContextMenu`, `MTIR_CheckSizeMenu` | Menu d'inventaire : lire la taille (sélection, ce cadavre, cadavres proches), retouche, remise en état, choix de taille, sous-menu de débogage. |
| `MTIR_PatternMenu`, `MTIR_PatternBinderMenu` | Tracer, coudre, copier, ranger, sortir, aperçu ; infobulle du classeur. |
| `MTIR_DecorMenu` | Teindre, broder, découdre ; ligne d'infobulle de la broderie ; commande `embroideryRemoved`. |
| `MTIR_SewingMachineWindow` + `MTIR_MachineTabPattern`, `MTIR_MachineTabAlter`, `MTIR_MachineTabEmbroider`, `MTIR_MachineUIUtil` | Panneau d'entité de la machine (ouvert par `ISEntityUI` via `LuaWindowClass`), quatre onglets, état et entretien. |
| `MTIR_PatternPreview` | Fenêtre d'aperçu 3D (`ISUI3DModel`, copie locale du descripteur). |
| `MTIR_ClientUI` | Taille sur l'écran Personnage, taille dans le nom en inventaire, bouton de taille dans la fenêtre d'artisanat, indice dans l'option « Enfiler ». |
| `MTIR_Tooltip` | Ligne d'infobulle taille / usure (TooltipLib). |
| `MTIR_ClientEvents` | Escalade et chute (commandes `climb`, `fall`), trébuchement à la réception, recalcul d'affichage des stats chaque minute en MP. |
| `MTIR_ClientFx` | Effets reçus (`fx` : réplique, son, halo, rafraîchissement), envoi de la taille d'artisanat (`setCraftSize`). |

### `server/`

| Module | Responsabilité |
|---|---|
| `MyTailorIsRich/MTIR_Server` | Boucle d'autorité (minute, heure, tick), tailles de la tenue d'un zombie à `OnZombieDead`, commandes client. Sort immédiatement si `isClient()`. |
| `MyTailorIsRich/MTIR_ServerTranslations` | Sur un serveur MP : rechargement des traductions des mods et migration des noms de patrons en clé brute (avant 0.4.5). |
| `Items/MTIR_Distributions` | Butin : machines, patrons du commerce, classeurs (listes procédurales et table `MTIR_SewingMachines`). |

## Flux de données

### Événements

| Événement | Où | Rôle |
|---|---|---|
| `EveryOneMinute` | serveur | `applyAuthorityWornEffects` + `applyDerivedStats` pour chaque joueur vivant. |
| `EveryOneMinute` | client | Stats dérivées du joueur local (affichage MP). |
| `EveryHours` | serveur | Usure des vêtements portés (`degradeWornClothes`). |
| `OnTick` | serveur | Plancher d'inconfort, puis tous les 30 ticks raideur et effets de chaussures ; resynchronisation de l'inconfort tous les 300 ticks. |
| `OnTick`, `OnAIStateChange` | client | Détection de l'escalade, de la chute et de la réception. |
| `OnCreatePlayer` | serveur (solo seulement) | Tailles de la tenue de départ. |
| `OnZombieDead` | serveur | Une taille de référence et une pointure par zombie, avant la création du cadavre. |
| `OnClothingUpdated` | partagé | Recalcul des stats dérivées. |
| `OnClientCommand` / `OnServerCommand` | serveur / client | Commandes du module `MTIR`. |
| `OnFillInventoryObjectContextMenu` | client | Menus (quatre abonnés). |
| `OnPostDistributionMerge`, `OnInitGlobalModData`, `OnFillContainer` | serveur | Butin (voir [specifications-techniques.md](specifications-techniques.md#butin)). |
| `EveryTenMinutes` | serveur MP | Migration des noms de patrons. |

### Commandes réseau (module `MTIR`)

Client → serveur : `setCraftSize`, `climb`, `fall`, `machineSound`. Serveur → client : `fx`, `machineSound`, `embroideryRemoved`. En solo, `sendClientCommand` est traité par le même gestionnaire et `MTIR.tell` applique l'effet directement. Arguments et contrôles : [specifications-techniques.md](specifications-techniques.md#commandes-réseau).

### Synchronisation

- Objet modifié : `syncItemFields` (ModData remplacée entièrement, état, nom, poids) via `MTIR.syncItem`, serveur seulement.
- Partie du corps (raideur, ampoules) : `syncBodyPart` ; trous de déchirure : `syncVisuals` ; endurance : `syncPlayerStats`.
- Machine posée : `transmitModData` après un changement d'état.
- Ajout / retrait d'objets : `sendAddItemToContainer`, `sendRemoveItemFromContainer`.

## Persistance

Tout l'état vit dans la ModData des objets, sauvegardée avec eux. Rien n'est stocké sur le joueur ni dans une ModData globale.

| Porteur | Clé | Contenu |
|---|---|---|
| Vêtement | `MTIR` | taille, révélée, indice, retouche antérieure |
| Chaussure | `MTIR_Shoe` | pointure, révélée, indice |
| Patron | `MTIR_Pattern` | modèle, genre, tissu, difficulté, précision, utilisations, copies |
| Classeur | `MTIR_Binder` | `nextId`, entrées (type, nom, ModData complète du patron) |
| Vêtement brodé | `MTIR_Embroidery` | texte, nom antérieur |
| Machine posée (`IsoObject`) | `movableData.mtirCondition` | état 0–100, recopié par le vanilla quand on ramasse et repose le meuble |

Valeurs non persistantes : pointure du pied (recalculée depuis le nom du personnage), taille d'artisanat choisie (`MTIR.ServerCraftSize`, en mémoire, par compte), jauge de frottement, caches d'options.

Migration existante : noms de patrons en clé brute `IGUI_MTIR_…` (0.4.5, `MTIR_ServerTranslations`). Aucun changement de schéma n'a demandé d'autre migration.

## Points d'extension et intégrations

- **TooltipLib** (prérequis) : `TooltipLib.registerProvider` pour la ligne de taille, la broderie et le contenu du classeur.
- **Vêtements d'autres mods** : tailles déduites automatiquement (`MTIR_Sizing`), patrons du commerce tirés parmi tous les scripts chargés, aperçu 3D et teinture compatibles.
- **Immersive Weighing** : si un mod de la liste `WEIGHT_HIDING_MODS` (`ImmersiveWeighing`) est actif, la taille n'est pas affichée sur l'écran Personnage.
- **Realistic Clothes** : déclaré incompatible (`incompatible=\RealisticClothes`).
- **Butin** : ajouts à `OnPostDistributionMerge`, après ceux des autres mods ; les listes contenant un kit de couture (y compris de mods) reçoivent la machine électrique.
- **Désinstallation** : `batman_MyTailorIsRich_Uninstall` redéclare les entités à `SpriteConfig`, les objets posables, les tuiles et leurs traductions, pour que `WorldDictionary.bin` reste satisfait.

## Outillage

- `python tests/run_tests.py` (option `--require-luacheck` en CI) : luacheck (`.luacheckrc`), syntaxe Lua 5.1 et appels interdits (`next`), traductions (JSON, clés et paramètres comparés à l'anglais, `%` isolé), descriptions Steam (`README.steam*` ≤ 8 000 octets, BBCode, liens, synchronisation avec `workshop.txt`), cohérence du mod de désinstallation, tests Lua sous `lupa` (`tests/lua/test_*.lua`, API du jeu simulée par `tests/lua_harness.py`).
- Tests qui lisent les tables de butin vanilla : variable `PZ_MEDIA` vers le dossier `media` du jeu, sinon ignorés.
- CI : `.github/workflows/checks.yml` (Ubuntu, Python 3.12, `lua-check`, `lupa`) à chaque push et pull request.
- `source/sewing_machine/`, `source/treadle_machine/` : fichiers `.blend` et scripts `build_*.py` qui génèrent les tuiles et packs des machines.
- Publication Workshop et notes de version : outillage commun du dossier `Workshop` (`CHANGELOG.md` lu par l'outil de publication).
