# ADR-001 — Album de patrons : le classeur devient consultable

| Champ | Valeur |
|---|---|
| Identifiant | `ADR-001-ALBUM-DE-PATRONS` |
| Date de création et de mise à jour | 2026-11-15 (D11 à D13 ajoutées le même jour), 2026-11-16 (D14 à D16) |
| Statut | Accepté (2026-11-15, demande de l'utilisateur : « code direct, je ferai le test moi-même ») |
| Avancement | Codé et testé hors jeu, test en jeu par l'utilisateur ; voir le [plan 001](../ADR-plans/plan-001-album-de-patrons.md) |
| Décideur | l'utilisateur |
| Portée | `batman_MyTailorIsRich` : Lua `client` (fenêtre, menus, onglet Patron de la machine), Lua `shared` (modèle de l'album), traductions des 9 langues, wiki |
| Documents liés | [ameliorations-et-idees.md](../ameliorations-et-idees.md) (I21), [specifications-fonctionnelles.md](../specifications-fonctionnelles.md) (F16 classeur, machine onglet Patron), [architecture.md](../architecture.md) |
| Références | `shared/MyTailorIsRich/MTIR_PatternBinder.lua` (données, `getBinderEntries`, `binderEntryPattern`), `shared/MyTailorIsRich/MTIR_Patterns.lua:355-375` (données d'un patron), `shared/MyTailorIsRich/MTIR_Sizing.lua:207` (`getSizing` : `kind`, `slot`), `client/MyTailorIsRich/MTIR_PatternBinderMenu.lua:187-230` (sous-menus actuels), `client/MyTailorIsRich/MTIR_MachineTabPattern.lua:84-125, 150-158` (choix et emplacement du patron), `client/MyTailorIsRich/MTIR_MachineUIUtil.lua:98, 114` (`ISItemDropBox`, `openChooser`), `client/MyTailorIsRich/MTIR_PatternPreview.lua` (aperçu 3D), `client/MyTailorIsRich/MTIR_SewingMachineWindow.lua:672` (`open`) |
| Origine | demande de l'utilisateur du 2026-11-15 : « un album de patrons […] avec une petite barre de recherche (nom, catégorie, matériaux, et une prévisualisation du patron quand je clique dessus) » |

## Contexte

Le classeur à patrons (F16) range déjà jusqu'à `PatternBinderCapacity` patrons (20 par défaut, 100 au plus) avec
leurs utilisations et leur précision. On le consulte par un sous-menu contextuel « Patrons (n/max) » : un patron par
ligne, et pour chacun coudre, sortir, aperçu. Au-delà d'une dizaine de patrons, ce sous-menu devient une longue liste
sans recherche ni image. Confirmé statiquement.

La machine à coudre lit déjà les classeurs : un clic sur l'emplacement du patron ouvre une liste
(`UI.openChooser`, menu contextuel) qui mélange les patrons portés et ceux de tous les classeurs portés, et la couture
part d'une entrée du classeur sans la sortir (`setPattern(binder, entryId)`). Confirmé statiquement.

Chaque patron porte ce qu'il faut pour le décrire (`MTIR_Patterns.lua:362-368`) : `fullType` du vêtement produit,
`kind` (`clothes`, `glove`, `shoe`), `fabric` (`cotton`, `denim`, `leather`), `difficulty`, `precision`, `uses`. La
partie du corps se déduit du vêtement par `MTIR.getSizing` (`slot`), comme pour les tailles : les vêtements des autres
mods sont donc couverts.

La question de l'utilisateur : une fois le patron dans l'album, comment s'en servir sur une machine ?

## Décisions

### D01 — Faire évoluer le classeur, pas créer un nouvel objet

L'album est une nouvelle façon de **consulter** le classeur existant. Même objet, même recette, mêmes données
(`{ nextId, entries }`), même capacité. Aucune migration, aucun nouvel objet à trouver ou fabriquer.
Raison : deux objets qui rangent des patrons seraient déroutants, et les sauvegardes restent valables.

### D02 — Une fenêtre « album » remplace le sous-menu des patrons

Le menu du classeur propose **Ouvrir l'album** à la place de « Patrons (n/max) » et de son sous-menu par patron.
**Tout ranger** reste dans le menu contextuel (geste rapide sans fenêtre). L'infobulle du classeur (liste du
contenu) ne change pas.

La fenêtre (`MTIR_PatternAlbumWindow`, `ISCollapsableWindow`) contient de haut en bas :

1. Une **barre de recherche** (`ISTextEntryBox`) et le compteur `n/max`.
2. Une **grille de vignettes** défilante : icône du vêtement produit, nom, utilisations restantes (`3/10`), tri par
   nom.
3. Une **zone de dépôt** (`ISItemDropBox`, le widget vanilla déjà utilisé par l'emplacement de la machine) :
   « Glissez un patron ici pour le ranger ».
4. Une **fiche** du patron sélectionné : nom, catégorie, matériau, précision, utilisations, besoins pour la taille du
   personnage (`MTIR.getSewRequirements`, texte déjà produit par `MTIR.SewUI.describeSew`), puis les boutons
   **Aperçu sur moi** (fenêtre 3D existante), **Coudre à la main** (tailles), **Coudre à la machine** (D06),
   **Sortir**.

Manette : flèches pour se déplacer dans la grille, A pour sélectionner, B pour fermer, comme la fenêtre d'aperçu.

### D03 — Recherche : un seul champ, trois critères

La recherche garde une vignette si chaque mot tapé apparaît dans son **nom**, sa **catégorie** ou son **matériau**,
textes traduits dans la langue du joueur, sans tenir compte des majuscules. Exemples : `jean` trouve les patrons en
jean, `haut cuir` les hauts en cuir, `chemise` les chemises.

Catégories affichées : Haut, Bas, Tenue complète, Gants, Chaussures, et Autre pour un emplacement non classé. Elles
viennent de `kind` puis du `slot` de `MTIR.getSizing(fullType)` ; le tableau `slot → catégorie` est une donnée, pas
une suite de `if`.

Limite connue : la comparaison sans majuscules de Kahlua ne traite que l'ASCII (`string.lower`). Un accent tapé doit
correspondre exactement à celui du texte.

### D04 — Un modèle pur, séparé de la fenêtre

`shared/MyTailorIsRich/MTIR_PatternAlbum.lua` ne touche ni à l'interface ni au réseau :

- `MTIR.PatternAlbum.cards(sources)` : à partir de sources `{ item, entryId? }` (classeurs et patrons isolés), rend des
  fiches `{ item, entryId, name, kind, category, fabric, uses, maxUses, precision, fullType }` ;
- `MTIR.PatternAlbum.filter(cards, query, accept?)` : recherche D03, puis filtre optionnel (D05 : patrons cousables à
  la machine) ;
- `MTIR.PatternAlbum.sort(cards)` : par nom.

La fenêtre (`client/MyTailorIsRich/MTIR_PatternAlbumWindow.lua`) affiche ce que le modèle rend et délègue chaque
geste à une action existante. Le modèle se teste hors jeu comme le reste du mod (`tests/lua/`).

### D05 — Depuis la machine : le même album, en mode « choisir »

Un clic sur l'emplacement du patron de la machine ouvre l'album en mode **choisir** à la place de la liste actuelle :

- il montre ensemble les patrons portés et ceux de tous les classeurs portés (les sources de `collectChoices`), avec
  le nom du classeur sur la vignette quand le patron y est rangé ;
- il ne garde que les patrons cousables à la machine (même règle qu'aujourd'hui : pas de chaussures) ;
- cliquer sur une vignette puis **Choisir** appelle `setPattern(item, entryId)`, et la fenêtre se ferme.

C'est la réponse à la question de l'utilisateur : le patron reste dans l'album, la machine le lit et décompte ses
utilisations dans le classeur, comme aujourd'hui. Le geste du joueur ne change pas (clic sur l'emplacement), il gagne
la recherche et les vignettes. Glisser un patron isolé sur l'emplacement reste possible.

### D06 — « Coudre à la machine » depuis la fiche

Le bouton est actif quand une machine à coudre est à portée du personnage (même règle de portée que la machine,
`MTIR.isNearSewingMachine`). Il ouvre la fenêtre de la machine (`MTIR_SewingMachineWindow.open`) sur l'onglet Patron
avec ce patron déjà choisi. Sinon, il est grisé avec une infobulle « Aucune machine à coudre à portée ».

### D07 — Ranger : glisser-déposer ou menu, par les actions existantes

- Déposer un ou plusieurs patrons sur la zone de dépôt met en file une `MTIR_BinderStoreAction` par patron.
- Le menu « Ranger dans le classeur » d'un patron reste tel quel.
- Sortir passe par `MTIR_BinderTakeAction`, coudre par `MTIR.SewUI.queueSew` : aucune nouvelle action, aucune
  nouvelle commande réseau. Le serveur garde l'autorité sur tout.

Glisser une vignette de l'album vers la machine n'est **pas** retenu : une vignette n'est pas un objet du jeu, ce
serait un glisser-déposer maison entre deux fenêtres, fragile en multijoueur, pour le même résultat que D05.

### D08 — Vignette : icône du vêtement produit

La vignette affiche l'icône du script de `fullType` (`UI.scriptTexture`, déjà utilisé par la machine :
`Item:getNormalTexture()`, posée par le jeu depuis `Icon` ou la première icône de couleur, `Item.java:1498-1499,
2036-2041`, confirmé statiquement), l'icône du patron si elle est introuvable (vêtement d'un mod retiré).

