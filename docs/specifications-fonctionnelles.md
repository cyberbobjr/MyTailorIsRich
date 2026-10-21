# Spécifications fonctionnelles — My Tailor Is Rich

Ce que fait le mod (version 0.4.5, Build 42.21) du point de vue du joueur et de l'administrateur. Chaque fonctionnalité a un identifiant stable. Les valeurs exactes, noms d'options et formats sont dans [specifications-techniques.md](specifications-techniques.md) ; l'organisation du code dans [architecture.md](architecture.md).

Prérequis : TooltipLib. Incompatible : Realistic Clothes (dont ce mod est une réécriture pour 42.21).

## Tailles des vêtements

### F01 — Taille du personnage
La taille du personnage suit son poids : XS ≤ 50 kg, S ≤ 65, M ≤ 75, L < 85, XL < 100, XXL ≥ 100. Elle change avec le poids. Elle s'affiche sur l'écran Personnage à côté du poids, avec la pointure (option `ShowPlayerSize`), sauf si un mod masque le poids (Immersive Weighing).

### F02 — Vêtements qui ont une taille
Hauts, bas, robes et combinaisons ont une taille XS à XXL, qu'ils viennent du jeu ou d'un autre mod. Les emplacements vanilla connus ont un profil fixe ; tout autre vêtement reçoit une taille d'après ce qu'il couvre (torse, jambes, les deux, ou pieds seuls pour une chaussure). Accessoires (chapeaux, masques, gants, bijoux, ceintures, écharpes, chaussettes…), sous-vêtements et cosmétiques n'ont pas de taille. L'administrateur ajoute des emplacements ou des objets, ou en exclut, par options (F27).

### F03 — Tirage de la taille
Un vêtement trouvé reçoit sa taille au premier besoin, selon une répartition fixe (L la plus fréquente). Les vêtements d'un même cadavre de zombie sont tirés autour d'une même taille de référence (même taille le plus souvent, sinon une de moins ou de plus). 10 % des vêtements trouvés ont déjà été retouchés et ne peuvent plus l'être (F07).

### F04 — Lire la taille (« Check clothes size »)
La taille d'un vêtement trouvé est inconnue. L'option **Check clothes size** lit l'étiquette : avec un niveau de Couture suffisant (difficulté du vêtement − 1, option `NeedTailoringLevel`), la taille exacte ; sinon un indice (« un peu serré », « très ample »…) que le personnage dit à voix haute. Un vêtement dans un cadavre, un meuble ou un coffre de véhicule à portée est lu sur place, sans être pris ; au sol, il est d'abord ramassé. Sous-menu : sélection, tous les vêtements de ce cadavre, tous les vêtements des cadavres accessibles proches (chaussures comprises). Les lectures groupées sautent les tailles connues et les indices qu'on ne peut pas améliorer avec le niveau actuel ; un objet retiré entre-temps par un autre joueur est ignoré. Une taille connue s'affiche dans le nom en inventaire et dans l'infobulle.

![Taille dans l'infobulle](images/screenshots/shot1.png)

### F05 — Effets d'un vêtement mal ajusté
- **Trop grand** : isolation réduite ; combat plus lent pour un haut ; un pantalon ou une jupe trop grand peut **tomber** sans ceinture quand les deux mains sont occupées ; trébuchement possible à la réception d'une clôture, même au pas (moins souvent qu'en courant).
- **Trop petit** : plus long à enfiler, peut **se déchirer** en escaladant, trébuchement possible après un mur, raideur musculaire des zones couvertes (aggravée par l'exercice) ; **impossible à enfiler** à 3 tailles ou plus d'écart.
- Prise de poids : un vêtement devenu impossible à porter est retiré.
- Un vêtement fabriqué dont la taille reste à choisir ne s'enfile pas.

### F06 — Taille d'un vêtement fabriqué
Dans la fenêtre d'artisanat, une recette qui produit un vêtement affiche un choix de taille ; le vêtement sort avec cette taille, déjà connue. Sans choix transmis au serveur, il sort avec une taille « à choisir », ne s'enfile pas, et l'option **Choose clothes size** du menu contextuel la fixe. Une chaussure fabriquée est à la pointure de l'artisan.

## Retouches et usure

### F07 — Retoucher (agrandir ou rétrécir)
Une seule retouche par vêtement, d'une taille, sur un vêtement de taille connue et en tissu reconnu (coton, jean, cuir). Agrandir consomme des bandes du tissu ; rétrécir, des trombones ; les deux, aiguille, ciseaux et fil (bobines de fil d'abord, puis tout fil du tag `base:thread` : aramide, tendon… ; matériaux favoris jamais pris) (et un dé à coudre à la main, F25). Niveau requis : difficulté du vêtement + difficulté du tissu (+1 pour agrandir) ; réussite 50 % au niveau requis, +25 % par niveau au-dessus. Un échec peut user le vêtement (option `ChanceToDegradeOnFailure`).

