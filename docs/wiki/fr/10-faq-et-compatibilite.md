# FAQ et compatibilité

## Compatibilité

| Mod | État |
|---|---|
| [TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672) | **Obligatoire.** |
| [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) | **Incompatible** (déclaré dans le mod). My Tailor Is Rich en est la réécriture pour la Build 42.21. |
| [Immersive Weighing](https://steamcommunity.com/sharedfiles/filedetails/?id=3791897755) | Compatible : quand le poids est masqué, la taille l'est aussi, puisqu'elle suit le poids. |
| Mods de vêtements | Compatibles : leurs vêtements reçoivent une taille d'après ce qu'ils couvrent ; patrons du commerce, aperçu 3D et teinture les incluent. |
| Mods de butin qui ajoutent des kits de couture | Compatibles : la machine électrique peut apparaître là où ils posent un kit de couture. |

## Un vêtement de mod n'a pas de taille (ou ne devrait pas en avoir)

Les vêtements d'autres mods reçoivent une taille d'après les parties du corps qu'ils couvrent. Chapeaux, masques, gants, bijoux, ceintures, chaussettes et accessoires semblables n'en ont jamais. Si un vêtement est oublié ou taillé à tort, utilisez les options **Vêtements supplémentaires**, **Emplacements supplémentaires** ou **Vêtements exclus** ([Options sandbox](08-options-sandbox.md#objets-qui-ont-une-taille)).

## Pourquoi un vêtement trop grand ne me ralentit-il pas ?

En Build 42.21, le `RunSpeedModifier` vanilla des vêtements n'est jamais appliqué au déplacement (seuls les sacs l'utilisent). Le mod utilise ce que le moteur permet : blessures aux pieds (ampoules) et endurance.

## J'ai mal aux bras après un combat

Les courbatures aux bras viennent des **poussées vanilla** : chaque poussée sollicite les bras. Un haut serré les fait seulement durer plus longtemps.

## Puis-je ajouter le mod à une partie existante ?

Oui. Les vêtements déjà présents reçoivent une taille la première fois qu'elle sert.

## Retirer le mod d'une partie

Ne désactivez pas simplement le mod dans une partie existante. Le jeu enregistre les deux machines à coudre (`Base.MTIR_SewingMachine`, `Base.MTIR_TreadleMachine`) dans le fichier `WorldDictionary.bin` de la sauvegarde et, en Build 42.21, n'efface jamais cet enregistrement. Une fois le mod retiré, chaque client multijoueur, hôte d'une partie en coopération compris, est refusé avec `[SpriteConfigs] Missing dictionary script on client: Base.MTIR_TreadleMachine`.

L'objet Workshop livre un second mod pour cela : **`batman_MyTailorIsRich_Uninstall`**.

1. Dans la liste des mods de la partie (ou du serveur), remplacez `batman_MyTailorIsRich` par `batman_MyTailorIsRich_Uninstall`. Restez abonné à l'objet Workshop.
2. Gardez-le activé pour toujours dans cette partie : le retirer ramène l'erreur.
3. N'activez jamais les deux mods ensemble (ils sont déclarés incompatibles).

Il ne contient aucun code : les machines posées restent dans le monde comme de simples meubles (sans panneau de couture), et les machines ramassées restent des objets valides. Les vêtements gardent leur taille dans leurs données, sans plus aucun effet. Les patrons, classeurs et autres objets du mod disparaissent, comme avec tout mod retiré.

## Outils de débogage

En mode debug, ou en multijoueur avec un rôle autorisé à éditer les objets, clic droit sur un vêtement ou des chaussures, puis **[Debug] Taille**. Le sous-menu montre votre taille, votre pointure, la puissance de piétinement, les risques de trébuchement et de perte de chaussure et, en solo, la jauge de frottement ; il permet de fixer n'importe quelle taille ou de l'effacer pour un nouveau tirage.

> Capture à faire : le sous-menu [Debug] Taille sur une paire de chaussures.

## Signaler un problème

Ouvrez une issue sur [GitHub](https://github.com/cyberbobjr/MyTailorIsRich/issues) avec votre version du jeu, votre liste de mods et les lignes qui commencent par `[MTIR]` ou l'erreur de `console.txt`.
