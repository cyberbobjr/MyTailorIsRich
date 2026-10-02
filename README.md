# My Tailor Is Rich — Clothing & Shoe Sizes

**Build 42.21 · Singleplayer & Multiplayer**

Clothes and shoes finally have sizes. Loot that doesn't fit, resize it with your tailoring skills, and think twice before sprinting in boots three sizes too big.

*Français plus bas.*

---

## Requirements

- **[TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672)** (required): the size and wear lines in item tooltips.
- **Incompatible** with [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356). This mod is a full rewrite of it for Build 42.21.
- **Compatible** with [Immersive Weighing](https://steamcommunity.com/sharedfiles/filedetails/?id=3791897755): when your weight is hidden, the size shown next to it is hidden too, since it follows your weight.

## Clothing sizes (XS to XXL)

- Your character's size follows their **weight**: XS ≤ 50 kg, S ≤ 65, M ≤ 75, L < 85, XL < 100, XXL ≥ 100.
- A found garment's size is **unknown**. Right-click it and choose **Check clothes size**. Reading the label may require some Tailoring; otherwise your character only guesses. Clothes in a corpse, a piece of furniture or a vehicle within reach are checked in place, without taking them; clothes on the floor are picked up first.
- **Check clothes size** has options for the selection, all clothes on the selected corpse, and all clothes on nearby accessible corpses. Shoes are included. Corpse checks never move you or take the clothes: each label takes its usual time. Items removed by another player before their turn are skipped. Group checks skip known sizes and hints you cannot yet improve with your current Tailoring level.
- Clothes on the same zombie corpse are within one size of each other: each piece is rolled around one reference size (same size most of the time, otherwise one size smaller or larger).
- Effects of a bad fit:
  - **too big**: less insulation, slower combat for tops, loose pants or skirts can **fall down** without a belt when both hands are busy, can make you **trip** when landing after a fence, even at walking pace (less often than when running);
  - **too small**: longer to put on, can **rip** when climbing, can make you **trip** after climbing a wall, muscle stiffness, and impossible to wear when far too small. If you gain weight, clothes that no longer fit come off.
- **Resize** a garment one size up (fabric strips) or down (paperclips) with needle, scissors and thread. Success depends on Tailoring and fabric.
- **Clothes wear out** over time (dirt, blood, wetness, tight fit). **Recondition** them with fabric strips or a spare copy of the same item.
- **Crafted clothes**: choose their size in the crafting window.
- **Clothes from other mods are sized automatically.** Known body locations use their usual profile. Any other garment (including new body locations added by mods) gets a size from what it covers: torso, legs, both, or feet for shoes. Accessories (hats, masks, gloves, jewelry, belts…), underwear and cosmetics stay unsized. Two sandbox lists handle the rest: extra body locations to size, and items to exclude.

## Shoe sizes (EU 35 to 47)

- Each character has a **fixed foot size** depending on sex: women 35–42, men 39–47. It is shown on the character screen next to your weight, with your clothing size (sandbox option; hidden when a mod hides your weight).
- Found shoes lean toward the usual wearer of the model. Work, army and hiking boots are mostly men's sizes; strapped and fancy shoes mostly women's. Shoes on a corpse match the zombie's sex.
- The size is printed inside the shoe: **Check clothes size** reads it without any skill.
- Improvised foot wraps (rags, burlap, denim, leather, tarp, twine) fit anyone. Crafted shoes are made to the crafter's size.

| Fit | Effects |
|---|---|
| 3+ sizes too small | Can't be worn |
| 1–2 sizes too small | **Discomfort** moodle, **blisters** (a friction gauge fills while walking, faster when running; your character warns you halfway), foot stiffness |
| Right size or 1 size bigger | Nothing |
| 2+ sizes too big | More **endurance** used when running, rare blisters, can make you **trip** after a fence or a wall, weaker **stomps** on downed zombies (down to barefoot level) |
| 3+ sizes too big | Discomfort, and you can **lose a shoe** when running, sprinting, vaulting, climbing or falling (more often with flip-flops and slippers, less with laced boots) |

A blister is a small foot scratch without zombie infection. Like any foot injury it slows you down until it heals, so bandage it.

## Sewing patterns

- Right-click a sized garment or pair of shoes: **Trace a pattern**. You need scissors, a pen or pencil and sheets of paper (more for complex clothes). Work at a table, desk, counter or workbench nearby: your character walks to it. The model must be in good condition (50% or more) and **is destroyed**: it is unpicked and cut up to transfer its pieces onto the paper.
- **Store-bought patterns** turn up in sewing shops, tailoring bookshelves and fashion bookstores. Each one is drawn at random among all the clothes and shoes that could be traced, **including those added by other mods**, with a good precision.
- Right-click the pattern: **Sew from pattern**, then pick any size (XS–XXL, or EU 35–47 for shoes). The new item comes out with its size known.
- Sewing **by hand** (patterns, resizing, reconditioning) needs a **thimble** in your inventory (sandbox option). Machines don't need one.
- Materials follow the fabric of the model: cotton (ripped sheets, cotton fabric roll), denim (denim strips, denim rolls) or leather (leather strips, tanned leather). Bigger sizes use more fabric. Leather work also accepts an awl and a sharp knife.
- **Precision**: the result can come out one size off (bigger or smaller). The risk goes from 50% down to 0% with the Tailoring level of the tracer plus that of the sewer.
- A pattern survives **5 sewings** (success or failure), then falls apart.
- Required Tailoring: garment difficulty + fabric (cotton 0, denim 1, leather 2); tracing needs one level less. **Shoes need level 8** (sandbox option), a needle **and an awl**, thread, **glue**, and leather or fabric depending on the model (trainers and slippers in cotton, the rest in leather); they are always sewn by hand. Rubber or plastic shoes (wellies, flip-flops) have no pattern.
- No pattern for ballistic protection or items without a sewable fabric.

## Pattern binder, copies and 3D preview

- **Pattern Binder**: holds up to 20 patterns (sandbox option), each with its uses and precision. Craft it with **Make Pattern Binder** (Tailoring category: scissors and needle kept, 1 thread, 2 fabric strips of cotton, denim or leather, 2 sheets of paper), or find it on sewing shelves. It weighs 0.3 kg plus 0.1 kg per pattern.
- Right-click a pattern: **Store in binder**. Right-click the binder: **Patterns (n/max)** lists each stored pattern with **Sew from pattern**, **Take out** and **Preview on me**, and **Store all patterns** files every loose pattern you carry.
- A sewing machine's Pattern tab also lists the clothing patterns stored in your binders and sews straight from them. Shoe patterns stored in a binder are sewn by hand from the binder menu.
- **Copy pattern**: same needs as tracing (scissors, pen or pencil, sheets of paper, a table nearby, the tracing Tailoring level). The original is kept. The copy loses 1 Tailoring level of precision (sandbox option, never below 0) and gets fresh uses; a copy of a copy loses it again. Copy a pattern after taking it out of the binder.
- **Preview on me**: a window shows your character (sex, skin, hair, outfit) wearing the garment or shoes of the pattern, in 3D. Drag with the mouse or use the arrow keys to rotate it; **Keep my other clothes on** toggles the rest of your outfit. Clothes from other mods are supported. Nothing is actually worn: the preview is client-side only.

## Dyeing and embroidery

- **Dye**: right-click a garment or shoes, pick one of the dyes you carry (**industrial dye** or **hair dye**, with a color swatch). You also need water: 2, 4 or 6 L depending on the garment's size, and 0.2 to 0.75 L of dye. The garment is taken off if worn, takes the color of the dye and comes out soaked. No skill needed; a little Tailoring XP.
- What can be dyed: any garment whose clothing model accepts a tint (`AllowRandomTint`), **vanilla or from other mods**, plus the clothes the vanilla **Dye Clothes** recipe accepts. Printed, camouflage or patterned clothes keep their texture colors, so the option is greyed out with an explanation (shown only when you carry a dye).
- **Embroider a name** (needle, 1 thread, thimble if required, Tailoring 1): type up to 24 characters; the garment is renamed (for example `Jacket "Bob"`) and its tooltip shows the embroidery. **Unpick the embroidery** with scissors brings the old name back. Not for shoes or rigid armor. You can also embroider on a sewing machine (**Embroidery** tab, see below); unpicking is always done by hand.
- In multiplayer, the server checks and applies everything. Other players see a dyed garment once it is put on.

## Sewing machines

- Two placeable machines: an **electric sewing machine** that sits on any table, and a heavy **treadle sewing machine** in its cast-iron cabinet that stands on its own. Both are found in sewing workshops and fabric shops, clothing and department stores, the bedding aisle of supermarkets, people's storage (garages, detached or attached, storage units, attics, sheds, storage rooms, closets) and, more rarely, wherever a sewing kit can turn up; the treadle one also among antiques. Pick them up and place them like any furniture.
- Click a machine (or right-click it) to open its panel, with four tabs:
  - **Pattern**: drag a clothing pattern into the slot (or click the slot to choose one), pick the size and the **quantity** to sew in a row. The panel shows the garment that will come out and the exact list of items used, and remembers the last pattern you used.
  - **Resize**: let out or take in a garment.
  - **Recondition**: repair a worn garment with fabric strips or a spare one.
  - **Embroidery**: drag a garment into the slot (or click to choose one), type the text (your character's first name to start with, up to 24 characters) and check the name it will get. Needle and thread, no thimble. **Electric**: twice as fast as by hand, Tailoring 1 counting the machine's bonus levels. **Treadle**: straight stitch only, so it takes real skill: **Tailoring 3** (the machine's bonus does not count), 25% faster than by hand. One use of thread either way. A garment that is already embroidered is shown as such: unpick it by hand with scissors first. This tab is hidden when embroidery is disabled in the sandbox options.
- The button shows the progress ("Sewing 2/5… 45%"). Your character walks to the machine and works facing it.
- **Electric**: needs **power** (the grid indoors, or a generator); twice as fast, +2 Tailoring levels, more precise size, 30% less thread. **Treadle**: no power needed; 25% faster, +1 level, 15% less thread.
- **Noise**: a running machine can be heard by zombies (the electric one much further than the treadle one).
- **Maintenance**: machines wear out with use; below 50% they are less reliable, sometimes **break the needle** you hold, and **jam** at 0%. Their **condition** is shown in the panel (bar and percentage). **Service** them with a screwdriver and a little cooking oil (vegetable or olive); the repair skill is Electrical for the electric machine, Mechanics for the treadle one. The machine keeps its wear when moved.

## Multiplayer

The server decides everything: sizes, resizing, wear, blisters, stiffness and lost shoes. It then syncs the result to clients. All timed actions run through the vanilla Build 42 network system.

## Sandbox options

Tailoring level requirement, tailoring XP, action time, rip / drop / trip / stiffness multipliers, insulation and combat penalties, clothes degrading (on/off, min/max days, failure chance, protection and resistance loss), custom clothes list, **extra sized body locations**, **excluded clothes**, **shoe sizes on/off**, **your size shown on the character screen**, **shoe fit effects intensity** (0 disables blisters, discomfort, extra endurance and lost shoes), **sewings per pattern**, **Tailoring level for shoe patterns**, **thimble for hand sewing**, **sewing machine bonus**, **machine noise**, **machine maintenance**, **sewing loot rarity**, **pattern copies**, **precision lost per copy**, **patterns per binder**, **enable dyeing**, **enable embroidery**.

## Debug

In debug mode, or in MP with a role allowed to edit items, right-click a garment or shoes and open **[Debug] Size**. It shows your size, foot size, friction gauge and stomp power, lets you set any size, or clears it for a new roll.

## Good to know

- In Build 42.21 the vanilla clothing **RunSpeedModifier** is only shown in tooltips and never applied to movement. Only bags actually use it. This mod slows you down the way the engine allows: foot injuries (blisters) and endurance.
- Arm soreness after fights comes from **vanilla shoving**: every push adds arm strain. Tight tops only make it last longer.

## Removing the mod from a save

Don't just disable the mod in an existing save. The game records the two sewing machines (`Base.MTIR_SewingMachine`, `Base.MTIR_TreadleMachine`) in the save's `WorldDictionary.bin` and, in Build 42.21, never clears that record. Once the mod is gone, every multiplayer client, co-op host included, is refused with `[SpriteConfigs] Missing dictionary script on client: Base.MTIR_TreadleMachine`.

The Workshop item ships a second mod for this: **`batman_MyTailorIsRich_Uninstall`**.

1. In the save's mod list (or the server's `Mods=` line), replace `batman_MyTailorIsRich` with `batman_MyTailorIsRich_Uninstall`. Keep the Workshop item subscribed.
2. Keep it enabled for good in that save: removing it brings the error back.
3. Never enable both mods together (they are declared incompatible).

It contains no code: only the machine tiles and entities, so placed machines stay in the world as plain furniture (no sewing panel), and picked-up machines stay valid items. Clothes keep their sizes in their data but have no effect anymore. Patterns and other items of the mod disappear, as with any removed mod.

## Languages

English, French, German, Spanish, Portuguese (Brazil and Portugal), Russian and Simplified Chinese. Corrections from native speakers are welcome.

## Development

`python tests/run_tests.py` checks the mod without starting the game: luacheck (`.luacheckrc`), Lua 5.1 syntax (Kahlua's language) and calls to `next()`, which Kahlua lacks, the translations (valid JSON, same keys and `%1` parameters as English, no lone `%`), the Steam descriptions (`README.steam*`: at most 8,000 UTF-8 bytes, balanced BBCode, same links as English, `workshop.txt` in sync), and Lua tests run under [lupa](https://pypi.org/project/lupa/) with a mocked game API (`tests/lua/test_*.lua`). Requirements: `pip install lupa`, and luacheck. Tests that read the vanilla loot tables need the game: set `PZ_MEDIA` to its `media` folder; they are skipped otherwise. GitHub Actions runs the same checks on every push.

## Credits

Based on [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) by **Gootube** (Workshop 3491510356), including its sounds. It was rewritten and ported to Build 42.21 with multiplayer support, then expanded with shoe sizes and sewing patterns. Tooltips by **TooltipLib**.

## License

The mod's code, translations and images are released under the [MIT License](LICENSE). The four sound files in `media/sound` come from [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) by Gootube and remain the property of their authors: the MIT License does not cover them. Sewing machine sounds: electric machine by Joseph Sardin ([BigSoundBank](https://bigsoundbank.com/sewing-machine-slow-speed-s1115.html), CC0); treadle machine by Work With Sounds / Museum of Municipal Engineering ([Wikimedia Commons](https://commons.wikimedia.org/wiki/File:WWS_Glovemakermachinesewing2.ogg), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)), trimmed into loops.

---

# Français

**Build 42.21 · Solo et multijoueur**

Les vêtements et les chaussures ont enfin une taille. Trouvez ce qui vous va, retouchez le reste, et réfléchissez avant de sprinter avec des bottes trois pointures trop grandes.

## Prérequis

- **[TooltipLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3694097672)** (obligatoire) : les lignes de taille et d'usure dans les infobulles.
- **Incompatible** avec [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356), dont ce mod est une réécriture complète pour la Build 42.21.
- **Compatible** avec [Immersive Weighing](https://steamcommunity.com/sharedfiles/filedetails/?id=3791897755) : quand le poids est caché, la taille affichée à côté l'est aussi, puisqu'elle découle du poids.

## Tailles de vêtements (XS à XXL)

- La taille du personnage suit son **poids** : XS ≤ 50 kg, S ≤ 65, M ≤ 75, L < 85, XL < 100, XXL ≥ 100.
- La taille d'un vêtement trouvé est **inconnue** : clic droit, **Lire l'étiquette**. Il faut parfois un peu de Couture ; sinon le personnage devine seulement.
- **Lire l'étiquette** propose la sélection, tous les vêtements du cadavre sélectionné et ceux des cadavres accessibles à proximité, chaussures comprises. Les lectures sur cadavre ne déplacent ni le personnage ni les vêtements ; chaque étiquette conserve sa durée habituelle. Un vêtement retiré avant son tour est ignoré. Les lectures groupées ignorent les tailles connues et les indices que le niveau de Couture actuel ne permet pas encore de préciser.
- Les vêtements d'un même cadavre ont au plus une taille d'écart : chaque pièce est tirée autour d'une taille de référence (le plus souvent la même, sinon une taille en dessous ou au-dessus).
- Effets d'une mauvaise taille :
  - **trop grand** : moins d'isolation, combat ralenti pour les hauts, un bas trop grand peut **tomber** sans ceinture quand on a les deux mains prises, risque de **trébucher** à la réception d'une clôture, même au pas (moins souvent qu'en courant) ;
  - **trop petit** : plus long à enfiler, peut se **déchirer** en escaladant, risque de **trébucher** après avoir escaladé un mur, courbatures, impossible à porter s'il est beaucoup trop petit. Si vous grossissez, les vêtements devenus trop petits s'enlèvent.
- **Retouche** : un cran de plus (bandes de tissu) ou de moins (trombones), avec aiguille, ciseaux et fil. La réussite dépend de la Couture et du tissu.
- Les **vêtements s'usent** (saleté, sang, humidité, vêtement serré). Remettez-les en état avec des bandes de tissu ou un exemplaire de rechange.
- **Vêtements fabriqués** : la taille se choisit dans la fenêtre d'artisanat.
- **Les vêtements des autres mods ont une taille automatiquement.** Un emplacement connu garde son profil habituel. Tout autre vêtement, y compris sur un emplacement créé par un mod, reçoit une taille d'après ce qu'il couvre : torse, jambes, les deux, ou les pieds pour une chaussure. Les accessoires (chapeaux, masques, gants, bijoux, ceintures…), les sous-vêtements et le cosmétique restent sans taille. Deux listes sandbox règlent le reste : emplacements supplémentaires à tailler, objets à exclure.

## Pointures de chaussures (EU 35 à 47)

- Chaque personnage a une **pointure fixe** selon son sexe : 35-42 pour les femmes, 39-47 pour les hommes. Elle s'affiche dans l'écran Personnage, après le poids, avec la taille de vêtements (option sandbox ; masquée quand un mod cache le poids).
- Les chaussures trouvées suivent le porteur habituel du modèle. Bottes de travail, militaires et de randonnée : surtout des pointures d'homme. Chaussures à brides et habillées : surtout de femme. Sur un cadavre, la pointure suit le sexe du zombie.
- La pointure est imprimée dans la chaussure : **Lire l'étiquette** la donne sans compétence.
- Les enveloppes improvisées (chiffon, jute, jean, cuir, bâche, ficelle) vont à tout le monde. Les chaussures fabriquées sont à la pointure de l'artisan.

| Ajustement | Effets |
|---|---|
| Trop petites de 3 pointures ou plus | Impossibles à enfiler |
| Trop petites de 1 ou 2 pointures | Humeur **Inconfort**, **ampoules** (une jauge de frottement monte en marchant, plus vite en courant ; le personnage prévient à mi-chemin), courbatures aux pieds |
| Bonne pointure ou une de plus | Rien |
| Trop grandes de 2 pointures ou plus | Plus d'**endurance** dépensée en courant, ampoules rares, risque de **trébucher** après une clôture ou un mur, **écrasement** des zombies au sol moins puissant (jusqu'au niveau pieds nus) |
| Trop grandes de 3 pointures ou plus | Inconfort, et la chaussure peut **s'échapper** en courant, en sprintant, en sautant, en escaladant ou en tombant (plus souvent avec des tongs ou des pantoufles, moins avec des bottes lacées) |

Une ampoule est une petite égratignure au pied, sans infection zombie. Comme toute blessure au pied, elle ralentit tant qu'elle n'est pas guérie : pansez-la.

## Patrons de couture

- Clic droit sur un vêtement ou une paire de chaussures ayant une taille : **Tracer un patron**. Il faut des ciseaux, un stylo ou un crayon et des feuilles de papier (plus pour un vêtement complexe). On travaille à une table, un bureau, un comptoir ou un établi proche : le personnage s'y rend. Le modèle doit être en bon état (50 % ou plus) et **il est détruit** : on le découd et on le découpe pour reporter ses pièces sur le papier.
- Des **patrons du commerce** se trouvent dans les merceries, les rayons couture et les librairies de mode. Chacun est tiré au hasard parmi tous les vêtements et chaussures traçables, **y compris ceux des autres mods**, avec une bonne précision.
- Clic droit sur le patron : **Coudre d'après le patron**, puis choisissez la taille (XS à XXL, ou 35 à 47 pour les chaussures). L'objet obtenu a une taille connue.
- Coudre **à la main** (patrons, retouches, remises en état) demande un **dé à coudre** dans l'inventaire (option sandbox). Les machines n'en ont pas besoin.
- Les matériaux suivent le tissu du modèle : coton (draps déchirés, rouleau de coton), jean (bandes de jean, rouleaux de jean) ou cuir (lanières de cuir, cuir tanné). Une grande taille demande plus de tissu. Pour le cuir, une alêne et un couteau aiguisé conviennent aussi.
- **Précision** : l'objet peut sortir avec une taille d'écart, plus grand ou plus petit. Le risque passe de 50 % à 0 % selon le niveau de Couture du traceur et celui de la couturière ou du couturier.
- Un patron supporte **5 coutures** (réussies ou non), puis part en morceaux.
- Couture requise : difficulté du vêtement + tissu (coton 0, jean 1, cuir 2) ; le tracé demande un niveau de moins. **Les chaussures demandent le niveau 8** (option sandbox), une aiguille **et un poinçon**, du fil, **de la colle**, et du cuir ou du tissu selon le modèle (baskets et chaussons en coton, le reste en cuir) ; elles se cousent toujours à la main. Les chaussures en caoutchouc ou en plastique (bottes de pluie, tongs) n'ont pas de patron.
- Pas de patron pour une protection balistique ni pour un objet sans tissu cousable.

## Classeur à patrons, copies et aperçu 3D

- **Classeur à patrons** : il range jusqu'à 20 patrons (option sandbox), chacun avec ses utilisations et sa précision. Recette **Fabriquer un classeur à patrons** (catégorie Couture : ciseaux et aiguille conservés, 1 fil, 2 bandes de tissu de coton, de jean ou de cuir, 2 feuilles de papier), ou butin des rayons couture. Il pèse 0,3 kg plus 0,1 kg par patron.
- Clic droit sur un patron : **Ranger dans le classeur**. Clic droit sur le classeur : **Patrons (n/max)** liste chaque patron rangé avec **Coudre d'après le patron**, **Sortir** et **Aperçu sur moi** ; **Ranger tous les patrons** y range tous les patrons portés.
- L'onglet Patron d'une machine à coudre propose aussi les patrons de vêtements rangés dans les classeurs et coud directement depuis eux. Les patrons de chaussures rangés se cousent à la main depuis le menu du classeur.
- **Copier le patron** : mêmes besoins que le relevé (ciseaux, stylo ou crayon, feuilles, table proche, niveau de Couture du relevé). L'original est conservé. La copie perd 1 niveau de précision (option sandbox, jamais sous 0) et reçoit des utilisations neuves ; une copie de copie en perd encore. Sortir le patron du classeur avant de le copier.
- **Aperçu sur moi** : une fenêtre montre le personnage (sexe, peau, cheveux, tenue) portant en 3D le vêtement ou les chaussures du patron. Glisser à la souris ou flèches pour le faire tourner ; **Garder mes autres vêtements** affiche ou retire le reste de la tenue. Vêtements des autres mods pris en charge. Rien n'est réellement porté : l'aperçu est purement local.

## Teinture et broderie

- **Teindre** : clic droit sur un vêtement ou des chaussures, choisir l'une des teintures portées (**colorant industriel** ou **teinture pour cheveux**, avec une pastille de sa couleur). Il faut aussi de l'eau : 2, 4 ou 6 L selon la taille du vêtement, et 0,2 à 0,75 L de teinture. Le vêtement est retiré s'il est porté, prend la couleur et ressort trempé. Aucune compétence requise ; un peu d'XP de Couture.
- Ce qui se teint : tout vêtement dont le modèle accepte une teinte (`AllowRandomTint`), **vanilla ou d'un autre mod**, plus les vêtements acceptés par la recette vanilla **Teindre les vêtements**. Les vêtements imprimés, camouflés ou à motifs gardent les couleurs de leur texture : l'option est grisée avec une explication (affichée seulement si l'on porte une teinture).
- **Broder un nom** (aiguille, 1 fil, dé à coudre si l'option l'exige, Couture 1) : jusqu'à 24 caractères ; le vêtement est renommé (par exemple `Veste « Bob »`) et son infobulle affiche la broderie. **Découdre la broderie** aux ciseaux rend l'ancien nom. Pas pour les chaussures ni les protections rigides. On peut aussi broder sur une machine à coudre (onglet **Broderie**, voir plus bas) ; le décousage se fait toujours à la main.
- En multijoueur, le serveur vérifie et applique tout. Les autres joueurs voient un vêtement teint une fois qu'il est enfilé.

## Machines à coudre

- Deux machines posables : une **machine à coudre électrique**, qui se pose sur n'importe quelle table, et une lourde **machine à pédale** dans son meuble en fonte, autonome. On les trouve dans les ateliers de couture et les merceries, les magasins de vêtements et les grands magasins, le rayon linge des supermarchés, le stockage des particuliers (garages séparés ou attenants, box de stockage, greniers, abris de jardin, réserves, placards) et, plus rarement, partout où l'on trouve un kit de couture ; celle à pédale aussi parmi les antiquités. Elles se ramassent et se posent comme des meubles.
- Cliquez sur une machine (ou clic droit) pour ouvrir son panneau à quatre onglets :
  - **Patron** : glissez un patron de vêtement dans l'emplacement (ou cliquez dessus pour en choisir un), choisissez la taille et la **quantité** à coudre à la suite. Le panneau montre le vêtement produit et la liste exacte des objets utilisés, et se souvient du dernier patron utilisé.
  - **Retouche** : agrandir ou rétrécir un vêtement.
  - **Remise en état** : réparer un vêtement usé avec des bandes de tissu ou un exemplaire de rechange.
  - **Broderie** : glissez un vêtement dans l'emplacement (ou cliquez pour en choisir un), saisissez le texte (prérempli avec le prénom du personnage, 24 caractères au plus) et vérifiez le nom obtenu. Aiguille et fil, sans dé à coudre. **Électrique** : deux fois plus rapide qu'à la main, Couture 1 en comptant les niveaux de bonus de la machine. **À pédale** : point droit seulement, il faut donc du métier : **Couture 3** (le bonus de la machine ne compte pas), 25 % plus rapide qu'à la main. Une utilisation de fil dans les deux cas. Un vêtement déjà brodé est signalé : découdre d'abord à la main, aux ciseaux. L'onglet est masqué si la broderie est désactivée dans les options sandbox.
- Le bouton affiche la progression (« Couture 2/5… 45 % »). Le personnage se rend à la machine et travaille face à elle.
- **Électrique** : demande du **courant** (réseau à l'intérieur, ou groupe électrogène) ; deux fois plus rapide, +2 niveaux de Couture, taille plus précise, 30 % de fil en moins. **À pédale** : sans courant ; 25 % plus rapide, +1 niveau, 15 % de fil en moins.
- **Bruit** : une machine en marche s'entend par les zombies (l'électrique bien plus loin que celle à pédale).
- **Entretien** : les machines s'usent ; sous 50 % elles sont moins fiables, **cassent parfois l'aiguille** tenue en main et se **bloquent** à 0 %. Leur **état** s'affiche dans le panneau (barre et pourcentage). **Entretenez-les** avec un tournevis et un peu d'huile de cuisine (végétale ou d'olive) ; la compétence utilisée est l'Électricité pour l'électrique, la Mécanique pour celle à pédale. La machine garde son usure quand on la déplace.

## Multijoueur

Le serveur décide de tout : tailles, retouches, usure, ampoules, courbatures, chaussures perdues. Il synchronise ensuite le résultat vers les clients. Toutes les actions passent par le système réseau vanilla de la Build 42.

## Options sandbox

Niveau de couture requis, XP de couture, durée des actions, multiplicateurs de déchirure, de chute du vêtement, de chute et de raideur, pertes d'isolation et de vitesse de combat, usure (activation, jours min/max, usure en cas d'échec, pertes de protection et de résistance), liste de vêtements supplémentaires, **emplacements supplémentaires**, **vêtements exclus**, **pointures activées ou non**, **taille affichée dans l'écran Personnage**, **intensité des effets des chaussures** (0 coupe ampoules, inconfort, endurance supplémentaire et pertes de chaussures), **coutures par patron**, **niveau de Couture des patrons de chaussures**, **dé à coudre pour coudre à la main**, **bonus des machines**, **bruit des machines**, **entretien des machines**, **rareté du butin de couture**, **copies de patrons**, **précision perdue par copie**, **patrons par classeur**, **teinture**, **broderie**.

## Débogage

En mode debug, ou en MP avec un rôle autorisé à éditer les objets : clic droit sur un vêtement ou une paire, **[Debug] Taille**. Le menu affiche votre taille, votre pointure, la jauge de frottement et la force d'écrasement. Il permet de fixer n'importe quelle taille ou de l'effacer pour un nouveau tirage.

## À savoir

- En Build 42.21, le **RunSpeedModifier** vanilla des vêtements est seulement affiché dans l'infobulle, jamais appliqué au déplacement. Seuls les sacs l'utilisent vraiment. Ce mod ralentit donc par les moyens que le moteur permet : blessures aux pieds (ampoules) et endurance.
- Les courbatures aux bras après un combat viennent des **poussées vanilla** : chaque poussée sollicite les bras. Un haut trop serré les fait seulement durer plus longtemps.

## Retirer le mod d'une partie

Ne désactivez pas simplement le mod dans une partie existante. Le jeu inscrit les deux machines à coudre (`Base.MTIR_SewingMachine`, `Base.MTIR_TreadleMachine`) dans le `WorldDictionary.bin` de la sauvegarde et, en Build 42.21, n'efface jamais cette inscription. Une fois le mod retiré, tout client multijoueur, hôte d'une partie coopérative compris, est refusé avec `[SpriteConfigs] Missing dictionary script on client: Base.MTIR_TreadleMachine`.

L'objet du Workshop contient pour cela un second mod : **`batman_MyTailorIsRich_Uninstall`**.

1. Dans la liste de mods de la partie (ou la ligne `Mods=` du serveur), remplacez `batman_MyTailorIsRich` par `batman_MyTailorIsRich_Uninstall`. Restez abonné à l'objet du Workshop.
2. Gardez-le activé définitivement dans cette partie : le retirer ramène l'erreur.
3. N'activez jamais les deux mods ensemble (ils sont déclarés incompatibles).

Il ne contient aucun code : seulement les tuiles et entités des machines. Les machines posées restent donc dans le monde comme simples meubles (sans panneau de couture), et les machines ramassées restent des objets valides. Les vêtements gardent leur taille dans leurs données, sans plus aucun effet. Les patrons et autres objets du mod disparaissent, comme pour tout mod retiré.

## Langues

Anglais, français, allemand, espagnol, portugais (Brésil et Portugal), russe et chinois simplifié. Les corrections de locuteurs natifs sont bienvenues.

## Développement

`python tests/run_tests.py` vérifie le mod sans lancer le jeu : luacheck (`.luacheckrc`), syntaxe Lua 5.1 (le langage de Kahlua) et appels à `next()`, absente de Kahlua, traductions (JSON valide, mêmes clés et mêmes paramètres `%1` que l'anglais, pas de `%` seul), descriptions Steam (`README.steam*` : 8 000 octets UTF-8 au plus, BBCode équilibré, mêmes liens que l'anglais, `workshop.txt` synchronisé), et tests Lua exécutés sous [lupa](https://pypi.org/project/lupa/) avec l'API du jeu simulée (`tests/lua/test_*.lua`). Prérequis : `pip install lupa`, et luacheck. Les tests qui lisent les tables de butin vanilla demandent le jeu : définir `PZ_MEDIA` vers son dossier `media`, sinon ils sont ignorés. GitHub Actions lance les mêmes vérifications à chaque push.

## Crédits

Basé sur [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) de **Gootube** (Workshop 3491510356), dont il reprend les sons. Réécrit et porté en Build 42.21 avec le multijoueur, puis enrichi des pointures de chaussures et des patrons de couture. Infobulles par **TooltipLib**.

## Licence

Le code, les traductions et les images du mod sont publiés sous [licence MIT](LICENSE). Les quatre sons de `media/sound` viennent de [Realistic Clothes](https://steamcommunity.com/sharedfiles/filedetails/?id=3491510356) de Gootube et restent la propriété de leurs auteurs : la licence MIT ne les couvre pas. Sons des machines à coudre : machine électrique de Joseph Sardin ([BigSoundBank](https://bigsoundbank.com/sewing-machine-slow-speed-s1115.html), CC0) ; machine à pédale de Work With Sounds / Museum of Municipal Engineering ([Wikimedia Commons](https://commons.wikimedia.org/wiki/File:WWS_Glovemakermachinesewing2.ogg), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)), découpés en boucles.