![Retouche sur machine à pédale](images/screenshots/shot2.png)

### F08 — Usure des vêtements
Les vêtements portés s'usent avec le temps (saleté, sang, humidité, vêtement trop serré). Leur état baisse, et avec lui leurs protections et résistances (options `ProtectionLossEachCondition`, `ResistanceLossEachCondition`). Poser ou retirer une rustine vanilla ne change plus l'état d'un vêtement qui s'use. L'infobulle d'un vêtement porté estime son usure. Option `EnableClothesDegrading` pour désactiver.

### F09 — Remise en état
**Recondition** répare un vêtement usé avec des bandes de tissu ou un second exemplaire du même objet (ni porté ni en main), qui est consommé. Les chances et le gain dépendent de la Couture, de l'Entretien et du nombre de réparations déjà faites (chaque réparation rend la suivante moins efficace). Comme pour une retouche, un échec peut user le vêtement.

## Chaussures

### F10 — Pointure du personnage et des chaussures
Pointures EU 35 à 47 (option `EnableShoeSizes`). Le pied du personnage a une pointure fixe selon son sexe (femmes 35–42, hommes 39–47). Les chaussures trouvées penchent vers le porteur habituel du modèle (bottes de travail, militaires et de randonnée plutôt masculines ; chaussures habillées à brides plutôt féminines) ; sur un cadavre, elles suivent le sexe du zombie. La pointure est imprimée dans la chaussure : la lire ne demande aucune compétence. Les enveloppes improvisées (chiffon, toile de jute, jean, cuir, bâche, ficelle) vont à tout le monde.

