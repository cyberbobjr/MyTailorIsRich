# My Tailor Is Rich — storyboard des captures Steam Workshop

Objectif : une galerie de 10 images qui raconte le mod dans l'ordre où un joueur le découvre.
1. Les vêtements ne vont pas.
2. On le voit.
3. On en souffre.
4. On s'équipe.
5. On coud.
6. On entretient.

Chaque image montre **une** fonction, lisible sans légende.

## Réglages communs

- **Format** : 1920×1080, PNG, capture Steam (F12). Les images de la galerie Workshop s'affichent en 16:9.
- **Vignette du mod** (`preview.png`, dans le mod) : 256×256. Utiliser un gros plan de la machine électrique, déjà rendu (`source/sewing_machine`).
- **Personnage** : le même homme dans toute la galerie, pour la continuité.
  - Environ 72 kg, donc taille **M** (de 65 à 75 kg), pointure **43**.
  - Un gabarit moyen : un XXL trouvé lui va large, une botte en 42 le serre.
  - Nom court et lisible (il apparaît dans l'écran du personnage).
  - L'histoire : un survivant mal fagoté (images 1 à 3) qui devient le tailleur de sa communauté (images 4 à 10).
- **Tailles des vêtements de la prise** : un vêtement apparu par le mode debug a une taille inconnue ou tirée au hasard. Avant la prise, la fixer avec le clic droit **[Debug] Size** : M pour ce qu'il porte bien, la taille voulue pour les vêtements « ratés ».
- **Couleurs** : les objets `…TINT` reçoivent une couleur au hasard. En faire apparaître plusieurs et garder la plus sobre (gris, brun, bleu marine).
- **Avant chaque prise** :
  - **désactiver l'invisibilité admin** (le personnage est dessiné différemment et reste muet) ;
  - fermer les fenêtres de debug ;
  - régler l'heure et la météo avec les outils admin : jour clair, 10 h ou 16 h, pour la lumière rasante.
- **Zoom** : un cran plus près que le zoom par défaut. Le personnage et l'objet mis en avant occupent environ le tiers central de l'image.
- **Interface** : ne garder que ce qui sert l'image (fenêtre du mod, infobulle, menu). Placer les fenêtres du mod près du personnage, pas dans un coin.
- **Objets** : les faire apparaître par la liste d'objets du mode debug avant la prise, puis la fermer.
  - Machines : `Base.Mov_MTIR_SewingMachine`, `Base.Mov_MTIR_TreadleMachine`.
  - Patron imprimé : `Base.MTIR_PrintedPattern`.
- **Langue** : faire chaque image en anglais (galerie principale). Refaire en français les images 4, 6 et 7 si l'on veut une page française.

## Lieux repérés (carte vanilla 42.21)

| Lieu | Coordonnées (x, y, z) | Usage |
|---|---|---|
| Atelier de couture, Riverside | 6418-6424, 5297-5314, 0 | Machines, patrons, séries |
| Garages séparés, Riverside | 6311,5371,0 · 6283,5383,0 | Butin, entretien |
| Magasin de vêtements, Rosewood | 8116-8131, 11457-11465, 0 | Tailles, essayages |
| Atelier de tailleur, Muldraugh | 10864-10874, 9517-9532, 0 | Couture de nuit, bruit |
| Garages séparés, Muldraugh | 10711,9707,0 · 10654,9713,0 | Butin |
| Salle de couture (maison), Louisville | 12029-12033, 2378-2383, 1 | Variante intimiste |

Relevé fait avec `lotheader_parser.py` : vérifier sur place qu'aucun mod de carte n'a changé le bâtiment.

## Garde-robe du tailleur (objets vanilla 42.21)

Codes à chercher dans la liste d'objets du mode debug (module `Base`).

**Tenue d'atelier** (images 4, 5 et 7) : l'allure d'un tailleur de petite ville en 1993, sobre et soignée.

| Pièce | Objet | Remarque |
|---|---|---|
| Chemise | `Shirt_FormalWhite` | Ou `Shirt_FormalTINT` bleu pâle |
| Gilet de costume | `Vest_WaistcoatTINT` (ou `Vest_Waistcoat`) | La pièce qui fait « tailleur » : gris anthracite ou brun |
| Cravate | `Tie_Worn` | Cravate desserrée, en plein travail ; `Tie_BowTieWorn` pour un style plus ancien |
| Pantalon | `Trousers_Suit` | Assorti au gilet si possible |
| Ceinture | `Belt2` | Utile aussi en jeu : un pantalon trop grand tombe sans ceinture |
| Chaussures | `Shoes_Brown` | Ou `Shoes_Black` |
| Lunettes | `Glasses_HalfMoon` | Demi-lunes de lecture, très « métier » ; sinon `Glasses_Reading` |
| En main | `Scissors` et `MeasuringTape` | Le mètre ruban vanilla n'a pas de modèle porté autour du cou : on le tient en main |

- **Cheveux et barbe** : `GreasedBack` ou `LeftParting` avec `Moustache`. Pour un tailleur plus âgé : `Recede` et `Chops`, cheveux grisonnants.
- **À éviter** : sac à dos, armes et protections visibles dans l'atelier. Les tabliers vanilla évoquent la cuisine (`Apron_White`) ou le restaurant ; un `Apron_Black` reste possible dans l'atelier de Muldraugh.

**Autres tenues de la galerie**

| Tenue | Images | Objets |
|---|---|---|
| Survivant mal fagoté | 1, 2, 3 | `HoodieDOWN_WhiteTINT` en **XXL** (couleur terne), `Trousers_Denim`, `Shoes_WorkBoots` en **42** (une pointure trop petite), `Jacket_Padded` à l'image 3 |
| Tenue d'intérieur | 6 | `Shirt_FormalWhite`, `Jumper_VNeck` par-dessus, `Trousers_Suit`, `Shoes_Slippers`, `Glasses_HalfMoon` |
| Mécanique | 8 | `Dungarees` (salopette) ou `Boilersuit`, `Tshirt_WhiteLongSleeve`, `Gloves_LeatherGlovesBrown`, `Shoes_WorkBoots` en 43 |
| Pillage | 9 | `Jacket_Padded`, `Trousers_Denim`, `Belt2`, un sac à dos, lampe torche en main |
| Cordonnier | 10 | `Shirt_Denim`, `Apron_Leather`, `Trousers_Denim`, `Gloves_FingerlessLeatherGloves_Brown`, `Glasses_Reading`, `Shoes_WorkBoots` usées |

---

## 1. « Nothing fits » — les tailles

- **But** : l'idée du mod en une image : un vêtement trouvé a une taille, et elle n'est pas la vôtre.
- **Lieu** : magasin de vêtements de Rosewood, entre deux portants.
- **Tenue** : survivant mal fagoté (sweat à capuche XXL qui flotte, jean, bottes de travail).
- **Mise en scène** : inventaire ouvert, infobulle d'une veste en jean XXL déjà vérifiée. La ligne de taille TooltipLib affiche « XXL (Loose) », suivie de la ligne d'usure.
- **Cadrage** : personnage au centre gauche, infobulle à droite du personnage.
- **Légende** : *Every garment has a size. Yours is M. This one is XXL.*

## 2. « Read the label » — vérifier une taille

- **But** : l'action « Check clothes size » et la taille cohérente d'un cadavre.
- **Lieu** : rue résidentielle de Muldraugh, en fin d'après-midi, un cadavre de zombie en costume sur le trottoir.
- **Tenue** : la même qu'en 1.
- **Mise en scène** : fenêtre de butin du cadavre ouverte, clic droit sur la veste de costume → menu « Check clothes size » en surbrillance. Avant lecture, l'infobulle affiche « ??? » à la place de la taille. Une seconde prise peut montrer la bulle du personnage après lecture de l'étiquette.
- **Légende** : *Loot a suit, check the label. All clothes on one corpse share a size.*

## 3. « Blisters » — des chaussures trop petites

- **But** : les effets des pointures : inconfort, ampoules, écran du personnage.
- **Lieu** : route de campagne à la sortie de Riverside, à l'aube, avec un peu de brume.
- **Tenue** : survivant mal fagoté avec `Jacket_Padded`, bottes de travail en 42 (une pointure trop petite).
- **Mise en scène** :
  - écran du personnage, onglet Info : le mod y ajoute la pointure à côté du poids ;
  - moodle d'inconfort visible ;
  - infobulle des bottes : « Size 42 (Tight) » ;
  - fenêtre de santé avec une ampoule au pied bandée.
- **Cadrage** : fenêtres à gauche, personnage en marche sur la route à droite.
- **Légende** : *Shoes one size too small? Enjoy the blisters.*

## 4. « The tailor's shop » — la machine à pédale et son panneau

- **But** : la machine à pédale et son panneau, onglet Patron.
- **Lieu** : atelier de couture de Riverside, machine à pédale posée contre un mur, près de la fenêtre.
- **Tenue** : tenue d'atelier complète (voir la garde-robe), mètre ruban en main.
- **Mise en scène** : panneau ouvert sur l'onglet **Pattern**.
  - Un patron de veste dans l'emplacement, taille M, quantité 3.
  - On voit l'icône du vêtement produit et la liste exacte des objets consommés.
  - Barre d'état de la machine vers 85 %.
- **Cadrage** : panneau à droite, personnage face à la machine à gauche.
- **Légende** : *A treadle machine needs no power. Pick a pattern, a size, a quantity.*

## 5. « Sewing at night » — la machine électrique et son bruit

- **But** : couture en série, progression dans le bouton, bruit qui attire les zombies.
- **Lieu** : atelier de tailleur de Muldraugh, la nuit. Lumière allumée (réseau ou groupe électrogène). Deux ou trois zombies derrière la vitre.
- **Tenue** : tenue d'atelier, cravate desserrée, sans lunettes (la lumière de la lampe éclaire le visage).
- **Mise en scène** : machine électrique sur une table, action lancée. Le bouton affiche « Sewing 2/5… 45% ». Les zombies sont collés à la fenêtre.
- **Cadrage** : fenêtre de l'atelier au premier plan si l'angle le permet, panneau du mod au centre droit.
- **Légende** : *Electric is twice as fast. It is also loud.*

## 6. « Cut it up » — tracer un patron

- **But** : le relevé d'un patron sur une table, avec destruction du modèle.
- **Lieu** : salle de couture d'une maison de Louisville (1er étage), ou table de cuisine d'une maison de Riverside.
- **Tenue** : tenue d'intérieur (chemise, pull en V, pantoufles, lunettes demi-lune), ciseaux en main, crayon dans l'autre.
- **Mise en scène**, deux prises (garder la meilleure) :
  - **a)** clic droit sur un blouson en cuir → « Trace a pattern ». L'infobulle montre les besoins cochés en vert : table, ciseaux, crayon, papier, Couture, et « The model is destroyed » ;
  - **b)** le personnage penché sur la table pendant l'action (animation de travail sur surface), barre de progression au-dessus de la tête.