### D09 — Multijoueur et rafraîchissement

L'album lit les données du classeur déjà synchronisées par les actions existantes. Il se recalcule quand le nombre
d'entrées des sources change (vérification dans `update`, sans crochet global par image hors de la fenêtre ouverte)
et à chaque frappe dans la recherche. Les noms affichés restent ceux des patrons (langue du serveur en MP, F16).

### D10 — Ce qui ne change pas

Aucune option de partie nouvelle, capacité inchangée, recette et poids du classeur inchangés. Textes nouveaux en
traductions dans les 9 langues du mod.

### D11 — Les besoins sous l'aperçu

(Demande de l'utilisateur du 2026-11-15.) La fiche montre la photo du vêtement, puis juste en dessous les
matériaux, outils et chances nécessaires pour coudre à la main à la taille du personnage
(`MTIR.SewUI.describeSew`), avant les boutons.

### D12 — Style « album ancien », tailles adaptatives

(Demande de l'utilisateur du 2026-11-15 : « style vintage, attention aux hautes résolutions 4K ».)

- Style (`client/MyTailorIsRich/MTIR_VintageStyle.lua`) : couverture en cuir bordée d'une couture pointillée,
  titre manuscrit doré (`UIFont.Handwritten`), page crème où chaque patron est une photo collée avec des coins
  photo, boutons en cuir clair à liseré doré. Fenêtre `ISPanel` dessinée par le mod, déplaçable à la souris.
- Tailles (`client/MyTailorIsRich/MTIR_UIScale.lua`, même méthode que Live Wire `LW_UIScale.lua`) : mise en page en
  pixels de référence 1080p (police de 19 px), multipliée par la hauteur réelle de la petite police rapportée à
  19, jamais sous 1, abaissée pour tenir à l'écran ; position ramenée dans l'écran. Hauteurs de ligne, boutons et
  cases lues sur les polices réellement dessinées ; textes raccourcis avec « ... » à la largeur disponible.

### D13 — Déchirer un patron

(Demande de l'utilisateur du 2026-11-15.) Recette `MTIR_TearPattern` : un patron isolé (tracé ou du commerce),
en main, sans outil, rend une feuille de papier (`Base.SheetPaper2`). Un patron rangé se sort d'abord.

### D14 — Deux volets : classeur de cartes à gauche, aperçu sur moi à droite

(Retour de l'utilisateur du 2026-11-15 : « la liste comme un classeur Pokémon à gauche, la prévisualisation à
droite » ; deux fenêtres séparées refusées.) Remplace la grille défilante et le bouton « Aperçu sur moi » de D02 :

- à gauche, pages de 3 × 3 pochettes (`MTIR_PatternAlbumPage`), tournées par des flèches, la molette ou LB/RB ; la
  recherche filtre puis découpe en pages ;
- à droite, l'aperçu 3D intégré : le panneau `MTIR_PatternPreviewPanel` est extrait de la fenêtre d'aperçu, qui
  l'utilise aussi (menus du patron et de la machine) ;
- la case de dépôt de D07 est remplacée par un dépôt sur la page elle-même.

Décision précédente (D02, grille et fenêtre d'aperçu séparée) gardée ci-dessus pour mémoire.

### D15 — Classeur sans limite de nombre

(Demande de l'utilisateur du 2026-11-15.) L'option `PatternBinderCapacity` et le refus « classeur plein » sont
supprimés : seul le poids grandit (0,3 kg + 0,1 kg par patron). Remplace la phrase « même capacité » de D01 et
« capacité inchangée » de D10. Une option déjà réglée sur un serveur est simplement ignorée.

### D16 — Album redimensionnable

(Demande de l'utilisateur du 2026-11-16 : panneau « un poil trop petit ».) Poignée cousue au coin bas-droit : le
cadre de la taille visée suit la souris, puis au relâchement tout l'album est reconstruit à l'agrandissement
choisi (`MTIR.UIScale.factor(baseW, baseH, zoom)` : police × agrandissement, au moins 1, borné à l'écran).
Agrandissement proportionnel plutôt que nouvelle disposition : mêmes proportions, aucune mise en page à
recalculer pièce par pièce. L'agrandissement est retenu dans la ModData globale `MTIR_ClientUI` côté client.

## Hors périmètre de cette version

- Un classeur **posé** près de la machine (table, étagère) : seuls les classeurs portés comptent, comme aujourd'hui.
- Glisser une vignette de l'album vers la machine (D07).
- Tri autre que par nom, favoris, dossiers dans l'album.

## Conséquences

- Les sous-menus par patron disparaissent du menu du classeur (`MTIR_PatternBinderMenu`, sans test hors jeu
  aujourd'hui) ; les données du classeur (`MTIR_PatternBinder`, testées) ne changent pas.
- Le choix de patron de la machine ne passe plus par `UI.openChooser` ; l'onglet Retouche, qui l'utilise aussi, n'est
  pas touché.
- Nouveaux fichiers : `MTIR_PatternAlbum.lua` (shared), `MTIR_PatternAlbumWindow.lua` (client), tests associés.
- Wiki (pages 05 et 06, EN et FR) et spécifications fonctionnelles F16 à mettre à jour.

## Découpage

Le découpage est suivi dans le [plan 001](../ADR-plans/plan-001-album-de-patrons.md).

1. Modèle pur : fiches, catégories, recherche, tri (tests hors jeu).
2. Fenêtre de l'album en consultation : grille, recherche, fiche, aperçu, sortir, coudre à la main ; menu « Ouvrir
   l'album ».
3. Zone de dépôt et rangement par glisser-déposer.
4. Mode « choisir » branché sur l'emplacement de la machine (D05).
5. Bouton « Coudre à la machine » (D06).
6. Traductions, wiki, spécifications ; test en jeu du parcours nominal (solo, puis MP par la suite automatique).