### F11 — Effets d'une chaussure mal ajustée
| Écart | Effets |
|---|---|
| 3 pointures ou plus trop petite | Impossible à enfiler |
| 1–2 trop petite | Humeur **inconfort**, **ampoules** (jauge de frottement qui se remplit en marchant, plus vite en courant ; le personnage prévient à mi-jauge), raideur des pieds |
| Bonne pointure ou une de plus | Rien |
| 2 ou plus trop grande | Endurance consommée en plus en course, ampoules rares, trébuchement possible après une clôture ou un mur, piétinement plus faible sur un zombie au sol (jusqu'au niveau pieds nus), **chaussure perdue** possible en enjambant une clôture, en escaladant ou en tombant |
| 3 ou plus trop grande | En plus : inconfort, et chaussure perdue possible aussi en courant ou en sprintant |

Le risque de perte est plus élevé avec des tongs et des pantoufles, plus faible avec des bottes lacées ; un tirage manqué de peu fait dire au personnage que la chaussure a failli partir.

Une ampoule est une petite égratignure au pied, sans infection zombie ; comme toute blessure au pied, elle ralentit jusqu'à guérison. L'intensité de ces effets se règle par `ShoeEffectMultiplier` (0 les désactive).

## Patrons de couture

### F12 — Tracer un patron
**Trace a pattern** sur un vêtement ou une paire taillés : ciseaux, stylo ou crayon, feuilles de papier vierges (plus pour un vêtement complexe ; une feuille écrite, renommée ou favorite n'est jamais prise), une table, un bureau, un comptoir, un établi ou la machine à pédale à proximité (le personnage s'y rend). Le modèle doit être en bon état (50 % ou plus) et **est détruit**. Niveau requis : un de moins que pour coudre. La précision du patron est le niveau de Couture du traceur. Aucun patron pour les protections balistiques, les objets sans tissu cousable, ni les chaussures en caoutchouc ou plastique.

![Tracer un patron](images/screenshots/shot3.png)

### F13 — Patrons du commerce
Des patrons imprimés se trouvent dans les merceries, les étagères des ateliers de couture et les librairies de mode. Chacun représente un vêtement ou une paire tirés parmi tout ce qui peut être tracé, **mods compris**, avec une précision de 5 à 8.

### F14 — Coudre d'après un patron
**Sew from pattern**, puis n'importe quelle taille (XS–XXL, ou EU 35–47 pour des chaussures). L'objet sort avec sa taille connue. Matériaux selon le tissu du modèle : coton (draps déchirés, rouleau de coton), jean (bandes, rouleaux), cuir (bandes, cuir tanné) ; plus de tissu pour les grandes tailles. Le cuir accepte aussi une alêne et un couteau tranchant. Niveau requis : difficulté du vêtement + tissu (coton 0, jean 1, cuir 2). Risque d'une taille de décalage : 50 % moins 5 % par niveau cumulé du traceur (précision) et du couturier, nul à 10 niveaux. Un patron sert 5 fois (option `PatternMaxUses`), réussite ou échec, puis tombe en morceaux.

### F15 — Chaussures sur patron
Niveau 8 (option `ShoePatternLevel`), aiguille **et alêne**, fil, **colle**, et cuir ou tissu selon le modèle (baskets et pantoufles en coton, le reste en cuir). Toujours cousues à la main.

### F16 — Classeur à patrons
Recette **Make Pattern Binder** (catégorie Couture : ciseaux et aiguille gardés, 1 fil, 2 bandes de coton, jean ou cuir, 2 feuilles), ou trouvé dans les rayons de couture. Il range jusqu'à 20 patrons (option `PatternBinderCapacity`) avec leurs utilisations et leur précision, pèse 0,3 kg plus 0,1 kg par patron. Menu du patron : **Store in binder** ; menu du classeur : **Patterns (n/max)** (coudre, sortir, aperçu par patron) et **Store all patterns**. L'infobulle liste son contenu.

### F17 — Copier un patron
**Copy pattern** : mêmes besoins que le tracé ; l'original est gardé. La copie perd 1 niveau de précision (option `PatternCopyPrecisionLoss`, jamais sous 0) et reçoit des utilisations neuves ; une copie de copie perd encore. On copie un patron sorti du classeur. Option `EnablePatternCopy`.

### F18 — Aperçu sur soi
**Preview on me** : fenêtre 3D du personnage (sexe, peau, cheveux, tenue) qui porte le vêtement ou les chaussures du patron. Rotation à la souris ou aux flèches ; **Keep my other clothes on** montre ou retire le reste de la tenue. Rien n'est réellement porté : aperçu local au client.

![Aperçu sur soi](images/screenshots/shot5.png)

## Teinture et broderie

### F19 — Teindre
Sur un vêtement ou des chaussures : choisir une teinture portée (**colorant industriel** ou **teinture pour cheveux**, avec pastille de couleur). Il faut de l'eau (2, 4 ou 6 L selon le volume du vêtement) et de 0,2 à 0,75 L de teinture. Le vêtement est retiré s'il est porté, prend la couleur et ressort trempé. Aucune compétence ; un peu d'XP de Couture. Possible pour tout vêtement dont le modèle accepte une teinte (vanilla ou mod) et ceux de la recette vanilla **Dye Clothes** ; un vêtement imprimé ou à motifs garde ses couleurs, l'option est grisée avec une explication (seulement si l'on porte une teinture). Option `EnableDyeing`.

### F20 — Broder un nom
**Embroider a name** (aiguille, 1 fil, dé si exigé, Couture 1) : jusqu'à 24 caractères ; le vêtement est renommé (par exemple `Jacket "Bob"`) et l'infobulle montre la broderie. **Unpick the embroidery** (ciseaux) rend l'ancien nom. Ni chaussures ni armures rigides. Option `EnableEmbroidery`.

## Machines à coudre

### F21 — Machines posables
Deux meubles : **machine électrique** posée sur une table, **machine à pédale** dans son meuble en fonte, posée au sol. On les trouve dans les ateliers de couture, merceries, magasins de vêtements et grands magasins, au rayon linge des supermarchés, dans les rangements (garages, box, greniers, abris, réserves, placards) et plus rarement partout où peut se trouver un kit de couture ; la machine à pédale aussi chez les antiquaires. Elles se ramassent et se posent comme tout meuble.

### F22 — Panneau de la machine
Clic (ou option du menu contextuel) : panneau avec bandeau des bonus, état et entretien, et quatre onglets.
- **Pattern** : glisser un patron de vêtement (ou cliquer pour choisir, y compris dans un classeur), taille, **quantité** à coudre d'affilée ; aperçu du résultat et liste exacte des objets consommés ; mémoire du dernier patron. Les patrons de chaussures se cousent à la main.
- **Alteration** : agrandir ou rétrécir.
- **Reconditioning** : remise en état.
- **Embroidery** : texte (prénom proposé), nom obtenu ; masqué si la broderie est désactivée.
Le bouton montre la progression (« Sewing 2/5… 45 % ») ; le personnage marche jusqu'à la machine et travaille face à elle. Un seul joueur à la fois.

![Machine électrique, onglet Patron](images/screenshots/shot4.png)

### F23 — Bonus des machines
| | Électrique | À pédale |
|---|---|---|
| Courant | Requis (réseau à l'intérieur, ou générateur) | Non |
| Durée | 50 % plus rapide | 25 % plus rapide |
| Niveaux de Couture | +2 | +1 |
| Précision de taille | +4 | +2 |
| Fil | −30 % | −15 % |
| Dé à coudre | Inutile | Inutile |
| Broderie | Couture 1 (bonus compris), 2× plus rapide | Couture 3 réelle (bonus non compté), 25 % plus rapide |

Bonus réglés par `MachineBonusMultiplier`.

### F24 — Bruit et entretien
Une machine en marche s'entend des zombies (l'électrique bien plus loin que la pédale ; option `MachineNoiseMultiplier`) et des joueurs proches. Elle s'use à chaque travail ; sous 50 % elle est moins fiable, casse parfois l'aiguille tenue, et se bloque à 0 %. **Service** avec un tournevis et un peu d'huile de cuisine (végétale, d'olive) ; compétence Électricité pour l'électrique, Mécanique pour la pédale. L'usure suit la machine ramassée et reposée. Option `EnableMachineMaintenance`.

### F25 — Dé à coudre
Coudre **à la main** (patrons, retouches, remises en état, broderie) demande un dé dans l'inventaire (option `RequireThimble`). Les machines n'en demandent pas.

## Administration

### F26 — Désinstallation propre
Le mod `batman_MyTailorIsRich_Uninstall`, livré dans le même objet Workshop, remplace le mod principal dans une partie existante : les machines posées restent des meubles sans panneau, les machines ramassées restent des objets valides, la sauvegarde se charge et les clients MP peuvent se connecter (sinon refus `Missing dictionary script on client: Base.MTIR_TreadleMachine`). Il reste activé pour toujours dans cette partie et ne s'active jamais avec le mod principal.

### F27 — Options sandbox
Toutes les options, leur effet et leurs bornes : [specifications-techniques.md](specifications-techniques.md#options-sandbox). Les options se lisent à chaque usage : une modification par un administrateur s'applique sans redémarrage, sauf la rareté du butin (au chargement de la partie).

### F28 — Débogage
En mode debug, ou en MP avec un rôle autorisé à éditer les objets : **[Debug] Size** sur un vêtement ou des chaussures montre taille et pointure du personnage, jauge de frottement, puissance de piétinement, risques de trébuchement et de perte, et permet de fixer une taille ou de l'effacer pour un nouveau tirage.

## Multijoueur

### F29 — Autorité du serveur
Le serveur décide tout : tailles, retouches, usure, ampoules, raideur, chaussures perdues, patrons, classeur, teinture, broderie, état des machines. Il synchronise le résultat vers les clients. Toutes les actions passent par le système d'actions réseau vanilla de Build 42. Un vêtement teint n'apparaît teint aux autres joueurs qu'une fois enfilé. Les noms de patrons sont dans la langue du serveur.

## Limites connues

- En 42.21, le `RunSpeedModifier` vanilla des vêtements n'est jamais appliqué au déplacement (seuls les sacs l'utilisent) : le mod ralentit par les blessures au pied (ampoules) et l'endurance.
- Les courbatures aux bras après un combat viennent des poussées vanilla ; un haut serré les fait seulement durer.
- Les vêtements gardent leurs données de taille si le mod est retiré, sans effet.
- La taille d'artisanat choisie est gardée en mémoire par le serveur, pas sauvegardée.