- **Légende** : *To make a pattern, you cut the original apart.*

## 7. « One pattern, every size » — le résultat

- **But** : un même patron donne toutes les tailles.
- **Lieu** : comptoir de l'atelier de Riverside.
- **Tenue** : la même qu'en 4.
- **Mise en scène** :
  - poser sur le comptoir le même blouson en S, M, L et XL (objets au sol ou sur le meuble) ;
  - ouvrir l'infobulle du patron : utilisations restantes (5/5), précision, niveau requis ;
  - le personnage porte le blouson en M, bien ajusté, par-dessus la tenue d'atelier sans gilet.
- **Légende** : *Sew it in any size, from XS to XXL — mod clothes included.*

## 8. « Keep it running » — l'entretien

- **But** : l'état de la machine et l'entretien avec du matériel vanilla.
- **Lieu** : garage séparé de Riverside (6311,5371), la machine à pédale entre des étagères métalliques.
- **Tenue** : mécanique (salopette, gants de cuir, bottes de travail).
- **Mise en scène** :
  - panneau ouvert, barre d'état orange vers 32 % ;
  - bouton **Maintain** actif, avec l'infobulle : tournevis et huile d'olive (3 utilisations) cochés, compétence Mécanique ;
  - bouteille d'huile d'olive et tournevis visibles dans l'inventaire.
- **Légende** : *Machines wear out. A screwdriver and some cooking oil bring them back.*

## 9. « Found in the garage » — le butin

- **But** : on trouve les machines dans les lieux du quotidien.
- **Lieu** : grenier ou garage séparé de Muldraugh (10711,9707), la nuit, lampe torche allumée.
- **Tenue** : pillage (blouson matelassé, jean, ceinture, sac à dos).
- **Mise en scène** : fenêtre de butin d'une caisse ouverte, avec « Electric Sewing Machine » et son poids. Le personnage accroupi devant la caisse.
- **Légende** : *Check garages, attics and sewing shops. Machines are rare but real.*

## 10. « Cobbler, level 8 » — les chaussures

- **But** : les chaussures sur patron, réservées aux experts.
- **Lieu** : atelier de tailleur de Muldraugh, établi ou table.
- **Tenue** : cordonnier (chemise en jean, tablier de cuir, mitaines de cuir, lunettes de lecture).
- **Mise en scène** : clic droit sur un patron de bottes en cuir → « Sew from pattern ». L'infobulle montre Couture 8, aiguille, **poinçon**, colle et cuir tanné, tous cochés en vert. Pointure proposée : 43, la sienne.
- **Légende** : *Shoes too: level 8, an awl, glue and leather.*

---

## Images optionnelles

- **Multijoueur** : deux survivants dans l'atelier de Riverside. L'un coud à la machine, l'autre essaie une veste (infobulle de taille). Légende : *Works in multiplayer: the server decides every size.*
- **Options sandbox** : page « My Tailor Is Rich » des options de partie, défilée pour montrer les options machines et butin. Utile pour les administrateurs de serveur. À placer en dernier.

## Ordre de la galerie et texte

1. Placer 5 en premier : la plus spectaculaire, elle sert souvent d'aperçu.
2. Puis 1, 4, 6, 7, 3, 8, 9, 10, 2.
3. Finir par les options sandbox.

Garder les légendes courtes, au présent, sans jargon de code.
